-- DataService: loads, caches, syncs and saves player data with DataStoreService.
--
-- Safety features
--   * Session locking: a profile is "owned" by one server (JobId). If the player
--     hops servers before the old server saved, we wait for the lock instead of
--     loading stale data (prevents item duplication / rollbacks).
--   * UpdateAsync everywhere (never SetAsync) so we never blindly overwrite.
--   * Retries with backoff; if loading truly fails we kick instead of handing the
--     player an empty profile that would overwrite their real save.
--   * Autosave + save on leave + BindToClose.
--   * In Studio without "Enable Studio Access to API Services", runs offline
--     (in-memory) and warns, so you can still play-test.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)
local Net = require(Shared.Net)

local DataService = {}
DataService.Profiles = {} :: { [Player]: any }
DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.ProfileReleasing = Signal.new() -- (player, profile)
DataService.Offline = false

local TEMPLATE = {
	Version = Config.DataVersion,
	Level = 1,
	XP = 0,
	Coins = 0,
	TotalKills = 0,
	BossKills = 0,
	ArenaKOs = 0,
	TotalCoinsEarned = 0,
	Upgrades = { Power = 0, Vitality = 0, Speed = 0, Fortune = 0 },
	Inventory = {}, -- [uid] = { Id = coreId, Time = unix }
	NextUid = 1,
	Equipped = "", -- uid or ""
	Displayed = {}, -- { uid, ... }
	ItemsFound = {}, -- [coreId] = true  (collection index)
	Pity = 0,
	PendingIncome = 0,
	UnlockedZones = { Scrapyard = true },
	Quests = { Day = 0, Active = {} },
	Tutorial = { Step = 1, Progress = 0, Done = false },
	Daily = { LastClaimDay = 0, Streak = 0 },
	Settings = { Music = 0.5, Sfx = 0.8, DamageNumbers = true, CameraShake = true },
	LastOnline = 0,
}

DataService.Template = TEMPLATE -- exposed read-only for tests/tools

local store: DataStore? = nil
local dirty: { [Player]: boolean } = {}
local S

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
DataService.DeepCopy = deepCopy

-- Adds any keys that exist in the template but not in saved data (new features).
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function loadData(player: Player)
	if DataService.Offline or not store then
		return deepCopy(TEMPLATE)
	end
	local dataStore = store :: DataStore
	for attempt = 1, 8 do
		local locked = false
		local loaded = nil
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(player), function(old)
				local data = old or deepCopy(TEMPLATE)
				local lock = data.SessionLock
				-- After 5 locked attempts (~30s) we assume the other server died and steal the lock.
				if lock and lock.JobId ~= game.JobId and os.time() - lock.Time < Config.SessionLockTimeout and attempt < 6 then
					locked = true
					return nil -- cancel the write
				end
				data.SessionLock = { JobId = game.JobId, Time = os.time() }
				loaded = data
				return data
			end)
		end)
		if ok and loaded then
			return loaded
		end
		if not ok then
			warn(("[Torque] Load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		end
		if not player.Parent then
			return nil
		end
		task.wait(if locked then 6 else math.min(2 ^ attempt, 16))
	end
	return nil
end

local function saveProfile(player: Player, profile, release: boolean): boolean
	profile.Data.LastOnline = os.time()
	if DataService.Offline or not store then
		return true
	end
	local dataStore = store :: DataStore
	local snapshot = deepCopy(profile.Data)
	snapshot.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
	for attempt = 1, 4 do
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(player), function(old)
				if old and old.SessionLock and old.SessionLock.JobId ~= game.JobId then
					return nil -- another server owns this profile now; never overwrite it
				end
				return snapshot
			end)
		end)
		if ok then
			return true
		end
		warn(("[Torque] Save attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(err)))
		task.wait(attempt)
	end
	return false
end

function DataService:GetProfile(player: Player)
	return self.Profiles[player]
end

-- Queue a DataSync to the client (coalesced: at most one per player per frame).
function DataService:MarkDirty(player: Player)
	dirty[player] = true
end

-- What the client is allowed to see. Adds a few derived values for UI convenience.
local function buildClientView(profile)
	local view = deepCopy(profile.Data)
	view.SessionLock = nil
	view.ServerTime = os.time()
	view.DisplaySlots = Config.DisplaySlots(profile.Data.Level)
	view.IncomePerSecond = S.PlotService and S.PlotService:GetIncomePerSecond(profile) or 0
	view.OverdriveUntil = profile.Runtime.OverdriveServerTime or 0
	return view
end

local function flush()
	for player in dirty do
		dirty[player] = nil
		local profile = DataService.Profiles[player]
		if profile and player.Parent then
			Net.Event("DataSync"):FireClient(player, buildClientView(profile))
			local stats = player:FindFirstChild("leaderstats")
			if stats then
				(stats :: any).Level.Value = profile.Data.Level;
				(stats :: any).Coins.Value = profile.Data.Coins;
				(stats :: any).Kills.Value = profile.Data.TotalKills
			end
		end
	end
end

local function onPlayerAdded(player: Player)
	local data = loadData(player)
	if not player.Parent then
		if data then
			saveProfile(player, { Data = data }, true)
		end
		return
	end
	if not data then
		player:Kick("Torque couldn't load your data. Your progress is safe - please rejoin in a minute.")
		return
	end
	reconcile(data, TEMPLATE)
	data.Version = Config.DataVersion -- future data migrations go here

	local profile = {
		Player = player,
		Data = data,
		LastOnline = data.LastOnline, -- captured before any save overwrites it
		Runtime = { Cooldowns = {}, OverdriveUntil = 0, OverdriveServerTime = 0 },
	}
	DataService.Profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
	DataService:MarkDirty(player)
end

local function onPlayerRemoving(player: Player)
	local profile = DataService.Profiles[player]
	dirty[player] = nil
	if not profile then
		return
	end
	DataService.ProfileReleasing:Fire(player, profile)
	saveProfile(player, profile, true)
	DataService.Profiles[player] = nil
end

function DataService:Init(services)
	S = services
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	end
	if RunService:IsStudio() then
		-- Probe once: fails if Studio API access is disabled or the place is unpublished.
		local probeOk = ok and pcall(function()
			(store :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			DataService.Offline = true
			warn("[Torque] DataStores unavailable in Studio - running OFFLINE (progress won't save). "
				.. "Enable Game Settings > Security > 'Enable Studio Access to API Services' to test saving.")
		end
	elseif not ok then
		warn("[Torque] Could not get DataStore: " .. tostring(result))
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	RunService.Heartbeat:Connect(flush)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player, profile in DataService.Profiles do
				task.spawn(saveProfile, player, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		if DataService.Offline then
			return
		end
		local pending = 0
		for player, profile in DataService.Profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService

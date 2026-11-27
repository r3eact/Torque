-- ProgressionService: XP/levels, coins, leaderstats, and applying stats
-- (max health, walk speed) to characters. All currency changes go through here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ProgressionService = {}
local S

function ProgressionService:Init(services)
	S = services
end

local function createLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in { "Level", "Coins", "Kills" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = folder
	end
	folder.Parent = player
end

function ProgressionService:IsOverdrive(profile): boolean
	return profile.Runtime.OverdriveUntil > os.clock()
end

-- Applies level/upgrade based stats to the current character. Safe to call any time.
function ProgressionService:ApplyCharacterStats(player: Player, healFull: boolean?)
	local profile = S.DataService:GetProfile(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local d = profile.Data
	local maxHealth = Config.MaxHealth(d.Level, d.Upgrades.Vitality)
	local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	humanoid.MaxHealth = maxHealth
	humanoid.Health = if healFull then maxHealth else math.clamp(maxHealth * ratio, 1, maxHealth)
	local speed = Config.WalkSpeed(d.Upgrades.Speed)
	if self:IsOverdrive(profile) then
		speed += Config.Abilities.Overdrive.SpeedBuff
	end
	humanoid.WalkSpeed = speed
end

-- Coins earned from gameplay can be boosted by Fortune (applyFortune = true).
-- Returns the amount actually added.
function ProgressionService:AddCoins(player: Player, amount: number, applyFortune: boolean?): number
	local profile = S.DataService:GetProfile(player)
	if not profile or amount <= 0 then
		return 0
	end
	local d = profile.Data
	if applyFortune then
		amount *= Config.CoinMultiplier(d.Upgrades.Fortune)
	end
	amount = math.floor(amount)
	d.Coins += amount
	d.TotalCoinsEarned += amount
	S.DataService:MarkDirty(player)
	S.QuestService:Track(player, "EarnCoins", amount)
	return amount
end

function ProgressionService:SpendCoins(player: Player, amount: number): boolean
	local profile = S.DataService:GetProfile(player)
	if not profile or amount < 0 or profile.Data.Coins < amount then
		return false
	end
	profile.Data.Coins -= amount
	S.DataService:MarkDirty(player)
	return true
end

function ProgressionService:AddXP(player: Player, amount: number)
	local profile = S.DataService:GetProfile(player)
	if not profile or amount <= 0 then
		return
	end
	local d = profile.Data
	local oldLevel = d.Level
	d.XP += math.floor(amount)
	while d.Level < Config.Player.MaxLevel and d.XP >= Config.XPForLevel(d.Level) do
		d.XP -= Config.XPForLevel(d.Level)
		d.Level += 1
	end
	if d.Level >= Config.Player.MaxLevel then
		d.XP = 0
	end
	if d.Level > oldLevel then
		S.NetService:EffectAll({ Type = "LevelUp", Player = player, Level = d.Level })
		S.NetService:Notify(player, ("LEVEL UP! You are now Level %d"):format(d.Level), "levelup")
		for _, ability in Config.Abilities do
			if ability.UnlockLevel > oldLevel and ability.UnlockLevel <= d.Level then
				S.NetService:Notify(player, ("New ability unlocked: %s %s [%s]"):format(ability.Icon, ability.Name, ability.KeyLabel), "reward")
			end
		end
		if Config.DisplaySlots(d.Level) > Config.DisplaySlots(oldLevel) then
			S.NetService:Notify(player, "New Garage pedestal unlocked!", "reward")
			S.PlotService:RefreshDisplay(player)
		end
		self:ApplyCharacterStats(player, true)
	end
	S.DataService:MarkDirty(player)
end

function ProgressionService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			self:ApplyCharacterStats(player, true)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	S.DataService.ProfileLoaded:Connect(function(player)
		createLeaderstats(player)
		self:ApplyCharacterStats(player, true)
	end)
end

return ProgressionService

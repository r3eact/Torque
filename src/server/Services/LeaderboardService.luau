-- LeaderboardService: global "Top Bot Destroyers" board using an OrderedDataStore.
-- Writes each online player's kill count and reads the top 10 every 90 seconds
-- (well within DataStore budgets even on full servers).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local LeaderboardService = {}
local S
local nameCache: { [number]: string } = {}

function LeaderboardService:Init(services)
	S = services
end

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and name then name else ("Player " .. userId)
	nameCache[userId] = result
	return result
end

local function render(rows: { { name: string, value: number } })
	local board = S.WorldBuilder.World:FindFirstChild("KillsBoard")
	local gui = board and board:FindFirstChild("Board")
	if not gui then
		return
	end
	for i = 1, 10 do
		local label = gui:FindFirstChild("Row" .. i) :: TextLabel
		local row = rows[i]
		label.Text = if row then ("  #%d  %s  —  %s"):format(i, row.name, Format.Commas(row.value)) else ("  #%d  ---"):format(i)
	end
end

-- Fallback when DataStores are unavailable (Studio offline): rank current server.
local function renderLocal()
	local rows = {}
	for player, profile in S.DataService.Profiles do
		table.insert(rows, { name = player.Name, value = profile.Data.TotalKills })
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	render(rows)
end

function LeaderboardService:Start()
	local store: OrderedDataStore? = nil
	if not S.DataService.Offline then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(Config.KillsBoardStoreName)
		end)
		if ok then
			store = result
		end
	end

	while true do
		if store then
			local ordered = store :: OrderedDataStore
			for player, profile in S.DataService.Profiles do
				pcall(function()
					ordered:SetAsync(tostring(player.UserId), profile.Data.TotalKills)
				end)
			end
			local ok, pages = pcall(function()
				return ordered:GetSortedAsync(false, 10)
			end)
			if ok and pages then
				local rows = {}
				for _, entry in pages:GetCurrentPage() do
					table.insert(rows, { name = getName(tonumber(entry.key) or 0), value = entry.value })
				end
				render(rows)
			else
				renderLocal()
			end
		else
			renderLocal()
		end
		task.wait(if store then 90 else 15)
	end
end

return LeaderboardService

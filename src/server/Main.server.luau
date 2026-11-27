-- Main (Script in ServerScriptService/Server)
-- Boots every server service in a fixed order:
--   1. require all modules
--   2. :Init(services)  -- wire references, create instances (no yielding)
--   3. :Start()         -- connect events, start loops (each in its own thread)
local ServicesFolder = script.Parent:WaitForChild("Services")

local ORDER = {
	"RateLimiter",
	"NetService",
	"DataService",
	"WorldBuilder",
	"ProgressionService",
	"QuestService",
	"InventoryService",
	"ShopService",
	"DailyService",
	"ZoneService",
	"PlotService",
	"EnemyService",
	"CombatService",
	"LeaderboardService",
}

local services = {}
for _, name in ORDER do
	services[name] = require(ServicesFolder:WaitForChild(name))
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service:Init(services)
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print("[Torque] Server started")

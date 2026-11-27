-- TestRunner: executed by tests/run.sh (SOURCES is prepended by the script).
-- Loads real game modules inside a minimal fake Roblox environment and checks the
-- game rules: formatting, balance curves, data integrity, crate odds + pity,
-- the full tutorial flow, shop/upgrade validation, daily streaks and quests.
local SOURCES = SOURCES :: { [string]: string }

---------------------------------------------------------------- tiny test framework
local passed, failed = 0, 0
local function check(cond: boolean, name: string)
	if cond then
		passed += 1
	else
		failed += 1
		print("  ✗ FAIL: " .. name)
	end
end
local function eq(a, b, name)
	check(a == b, ("%s (got %s, expected %s)"):format(name, tostring(a), tostring(b)))
end
local function section(name)
	print("-- " .. name)
end

---------------------------------------------------------------- Roblox mocks
local Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
function Color3:Lerp(o, a)
	return Color3.new(self.R + (o.R - self.R) * a, self.G + (o.G - self.G) * a, self.B + (o.B - self.B) * a)
end
function Color3:ToHex()
	return string.format("%02X%02X%02X", self.R * 255, self.G * 255, self.B * 255)
end

local Vector3 = {}
Vector3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return Vector3[k]
end
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__mul = function(a, b) return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
function Vector3:Dot(o) return self.X * o.X + self.Y * o.Y + self.Z * o.Z end

-- Enum.Material.Slate -> "Enum.Material.Slate"
local Enum = setmetatable({}, {
	__index = function(_, group)
		return setmetatable({}, { __index = function(_, item) return "Enum." .. group .. "." .. item end })
	end,
})

-- Deterministic Random (LCG) so test runs are reproducible.
local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (seed or 12345) % 2147483647 + 1 }, Random)
end
function Random:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_next()
end
function Random:NextInteger(a, b)
	return math.min(b, a + math.floor(self:_next() * (b - a + 1)))
end

local fakeTime = 1_800_000_000 -- controllable clock for daily logic
local fakeOs = setmetatable({ time = function() return fakeTime end }, { __index = os })

local function fakeSignal()
	local handlers = {}
	return {
		Connect = function(_, fn) table.insert(handlers, fn) return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, fn in handlers do fn(...) end end,
	}
end

local task = {
	spawn = function(fn, ...) return fn(...) end,
	delay = function() end,
	wait = function() return 0 end,
}

---------------------------------------------------------------- module loader
-- Instances are faked as { __path = "shared" } tables; indexing builds child paths.
local moduleCache = {}
local function pathNode(path)
	return setmetatable({ __path = path }, {
		__index = function(self, child)
			return pathNode(rawget(self, "__path") .. "/" .. child)
		end,
	})
end
local services = {
	ReplicatedStorage = setmetatable({ Shared = pathNode("shared") }, { __index = function(_, k) return pathNode("ReplicatedStorage/" .. k) end }),
	Players = { PlayerAdded = fakeSignal(), PlayerRemoving = fakeSignal(), GetPlayers = function() return {} end },
	RunService = { IsServer = function() return true end, IsStudio = function() return true end, Heartbeat = fakeSignal() },
}
local game = {
	GetService = function(_, name)
		return services[name] or setmetatable({}, { __index = function() return function() end end })
	end,
	JobId = "test-job",
}

local loadModule
local function makeEnv()
	return setmetatable({
		Color3 = Color3, Vector3 = Vector3, Enum = Enum, Random = Random, os = fakeOs, task = task,
		game = game, typeof = function(v)
			local mt = getmetatable(v)
			if mt == Vector3 then return "Vector3" end
			return typeof(v)
		end,
		require = function(node) return loadModule(rawget(node, "__path")) end,
	}, { __index = _G })
end
function loadModule(path: string)
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	local source = SOURCES[path]
	assert(source, "no source for " .. path)
	local fn, err = loadstring(source, path)
	assert(fn, err)
	setfenv(fn, makeEnv())
	local result = fn()
	moduleCache[path] = result
	return result
end

-- Net creates real RemoteEvents; replace it with a stub for tests.
local stubRemote = setmetatable({}, { __index = function() return function() end end })
moduleCache["shared/Net"] = { Event = function() return stubRemote end, Function = function() return stubRemote end }

local Format = loadModule("shared/Format")
local Config = loadModule("shared/Config")
local ItemData = loadModule("shared/ItemData")
local ZoneData = loadModule("shared/ZoneData")
local QuestData = loadModule("shared/QuestData")

---------------------------------------------------------------- shared modules
section("Format")
eq(Format.Short(999), "999", "Short 999")
eq(Format.Short(1000), "1K", "Short 1000")
eq(Format.Short(1234), "1.23K", "Short 1234")
eq(Format.Short(100000), "100K", "Short 100000")
eq(Format.Short(1500000), "1.5M", "Short 1.5M")
eq(Format.Short(12000000000), "12B", "Short 12B")
eq(Format.Commas(1234567), "1,234,567", "Commas")
eq(Format.Commas(-1000), "-1,000", "Commas negative")
eq(Format.Commas(100), "100", "Commas small")
eq(Format.Time(3725), "1h 02m", "Time h")
eq(Format.Time(125), "2m 05s", "Time m")
eq(Format.Time(9), "9s", "Time s")

section("Config curves")
local prev = 0
local monotonic = true
for level = 1, Config.Player.MaxLevel do
	local xp = Config.XPForLevel(level)
	if xp <= prev then monotonic = false end
	prev = xp
end
check(monotonic, "XP curve strictly increasing")
eq(Config.XPForLevel(1), 40, "Level 1 -> 2 needs 40 XP (~4 bots)")
eq(Config.DisplaySlots(1), 3, "3 pedestals at level 1")
eq(Config.DisplaySlots(9), 4, "4 pedestals at level 9")
eq(Config.DisplaySlots(200), Config.Player.MaxDisplaySlots, "pedestals capped")
eq(Config.MaxHealth(1, 0), 100, "base health")
check(Config.UpgradeCost("Power", 1) > Config.UpgradeCost("Power", 0), "upgrade cost grows")
for id, ability in Config.Abilities do
	check(ability.Cooldown > 0 and ability.UnlockLevel >= 1, "ability sane: " .. id)
end

section("Item data")
for crateId, crate in ItemData.Crates do
	local total = 0
	for rarity, pct in ItemData.GetOdds(crateId) do
		total += pct
		check(ItemData.ByRarity[rarity] ~= nil and #ItemData.ByRarity[rarity] > 0, crateId .. " rarity has items: " .. rarity)
	end
	check(math.abs(total - 100) < 1e-6, crateId .. " odds sum to 100%")
	check(ZoneData.ById[crate.RequiredZone] ~= nil, crateId .. " required zone exists")
end
for id, core in ItemData.Cores do
	check(Config.Rarities[core.Rarity] ~= nil, "core rarity valid: " .. id)
	check(core.SellValue > 0 and core.Income > 0 and core.DamageMult >= 1, "core stats sane: " .. id)
end

section("Zone data")
eq(ZoneData.GetZoneIdAt(Vector3.new(0, 3, 55)), "Hub", "spawn is in Hub")
eq(ZoneData.GetZoneIdAt(Vector3.new(0, 3, -100)), "Scrapyard", "z=-100 Scrapyard")
eq(ZoneData.GetZoneIdAt(Vector3.new(0, 3, -301)), "NeonFoundry", "z=-301 Foundry")
eq(ZoneData.GetZoneIdAt(Vector3.new(0, 3, -600)), "StormReactor", "z=-600 Reactor")
eq(ZoneData.GetZoneIdAt(Vector3.new(500, 3, 0)), nil, "outside world is nil")
for i, zone in ZoneData.Zones do
	if i > 1 then
		eq(zone.MaxZ, ZoneData.Zones[i - 1].MinZ, "zones contiguous " .. zone.Id)
		check(zone.RequiredLevel > ZoneData.Zones[i - 1].RequiredLevel, "zones get harder " .. zone.Id)
	end
	for enemyId in zone.Spawns do
		check(ZoneData.Enemies[enemyId] ~= nil, zone.Id .. " spawn exists " .. enemyId)
	end
	check(ZoneData.Enemies[zone.Boss] and ZoneData.Enemies[zone.Boss].Boss == true, zone.Id .. " boss valid")
	for _, coreId in zone.DropPool do check(ItemData.Cores[coreId] ~= nil, zone.Id .. " drop exists " .. coreId) end
	for _, coreId in zone.BossDropPool do check(ItemData.Cores[coreId] ~= nil, zone.Id .. " boss drop exists " .. coreId) end
end

section("Quest data")
local seen = {}
for _, q in QuestData.Daily do
	check(not seen[q.Id], "daily id unique " .. q.Id)
	seen[q.Id] = true
end
check(#QuestData.Daily >= QuestData.DailyCount, "enough dailies in pool")

---------------------------------------------------------------- server services
-- Real gameplay services + fake Data/Net/Plot services.
local DataService = loadModule("server/Services/DataService")
local function newProfile()
	return { Data = DataService.DeepCopy(DataService.Template), Runtime = { Cooldowns = {}, OverdriveUntil = 0 }, LastOnline = 0 }
end

local notifications = {}
local fakeData = { Profiles = {}, ProfileLoaded = fakeSignal(), ProfileReleasing = fakeSignal() }
function fakeData:GetProfile(p) return self.Profiles[p] end
function fakeData:MarkDirty() end
local handlers = {}
local fakeNet = {}
function fakeNet:Handle(name, fn) handlers[name] = fn end
function fakeNet:Notify(_, text) table.insert(notifications, text) end
function fakeNet:NotifyAll(text) table.insert(notifications, text) end
function fakeNet:Effect() end
function fakeNet:EffectAll() end
local fakePlot = { RefreshDisplay = function() end }

local S = {
	DataService = fakeData,
	NetService = fakeNet,
	PlotService = fakePlot,
	ProgressionService = loadModule("server/Services/ProgressionService"),
	QuestService = loadModule("server/Services/QuestService"),
	InventoryService = loadModule("server/Services/InventoryService"),
	ShopService = loadModule("server/Services/ShopService"),
	DailyService = loadModule("server/Services/DailyService"),
}
for _, name in { "ProgressionService", "QuestService", "InventoryService", "ShopService", "DailyService" } do
	S[name]:Init(S)
end
for _, name in { "QuestService", "InventoryService", "ShopService", "DailyService" } do
	S[name]:Start()
end
S.ProgressionService.ApplyCharacterStats = function() end -- needs a real character

local player = { UserId = 1001, Name = "Tester", DisplayName = "Tester", Parent = true, Character = nil }
local profile = newProfile()
fakeData.Profiles[player] = profile
local d = profile.Data
local function call(action, ...)
	return handlers[action](player, profile, ...)
end

section("Tutorial flow (new player, first minutes)")
S.QuestService:RefreshDailies(player, profile)
eq(#d.Quests.Active, 3, "3 daily quests rolled")
for _ = 1, 3 do
	S.QuestService:Track(player, "Kill", 1)
end
eq(d.Tutorial.Step, 2, "after 3 kills -> step 2")
eq(d.Coins, 100, "step 1 reward paid")
local res = call("OpenCrate", "Basic")
check(res.ok and res.Item ~= nil, "free tutorial crate opens")
eq(d.Coins, 150, "free crate didn't cost coins (+50 reward)")
eq(d.Tutorial.Step, 3, "-> step 3 (equip)")
check(res.Uid ~= nil and d.Inventory[res.Uid] ~= nil, "crate item in inventory")
local tutorialUid = res.Uid
check(call("Equip", res.Uid).ok, "equip ok")
eq(d.Equipped, res.Uid, "equipped uid stored")
eq(d.Tutorial.Step, 4, "-> step 4 (display)")
check(call("Display", res.Uid).ok, "display ok")
eq(#d.Displayed, 1, "one displayed")
eq(d.Tutorial.Step, 5, "-> step 5 (collect)")
S.QuestService:Track(player, "Collect", 1)
eq(d.Tutorial.Step, 6, "-> step 6 (upgrade)")
check(call("BuyUpgrade", "Power").ok, "buy first Power upgrade")
check(d.Tutorial.Done, "tutorial complete")
eq(d.Upgrades.Power, 1, "power level 1")

section("Shop validation")
local coinsBefore = d.Coins
res = call("OpenCrate", "Basic")
check(d.Coins == coinsBefore and not res.ok or res.ok and d.Coins == coinsBefore - 250, "crate charges or refuses correctly")
d.Coins = 0
check(not call("OpenCrate", "Basic").ok, "can't buy crate without coins")
check(not call("OpenCrate", "Neon").ok, "can't buy locked-zone crate")
check(not call("OpenCrate", 123).ok, "rejects non-string crate id")
check(not call("OpenCrate", "Nope").ok, "rejects unknown crate")
check(not call("BuyUpgrade", "Power").ok, "can't upgrade without coins")
check(not call("BuyUpgrade", {}).ok, "rejects table upgrade id")
d.Coins = 10 ^ 12
d.Upgrades.Speed = Config.Upgrades.Speed.Max
check(not call("BuyUpgrade", "Speed").ok, "can't exceed max upgrade")
check(not call("Equip", "u999").ok, "can't equip item you don't own")
check(not call("Display", tutorialUid).ok, "can't display the same core twice")
check(not call("Display", 42).ok, "rejects non-string uid")

section("Crate odds + pity (20,000 rolls)")
local rollProfile = newProfile()
local counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 }
local sinceLegendary, worstDrought = 0, 0
for _ = 1, 20000 do
	local id = S.ShopService:RollCrate(rollProfile, "Basic")
	local rarity = ItemData.Cores[id].Rarity
	counts[rarity] += 1
	if Config.Rarities[rarity].Order >= 4 then
		sinceLegendary = 0
	else
		sinceLegendary += 1
		worstDrought = math.max(worstDrought, sinceLegendary)
	end
end
print(("   Common %d  Rare %d  Epic %d  Legendary %d  Mythic %d  (longest drought %d)"):format(counts.Common, counts.Rare, counts.Epic, counts.Legendary, counts.Mythic, worstDrought))
check(math.abs(counts.Common / 20000 - 0.72) < 0.03, "Common ~72%")
check(math.abs(counts.Rare / 20000 - 0.24) < 0.03, "Rare ~24%")
check(worstDrought < Config.Pity, "pity guarantees Legendary+ within 60 crates")

section("Inventory selling")
local p2 = newProfile()
local player2 = { UserId = 1002, Name = "Seller", DisplayName = "Seller", Parent = true }
fakeData.Profiles[player2] = p2
local u1 = S.InventoryService:AddItem(player2, "RustyCore")
local u2 = S.InventoryService:AddItem(player2, "RustyCore")
local u3 = S.InventoryService:AddItem(player2, "VoltCore")
p2.Data.Equipped = u1
res = handlers.SellRarity(player2, p2, "Common")
check(res.ok and p2.Data.Inventory[u1] ~= nil and p2.Data.Inventory[u2] == nil, "SellRarity keeps equipped core")
eq(p2.Data.Coins, 15, "sold one Rusty Core for 15")
check(not handlers.SellRarity(player2, p2, "Legendary").ok, "can't bulk-sell Legendary")
res = handlers.Sell(player2, p2, u1)
check(res.ok and p2.Data.Equipped == "", "selling equipped core unequips it")
check(p2.Data.Inventory[u3] ~= nil, "rare untouched")

section("Inventory cap")
for _ = 1, Config.Player.MaxInventory + 5 do
	S.InventoryService:AddItem(player2, "CopperCoil")
end
local n = 0
for _ in p2.Data.Inventory do n += 1 end
eq(n, Config.Player.MaxInventory, "inventory never exceeds cap (extras auto-sold)")

section("Leveling")
local p3 = newProfile()
local player3 = { UserId = 1003, Name = "Leveler", DisplayName = "Leveler", Parent = true }
fakeData.Profiles[player3] = p3
S.ProgressionService:AddXP(player3, 40)
eq(p3.Data.Level, 2, "40 XP -> level 2")
S.ProgressionService:AddXP(player3, 100000)
check(p3.Data.Level > 10, "big XP grant levels through many levels")
check(p3.Data.XP < Config.XPForLevel(p3.Data.Level), "leftover XP below next threshold")
eq(S.ProgressionService:AddCoins(player3, 100, true), 100, "no Fortune -> no bonus")
p3.Data.Upgrades.Fortune = 5
eq(S.ProgressionService:AddCoins(player3, 100, true), 150, "Fortune 5 -> +50%")
check(not S.ProgressionService:SpendCoins(player3, 10 ^ 9), "can't overspend")
check(not S.ProgressionService:SpendCoins(player3, -5), "negative spend rejected")

section("Daily rewards")
local p4 = newProfile()
local player4 = { UserId = 1004, Name = "Daily", DisplayName = "Daily", Parent = true }
fakeData.Profiles[player4] = p4
res = handlers.ClaimDaily(player4, p4)
check(res.ok and p4.Data.Daily.Streak == 1, "day 1 claimed")
check(not handlers.ClaimDaily(player4, p4).ok, "can't claim twice in a day")
fakeTime += 86400
res = handlers.ClaimDaily(player4, p4)
eq(p4.Data.Daily.Streak, 2, "consecutive day -> streak 2")
fakeTime += 86400
res = handlers.ClaimDaily(player4, p4)
eq(p4.Data.Daily.Streak, 3, "day 3")
eq(#res.Items, 1, "day 3 gives a crate item")
fakeTime += 86400 * 3
handlers.ClaimDaily(player4, p4)
eq(p4.Data.Daily.Streak, 1, "missed days reset streak")

section("Daily quests")
S.QuestService:RefreshDailies(player4, p4)
local quest = p4.Data.Quests.Active[1]
local def = QuestData.DailyById[quest.Id]
check(not handlers.ClaimQuest(player4, p4, 1).ok, "unfinished quest can't be claimed")
S.QuestService:Track(player4, def.Event, def.Target)
local coins = p4.Data.Coins
check(handlers.ClaimQuest(player4, p4, 1).ok, "finished quest claims")
check(p4.Data.Coins > coins, "quest paid coins")
check(not handlers.ClaimQuest(player4, p4, 1).ok, "can't claim twice")
check(not handlers.ClaimQuest(player4, p4, "1").ok, "rejects string index")
check(not handlers.ClaimQuest(player4, p4, 1.5).ok, "rejects fractional index")
local oldDay = p4.Data.Quests.Day
fakeTime += 86400
S.QuestService:RefreshDailies(player4, p4)
check(p4.Data.Quests.Day ~= oldDay and not p4.Data.Quests.Active[1].Claimed, "quests reset next day")

section("Settings validation")
res = handlers.SaveSettings(player4, p4, { Music = 5, Sfx = -3, DamageNumbers = "yes", CameraShake = false })
eq(p4.Data.Settings.Music, 1, "music clamped")
eq(p4.Data.Settings.Sfx, 0, "sfx clamped")
eq(p4.Data.Settings.DamageNumbers, true, "wrong type ignored")
eq(p4.Data.Settings.CameraShake, false, "valid bool saved")
check(not handlers.SaveSettings(player4, p4, "bad").ok, "rejects non-table settings")

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("tests failed")
end

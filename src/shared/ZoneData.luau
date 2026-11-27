-- ZoneData: the world is a straight line of zones running toward -Z.
--   Hub (spawn, shop, Garages, arena)  ->  Scrapyard  ->  Neon Foundry  ->  Storm Reactor
-- Each zone is ZONE_LENGTH studs long and WIDTH studs wide. WorldBuilder builds them,
-- ZoneService enforces locks, EnemyService spawns their bots.
local ZoneData = {}

ZoneData.WIDTH = 220
ZoneData.ZONE_LENGTH = 220
ZoneData.HUB_MIN_Z = -80
ZoneData.HUB_MAX_Z = 170

ZoneData.Enemies = {
	-- Scrapyard
	ScrapBot = { Name = "Scrap Bot", Health = 35, Damage = 4, AttackCooldown = 1.5, AttackRange = 5, Speed = 10, Aggro = 34, XP = 10, Coins = 12, Scale = 1, Color = Color3.fromRGB(196, 110, 58), Eye = Color3.fromRGB(255, 80, 40) },
	RustCrawler = { Name = "Rust Crawler", Health = 80, Damage = 7, AttackCooldown = 1.6, AttackRange = 6, Speed = 12, Aggro = 34, XP = 22, Coins = 25, Scale = 1.3, Color = Color3.fromRGB(130, 80, 50), Eye = Color3.fromRGB(255, 170, 40) },
	JunkTitan = { Name = "Junk Titan", Boss = true, Health = 3000, Damage = 18, AttackCooldown = 2, AttackRange = 10, Speed = 9, Aggro = 60, XP = 600, Coins = 1500, Scale = 3.5, Color = Color3.fromRGB(110, 70, 45), Eye = Color3.fromRGB(255, 40, 40), SlamRadius = 18, SlamEvery = 7, Respawn = 150 },
	-- Neon Foundry
	NeonDrone = { Name = "Neon Drone", Health = 400, Damage = 15, AttackCooldown = 1.4, AttackRange = 6, Speed = 13, Aggro = 38, XP = 70, Coins = 90, Scale = 1.1, Color = Color3.fromRGB(40, 50, 90), Eye = Color3.fromRGB(0, 230, 255) },
	ForgeBrute = { Name = "Forge Brute", Health = 900, Damage = 25, AttackCooldown = 1.8, AttackRange = 7, Speed = 11, Aggro = 38, XP = 150, Coins = 200, Scale = 1.8, Color = Color3.fromRGB(70, 40, 100), Eye = Color3.fromRGB(255, 60, 220) },
	FoundryOverseer = { Name = "Foundry Overseer", Boss = true, Health = 40000, Damage = 45, AttackCooldown = 2, AttackRange = 11, Speed = 10, Aggro = 70, XP = 6000, Coins = 15000, Scale = 4, Color = Color3.fromRGB(30, 30, 60), Eye = Color3.fromRGB(0, 255, 255), SlamRadius = 20, SlamEvery = 6, Respawn = 240 },
	-- Storm Reactor
	StormSentinel = { Name = "Storm Sentinel", Health = 4000, Damage = 60, AttackCooldown = 1.4, AttackRange = 7, Speed = 14, Aggro = 40, XP = 500, Coins = 700, Scale = 1.5, Color = Color3.fromRGB(60, 60, 30), Eye = Color3.fromRGB(255, 230, 60) },
	ArcGolem = { Name = "Arc Golem", Health = 9000, Damage = 90, AttackCooldown = 2, AttackRange = 8, Speed = 11, Aggro = 40, XP = 1100, Coins = 1500, Scale = 2.2, Color = Color3.fromRGB(40, 40, 40), Eye = Color3.fromRGB(255, 255, 120) },
	ReactorTitan = { Name = "Reactor Titan", Boss = true, Health = 250000, Damage = 140, AttackCooldown = 2, AttackRange = 12, Speed = 10, Aggro = 80, XP = 50000, Coins = 150000, Scale = 4.5, Color = Color3.fromRGB(50, 45, 20), Eye = Color3.fromRGB(255, 255, 255), SlamRadius = 22, SlamEvery = 5, Respawn = 300 },
}

ZoneData.Zones = {
	{
		Id = "Scrapyard",
		Name = "Scrapyard",
		RequiredLevel = 1,
		UnlockCost = 0,
		FloorColor = Color3.fromRGB(92, 78, 66),
		AccentColor = Color3.fromRGB(255, 140, 40),
		Material = Enum.Material.Slate,
		MaxEnemies = 14,
		Spawns = { ScrapBot = 3, RustCrawler = 1 },
		Boss = "JunkTitan",
		DropChance = 0.04,
		DropPool = { "RustyCore", "CopperCoil", "ScrapHeart", "VoltCore" },
		BossDropPool = { "VoltCore", "GearHeart", "NeonPiston", "PlasmaCore" },
	},
	{
		Id = "NeonFoundry",
		Name = "Neon Foundry",
		RequiredLevel = 10,
		UnlockCost = 2500,
		FloorColor = Color3.fromRGB(30, 32, 52),
		AccentColor = Color3.fromRGB(0, 220, 255),
		Material = Enum.Material.DiamondPlate,
		MaxEnemies = 14,
		Spawns = { NeonDrone = 3, ForgeBrute = 1 },
		Boss = "FoundryOverseer",
		DropChance = 0.035,
		DropPool = { "VoltCore", "GearHeart", "NeonPiston", "PlasmaCore" },
		BossDropPool = { "PlasmaCore", "TurboHeart", "PrismReactor", "StormEngine" },
	},
	{
		Id = "StormReactor",
		Name = "Storm Reactor",
		RequiredLevel = 25,
		UnlockCost = 25000,
		FloorColor = Color3.fromRGB(44, 42, 30),
		AccentColor = Color3.fromRGB(255, 220, 60),
		Material = Enum.Material.Metal,
		MaxEnemies = 12,
		Spawns = { StormSentinel = 3, ArcGolem = 1 },
		Boss = "ReactorTitan",
		DropChance = 0.03,
		DropPool = { "PlasmaCore", "TurboHeart", "PrismReactor", "StormEngine" },
		BossDropPool = { "StormEngine", "SolarDynamo", "SingularityCore" },
	},
}

-- Fill in derived bounds: zone i spans Z from MaxZ (entrance, near the hub) to MinZ.
ZoneData.ById = {}
for i, zone in ZoneData.Zones do
	zone.Index = i
	zone.MaxZ = ZoneData.HUB_MIN_Z - (i - 1) * ZoneData.ZONE_LENGTH
	zone.MinZ = zone.MaxZ - ZoneData.ZONE_LENGTH
	zone.CenterZ = (zone.MaxZ + zone.MinZ) / 2
	ZoneData.ById[zone.Id] = zone
end

-- Returns the zone definition containing a position, "Hub", or nil (out of bounds).
function ZoneData.GetZoneIdAt(position: Vector3): string?
	local half = ZoneData.WIDTH / 2
	if math.abs(position.X) > half + 4 then
		return nil
	end
	if position.Z <= ZoneData.HUB_MAX_Z and position.Z > ZoneData.HUB_MIN_Z then
		return "Hub"
	end
	for _, zone in ZoneData.Zones do
		if position.Z <= zone.MaxZ and position.Z > zone.MinZ then
			return zone.Id
		end
	end
	return nil
end

return ZoneData

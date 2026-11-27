-- ItemData: every collectible "Core" and every crate.
-- Cores are the game's rare items: equip one to boost combat, display them in your
-- Garage to earn passive income.
local ItemData = {}

ItemData.Cores = {
	-- Common
	RustyCore = { Name = "Rusty Core", Rarity = "Common", DamageMult = 1.10, CritChance = 0.03, Income = 1, SellValue = 15, Color = Color3.fromRGB(181, 102, 61) },
	CopperCoil = { Name = "Copper Coil", Rarity = "Common", DamageMult = 1.15, CritChance = 0.04, Income = 2, SellValue = 25, Color = Color3.fromRGB(214, 133, 77) },
	ScrapHeart = { Name = "Scrap Heart", Rarity = "Common", DamageMult = 1.20, CritChance = 0.05, Income = 3, SellValue = 35, Color = Color3.fromRGB(150, 150, 160) },
	-- Rare
	VoltCore = { Name = "Volt Core", Rarity = "Rare", DamageMult = 1.40, CritChance = 0.07, Income = 8, SellValue = 150, Color = Color3.fromRGB(80, 190, 255) },
	GearHeart = { Name = "Gear Heart", Rarity = "Rare", DamageMult = 1.50, CritChance = 0.08, Income = 12, SellValue = 220, Color = Color3.fromRGB(90, 230, 200) },
	NeonPiston = { Name = "Neon Piston", Rarity = "Rare", DamageMult = 1.60, CritChance = 0.09, Income = 18, SellValue = 320, Color = Color3.fromRGB(60, 120, 255) },
	-- Epic
	PlasmaCore = { Name = "Plasma Core", Rarity = "Epic", DamageMult = 2.00, CritChance = 0.12, Income = 45, SellValue = 1200, Color = Color3.fromRGB(190, 90, 255) },
	TurboHeart = { Name = "Turbo Heart", Rarity = "Epic", DamageMult = 2.20, CritChance = 0.13, Income = 65, SellValue = 1800, Color = Color3.fromRGB(255, 90, 220) },
	PrismReactor = { Name = "Prism Reactor", Rarity = "Epic", DamageMult = 2.40, CritChance = 0.14, Income = 90, SellValue = 2600, Color = Color3.fromRGB(140, 110, 255) },
	-- Legendary
	StormEngine = { Name = "Storm Engine", Rarity = "Legendary", DamageMult = 3.20, CritChance = 0.18, Income = 300, SellValue = 12000, Color = Color3.fromRGB(255, 210, 60) },
	SolarDynamo = { Name = "Solar Dynamo", Rarity = "Legendary", DamageMult = 3.60, CritChance = 0.20, Income = 420, SellValue = 18000, Color = Color3.fromRGB(255, 150, 40) },
	-- Mythic
	SingularityCore = { Name = "Singularity Core", Rarity = "Mythic", DamageMult = 5.50, CritChance = 0.25, Income = 1500, SellValue = 90000, Color = Color3.fromRGB(255, 60, 120) },
	OmegaTorque = { Name = "Omega Torque", Rarity = "Mythic", DamageMult = 7.00, CritChance = 0.30, Income = 2500, SellValue = 150000, Color = Color3.fromRGB(255, 255, 255) },
}

-- Crates are bought with Coins. Weights are relative (they don't need to add to 100).
ItemData.Crates = {
	Basic = {
		Order = 1,
		Name = "Scrap Crate",
		Price = 250,
		RequiredZone = "Scrapyard",
		Color = Color3.fromRGB(200, 120, 60),
		Weights = { Common = 72, Rare = 24, Epic = 3.6, Legendary = 0.38, Mythic = 0.02 },
	},
	Neon = {
		Order = 2,
		Name = "Neon Crate",
		Price = 3000,
		RequiredZone = "NeonFoundry",
		Color = Color3.fromRGB(60, 200, 255),
		Weights = { Rare = 62, Epic = 31, Legendary = 6.5, Mythic = 0.5 },
	},
	Storm = {
		Order = 3,
		Name = "Storm Crate",
		Price = 30000,
		RequiredZone = "StormReactor",
		Color = Color3.fromRGB(255, 210, 60),
		Weights = { Epic = 64, Legendary = 33, Mythic = 3 },
	},
}

-- Lookup: rarity -> { coreId, ... } (sorted so results are deterministic)
ItemData.ByRarity = {}
for id, core in ItemData.Cores do
	ItemData.ByRarity[core.Rarity] = ItemData.ByRarity[core.Rarity] or {}
	table.insert(ItemData.ByRarity[core.Rarity], id)
end
for _, list in ItemData.ByRarity do
	table.sort(list)
end

-- Returns odds as percentages, e.g. { Common = 72.0, ... }, for the shop UI.
function ItemData.GetOdds(crateId: string): { [string]: number }
	local crate = ItemData.Crates[crateId]
	local total = 0
	for _, w in crate.Weights do
		total += w
	end
	local odds = {}
	for rarity, w in crate.Weights do
		odds[rarity] = w / total * 100
	end
	return odds
end

return ItemData

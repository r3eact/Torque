-- Config: every tunable number in Torque lives here so balancing never requires
-- touching gameplay code. Shared by server and client (the client only *displays*
-- these values; the server is the one that enforces them).
local Config = {}

Config.DataVersion = 1
Config.DataStoreName = "TorqueData_v1"
Config.KillsBoardStoreName = "TorqueKills_v1"
Config.AutosaveInterval = 120 -- seconds
Config.SessionLockTimeout = 600 -- a lock older than this is considered abandoned

Config.Player = {
	BaseHealth = 100,
	HealthPerVitality = 20,
	HealthPerLevel = 5,
	BaseWalkSpeed = 18,
	SpeedPerUpgrade = 1,
	BaseDamage = 10,
	DamagePerPower = 0.2, -- +20% damage per Power upgrade
	DamagePerLevel = 0.05, -- +5% damage per level
	CoinBonusPerFortune = 0.1, -- +10% coins earned per Fortune upgrade
	CritMultiplier = 2,
	MaxLevel = 200,
	MaxInventory = 120,
	BaseDisplaySlots = 3,
	MaxDisplaySlots = 8,
	LevelsPerDisplaySlot = 8, -- +1 Garage pedestal every 8 levels
	OfflineIncomeHours = 8,
	OfflineIncomeRate = 0.5, -- 50% of normal income while offline
}

Config.PvP = {
	DamageScale = 0.35, -- PvP hits deal 35% of PvE damage so fights last a few seconds
}

Config.Pity = 60 -- every 60th crate without a Legendary+ is a guaranteed Legendary+
Config.KillShareThreshold = 0.10 -- deal 10% of a bot's HP to get full kill rewards
Config.BossShareThreshold = 0.03 -- deal 3% of a boss' HP to get boss rewards

-- Abilities. Keys are bound on the client; the server enforces UnlockLevel + Cooldown.
Config.Abilities = {
	Strike = {
		Order = 1,
		Name = "Strike",
		Icon = "👊",
		UnlockLevel = 1,
		Cooldown = 0.45,
		Range = 10,
		ArcDot = -0.1, -- ~95 degree half-angle cleave in front of the player
		DamageMult = 1,
		KeyLabel = "LMB",
	},
	Slam = {
		Order = 2,
		Name = "Torque Slam",
		Icon = "💥",
		UnlockLevel = 3,
		Cooldown = 6,
		Radius = 15,
		DamageMult = 2.5,
		KeyLabel = "Q",
	},
	Overdrive = {
		Order = 3,
		Name = "Overdrive",
		Icon = "⚡",
		UnlockLevel = 8,
		Cooldown = 30,
		Duration = 8,
		DamageBuff = 1.5,
		SpeedBuff = 8,
		KeyLabel = "R",
	},
}

Config.Upgrades = {
	Power = { Order = 1, Name = "Power", Icon = "💪", Description = "+20% damage", BaseCost = 60, Growth = 1.28, Max = 60 },
	Vitality = { Order = 2, Name = "Vitality", Icon = "❤️", Description = "+20 max health", BaseCost = 50, Growth = 1.25, Max = 60 },
	Speed = { Order = 3, Name = "Speed", Icon = "👟", Description = "+1 walk speed", BaseCost = 80, Growth = 1.45, Max = 15 },
	Fortune = { Order = 4, Name = "Fortune", Icon = "🍀", Description = "+10% coins from bots", BaseCost = 120, Growth = 1.35, Max = 40 },
}

Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(176, 182, 196) },
	Rare = { Order = 2, Color = Color3.fromRGB(64, 156, 255) },
	Epic = { Order = 3, Color = Color3.fromRGB(176, 86, 255) },
	Legendary = { Order = 4, Color = Color3.fromRGB(255, 190, 40) },
	Mythic = { Order = 5, Color = Color3.fromRGB(255, 58, 112) },
}
Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

-- Built-in Roblox sounds/animations so the game works with zero uploads.
-- Swap these for your own Creator Store asset ids any time.
Config.Sounds = {
	Swing = "rbxasset://sounds/swordslash.wav",
	Hit = "rbxasset://sounds/swordlunge.wav",
	Slam = "rbxasset://sounds/impact_water.mp3",
	UIClick = "rbxasset://sounds/electronicpingshort.wav",
	Reward = "rbxasset://sounds/electronicpingshort.wav",
	LevelUp = "rbxasset://sounds/action_jump.mp3",
	Music = "", -- put a music asset id here, e.g. "rbxassetid://1234567890"
}

Config.Animations = {
	R15 = { Strike = "rbxassetid://522635514", Slam = "rbxassetid://522638767" },
	R6 = { Strike = "rbxassetid://129967390", Slam = "rbxassetid://129967478" },
}

-- XP needed to go from `level` to `level + 1`. Level 2 takes ~4 bots: fast early hook.
function Config.XPForLevel(level: number): number
	return math.floor(40 * level ^ 1.6)
end

function Config.MaxHealth(level: number, vitality: number): number
	local p = Config.Player
	return p.BaseHealth + vitality * p.HealthPerVitality + (level - 1) * p.HealthPerLevel
end

function Config.WalkSpeed(speedLevel: number): number
	return Config.Player.BaseWalkSpeed + speedLevel * Config.Player.SpeedPerUpgrade
end

function Config.BaseDamage(level: number, power: number): number
	local p = Config.Player
	return p.BaseDamage * (1 + power * p.DamagePerPower) * (1 + (level - 1) * p.DamagePerLevel)
end

function Config.CoinMultiplier(fortune: number): number
	return 1 + fortune * Config.Player.CoinBonusPerFortune
end

function Config.DisplaySlots(level: number): number
	local p = Config.Player
	return math.min(p.MaxDisplaySlots, p.BaseDisplaySlots + (level - 1) // p.LevelsPerDisplaySlot)
end

function Config.UpgradeCost(upgradeId: string, currentLevel: number): number
	local def = Config.Upgrades[upgradeId]
	return math.floor(def.BaseCost * def.Growth ^ currentLevel)
end

-- Day number used for daily quests/rewards (UTC midnight reset).
function Config.Day(timestamp: number): number
	return timestamp // 86400
end

return Config

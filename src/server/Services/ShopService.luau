-- ShopService: crate rolls (with a pity system) and stat upgrades.
-- All randomness happens on the server with a server-side Random object.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)
local ZoneData = require(Shared.ZoneData)

local ShopService = {}
local S
local rng = Random.new()

function ShopService:Init(services)
	S = services
end

local function weightedRarity(weights: { [string]: number }): string
	local total = 0
	for _, rarity in Config.RarityOrder do
		total += weights[rarity] or 0
	end
	local roll = rng:NextNumber() * total
	for _, rarity in Config.RarityOrder do
		local w = weights[rarity] or 0
		if roll < w then
			return rarity
		end
		roll -= w
	end
	return Config.RarityOrder[1]
end

-- Rolls one core from a crate, updating the player's pity counter.
function ShopService:RollCrate(profile, crateId: string): string
	local crate = ItemData.Crates[crateId]
	local d = profile.Data
	d.Pity += 1
	local rarity
	if d.Pity >= Config.Pity then
		-- Guaranteed Legendary+ (small Mythic chance if the crate can drop Mythic)
		rarity = if (crate.Weights.Mythic or 0) > 0 and rng:NextNumber() < 0.1 then "Mythic" else "Legendary"
	else
		rarity = weightedRarity(crate.Weights)
	end
	if Config.Rarities[rarity].Order >= Config.Rarities.Legendary.Order then
		d.Pity = 0
	end
	local pool = ItemData.ByRarity[rarity]
	return pool[rng:NextInteger(1, #pool)]
end

function ShopService:Start()
	local Net = S.NetService

	Net:Handle("OpenCrate", function(player, profile, crateId)
		if typeof(crateId) ~= "string" then
			return { ok = false }
		end
		local crate = ItemData.Crates[crateId]
		if not crate then
			return { ok = false }
		end
		local d = profile.Data
		if not d.UnlockedZones[crate.RequiredZone] then
			return { ok = false, msg = ("Unlock the %s to buy this crate."):format(ZoneData.ById[crate.RequiredZone].Name) }
		end
		if S.InventoryService:IsFull(profile) then
			return { ok = false, msg = "Inventory full! Sell some cores first." }
		end
		local free = crateId == "Basic" and S.QuestService:IsTutorialStep(profile, "OpenCrate")
		if not free and not S.ProgressionService:SpendCoins(player, crate.Price) then
			return { ok = false, msg = "Not enough coins!" }
		end
		local coreId = self:RollCrate(profile, crateId)
		local uid = S.InventoryService:AddItem(player, coreId)
		S.QuestService:Track(player, "OpenCrate", 1)
		return { ok = true, Item = coreId, Uid = uid }
	end)

	Net:Handle("BuyUpgrade", function(player, profile, upgradeId)
		if typeof(upgradeId) ~= "string" then
			return { ok = false }
		end
		local def = Config.Upgrades[upgradeId]
		if not def then
			return { ok = false }
		end
		local d = profile.Data
		local current = d.Upgrades[upgradeId] or 0
		if current >= def.Max then
			return { ok = false, msg = "Already maxed!" }
		end
		local cost = Config.UpgradeCost(upgradeId, current)
		if not S.ProgressionService:SpendCoins(player, cost) then
			return { ok = false, msg = "Not enough coins!" }
		end
		d.Upgrades[upgradeId] = current + 1
		S.ProgressionService:ApplyCharacterStats(player)
		S.QuestService:Track(player, "Upgrade", 1)
		S.DataService:MarkDirty(player)
		return { ok = true, msg = ("%s upgraded to Lv %d"):format(def.Name, current + 1) }
	end)

	-- Settings are stored in the profile so they follow the player across devices.
	Net:Handle("SaveSettings", function(player, profile, settings)
		if typeof(settings) ~= "table" then
			return { ok = false }
		end
		local s = profile.Data.Settings
		if typeof(settings.Music) == "number" then
			s.Music = math.clamp(math.floor(settings.Music * 10 + 0.5) / 10, 0, 1)
		end
		if typeof(settings.Sfx) == "number" then
			s.Sfx = math.clamp(math.floor(settings.Sfx * 10 + 0.5) / 10, 0, 1)
		end
		if typeof(settings.DamageNumbers) == "boolean" then
			s.DamageNumbers = settings.DamageNumbers
		end
		if typeof(settings.CameraShake) == "boolean" then
			s.CameraShake = settings.CameraShake
		end
		S.DataService:MarkDirty(player)
		return { ok = true }
	end)
end

return ShopService

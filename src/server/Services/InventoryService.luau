-- InventoryService: owns the player's Cores. Equip one for combat bonuses, display up
-- to N in the Garage for passive income, or sell them for coins.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)

local InventoryService = {}
local S

function InventoryService:Init(services)
	S = services
end

local function count(inventory): number
	local n = 0
	for _ in inventory do
		n += 1
	end
	return n
end

function InventoryService:IsFull(profile): boolean
	return count(profile.Data.Inventory) >= Config.Player.MaxInventory
end

-- Returns the equipped core definition (or nil).
function InventoryService:GetEquipped(profile)
	local d = profile.Data
	local item = d.Inventory[d.Equipped]
	return item and ItemData.Cores[item.Id]
end

-- Adds a core and returns its uid. If the inventory is full the core is auto-sold.
function InventoryService:AddItem(player: Player, coreId: string): string?
	local profile = S.DataService:GetProfile(player)
	local core = ItemData.Cores[coreId]
	if not profile or not core then
		return nil
	end
	local d = profile.Data
	if self:IsFull(profile) then
		S.ProgressionService:AddCoins(player, core.SellValue, false)
		S.NetService:Notify(player, ("Inventory full! Auto-sold %s for %d coins."):format(core.Name, core.SellValue), "warn")
		return nil
	end
	local uid = "u" .. d.NextUid
	d.NextUid += 1
	d.Inventory[uid] = { Id = coreId, Time = os.time() }
	local isNew = not d.ItemsFound[coreId]
	d.ItemsFound[coreId] = true
	-- Server-wide shoutout for big pulls: social proof that rare drops are real.
	if Config.Rarities[core.Rarity].Order >= Config.Rarities.Legendary.Order then
		S.NetService:NotifyAll(("🌟 %s found a %s %s!"):format(player.DisplayName, string.upper(core.Rarity), core.Name), "rare")
	elseif isNew then
		S.NetService:Notify(player, ("New Core discovered: %s!"):format(core.Name), "reward")
	end
	S.DataService:MarkDirty(player)
	return uid
end

local function removeFromList(list, value)
	local index = table.find(list, value)
	if index then
		table.remove(list, index)
		return true
	end
	return false
end

function InventoryService:Start()
	local Net = S.NetService

	Net:Handle("Equip", function(player, profile, uid)
		if typeof(uid) ~= "string" or not profile.Data.Inventory[uid] then
			return { ok = false, msg = "Item not found." }
		end
		profile.Data.Equipped = uid
		S.QuestService:Track(player, "Equip", 1)
		S.DataService:MarkDirty(player)
		return { ok = true }
	end)

	Net:Handle("Unequip", function(player, profile)
		profile.Data.Equipped = ""
		S.DataService:MarkDirty(player)
		return { ok = true }
	end)

	Net:Handle("Display", function(player, profile, uid)
		local d = profile.Data
		if typeof(uid) ~= "string" or not d.Inventory[uid] then
			return { ok = false, msg = "Item not found." }
		end
		if table.find(d.Displayed, uid) then
			return { ok = false, msg = "Already displayed." }
		end
		if #d.Displayed >= Config.DisplaySlots(d.Level) then
			return { ok = false, msg = "All pedestals are full. Level up for more!" }
		end
		table.insert(d.Displayed, uid)
		S.PlotService:RefreshDisplay(player)
		S.QuestService:Track(player, "Display", 1)
		S.DataService:MarkDirty(player)
		return { ok = true }
	end)

	Net:Handle("Undisplay", function(player, profile, uid)
		if typeof(uid) ~= "string" or not removeFromList(profile.Data.Displayed, uid) then
			return { ok = false }
		end
		S.PlotService:RefreshDisplay(player)
		S.DataService:MarkDirty(player)
		return { ok = true }
	end)

	Net:Handle("Sell", function(player, profile, uid)
		local d = profile.Data
		if typeof(uid) ~= "string" or not d.Inventory[uid] then
			return { ok = false, msg = "Item not found." }
		end
		local core = ItemData.Cores[d.Inventory[uid].Id]
		d.Inventory[uid] = nil
		if d.Equipped == uid then
			d.Equipped = ""
		end
		if removeFromList(d.Displayed, uid) then
			S.PlotService:RefreshDisplay(player)
		end
		local value = if core then core.SellValue else 0
		S.ProgressionService:AddCoins(player, value, false)
		return { ok = true, msg = ("Sold for %d coins"):format(value) }
	end)

	-- Sells every Common or Rare core that isn't equipped or displayed.
	Net:Handle("SellRarity", function(player, profile, rarity)
		if rarity ~= "Common" and rarity ~= "Rare" then
			return { ok = false }
		end
		local d = profile.Data
		local total, sold = 0, 0
		for uid, item in d.Inventory do
			local core = ItemData.Cores[item.Id]
			if core and core.Rarity == rarity and d.Equipped ~= uid and not table.find(d.Displayed, uid) then
				d.Inventory[uid] = nil
				total += core.SellValue
				sold += 1
			end
		end
		if sold == 0 then
			return { ok = false, msg = "Nothing to sell." }
		end
		S.ProgressionService:AddCoins(player, total, false)
		return { ok = true, msg = ("Sold %d cores for %d coins"):format(sold, total) }
	end)
end

return InventoryService

-- Inventory window: grid of Cores + detail panel (Equip / Display / Sell).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)
local Format = require(Shared.Format)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme

return function(UI, C)
	local win = UI:CreateWindow("Inventory", "🎒 CORES", T.Accent)
	local body = win.Body
	local selected: string? = nil
	local confirmSell = false

	local header = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), ZIndex = 22, Parent = body })
	local summary = UIKit.label({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, Size = UDim2.new(1, -330, 1, 0), ZIndex = 22, Parent = header })

	local function action(name: string, ...)
		local result = C.ClientState:Call(name, ...)
		if result.msg then
			UI:Notify(result.msg, if result.ok then "reward" else "warn")
		end
		return result
	end

	UIKit.button({ Text = "Sell Commons", TextSize = 15, Size = UDim2.fromOffset(150, 34), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -160, 0, 0), Color = T.Panel3, ZIndex = 22, Parent = header }, function()
		action("SellRarity", "Common")
	end)
	UIKit.button({ Text = "Sell Rares", TextSize = 15, Size = UDim2.fromOffset(150, 34), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Color = T.Panel3, ZIndex = 22, Parent = header }, function()
		action("SellRarity", "Rare")
	end)

	local grid = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(0.62, -8, 1, -44),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Accent,
		ZIndex = 22,
		Parent = body,
	})
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(108, 124), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = grid })

	local detail = UIKit.panel({ Position = UDim2.new(0.62, 8, 0, 44), Size = UDim2.new(0.38, -8, 1, -44), BackgroundColor3 = T.Panel2, Radius = 14, ZIndex = 22, Parent = body })
	UIKit.padding(detail, 12)
	local dName = UIKit.label({ Text = "Select a Core", Font = UIKit.Fonts.Title, TextSize = 24, Size = UDim2.new(1, 0, 0, 32), ZIndex = 23, Parent = detail })
	local dRarity = UIKit.label({ Text = "", TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 34), ZIndex = 23, Parent = detail })
	local dStats = UIKit.label({ Text = "Open crates and defeat bots to find Cores.", TextSize = 15, TextColor3 = T.Muted, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromOffset(0, 62), ZIndex = 23, Parent = detail })
	local buttons = UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 150), ZIndex = 23, Parent = detail })
	UIKit.list(buttons, 8)
	local equipBtn, displayBtn, sellBtn

	equipBtn = UIKit.button({ Text = "Equip", Size = UDim2.new(1, 0, 0, 42), Color = T.Accent, LayoutOrder = 1, ZIndex = 24, Parent = buttons }, function()
		local data = C.ClientState.Data
		if selected and data then
			action(if data.Equipped == selected then "Unequip" else "Equip", selected)
		end
	end)
	displayBtn = UIKit.button({ Text = "Display in Garage", Size = UDim2.new(1, 0, 0, 42), Color = T.Good, LayoutOrder = 2, ZIndex = 24, Parent = buttons }, function()
		local data = C.ClientState.Data
		if selected and data then
			action(if table.find(data.Displayed, selected) then "Undisplay" else "Display", selected)
		end
	end)
	sellBtn = UIKit.button({ Text = "Sell", Size = UDim2.new(1, 0, 0, 42), Color = T.Bad, LayoutOrder = 3, ZIndex = 24, Parent = buttons }, function()
		if not selected then
			return
		end
		if not confirmSell then
			confirmSell = true
			sellBtn.Text = "Tap again to confirm"
			task.delay(2.5, function()
				confirmSell = false
			end)
			return
		end
		confirmSell = false
		local result = action("Sell", selected)
		if result.ok then
			selected = nil
		end
	end)

	local function renderDetail(data)
		local item = selected and data.Inventory[selected]
		local core = item and ItemData.Cores[item.Id]
		buttons.Visible = core ~= nil
		if not core then
			dName.Text = "Select a Core"
			dName.TextColor3 = T.Text
			dRarity.Text = ""
			dStats.Text = "Open crates and defeat bots to find Cores.\n\nEquip a Core to hit harder.\nDisplay Cores in your Garage to earn coins every second - even while offline!"
			return
		end
		local color = Config.Rarities[core.Rarity].Color
		dName.Text = core.Name
		dName.TextColor3 = color
		dRarity.Text = string.upper(core.Rarity)
		dRarity.TextColor3 = color
		dStats.Text = ("⚔️ Damage  x%.2f\n🎯 Crit chance  %d%%\n💰 Garage income  +%s/s\n🪙 Sell value  %s"):format(core.DamageMult, math.floor(core.CritChance * 100), Format.Short(core.Income), Format.Commas(core.SellValue))
		dStats.TextColor3 = T.Text
		equipBtn.Text = if data.Equipped == selected then "Unequip" else "Equip"
		displayBtn.Text = if table.find(data.Displayed, selected) then "Remove from Garage" else "Display in Garage"
		if not confirmSell then
			sellBtn.Text = ("Sell (%s)"):format(Format.Short(core.SellValue))
		end
	end

	local function refresh(data)
		local count = 0
		for _ in data.Inventory do
			count += 1
		end
		summary.Text = ("Cores %d/%d   •   Garage %d/%d"):format(count, Config.Player.MaxInventory, #data.Displayed, data.DisplaySlots)
		if selected and not data.Inventory[selected] then
			selected = nil
		end

		UIKit.clear(grid)
		local entries = {}
		for uid, item in data.Inventory do
			local core = ItemData.Cores[item.Id]
			if core then
				table.insert(entries, { uid = uid, core = core })
			end
		end
		table.sort(entries, function(a, b)
			local ra, rb = Config.Rarities[a.core.Rarity].Order, Config.Rarities[b.core.Rarity].Order
			if ra ~= rb then
				return ra > rb
			end
			if a.core.DamageMult ~= b.core.DamageMult then
				return a.core.DamageMult > b.core.DamageMult
			end
			return a.uid < b.uid
		end)
		for i, entry in entries do
			local core = entry.core
			local color = Config.Rarities[core.Rarity].Color
			local card = UIKit.button({ LayoutOrder = i, Color = T.Panel2, Radius = 12, ZIndex = 23, Parent = grid }, function()
				selected = entry.uid
				confirmSell = false
				refresh(C.ClientState.Data)
			end)
			UIKit.stroke(card, color, if entry.uid == selected then 4 else 2)
			local gem = UIKit.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(40, 40), Rotation = 45, BackgroundColor3 = core.Color, Radius = 6, ZIndex = 24, Parent = card })
			UIKit.stroke(gem, color, 2)
			UIKit.label({ Text = core.Name, TextSize = 13, Position = UDim2.fromOffset(4, 72), Size = UDim2.new(1, -8, 0, 32), ZIndex = 24, Parent = card })
			UIKit.label({ Text = core.Rarity, TextSize = 11, TextColor3 = color, Position = UDim2.fromOffset(0, 102), Size = UDim2.new(1, 0, 0, 16), ZIndex = 24, Parent = card })
			local tags = {}
			if data.Equipped == entry.uid then
				table.insert(tags, "⚔️")
			end
			if table.find(data.Displayed, entry.uid) then
				table.insert(tags, "🏠")
			end
			if #tags > 0 then
				UIKit.label({ Text = table.concat(tags, " "), TextSize = 16, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(60, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 25, Parent = card })
			end
		end
		renderDetail(data)
	end

	return {
		Window = win,
		Refresh = refresh,
		OnOpen = function()
			confirmSell = false
		end,
	}
end

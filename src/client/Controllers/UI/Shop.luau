-- Shop window: Crates tab and Upgrades tab.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)
local ZoneData = require(Shared.ZoneData)
local Format = require(Shared.Format)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme

return function(UI, C)
	local win = UI:CreateWindow("Shop", "🛒 SHOP", T.Accent2)
	local body = win.Body
	local tab = "Crates"
	local busy = false

	local tabs = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), ZIndex = 22, Parent = body })
	UIKit.list(tabs, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
	local page = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.Accent2,
		ZIndex = 22,
		Parent = body,
	})
	local refresh

	local tabButtons = {}
	for i, name in { "Crates", "Upgrades" } do
		tabButtons[name] = UIKit.button({ Text = name, LayoutOrder = i, Size = UDim2.fromOffset(150, 38), Color = T.Panel3, ZIndex = 23, Parent = tabs }, function()
			tab = name
			refresh(C.ClientState.Data)
		end)
	end

	local function isTutorialFreeCrate(data): boolean
		if data.Tutorial.Done then
			return false
		end
		local QuestData = require(Shared.QuestData)
		local step = QuestData.Tutorial[data.Tutorial.Step]
		return step ~= nil and step.Event == "OpenCrate"
	end

	local function openCrate(crateId: string)
		if busy then
			return
		end
		busy = true
		local result = C.ClientState:Call("OpenCrate", crateId)
		if result.ok and result.Item then
			UI:Close()
			UI.CrateReveal.Play(result.Item, ItemData.Crates[crateId].Color)
		elseif result.msg then
			UI:Notify(result.msg, "warn")
		end
		busy = false
	end

	local function renderCrates(data)
		page:ClearAllChildren()
		local layout = UIKit.list(page, 12, true)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local crates = {}
		for id, crate in ItemData.Crates do
			table.insert(crates, { id = id, crate = crate })
		end
		table.sort(crates, function(a, b)
			return a.crate.Order < b.crate.Order
		end)
		for _, entry in crates do
			local crate = entry.crate
			local unlocked = data.UnlockedZones[crate.RequiredZone] == true
			local card = UIKit.panel({ LayoutOrder = crate.Order, Size = UDim2.fromOffset(226, 340), BackgroundColor3 = T.Panel2, Radius = 16, ZIndex = 23, Parent = page })
			UIKit.stroke(card, crate.Color, 3)
			local box = UIKit.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(84, 84), Rotation = -8, BackgroundColor3 = crate.Color, Radius = 14, ZIndex = 24, Parent = card })
			UIKit.gradient(box, Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 150))
			UIKit.label({ Text = "?", Font = UIKit.Fonts.Title, TextSize = 46, Size = UDim2.fromScale(1, 1), ZIndex = 25, Parent = box })
			UIKit.label({ Text = crate.Name, Font = UIKit.Fonts.Title, TextSize = 22, TextColor3 = crate.Color, Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 28), ZIndex = 24, Parent = card })
			local odds = ItemData.GetOdds(entry.id)
			local lines = {}
			for _, rarity in Config.RarityOrder do
				if odds[rarity] then
					table.insert(lines, ('<font color="#%s">%s</font>  %s%%'):format(Config.Rarities[rarity].Color:ToHex(), rarity, if odds[rarity] < 1 then string.format("%.2f", odds[rarity]) else string.format("%.1f", odds[rarity])))
				end
			end
			UIKit.label({ Text = table.concat(lines, "\n"), RichText = true, TextSize = 14, TextColor3 = T.Text, Position = UDim2.fromOffset(10, 138), Size = UDim2.new(1, -20, 0, 100), ZIndex = 24, Parent = card })
			local free = entry.id == "Basic" and isTutorialFreeCrate(data)
			local label, color
			if not unlocked then
				label, color = "🔒 " .. ZoneData.ById[crate.RequiredZone].Name, T.Panel3
			elseif free then
				label, color = "OPEN FREE!", T.Good
			else
				label, color = "🪙 " .. Format.Short(crate.Price), if data.Coins >= crate.Price then T.Accent2 else T.Panel3
			end
			local btn = UIKit.button({ Text = label, TextSize = 20, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -24, 0, 48), Color = color, ZIndex = 24, Parent = card }, function()
				openCrate(entry.id)
			end)
			if free then
				UI:PulseButton("Shop", false)
				UIKit.stroke(btn, T.Gold, 3)
			end
		end
		UIKit.label({ Text = ("Pity: %d/%d  (guaranteed Legendary+)"):format(data.Pity, Config.Pity), TextSize = 14, TextColor3 = T.Muted, LayoutOrder = 99, Size = UDim2.fromOffset(160, 340), ZIndex = 23, Parent = page })
	end

	local function renderUpgrades(data)
		page:ClearAllChildren()
		UIKit.list(page, 10)
		local ids = {}
		for id in Config.Upgrades do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			return Config.Upgrades[a].Order < Config.Upgrades[b].Order
		end)
		for _, id in ids do
			local def = Config.Upgrades[id]
			local level = data.Upgrades[id] or 0
			local maxed = level >= def.Max
			local cost = Config.UpgradeCost(id, level)
			local row = UIKit.panel({ LayoutOrder = def.Order, Size = UDim2.new(1, -12, 0, 76), BackgroundColor3 = T.Panel2, Radius = 14, ZIndex = 23, Parent = page })
			UIKit.label({ Text = def.Icon, TextSize = 34, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(56, 76), ZIndex = 24, Parent = row })
			UIKit.label({ Text = ("%s  <font color=\"#%s\">Lv %d/%d</font>"):format(def.Name, T.Muted:ToHex(), level, def.Max), RichText = true, Font = UIKit.Fonts.Title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(72, 10), Size = UDim2.new(1, -260, 0, 28), ZIndex = 24, Parent = row })
			UIKit.label({ Text = def.Description, TextSize = 15, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(72, 40), Size = UDim2.new(1, -260, 0, 24), ZIndex = 24, Parent = row })
			UIKit.button({
				Text = if maxed then "MAX" else "🪙 " .. Format.Short(cost),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(160, 48),
				Color = if maxed then T.Panel3 elseif data.Coins >= cost then T.Good else T.Panel3,
				ZIndex = 24,
				Parent = row,
			}, function()
				if maxed or busy then
					return
				end
				busy = true
				local result = C.ClientState:Call("BuyUpgrade", id)
				if result.ok then
					C.SoundController:Play("Reward", nil, 0.6, 1.3)
					C.EffectsController:UpgradeBurst()
				elseif result.msg then
					UI:Notify(result.msg, "warn")
				end
				busy = false
			end)
		end
	end

	refresh = function(data)
		if not data then
			return
		end
		for name, button in tabButtons do
			UIKit.setButtonColor(button, if name == tab then T.Accent2 else T.Panel3)
		end
		if tab == "Crates" then
			renderCrates(data)
		else
			renderUpgrades(data)
		end
	end

	return {
		Window = win,
		Refresh = refresh,
		OnOpen = function(arg)
			tab = if arg == "Upgrades" then "Upgrades" else "Crates"
		end,
	}
end

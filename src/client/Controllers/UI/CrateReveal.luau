-- CrateReveal: the roulette-style unboxing animation. The server has ALREADY decided
-- the item; this is purely presentation (a slowing spin that lands on the result).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme

return function(UI, C, root: ScreenGui)
	local overlay = UIKit.new("TextButton", { Name = "CrateReveal", Text = "", AutoButtonColor = false, Selectable = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50, Parent = root })
	local rays = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.7, 0.7), BackgroundTransparency = 1, ZIndex = 51, Parent = overlay })
	UIKit.new("UIAspectRatioConstraint", { Parent = rays })
	local rayParts = {}
	for i = 1, 8 do
		local ray = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.08, 1), Rotation = i * 22.5, BackgroundColor3 = T.Gold, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 51, Parent = rays })
		UIKit.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90, Parent = ray })
		table.insert(rayParts, ray)
	end
	local card = UIKit.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.26, 0.42), BackgroundColor3 = T.Panel, Radius = 22, ZIndex = 52, Parent = overlay })
	UIKit.new("UIAspectRatioConstraint", { AspectRatio = 0.78, Parent = card })
	local cardStroke = UIKit.stroke(card, T.Accent, 5)
	local cardScale = UIKit.new("UIScale", { Parent = card })
	local gem = UIKit.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.42, 0.33), Rotation = 45, BackgroundColor3 = T.Accent, Radius = 12, ZIndex = 53, Parent = card })
	UIKit.new("UIAspectRatioConstraint", { Parent = gem })
	UIKit.gradient(gem, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160))
	local nameLabel = UIKit.label({ Text = "", Font = UIKit.Fonts.Title, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.9, 0.13), ZIndex = 53, Parent = card })
	local rarityLabel = UIKit.label({ Text = "", Font = UIKit.Fonts.Title, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.7, 0.09), ZIndex = 53, Parent = card })
	local hint = UIKit.label({ Text = "Tap to continue", TextScaled = true, TextColor3 = T.Muted, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(0.4, 0.04), ZIndex = 52, Visible = false, Parent = overlay })

	local playing = false
	local canClose = false
	local spinConn: RBXScriptConnection? = nil

	local allCores = {}
	for id in ItemData.Cores do
		table.insert(allCores, id)
	end
	table.sort(allCores)

	local function show(coreId: string)
		local core = ItemData.Cores[coreId]
		local color = Config.Rarities[core.Rarity].Color
		gem.BackgroundColor3 = core.Color
		cardStroke.Color = color
		nameLabel.Text = core.Name
		nameLabel.TextColor3 = T.Text
		rarityLabel.Text = string.upper(core.Rarity)
		rarityLabel.TextColor3 = color
	end

	local function close()
		if not canClose then
			return
		end
		canClose = false
		UIKit.tween(overlay, 0.25, { BackgroundTransparency = 1 })
		UIKit.tween(cardScale, 0.2, { Scale = 0 })
		task.wait(0.25)
		overlay.Visible = false
		if spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
		playing = false
	end
	overlay.Activated:Connect(close)

	local module = {}

	function module.WaitClosed()
		while playing do
			task.wait(0.1)
		end
	end

	function module.Play(coreId: string, crateColor: Color3?)
		module.WaitClosed()
		playing = true
		canClose = false
		overlay.Visible = true
		hint.Visible = false
		for _, ray in rayParts do
			ray.BackgroundTransparency = 1
		end
		cardStroke.Color = crateColor or T.Accent
		overlay.BackgroundTransparency = 1
		UIKit.tween(overlay, 0.25, { BackgroundTransparency = 0.35 })
		cardScale.Scale = 0.3
		UIKit.tween(cardScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)

		-- Roulette: flick through random cores, slowing down.
		local ticks = 22
		for k = 1, ticks do
			local id = allCores[math.random(1, #allCores)]
			show(id)
			rarityLabel.Text = "?"
			C.SoundController:Play("UIClick", nil, 0.25, 0.8 + k / ticks)
			cardScale.Scale = 1.04
			UIKit.tween(cardScale, 0.05, { Scale = 1 })
			task.wait(0.035 + (k / ticks) ^ 3 * 0.25)
		end

		-- Reveal
		local core = ItemData.Cores[coreId]
		local rarity = Config.Rarities[core.Rarity]
		show(coreId)
		cardScale.Scale = 1.35
		UIKit.tween(cardScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		for _, ray in rayParts do
			ray.BackgroundColor3 = rarity.Color
			UIKit.tween(ray, 0.3, { BackgroundTransparency = if rarity.Order >= 3 then 0 else 0.5 })
		end
		spinConn = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation = (rays.Rotation + dt * 30) % 360
		end)
		C.SoundController:Play("Reward", nil, 1, if rarity.Order >= 4 then 0.8 else 1.2)
		if rarity.Order >= 4 then
			C.EffectsController:Shake(0.6, 0.5)
			C.SoundController:Play("LevelUp", nil, 1, 0.9)
		end
		task.wait(0.6)
		hint.Visible = true
		canClose = true
		task.delay(3.5, close)
	end

	return module
end

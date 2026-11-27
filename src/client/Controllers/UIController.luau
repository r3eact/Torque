-- UIController: builds the entire interface in code (no manual UI setup needed).
--
-- Layout is authored at a 1280x800 reference size inside a "Content" frame, then a
-- UIScale shrinks/grows it to fit any screen (phone, tablet, PC, TV). Touch devices
-- get a larger scale floor and a thumb-friendly ability cluster.
--
-- Windows (Inventory, Shop, Quests, Daily, Settings) live in UI/ as separate modules.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Signal = require(Shared.Signal)
local UIKit = require(script.Parent.UI.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer

local UIController = {}
UIController.AbilityPressed = Signal.new() -- (abilityId, isDown)
UIController.WindowChanged = Signal.new() -- (nameOrNil)
UIController.IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
UIController.Windows = {}
UIController.Current = nil :: string?

local C
local root: ScreenGui
local content: Frame
local uiScale: UIScale
local menuButtons: { [string]: TextButton } = {}
local abilityButtons: { [string]: { Button: TextButton, Overlay: Frame, Label: TextLabel, Lock: TextLabel } } = {}
local notifyStack: Frame
local dim: TextButton
local hud = {} :: any

local REF_W, REF_H = 1280, 800

local function applyScale()
	local size = root.AbsoluteSize
	if size.X <= 0 then
		return
	end
	local s = math.min(size.X / REF_W, size.Y / REF_H)
	local minScale = if UIController.IsTouch then 0.62 else 0.5
	s = math.clamp(s, minScale, 1.35)
	uiScale.Scale = s
	content.Size = UDim2.fromOffset(size.X / s, size.Y / s)
end

function UIController:GetContentSize(): Vector2
	return content.AbsoluteSize / uiScale.Scale
end

---------------------------------------------------------------- windows
function UIController:CreateWindow(name: string, title: string, accent: Color3?)
	local frame = UIKit.panel({
		Name = name .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(780, 520),
		BackgroundColor3 = T.Panel,
		Visible = false,
		ZIndex = 20,
		Radius = 18,
		Parent = content,
	})
	UIKit.stroke(frame, accent or T.Accent, 3)
	UIKit.gradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 210, 230))
	local scale = UIKit.new("UIScale", { Parent = frame })
	local header = UIKit.panel({ Name = "Header", Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = T.Panel2, Radius = 18, ZIndex = 21, Parent = frame })
	UIKit.label({ Text = title, Font = UIKit.Fonts.Title, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -100, 1, 0), ZIndex = 22, TextColor3 = accent or T.Accent, Parent = header })
	UIKit.button({ Text = "✕", Size = UDim2.fromOffset(42, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Color = T.Bad, ZIndex = 23, TextSize = 22, Parent = header }, function()
		self:Close()
	end)
	local body = UIKit.new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 1, -86), ZIndex = 21, Parent = frame })
	return { Frame = frame, Body = body, Scale = scale }
end

-- module: { Window = CreateWindow(...), Refresh = fn(data), OnOpen = fn(arg) }
function UIController:RegisterWindow(name: string, module)
	self.Windows[name] = module
end

function UIController:Open(name: string, arg: any?)
	local module = self.Windows[name]
	if not module then
		return
	end
	if self.Current and self.Current ~= name then
		self.Windows[self.Current].Window.Frame.Visible = false
	end
	self.Current = name
	local win = module.Window
	local view = self:GetContentSize()
	win.Frame.Size = UDim2.fromOffset(math.min(780, view.X - 24), math.min(520, view.Y - 24))
	if module.OnOpen then
		module.OnOpen(arg)
	end
	if module.Refresh and C.ClientState.Data then
		module.Refresh(C.ClientState.Data)
	end
	win.Frame.Visible = true
	dim.Visible = true
	win.Scale.Scale = 0.85
	UIKit.tween(win.Scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	C.SoundController:Play("UIClick", nil, 0.5, 1.2)
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = win.Frame:FindFirstChildWhichIsA("GuiButton", true)
	end
	self.WindowChanged:Fire(name)
end

function UIController:Close()
	if not self.Current then
		return
	end
	local win = self.Windows[self.Current].Window
	self.Current = nil
	dim.Visible = false
	local tween = UIKit.tween(win.Scale, 0.12, { Scale = 0.85 })
	tween.Completed:Once(function()
		if self.Windows and win.Scale.Scale <= 0.86 then
			win.Frame.Visible = false
		end
	end)
	GuiService.SelectedObject = nil
	self.WindowChanged:Fire(nil)
end

function UIController:Toggle(name: string, arg: any?)
	if self.Current == name then
		self:Close()
	else
		self:Open(name, arg)
	end
end

---------------------------------------------------------------- feedback
local NOTIFY_COLORS = {
	info = T.Accent,
	reward = T.Good,
	levelup = T.Gold,
	warn = T.Bad,
	rare = Color3.fromRGB(255, 90, 200),
	drop = Color3.fromRGB(176, 120, 255),
}

function UIController:Notify(text: string, kind: string?)
	local color = NOTIFY_COLORS[kind or "info"] or T.Accent
	local item = UIKit.panel({ Size = UDim2.fromOffset(520, 44), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.15, Radius = 12, ZIndex = 40, Parent = notifyStack })
	local stroke = UIKit.stroke(item, color, 2)
	local label = UIKit.label({ Text = text, TextColor3 = color, TextSize = 19, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), ZIndex = 41, Parent = item })
	local scale = UIKit.new("UIScale", { Scale = 0.6, Parent = item })
	UIKit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "reward" or kind == "levelup" or kind == "drop" or kind == "rare" then
		C.SoundController:Play("Reward", nil, 0.5, 1.1)
	end
	task.delay(3.6, function()
		UIKit.tween(item, 0.35, { BackgroundTransparency = 1 })
		UIKit.tween(label, 0.35, { TextTransparency = 1 })
		UIKit.tween(stroke, 0.35, { Transparency = 1 })
		task.wait(0.36)
		item:Destroy()
	end)
	local items = {}
	for _, child in notifyStack:GetChildren() do
		if child:IsA("Frame") then
			table.insert(items, child)
		end
	end
	if #items > 5 then
		items[1]:Destroy()
	end
end

function UIController:Banner(text: string, color: Color3?)
	local label = UIKit.label({
		Text = text,
		Font = UIKit.Fonts.Title,
		TextSize = 54,
		TextColor3 = color or T.Accent,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromOffset(900, 80),
		TextTransparency = 1,
		ZIndex = 30,
		Parent = content,
	})
	local scale = UIKit.new("UIScale", { Scale = 1.4, Parent = label })
	UIKit.tween(label, 0.3, { TextTransparency = 0 })
	UIKit.tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		UIKit.tween(label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		task.wait(0.5)
		label:Destroy()
	end)
end

function UIController:ShowLevelUp(level: number)
	self:Banner(("LEVEL %d!"):format(level), T.Gold)
	local flash = UIKit.new("Frame", { BackgroundColor3 = T.Gold, BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), ZIndex = 29, BorderSizePixel = 0, Parent = content })
	UIKit.tween(flash, 0.6, { BackgroundTransparency = 1 }).Completed:Once(function()
		flash:Destroy()
	end)
end

function UIController:FlashDamage()
	hud.Vignette.Transparency = 0.45
	UIKit.tween(hud.Vignette, 0.5, { Transparency = 1 })
end

-- Floating "+12 XP" style text near the bottom center.
function UIController:FloatText(text: string, color: Color3)
	local label = UIKit.label({
		Text = text,
		Font = UIKit.Fonts.Title,
		TextSize = 28,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.random(-60, 60), 0.62, 0),
		Size = UDim2.fromOffset(300, 40),
		ZIndex = 25,
		Parent = content,
	})
	UIKit.tween(label, 0.9, { Position = label.Position - UDim2.fromOffset(0, 70), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(0.95, function()
		label:Destroy()
	end)
end

function UIController:PulseButton(name: string, enabled: boolean)
	local button = menuButtons[name]
	if not button then
		return
	end
	local stroke = button:FindFirstChild("PulseStroke") :: UIStroke?
	if enabled and not stroke then
		local s = UIKit.stroke(button, T.Gold, 4)
		s.Name = "PulseStroke"
		task.spawn(function()
			while s.Parent do
				UIKit.tween(s, 0.5, { Transparency = 0.8 })
				task.wait(0.5)
				UIKit.tween(s, 0.5, { Transparency = 0 })
				task.wait(0.5)
			end
		end)
	elseif not enabled and stroke then
		stroke:Destroy()
	end
end

function UIController:SetBadge(name: string, visible: boolean)
	local button = menuButtons[name]
	if button then
		(button :: any).Badge.Visible = visible
	end
end

function UIController:SetCooldown(abilityId: string, duration: number)
	local entry = abilityButtons[abilityId]
	if not entry then
		return
	end
	entry.Overlay.Size = UDim2.fromScale(1, 1)
	entry.Overlay.Visible = true
	local tween = UIKit.tween(entry.Overlay, duration, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Linear)
	tween.Completed:Once(function()
		entry.Overlay.Visible = false
	end)
end

function UIController:SetHudVisible(visible: boolean)
	content.Visible = visible
end

---------------------------------------------------------------- HUD
local function buildStats()
	local panel = UIKit.panel({ Name = "Stats", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(310, 96), BackgroundColor3 = T.Bg, BackgroundTransparency = 0.2, Radius = 16, Parent = content })
	UIKit.stroke(panel, T.Panel3, 2)
	local badge = UIKit.panel({ Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = T.Accent2, Radius = 36, Parent = panel })
	UIKit.gradient(badge, Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 110, 30))
	UIKit.label({ Text = "LV", TextSize = 14, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 8), Parent = badge })
	hud.Level = UIKit.label({ Text = "1", Font = UIKit.Fonts.Title, TextSize = 32, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 26), Parent = badge })
	hud.XPText = UIKit.label({ Text = "0 / 40 XP", TextSize = 14, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(96, 12), Size = UDim2.fromOffset(200, 18), Parent = panel })
	local _, setXP = UIKit.bar({ Position = UDim2.fromOffset(96, 32), Size = UDim2.fromOffset(200, 14), Parent = panel }, T.Accent)
	hud.SetXP = setXP
	hud.Coins = UIKit.label({ Text = "🪙 0", Font = UIKit.Fonts.Title, TextSize = 26, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(96, 50), Size = UDim2.fromOffset(130, 32), Parent = panel })
	hud.Income = UIKit.label({ Text = "", TextSize = 14, TextColor3 = T.Good, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(196, 56), Size = UDim2.fromOffset(100, 24), Parent = panel })
end

local MENU = {
	{ Id = "Inventory", Icon = "🎒", Label = "Cores" },
	{ Id = "Shop", Icon = "🛒", Label = "Shop" },
	{ Id = "Quests", Icon = "📜", Label = "Quests" },
	{ Id = "Daily", Icon = "🎁", Label = "Daily" },
	{ Id = "Home", Icon = "🏠", Label = "Garage" },
	{ Id = "Settings", Icon = "⚙️", Label = "Settings" },
}

local function buildMenu()
	local frame = UIKit.new("Frame", { Name = "Menu", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 10), Size = UDim2.fromOffset(78, #MENU * 84), Parent = content })
	UIKit.list(frame, 8)
	for i, entry in MENU do
		local button = UIKit.button({ Name = entry.Id, LayoutOrder = i, Size = UDim2.fromOffset(74, 74), Color = T.Panel2, Radius = 16, Parent = frame }, function()
			if entry.Id == "Home" then
				local result = C.ClientState:Call("TeleportHome")
				if not result.ok and result.msg then
					UIController:Notify(result.msg, "warn")
				end
			else
				UIController:Toggle(entry.Id)
			end
		end)
		UIKit.stroke(button, T.Panel3, 2)
		UIKit.label({ Text = entry.Icon, TextSize = 30, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 4), Parent = button })
		UIKit.label({ Text = entry.Label, TextSize = 13, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 50), TextColor3 = T.Muted, Parent = button })
		local badge = UIKit.panel({ Name = "Badge", Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -14, 0, -4), BackgroundColor3 = T.Bad, Radius = 9, Visible = false, ZIndex = 3, Parent = button })
		UIKit.label({ Text = "!", TextSize = 14, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = badge })
		menuButtons[entry.Id] = button
	end
end

local function buildTracker()
	local panel = UIKit.panel({ Name = "Tracker", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(320, 40), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Bg, BackgroundTransparency = 0.25, Radius = 14, Parent = content })
	UIKit.stroke(panel, T.Panel3, 2)
	UIKit.padding(panel, 10)
	UIKit.list(panel, 6)
	hud.Tracker = panel
end

local function renderTracker(data)
	local QuestData = require(Shared.QuestData)
	UIKit.clear(hud.Tracker)
	local function line(text: string, color: Color3, order: number, size: number?)
		return UIKit.label({ Text = text, TextColor3 = color, TextSize = size or 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = hud.Tracker })
	end
	if not data.Tutorial.Done then
		local step = QuestData.Tutorial[data.Tutorial.Step]
		if step then
			line(("⭐ TUTORIAL  %d/%d"):format(data.Tutorial.Step, #QuestData.Tutorial), T.Gold, 1, 17)
			line(step.Text, T.Text, 2, 17)
			local _, set = UIKit.bar({ Size = UDim2.new(1, 0, 0, 10), LayoutOrder = 3, Parent = hud.Tracker }, T.Gold)
			set(data.Tutorial.Progress / step.Target, true)
			line(("Reward: %d coins"):format(step.Reward), T.Muted, 4, 13)
			return
		end
	end
	line("📜 DAILY QUESTS", T.Accent, 1, 17)
	for i, quest in data.Quests.Active do
		local def = QuestData.DailyById[quest.Id]
		if def then
			local done = quest.Progress >= def.Target
			local text = if quest.Claimed then ("✔ %s"):format(def.Text) else ("%s  %s/%s"):format(def.Text, Format.Short(quest.Progress), Format.Short(def.Target))
			line(text, if quest.Claimed then T.Muted elseif done then T.Good else T.Text, i + 1)
		end
	end
end

local function buildHealth()
	local back, setHealth = UIKit.bar({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -118), Size = UDim2.fromOffset(380, 22), Parent = content }, T.Good)
	UIKit.stroke(back, T.Bg, 3)
	hud.HealthText = UIKit.label({ Text = "100 / 100", TextSize = 15, Size = UDim2.fromScale(1, 1), ZIndex = 3, TextStrokeTransparency = 0.5, Parent = back })
	hud.SetHealth = setHealth
	hud.HealthBar = back

	local function bind(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local last = humanoid.Health
		local function update()
			setHealth(humanoid.Health / math.max(1, humanoid.MaxHealth))
			hud.HealthText.Text = ("%d / %d"):format(math.ceil(humanoid.Health), humanoid.MaxHealth)
			if humanoid.Health < last - 0.5 then
				UIController:FlashDamage()
			end
			last = humanoid.Health
		end
		humanoid.HealthChanged:Connect(update)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
		update()
	end
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(bind)

	-- Red edge vignette: a thick UIStroke around a frame inset from the screen edges.
	local vignette = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -80, 1, -80),
		ZIndex = 0,
		Parent = content,
	})
	hud.Vignette = UIKit.stroke(vignette, T.Bad, 80, 1)
end

local function buildAbilities()
	local frame = UIKit.new("Frame", { Name = "Abilities", BackgroundTransparency = 1, Parent = content })
	local touch = UIController.IsTouch
	if touch then
		frame.AnchorPoint = Vector2.new(1, 1)
		frame.Position = UDim2.new(1, -20, 1, -20)
		frame.Size = UDim2.fromOffset(300, 260)
	else
		frame.AnchorPoint = Vector2.new(0.5, 1)
		frame.Position = UDim2.new(0.5, 0, 1, -16)
		frame.Size = UDim2.fromOffset(3 * 92, 88)
	end
	-- Touch: big Strike button bottom-right with skills arcing around it (thumb reach).
	local touchLayout = {
		Strike = { pos = UDim2.new(1, -150, 1, -150), size = 150 },
		Slam = { pos = UDim2.new(1, -250, 1, -100), size = 96 },
		Overdrive = { pos = UDim2.new(1, -110, 1, -256), size = 96 },
	}
	local gamepadLabels = { Strike = "R2", Slam = "R1", Overdrive = "L1" }
	for id, def in Config.Abilities do
		local size, pos
		if touch then
			size = touchLayout[id].size
			pos = touchLayout[id].pos
		else
			size = 82
			pos = UDim2.fromOffset((def.Order - 1) * 92 + 5, 0)
		end
		local button = UIKit.button({ Name = id, Size = UDim2.fromOffset(size, size), Position = pos, Color = T.Panel2, Radius = size // 2, Parent = frame })
		UIKit.stroke(button, T.Accent, 3)
		UIKit.label({ Text = def.Icon, TextSize = size * 0.42, Size = UDim2.fromScale(1, 0.7), Parent = button })
		local key = UIKit.label({ Text = if UserInputService.GamepadEnabled and not touch then gamepadLabels[id] else (if touch then def.Name else def.KeyLabel), TextSize = if touch then 12 else 14, TextColor3 = T.Muted, Position = UDim2.fromScale(0, 0.66), Size = UDim2.fromScale(1, 0.28), Parent = button })
		local overlay = UIKit.new("Frame", { Name = "Cooldown", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), Visible = false, ZIndex = 5, Parent = button })
		UIKit.corner(overlay, size // 2)
		local lock = UIKit.label({ Text = "🔒 Lv " .. def.UnlockLevel, TextSize = 14, BackgroundTransparency = 0.3, BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 6, Visible = false, Parent = button })
		UIKit.corner(lock, size // 2)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				UIController.AbilityPressed:Fire(id, true)
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				UIController.AbilityPressed:Fire(id, false)
			end
		end)
		abilityButtons[id] = { Button = button, Overlay = overlay, Label = key, Lock = lock }
	end
	if touch then
		hud.HealthBar.Position = UDim2.new(0.5, 0, 1, -24)
	end
end

local function render(data)
	hud.Level.Text = tostring(data.Level)
	local needed = Config.XPForLevel(data.Level)
	hud.XPText.Text = ("%s / %s XP"):format(Format.Short(data.XP), Format.Short(needed))
	hud.SetXP(data.XP / needed)
	local coinsText = "🪙 " .. Format.Short(data.Coins)
	if hud.Coins.Text ~= coinsText then
		hud.Coins.Text = coinsText
		local s = hud.Coins:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", { Parent = hud.Coins })
		s.Scale = 1.15
		UIKit.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	hud.Income.Text = if data.IncomePerSecond > 0 then ("+%s/s"):format(Format.Short(data.IncomePerSecond)) else ""
	for id, def in Config.Abilities do
		abilityButtons[id].Lock.Visible = data.Level < def.UnlockLevel
	end
	local today = Config.Day(data.ServerTime)
	UIController:SetBadge("Daily", data.Daily.LastClaimDay < today)
	local claimable = false
	local QuestData = require(Shared.QuestData)
	for _, q in data.Quests.Active do
		local def = QuestData.DailyById[q.Id]
		if def and not q.Claimed and q.Progress >= def.Target then
			claimable = true
		end
	end
	UIController:SetBadge("Quests", claimable)
	renderTracker(data)
	if UIController.Current then
		local module = UIController.Windows[UIController.Current]
		if module and module.Refresh then
			module.Refresh(data)
		end
	end
end

---------------------------------------------------------------- lifecycle
function UIController:Init(controllers)
	C = controllers
	local playerGui = player:WaitForChild("PlayerGui")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	root = UIKit.new("ScreenGui", {
		Name = "TorqueUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	pcall(function()
		(root :: any).ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	content = UIKit.new("Frame", { Name = "Content", BackgroundTransparency = 1, Visible = false, Parent = root })
	uiScale = UIKit.new("UIScale", { Parent = content })
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyScale)
	applyScale()

	dim = UIKit.new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 19, Selectable = false, Parent = content })
	dim.Activated:Connect(function()
		self:Close()
	end)

	notifyStack = UIKit.new("Frame", { Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(520, 300), ZIndex = 40, Parent = content })
	UIKit.list(notifyStack, 6)

	buildStats()
	buildMenu()
	buildTracker()
	buildHealth()
	buildAbilities()

	-- Windows
	local UI = script.Parent.UI
	for _, name in { "Inventory", "Shop", "Quests", "Daily", "Settings" } do
		local module = require(UI:WaitForChild(name))(self, C)
		self:RegisterWindow(name, module)
	end
	self.CrateReveal = require(UI:WaitForChild("CrateReveal"))(self, C, root)
	self.Menu = require(UI:WaitForChild("Menu"))(self, C, playerGui)
end

function UIController:Start()
	local Net = require(Shared.Net)
	Net.Event("Notify").OnClientEvent:Connect(function(text, kind)
		self:Notify(text, kind)
	end)
	C.ClientState.Changed:Connect(render)
	if C.ClientState.Data then
		render(C.ClientState.Data)
	end

	-- Keyboard / gamepad shortcuts for menus
	local shortcuts = {
		[Enum.KeyCode.F] = "Inventory",
		[Enum.KeyCode.G] = "Shop",
		[Enum.KeyCode.T] = "Quests",
		[Enum.KeyCode.DPadLeft] = "Inventory",
		[Enum.KeyCode.DPadRight] = "Shop",
		[Enum.KeyCode.DPadUp] = "Quests",
		[Enum.KeyCode.DPadDown] = "Daily",
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not content.Visible then
			return
		end
		local target = shortcuts[input.KeyCode]
		if target then
			self:Toggle(target)
		elseif input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
			self:Close()
		end
	end)
	ContextActionService:BindAction("TorqueCloseWindow", function(_, state)
		if state == Enum.UserInputState.Begin and self.Current then
			self:Close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB)

	self.Menu.Show()
end

return UIController

-- Settings window: volume, damage numbers, camera shake, tutorial skip.
-- Changes apply instantly on the client and are saved to the profile (debounced).
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme

return function(UI, C)
	local win = UI:CreateWindow("Settings", "⚙️ SETTINGS", T.Muted)
	local body = win.Body
	local list = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = body })
	UIKit.list(list, 10)
	local pending: { [string]: any } = {}
	local saveScheduled = false

	local function save(key: string, value: any)
		-- Optimistic local update so the UI responds immediately.
		local data = C.ClientState.Data
		if data then
			data.Settings[key] = value
			C.ClientState.Changed:Fire(data)
		end
		pending[key] = value
		if not saveScheduled then
			saveScheduled = true
			task.delay(0.6, function()
				saveScheduled = false
				local toSend = pending
				pending = {}
				C.ClientState:Call("SaveSettings", toSend)
			end)
		end
	end

	local function row(order: number, title: string)
		local r = UIKit.panel({ LayoutOrder = order, Size = UDim2.new(1, -12, 0, 64), BackgroundColor3 = T.Panel2, Radius = 14, ZIndex = 23, Parent = list })
		UIKit.label({ Text = title, Font = UIKit.Fonts.Title, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 24, Parent = r })
		return r
	end

	local refreshers = {}

	local function volumeRow(order: number, title: string, key: string)
		local r = row(order, title)
		local value = UIKit.label({ Text = "", TextSize = 20, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -76, 0.5, 0), Size = UDim2.fromOffset(80, 40), ZIndex = 24, Parent = r })
		local function change(delta: number)
			local data = C.ClientState.Data
			if data then
				save(key, math.clamp(math.floor((data.Settings[key] + delta) * 10 + 0.5) / 10, 0, 1))
			end
		end
		UIKit.button({ Text = "−", TextSize = 26, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -160, 0.5, 0), Size = UDim2.fromOffset(48, 44), Color = T.Panel3, ZIndex = 24, Parent = r }, function()
			change(-0.1)
		end)
		UIKit.button({ Text = "+", TextSize = 26, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(48, 44), Color = T.Accent, ZIndex = 24, Parent = r }, function()
			change(0.1)
		end)
		table.insert(refreshers, function(data)
			value.Text = ("%d%%"):format(math.floor(data.Settings[key] * 100 + 0.5))
		end)
	end

	local function toggleRow(order: number, title: string, key: string)
		local r = row(order, title)
		local toggle = UIKit.button({ Text = "", TextSize = 18, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 44), ZIndex = 24, Parent = r }, function()
			local data = C.ClientState.Data
			if data then
				save(key, not data.Settings[key])
			end
		end)
		table.insert(refreshers, function(data)
			local on = data.Settings[key]
			toggle.Text = if on then "ON" else "OFF"
			UIKit.setButtonColor(toggle, if on then T.Good else T.Panel3)
		end)
	end

	volumeRow(1, "🎵 Music", "Music")
	volumeRow(2, "🔊 Sound Effects", "Sfx")
	toggleRow(3, "🔢 Damage Numbers", "DamageNumbers")
	toggleRow(4, "📳 Camera Shake", "CameraShake")
	local tutorialRow = row(5, "⭐ Tutorial")
	local skipBtn = UIKit.button({ Text = "Skip", TextSize = 18, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 44), Color = T.Bad, ZIndex = 24, Parent = tutorialRow }, function()
		C.ClientState:Call("SkipTutorial")
	end)
	UIKit.label({ Text = "Controls — PC: LMB Strike, Q Slam, R Overdrive, F Cores, G Shop, T Quests  •  Gamepad: R2 / R1 / L1, D-Pad menus  •  Mobile: on-screen buttons", TextSize = 13, TextColor3 = T.Muted, LayoutOrder = 6, Size = UDim2.new(1, -12, 0, 44), ZIndex = 23, Parent = list })

	local function refresh(data)
		for _, fn in refreshers do
			fn(data)
		end
		skipBtn.Text = if data.Tutorial.Done then "Done ✔" else "Skip"
		UIKit.setButtonColor(skipBtn, if data.Tutorial.Done then T.Panel3 else T.Bad)
	end

	return { Window = win, Refresh = refresh }
end

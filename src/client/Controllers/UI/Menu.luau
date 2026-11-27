-- Main menu: a title screen shown on join with a slow cinematic camera orbit.
-- Pressing PLAY fades it out and hands the camera back to the player.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme
local player = Players.LocalPlayer

return function(UI, C, playerGui: PlayerGui)
	local gui = UIKit.new("ScreenGui", { Name = "TorqueMenu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false, Parent = playerGui })
	local bg = UIKit.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Parent = gui })
	UIKit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(10, 20, 40), Color3.fromRGB(40, 10, 30)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0.1) }),
		Rotation = 90,
		Parent = bg,
	})
	local center = UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.8), Parent = bg })
	local title = UIKit.label({ Text = "TORQUE", Font = UIKit.Fonts.Title, TextScaled = true, TextColor3 = T.Accent2, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(60, 20, 0), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.08), Size = UDim2.fromScale(0.8, 0.26), Parent = center })
	UIKit.gradient(title, Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 110, 20))
	local titleScale = UIKit.new("UIScale", { Parent = title })
	UIKit.label({ Text = "CORE RUSH", Font = UIKit.Fonts.Title, TextScaled = true, TextColor3 = T.Accent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromScale(0.5, 0.08), Parent = center })
	UIKit.label({ Text = "Smash bots  •  Loot rare Cores  •  Build your Garage empire", TextScaled = true, TextColor3 = T.Text, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.7, 0.05), Parent = center })
	local play = UIKit.button({ Text = "Loading...", Font = UIKit.Fonts.Title, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.26, 0.13), Color = T.Accent2, Radius = 20, Parent = center })
	UIKit.new("UISizeConstraint", { MinSize = Vector2.new(200, 60), MaxSize = Vector2.new(420, 110), Parent = play })
	UIKit.new("UITextSizeConstraint", { MaxTextSize = 48, Parent = play })
	UIKit.stroke(play, Color3.fromRGB(255, 230, 160), 4)
	local tip = UIKit.label({ Text = "", TextScaled = true, TextColor3 = T.Muted, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromScale(0.7, 0.04), Parent = center })

	local TIPS = {
		"Tip: Cores in your Garage earn coins even while you're offline!",
		"Tip: Bosses respawn every few minutes - team up to take them down.",
		"Tip: Every 60th crate is a guaranteed Legendary or better.",
		"Tip: Step into the PvP Arena to battle other players.",
		"Tip: Log in daily - Day 7 gives a Neon Crate!",
	}

	local orbitConn: RBXScriptConnection? = nil
	local started = false

	local function startOrbit()
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		orbitConn = RunService.RenderStepped:Connect(function()
			camera.CameraType = Enum.CameraType.Scriptable -- the default camera script may reset it on spawn
			local t = (os.clock() - t0) * 0.08
			local focus = Vector3.new(0, 10, 40)
			local pos = focus + Vector3.new(math.sin(t) * 95, 38, math.cos(t) * 95)
			camera.CFrame = CFrame.lookAt(pos, focus)
		end)
	end

	local function stopOrbit()
		if orbitConn then
			orbitConn:Disconnect()
			orbitConn = nil
		end
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	local function onPlay()
		if started or not C.ClientState.Data then
			return
		end
		started = true
		C.SoundController:Play("UIClick", nil, 0.8, 1)
		UIKit.tween(bg, 0.5, { BackgroundTransparency = 1 })
		for _, d in gui:GetDescendants() do
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				UIKit.tween(d, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 })
			end
		end
		task.wait(0.45)
		gui.Enabled = false
		stopOrbit()
		UI:SetHudVisible(true)
		GuiService.SelectedObject = nil
		local data = C.ClientState.Data
		if data.TotalKills == 0 and not data.Tutorial.Done then
			UI:Banner("WELCOME TO TORQUE!", T.Accent2)
			task.delay(2.4, function()
				UI:Banner("Follow the glowing beam!", T.Accent)
			end)
		end
	end
	play.Activated:Connect(onPlay)

	return {
		Show = function()
			gui.Enabled = true
			UI:SetHudVisible(false)
			startOrbit()
			tip.Text = TIPS[math.random(1, #TIPS)]
			task.spawn(function()
				while not started do
					UIKit.tween(titleScale, 1.2, { Scale = 1.05 }, Enum.EasingStyle.Sine)
					task.wait(1.2)
					UIKit.tween(titleScale, 1.2, { Scale = 1 }, Enum.EasingStyle.Sine)
					task.wait(1.2)
				end
			end)
			C.ClientState:WaitForData()
			play.Text = "PLAY"
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = play
			end
		end,
	}
end

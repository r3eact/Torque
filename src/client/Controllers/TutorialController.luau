-- TutorialController: points new players at their next objective with a glowing beam
-- from their character to the target, plus a bouncing arrow over it. Objectives come
-- from the server-side tutorial step in the player's data.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestData = require(Shared.QuestData)

local player = Players.LocalPlayer

local TutorialController = {}
local C
local beam: Beam
local targetAttachment: Attachment
local arrow: BillboardGui
local currentHint: string? = nil

function TutorialController:Init(controllers)
	C = controllers
end

local function findTarget(hint: string): BasePart?
	local world = workspace:FindFirstChild("World")
	if not world then
		return nil
	end
	if hint == "Collector" then
		local index = player:GetAttribute("PlotIndex")
		local plot = index and world.Plots:FindFirstChild("Plot" .. index)
		return plot and plot:FindFirstChild("Collector") :: BasePart?
	end
	if hint == "Scrapyard" then
		-- Point at the closest living bot once the player is in the zone.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and root.Position.Z < -80 then
			local best, bestDist = nil, math.huge
			for _, model in world.Enemies:GetChildren() do
				local eRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if eRoot and model:GetAttribute("EnemyId") == "ScrapBot" then
					local d = (eRoot.Position - root.Position).Magnitude
					if d < bestDist then
						best, bestDist = eRoot, d
					end
				end
			end
			if best then
				return best
			end
		end
	end
	return world.Markers:FindFirstChild(hint) :: BasePart?
end

local function attachToCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local a0 = Instance.new("Attachment")
	a0.Name = "TutorialAttachment"
	a0.Parent = root
	beam.Attachment0 = a0
end

function TutorialController:Start()
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = workspace.Terrain

	beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 210, 60), Color3.fromRGB(0, 214, 255))
	beam.LightEmission = 1
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.Segments = 20
	beam.CurveSize0 = 4
	beam.Transparency = NumberSequence.new(0.2)
	beam.Enabled = false
	beam.Parent = workspace.Terrain

	arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(80, 80)
	arrow.AlwaysOnTop = true
	arrow.LightInfluence = 0
	arrow.Adornee = targetAttachment
	arrow.Enabled = false
	arrow.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "▼"
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeTransparency = 0
	label.Parent = arrow

	player.CharacterAdded:Connect(attachToCharacter)
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end

	local function onData(data)
		local hint = nil
		if not data.Tutorial.Done then
			local step = QuestData.Tutorial[data.Tutorial.Step]
			hint = step and step.Hint
		end
		if hint ~= currentHint then
			currentHint = hint
			C.UIController:PulseButton("Inventory", hint == "Inventory")
			C.UIController:PulseButton("Shop", hint == "Shop")
		end
	end
	C.ClientState.Changed:Connect(onData)
	if C.ClientState.Data then
		onData(C.ClientState.Data)
	end

	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		local target = currentHint and currentHint ~= "Inventory" and findTarget(currentHint)
		if target and C.UIController.Current == nil then
			targetAttachment.WorldPosition = target.Position + Vector3.new(0, 4 + math.sin(t * 4) * 0.6, 0)
			beam.Enabled = true
			arrow.Enabled = true
		else
			beam.Enabled = false
			arrow.Enabled = false
		end
	end)
end

return TutorialController

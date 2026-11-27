-- WorldController: client-side world behaviour.
--   * Spins/bobs decorative parts tagged "Spin"/"SpinX" (cheap, local only)
--   * Makes unlocked zone gates passable for this player only
--   * Opens UI windows from in-world ProximityPrompts (Shop, Upgrades)
--   * Shows an "Entering <Zone>" banner when crossing zone borders
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneData = require(Shared.ZoneData)

local player = Players.LocalPlayer

local WorldController = {}
local C
local spinning: { [Instance]: CFrame } = {}

function WorldController:Init(controllers)
	C = controllers
end

local function track(tag: string)
	local function add(inst: Instance)
		if inst:IsA("BasePart") then
			spinning[inst] = inst.CFrame
		elseif inst:IsA("Model") then
			spinning[inst] = inst:GetPivot()
		end
	end
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		spinning[inst] = nil
	end)
end

local function updateGates(data)
	for _, gate in CollectionService:GetTagged("ZoneGate") do
		if gate:IsA("BasePart") then
			local unlocked = data.UnlockedZones[gate:GetAttribute("ZoneId")] == true
			gate.CanCollide = not unlocked
			gate.Transparency = if unlocked then 0.9 else 0.1
			for _, d in gate:GetDescendants() do
				if d:IsA("SurfaceGui") then
					d.Enabled = not unlocked
				elseif d:IsA("ProximityPrompt") then
					d.Enabled = not unlocked
				end
			end
		end
	end
end

function WorldController:Start()
	track("Spin")
	track("SpinX")
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		for inst, base in spinning do
			if not inst.Parent then
				spinning[inst] = nil
				continue
			end
			if CollectionService:HasTag(inst, "SpinX") then
				(inst :: Model):PivotTo(base * CFrame.Angles(t * 0.6, 0, 0))
			else
				local bob = math.sin(t * 2 + base.Position.X) * 0.4
				(inst :: BasePart).CFrame = CFrame.new(base.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * 1.5, 0) * base.Rotation
			end
		end
	end)

	C.ClientState.Changed:Connect(updateGates)
	if C.ClientState.Data then
		updateGates(C.ClientState.Data)
	end
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(function()
		if C.ClientState.Data then
			updateGates(C.ClientState.Data)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local opens = prompt:GetAttribute("OpensUI")
		if opens == "Shop" then
			C.UIController:Open("Shop", "Crates")
		elseif opens == "Upgrades" then
			C.UIController:Open("Shop", "Upgrades")
		end
	end)

	-- Zone banner
	local lastZone = nil
	while true do
		task.wait(0.4)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local zoneId = ZoneData.GetZoneIdAt(root.Position)
			if zoneId and zoneId ~= lastZone then
				if lastZone ~= nil then
					local zone = ZoneData.ById[zoneId]
					if zone then
						C.UIController:Banner(string.upper(zone.Name), zone.AccentColor)
					else
						C.UIController:Banner("HUB", Color3.fromRGB(0, 214, 255))
					end
				end
				lastZone = zoneId
			end
		end
	end
end

return WorldController

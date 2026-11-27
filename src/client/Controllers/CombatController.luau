-- CombatController: turns input (mouse, keyboard, gamepad, touch buttons) into ability
-- requests. The client plays the animation/sound/swing instantly for responsiveness
-- (cosmetic prediction) and sends only (abilityId, aimDirection) to the server, which
-- decides what actually gets hit.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local CombatController = {}
local C
local abilityRemote = Net.Event("Ability")
local readyAt: { [string]: number } = {}
local holding = { Mouse = false, Button = false, Gamepad = false }
local tracks: { [string]: AnimationTrack } = {}

function CombatController:Init(controllers)
	C = controllers
end

local function loadAnimations(character: Model)
	table.clear(tracks)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local set = if humanoid.RigType == Enum.HumanoidRigType.R15 then Config.Animations.R15 else Config.Animations.R6
	for name, id in set do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			tracks[name] = track
		end
	end
end

-- Aim assist: face the closest bot in front (or very close) so mobile/gamepad players
-- don't need precise aiming. Returns a flat aim direction.
local function computeAim(root: BasePart, range: number): Vector3
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local enemies = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Enemies")
	if not enemies then
		return look
	end
	local best, bestScore = nil, math.huge
	for _, model in enemies:GetChildren() do
		local eRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if eRoot and humanoid and humanoid.Health > 0 then
			local offset = eRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local dist = flat.Magnitude
			if dist < range + 4 and dist > 0.1 then
				local dot = flat.Unit:Dot(look)
				if dot > -0.2 or dist < 6 then
					local score = dist - dot * 4
					if score < bestScore then
						best, bestScore = flat.Unit, score
					end
				end
			end
		end
	end
	if best then
		-- Turn the character toward the target (the client owns its character).
		root.CFrame = CFrame.lookAt(root.Position, root.Position + best)
		return best
	end
	return look
end

function CombatController:Use(abilityId: string)
	local def = Config.Abilities[abilityId]
	local data = C.ClientState.Data
	if not def or not data then
		return
	end
	if data.Level < def.UnlockLevel then
		if abilityId ~= "Strike" then
			C.UIController:Notify(("%s unlocks at Level %d"):format(def.Name, def.UnlockLevel), "warn")
		end
		return
	end
	local now = os.clock()
	if (readyAt[abilityId] or 0) > now then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	readyAt[abilityId] = now + def.Cooldown
	if def.Cooldown >= 1 then
		C.UIController:SetCooldown(abilityId, def.Cooldown)
	end

	local aim = computeAim(root, def.Range or def.Radius or 10)
	if abilityId == "Strike" then
		local track = tracks.Strike
		if track then
			track:Play(0.05, 1, 1.8)
		end
		C.EffectsController:Swing(root, aim)
		C.SoundController:Play("Swing", nil, 0.5, 0.9 + math.random() * 0.25)
	elseif abilityId == "Slam" then
		local track = tracks.Slam
		if track then
			track:Play(0.05, 1, 1.4)
		end
		C.EffectsController:Shockwave(root.Position, def.Radius, Color3.fromRGB(0, 214, 255))
		C.EffectsController:Shake(0.4, 0.25)
		C.SoundController:Play("Slam", nil, 0.8)
	elseif abilityId == "Overdrive" then
		C.SoundController:Play("LevelUp", nil, 0.7, 1.3)
	end
	abilityRemote:FireServer(abilityId, aim)
end

local function isHolding(): boolean
	return holding.Mouse or holding.Button or holding.Gamepad
end

function CombatController:Start()
	player.CharacterAdded:Connect(loadAnimations)
	if player.Character then
		task.spawn(loadAnimations, player.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if C.UIController.Current then
			return -- a window is open; clicks belong to the UI
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding.Mouse = true
			self:Use("Strike")
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			holding.Gamepad = true
			self:Use("Strike")
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonR1 then
			self:Use("Slam")
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonL1 then
			self:Use("Overdrive")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding.Mouse = false
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			holding.Gamepad = false
		end
	end)

	-- On-screen ability buttons (touch + mouse)
	C.UIController.AbilityPressed:Connect(function(abilityId, isDown)
		if abilityId == "Strike" then
			holding.Button = isDown
		end
		if isDown then
			self:Use(abilityId)
		end
	end)

	-- Hold-to-attack: keeps striking at the cooldown rate while held.
	RunService.Heartbeat:Connect(function()
		if isHolding() and not C.UIController.Current then
			self:Use("Strike")
		end
	end)
end

return CombatController

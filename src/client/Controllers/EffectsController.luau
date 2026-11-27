-- EffectsController: all visual "juice" — damage numbers, hit sparks, shockwaves,
-- boss telegraphs, explosions, coins flying to the player, level-up pillars, camera
-- shake. Driven by the server's Effect remote, plus local calls for instant feedback.
-- Everything here is cosmetic and created only on the client.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Format)

local player = Players.LocalPlayer

local EffectsController = {}
local C
local fxFolder: Folder
local shakeIntensity, shakeUntil, shakeDuration = 0, 0, 0
local activeNumbers = 0

local function tween(inst: Instance, time: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function fxPart(props): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in props do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Parent = fxFolder
	return p
end

local function settings()
	local data = C.ClientState.Data
	return if data then data.Settings else { DamageNumbers = true, CameraShake = true }
end

function EffectsController:Shake(intensity: number, duration: number)
	if not settings().CameraShake then
		return
	end
	if intensity >= shakeIntensity or os.clock() > shakeUntil then
		shakeIntensity = intensity
		shakeDuration = duration
		shakeUntil = os.clock() + duration
	end
end

function EffectsController:DamageNumber(position: Vector3, amount: number, crit: boolean)
	if not settings().DamageNumbers or activeNumbers > 40 then
		return
	end
	activeNumbers += 1
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position + Vector3.new(math.random(-15, 15) / 10, 2 + math.random() * 1.5, math.random(-15, 15) / 10)
	attachment.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Adornee = attachment
	gui.Parent = attachment
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = if crit then 40 else 28
	label.TextColor3 = if crit then Color3.fromRGB(255, 210, 60) else Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = (if crit then "CRIT " else "") .. Format.Short(amount)
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = label
	tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(gui, 0.8, { StudsOffset = Vector3.new(0, 3, 0) })
	task.delay(0.45, function()
		tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	task.delay(0.85, function()
		attachment:Destroy()
		activeNumbers -= 1
	end)
end

function EffectsController:Sparks(position: Vector3, color: Color3, count: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.25, 0.45)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, 1)
end

function EffectsController:Swing(root: BasePart, aim: Vector3)
	local origin = root.Position + aim * 4
	local slash = fxPart({
		ClassName = "Part",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 4, 4),
		CFrame = CFrame.lookAt(origin, origin + aim) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 230, 255),
		Transparency = 0.3,
	})
	tween(slash, 0.18, { Size = Vector3.new(0.2, 9, 9), Transparency = 1 })
	Debris:AddItem(slash, 0.2)
end

function EffectsController:Shockwave(position: Vector3, radius: number, color: Color3)
	local ground = Vector3.new(position.X, 0.3, position.Z)
	local ring = fxPart({
		ClassName = "Part",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 2, 2),
		CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.15,
	})
	tween(ring, 0.35, { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, 0.4)
	local dome = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = ground, Color = color, Transparency = 0.5, Material = Enum.Material.ForceField })
	tween(dome, 0.3, { Size = Vector3.new(radius, radius, radius), Transparency = 1 })
	Debris:AddItem(dome, 0.35)
	self:Sparks(ground + Vector3.new(0, 1, 0), color, 30)
end

function EffectsController:Explosion(position: Vector3, color: Color3, scale: number)
	for _ = 1, math.clamp(math.floor(6 * scale), 6, 18) do
		local size = math.random(4, 9) / 10 * scale
		local debris = Instance.new("Part")
		debris.Size = Vector3.new(size, size, size)
		debris.Position = position + Vector3.new(math.random(-10, 10) / 10, math.random(0, 10) / 10, math.random(-10, 10) / 10) * scale
		debris.Color = if math.random() < 0.5 then color else Color3.fromRGB(60, 60, 70)
		debris.Material = if math.random() < 0.5 then Enum.Material.Neon else Enum.Material.Metal
		debris.CanQuery = false
		debris.CanTouch = false
		debris.CollisionGroup = "Default"
		debris.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(25, 50), math.random(-30, 30))
		debris.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
		debris.Parent = fxFolder
		task.delay(0.9, function()
			tween(debris, 0.4, { Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05) })
		end)
		Debris:AddItem(debris, 1.4)
	end
	local flash = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2) * scale, Position = position, Color = color, Transparency = 0.2 })
	tween(flash, 0.3, { Size = Vector3.new(7, 7, 7) * scale, Transparency = 1 })
	Debris:AddItem(flash, 0.35)
	self:Sparks(position, color, 25)
end

-- Little coins that fly from `from` into the local player's character.
function EffectsController:CoinsToPlayer(from: Vector3, count: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for i = 1, count do
		task.delay(i * 0.04, function()
			local coin = fxPart({
				ClassName = "Part",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.25, 1, 1),
				CFrame = CFrame.new(from + Vector3.new(math.random(-20, 20) / 10, math.random(5, 25) / 10, math.random(-20, 20) / 10)),
				Color = Color3.fromRGB(255, 205, 50),
			})
			local start = coin.Position
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local alpha = math.min(1, (os.clock() - t0) / 0.45)
				if not root.Parent or alpha >= 1 then
					conn:Disconnect()
					coin:Destroy()
					return
				end
				local target = root.Position
				local mid = (start + target) / 2 + Vector3.new(0, 6, 0)
				local a = start:Lerp(mid, alpha)
				local b = mid:Lerp(target, alpha)
				coin.CFrame = CFrame.new(a:Lerp(b, alpha)) * CFrame.Angles(0, alpha * 12, math.rad(90))
			end)
		end)
	end
	task.delay(0.45, function()
		C.SoundController:Play("Reward", nil, 0.25, 1.6)
	end)
end

function EffectsController:Telegraph(position: Vector3, radius: number, duration: number)
	local ground = Vector3.new(position.X, 0.25, position.Z)
	local outline = fxPart({
		ClassName = "Part",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 40, 40),
		Transparency = 0.7,
	})
	local fill = fxPart({
		ClassName = "Part",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 0.5, 0.5),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 80, 40),
		Transparency = 0.4,
	})
	tween(fill, duration, { Size = Vector3.new(0.3, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(outline, duration + 0.05)
	Debris:AddItem(fill, duration + 0.05)
end

function EffectsController:LevelPillar(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local pillar = fxPart({
		ClassName = "Part",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(40, 6, 6),
		CFrame = CFrame.new(root.Position + Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 210, 80),
		Transparency = 0.3,
	})
	tween(pillar, 1, { Size = Vector3.new(40, 0.5, 0.5), Transparency = 1 })
	Debris:AddItem(pillar, 1.05)
	self:Sparks(root.Position, Color3.fromRGB(255, 220, 90), 50)
end

function EffectsController:UpgradeBurst()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		self:Sparks(root.Position, Color3.fromRGB(80, 255, 140), 40)
		self:Shockwave(root.Position, 8, Color3.fromRGB(80, 255, 140))
	end
end

function EffectsController:OverdriveAura(character: Model, duration: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 200, 40)
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 240, 120)
	highlight.Parent = character
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 210, 60))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(2, 5)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 40
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = root
	Debris:AddItem(highlight, duration)
	Debris:AddItem(emitter, duration)
	self:Shockwave(root.Position, 10, Color3.fromRGB(255, 210, 60))
end

local handlers = {}

function handlers.Ability(payload)
	local fromMe = payload.Player == player
	local character = payload.Player and payload.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if payload.Ability == "Slam" then
		if not fromMe then
			EffectsController:Shockwave(payload.Origin, 15, Color3.fromRGB(0, 214, 255))
			C.SoundController:Play("Slam", payload.Origin, 0.7)
		end
	elseif not fromMe and root then
		EffectsController:Swing(root, payload.Aim)
	end
	for _, hit in payload.Hits do
		EffectsController:DamageNumber(hit.Pos, hit.Amount, hit.Crit)
		EffectsController:Sparks(hit.Pos, if hit.Crit then Color3.fromRGB(255, 210, 60) else Color3.fromRGB(150, 230, 255), if hit.Crit then 18 else 8)
	end
	if #payload.Hits > 0 then
		C.SoundController:Play("Hit", payload.Hits[1].Pos, if fromMe then 0.8 else 0.4, 0.9 + math.random() * 0.3)
		if fromMe then
			local anyCrit = false
			for _, hit in payload.Hits do
				anyCrit = anyCrit or hit.Crit
			end
			EffectsController:Shake(if anyCrit then 0.35 else 0.12, 0.15)
		end
	end
end

function handlers.EnemyDeath(payload)
	EffectsController:Explosion(payload.Pos, payload.Color, payload.Scale)
	if table.find(payload.Rewarded, player.UserId) then
		EffectsController:CoinsToPlayer(payload.Pos, math.clamp(math.floor(payload.Scale * 4), 4, 14))
		C.UIController:FloatText(("+%s XP"):format(Format.Short(payload.XP)), Color3.fromRGB(120, 220, 255))
		if payload.Scale >= 3 then
			EffectsController:Shake(0.8, 0.6)
		end
	end
end

function handlers.Telegraph(payload)
	EffectsController:Telegraph(payload.Pos, payload.Radius, payload.Duration)
end

function handlers.BossSlam(payload)
	EffectsController:Shockwave(payload.Pos, payload.Radius, Color3.fromRGB(255, 60, 40))
	C.SoundController:Play("Slam", payload.Pos, 1, 0.7)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and (root.Position - payload.Pos).Magnitude < payload.Radius * 2.5 then
		EffectsController:Shake(0.7, 0.4)
	end
end

function handlers.LevelUp(payload)
	local character = payload.Player and payload.Player.Character
	if character then
		EffectsController:LevelPillar(character)
	end
	if payload.Player == player then
		C.UIController:ShowLevelUp(payload.Level)
		C.SoundController:Play("LevelUp", nil, 1, 1)
	end
end

function handlers.Overdrive(payload)
	local character = payload.Player and payload.Player.Character
	if character then
		EffectsController:OverdriveAura(character, payload.Duration)
	end
end

function handlers.Hurt()
	EffectsController:Shake(0.15, 0.12)
end

function handlers.Collect(payload)
	EffectsController:CoinsToPlayer(payload.Pos, 12)
	C.UIController:FloatText(("+%s coins"):format(Format.Short(payload.Amount)), Color3.fromRGB(255, 210, 60))
end

function handlers.TutorialStep()
	C.SoundController:Play("Reward", nil, 0.8, 1.4)
end

function EffectsController:Init(controllers)
	C = controllers
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFX"
	fxFolder.Parent = workspace
end

function EffectsController:Start()
	Net.Event("Effect").OnClientEvent:Connect(function(payload)
		local handler = typeof(payload) == "table" and handlers[payload.Type]
		if handler then
			handler(payload)
		end
	end)

	-- Camera shake runs after the default camera update.
	RunService:BindToRenderStep("TorqueShake", Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		if now < shakeUntil then
			local fade = (shakeUntil - now) / shakeDuration
			local m = shakeIntensity * fade
			local camera = workspace.CurrentCamera
			camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * m * 4), math.rad((math.random() - 0.5) * m * 4), 0)
		end
	end)
end

return EffectsController

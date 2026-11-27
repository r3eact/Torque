-- EnemyService: spawns, drives (AI) and rewards the bots in every zone.
--
-- Bots are lightweight Humanoid rigs: an invisible HumanoidRootPart + welded visual
-- parts, using Humanoid.HipHeight so no legs/joints need simulating. The server owns
-- their physics (SetNetworkOwner(nil)) so players can't teleport or freeze them.
-- AI runs on one loop at 5 Hz for all bots (cheap even with 40+ bots).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ZoneData = require(Shared.ZoneData)
local ItemData = require(Shared.ItemData)

local EnemyService = {}
local S
local rng = Random.new()

type Enemy = {
	Model: Model,
	Id: string,
	Def: any,
	Zone: any,
	Humanoid: Humanoid,
	Root: BasePart,
	Radius: number,
	Home: Vector3,
	Damagers: { [Player]: number },
	LastAttack: number,
	LastSlam: number,
	NextWander: number,
	Dead: boolean,
	Bar: Frame,
}

local enemies: { [Model]: Enemy } = {}
local zoneCounts: { [string]: number } = {}
local bossAlive: { [string]: boolean } = {}
local folder: Folder

function EnemyService:Init(services)
	S = services
end

local function weld(root: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

local function visualPart(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = root.CFrame * offset
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	weld(root, p)
	return p
end

local function buildHealthBar(root: BasePart, def): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthGui"
	gui.Size = UDim2.fromOffset(if def.Boss then 260 else 140, if def.Boss then 46 else 34)
	gui.StudsOffset = Vector3.new(0, 1.6 * def.Scale + 1.6, 0)
	gui.MaxDistance = if def.Boss then 200 else 90
	gui.LightInfluence = 0
	gui.Parent = root
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.5, 0)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = if def.Boss then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.4
	name.Text = if def.Boss then "👑 " .. def.Name else def.Name
	name.Parent = gui
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	back.BorderSizePixel = 0
	back.Position = UDim2.fromScale(0, 0.58)
	back.Size = UDim2.fromScale(1, 0.34)
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = if def.Boss then Color3.fromRGB(255, 60, 80) else Color3.fromRGB(90, 230, 110)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	corner:Clone().Parent = fill
	return fill
end

local function build(id: string, def, position: Vector3): (Model, Humanoid, BasePart)
	local s = def.Scale
	local model = Instance.new("Model")
	model.Name = def.Name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.6, 2.2, 2.2) * s
	root.Transparency = 1
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.CFrame = CFrame.new(position)
	root.Parent = model
	model.PrimaryPart = root

	local metal = Enum.Material.Metal
	visualPart(model, root, "Body", Vector3.new(2.6, 2.2, 2.2) * s, CFrame.new(), def.Color, metal)
	visualPart(model, root, "Eye", Vector3.new(1.6, 0.45, 0.2) * s, CFrame.new(0, 0.35 * s, -1.12 * s), def.Eye, Enum.Material.Neon)
	visualPart(model, root, "Plate", Vector3.new(2.8, 0.3, 2.4) * s, CFrame.new(0, 1.15 * s, 0), def.Color:Lerp(Color3.new(0, 0, 0), 0.35), metal)
	for _, x in { -0.8, 0.8 } do
		visualPart(model, root, "Leg", Vector3.new(0.7, 1.4, 0.7) * s, CFrame.new(x * s, -1.8 * s, 0), def.Color:Lerp(Color3.new(0, 0, 0), 0.4), metal)
		visualPart(model, root, "Arm", Vector3.new(0.5, 1.5, 0.5) * s, CFrame.new(x * 1.75 * s, -0.2 * s, -0.2 * s), def.Color:Lerp(Color3.new(0, 0, 0), 0.25), metal)
	end
	visualPart(model, root, "Antenna", Vector3.new(0.15, 1, 0.15) * s, CFrame.new(0.6 * s, 1.75 * s, 0), Color3.fromRGB(40, 40, 40), metal)
	local tip = visualPart(model, root, "AntennaTip", Vector3.new(0.4, 0.4, 0.4) * s, CFrame.new(0.6 * s, 2.3 * s, 0), def.Eye, Enum.Material.Neon)
	tip.Shape = Enum.PartType.Ball
	if def.Boss then
		for _, x in { -1, 1 } do
			visualPart(model, root, "Spike", Vector3.new(0.6, 1.4, 0.6) * s, CFrame.new(x * 1.1 * s, 1.9 * s, 0) * CFrame.Angles(0, 0, math.rad(-x * 25)), def.Eye, Enum.Material.Neon)
		end
		local light = Instance.new("PointLight")
		light.Color = def.Eye
		light.Range = 24
		light.Brightness = 2
		light.Parent = root
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.HipHeight = 1.4 * s
	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.WalkSpeed = def.Speed
	humanoid.AutoRotate = true
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, state in {
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Flying,
		Enum.HumanoidStateType.GettingUp,
	} do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model
	model:SetAttribute("EnemyId", id)
	return model, humanoid, root
end

local function nearestTarget(enemy: Enemy): (Player?, BasePart?, number)
	local best, bestRoot, bestDist = nil, nil, enemy.Def.Aggro
	local pos = enemy.Root.Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and ZoneData.GetZoneIdAt(root.Position) == enemy.Zone.Id then
			local dist = (root.Position - pos).Magnitude
			if dist < bestDist then
				best, bestRoot, bestDist = player, root, dist
			end
		end
	end
	return best, bestRoot, bestDist
end

local function randomPointIn(zone, margin: number): Vector3
	local half = ZoneData.WIDTH / 2 - 40
	return Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(zone.MinZ + margin, zone.MaxZ - margin))
end

local function onDeath(enemy: Enemy)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	local def = enemy.Def
	local zone = enemy.Zone
	local threshold = (if def.Boss then Config.BossShareThreshold else Config.KillShareThreshold) * def.Health
	local rewarded = {}
	local count = 0
	for player, damage in enemy.Damagers do
		local profile = S.DataService:GetProfile(player)
		if profile and player.Parent and damage >= threshold then
			count += 1
			table.insert(rewarded, player.UserId)
			local d = profile.Data
			d.TotalKills += 1
			S.ProgressionService:AddCoins(player, def.Coins, true)
			S.ProgressionService:AddXP(player, def.XP)
			S.QuestService:Track(player, "Kill", 1)
			local dropId
			if def.Boss then
				d.BossKills += 1
				S.QuestService:Track(player, "BossKill", 1)
				dropId = zone.BossDropPool[rng:NextInteger(1, #zone.BossDropPool)]
			elseif rng:NextNumber() < zone.DropChance then
				dropId = zone.DropPool[rng:NextInteger(1, #zone.DropPool)]
			end
			if dropId then
				local uid = S.InventoryService:AddItem(player, dropId)
				if uid then
					local core = ItemData.Cores[dropId]
					S.NetService:Notify(player, ("Dropped: %s (%s)"):format(core.Name, core.Rarity), "drop")
				end
			end
		end
	end
	S.NetService:EffectAll({
		Type = "EnemyDeath",
		Pos = enemy.Root.Position,
		Color = def.Eye,
		Scale = def.Scale,
		Rewarded = rewarded,
		XP = def.XP,
		Coins = def.Coins,
	})
	if def.Boss then
		S.NetService:NotifyAll(("👑 %s was destroyed! %d player(s) rewarded."):format(def.Name, count), "rare")
	end
	enemies[enemy.Model] = nil
	zoneCounts[zone.Id] -= if def.Boss then 0 else 1
	task.delay(0.05, function()
		enemy.Model:Destroy()
	end)
	if def.Boss then
		bossAlive[zone.Id] = false
		task.delay(def.Respawn, function()
			EnemyService:SpawnBoss(zone)
		end)
	end
end

function EnemyService:Spawn(zone, id: string, position: Vector3)
	local def = ZoneData.Enemies[id]
	local spawnPos = position + Vector3.new(0, 2.5 * def.Scale + 0.5, 0)
	local model, humanoid, root = build(id, def, spawnPos)
	local enemy: Enemy = {
		Model = model,
		Id = id,
		Def = def,
		Zone = zone,
		Humanoid = humanoid,
		Root = root,
		Radius = 1.4 * def.Scale,
		Home = spawnPos,
		Damagers = {},
		LastAttack = 0,
		LastSlam = os.clock(),
		NextWander = os.clock() + rng:NextNumber(1, 4),
		Dead = false,
		Bar = buildHealthBar(root, def),
	}
	enemies[model] = enemy
	if not def.Boss then
		zoneCounts[zone.Id] = (zoneCounts[zone.Id] or 0) + 1
	end
	humanoid.HealthChanged:Connect(function(health)
		enemy.Bar.Size = UDim2.fromScale(math.clamp(health / humanoid.MaxHealth, 0, 1), 1)
	end)
	humanoid.Died:Connect(function()
		onDeath(enemy)
	end)
	model.Parent = folder
	root:SetNetworkOwner(nil)
	return enemy
end

function EnemyService:SpawnBoss(zone)
	if bossAlive[zone.Id] then
		return
	end
	bossAlive[zone.Id] = true
	self:Spawn(zone, zone.Boss, Vector3.new(0, 0, zone.MinZ + 40))
	S.NetService:NotifyAll(("👑 %s has appeared in the %s!"):format(ZoneData.Enemies[zone.Boss].Name, zone.Name), "rare")
end

local function pickSpawnType(zone): string
	local total = 0
	for _, w in zone.Spawns do
		total += w
	end
	local roll = rng:NextNumber() * total
	for id, w in zone.Spawns do
		if roll < w then
			return id
		end
		roll -= w
	end
	return next(zone.Spawns)
end

-- Damage from a player. Returns (didHit, killed).
function EnemyService:DamageEnemy(model: Model, player: Player, amount: number): (boolean, boolean)
	local enemy = enemies[model]
	if not enemy or enemy.Dead then
		return false, false
	end
	local applied = math.min(amount, enemy.Humanoid.Health)
	enemy.Damagers[player] = (enemy.Damagers[player] or 0) + applied
	enemy.Humanoid:TakeDamage(amount)
	-- Small knockback for juice (bosses don't budge)
	if not enemy.Def.Boss then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local dir = enemy.Root.Position - root.Position
			dir = Vector3.new(dir.X, 0, dir.Z)
			if dir.Magnitude > 0.01 then
				enemy.Root.AssemblyLinearVelocity = dir.Unit * 30 + Vector3.new(0, 12, 0)
			end
		end
	end
	return true, enemy.Humanoid.Health <= 0
end

-- Returns enemies whose body is within `radius` of `position` (horizontal distance).
function EnemyService:GetEnemiesNear(position: Vector3, radius: number): { Enemy }
	local result = {}
	for _, enemy in enemies do
		if not enemy.Dead then
			local offset = enemy.Root.Position - position
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat - enemy.Radius <= radius and math.abs(offset.Y) < 12 + enemy.Radius then
				table.insert(result, enemy)
			end
		end
	end
	return result
end

local function bossSlam(enemy: Enemy)
	local def = enemy.Def
	local center = enemy.Root.Position - Vector3.new(0, enemy.Root.Position.Y, 0)
	S.NetService:EffectAll({ Type = "Telegraph", Pos = center, Radius = def.SlamRadius, Duration = 1.2 })
	task.delay(1.2, function()
		if enemy.Dead then
			return
		end
		S.NetService:EffectAll({ Type = "BossSlam", Pos = center, Radius = def.SlamRadius })
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				local offset = root.Position - center
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= def.SlamRadius and offset.Y < 10 then
					humanoid:TakeDamage(def.Damage * 2)
				end
			end
		end
	end)
end

local function think(enemy: Enemy, now: number)
	local def = enemy.Def
	local humanoid = enemy.Humanoid
	local rootPos = enemy.Root.Position
	if rootPos.Y < -30 then
		humanoid.Health = 0
		return
	end
	local target, targetRoot, dist = nearestTarget(enemy)
	if target and targetRoot then
		local reach = def.AttackRange + enemy.Radius
		if dist > reach - 1 then
			humanoid:MoveTo(targetRoot.Position)
		else
			humanoid:MoveTo(rootPos)
			local look = Vector3.new(targetRoot.Position.X, rootPos.Y, targetRoot.Position.Z)
			if (look - rootPos).Magnitude > 0.1 then
				enemy.Root.CFrame = CFrame.lookAt(rootPos, look)
			end
		end
		if dist <= reach and now - enemy.LastAttack >= def.AttackCooldown then
			enemy.LastAttack = now
			local targetHumanoid = (targetRoot.Parent :: Model):FindFirstChildOfClass("Humanoid")
			if targetHumanoid then
				targetHumanoid:TakeDamage(def.Damage)
				S.NetService:Effect(target, { Type = "Hurt", Amount = def.Damage })
			end
		end
		if def.Boss and now - enemy.LastSlam >= def.SlamEvery then
			enemy.LastSlam = now
			bossSlam(enemy)
		end
	else
		-- No target: wander near home, and heal slowly so abandoned fights reset.
		if humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.02)
			if humanoid.Health >= humanoid.MaxHealth then
				table.clear(enemy.Damagers)
			end
		end
		if now >= enemy.NextWander then
			enemy.NextWander = now + rng:NextNumber(3, 7)
			local radius = if def.Boss then 15 else 25
			humanoid:MoveTo(enemy.Home + Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius)))
		end
	end
end

function EnemyService:Start()
	folder = S.WorldBuilder.World:WaitForChild("Enemies") :: Folder
	for _, zone in ZoneData.Zones do
		zoneCounts[zone.Id] = 0
		for _ = 1, zone.MaxEnemies do
			self:Spawn(zone, pickSpawnType(zone), randomPointIn(zone, 25))
		end
		self:SpawnBoss(zone)
	end

	-- Respawner: refill each zone one bot at a time.
	task.spawn(function()
		while true do
			task.wait(1.5)
			for _, zone in ZoneData.Zones do
				if zoneCounts[zone.Id] < zone.MaxEnemies then
					self:Spawn(zone, pickSpawnType(zone), randomPointIn(zone, 25))
				end
			end
		end
	end)

	-- AI loop
	while true do
		task.wait(0.2)
		local now = os.clock()
		for _, enemy in enemies do
			if not enemy.Dead then
				think(enemy, now)
			end
		end
	end
end

return EnemyService

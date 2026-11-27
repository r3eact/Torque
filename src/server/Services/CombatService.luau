-- CombatService: the only place player damage is calculated.
--
-- The client sends ONLY (abilityId, aimDirection). The server checks unlock level,
-- cooldown, that the character is alive, then finds targets itself from server-side
-- positions. A modified client can't pick targets, change damage, or skip cooldowns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local CombatService = {}
local S
local rng = Random.new()

function CombatService:Init(services)
	S = services
end

local function flatUnit(v: Vector3): Vector3?
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 0.05 then
		return nil
	end
	return flat.Unit
end

local function inArena(position: Vector3): boolean
	local arena = S.WorldBuilder.Arena
	local offset = position - arena.Center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= arena.Radius and offset.Y < 15
end

-- Rolls one hit's damage for this player.
local function rollDamage(profile, abilityDef): (number, boolean)
	local d = profile.Data
	local core = S.InventoryService:GetEquipped(profile)
	local damage = Config.BaseDamage(d.Level, d.Upgrades.Power) * abilityDef.DamageMult
	if core then
		damage *= core.DamageMult
	end
	if S.ProgressionService:IsOverdrive(profile) then
		damage *= Config.Abilities.Overdrive.DamageBuff
	end
	damage *= rng:NextNumber(0.9, 1.1)
	local critChance = 0.02 + (if core then core.CritChance else 0)
	local crit = rng:NextNumber() < critChance
	if crit then
		damage *= Config.Player.CritMultiplier
	end
	return math.max(1, math.floor(damage)), crit
end

local function isTargetInShape(abilityId: string, def, origin: Vector3, aim: Vector3, targetPos: Vector3, targetRadius: number): boolean
	local offset = targetPos - origin
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if math.abs(offset.Y) > 10 + targetRadius then
		return false
	end
	if abilityId == "Slam" then
		return flat.Magnitude - targetRadius <= def.Radius
	end
	-- Strike: cone in front of the player
	if flat.Magnitude - targetRadius > def.Range then
		return false
	end
	if flat.Magnitude < targetRadius + 1.5 then
		return true -- point blank always hits
	end
	return flat.Unit:Dot(aim) >= def.ArcDot
end

local function handleOverdrive(player: Player, profile)
	local def = Config.Abilities.Overdrive
	profile.Runtime.OverdriveUntil = os.clock() + def.Duration
	profile.Runtime.OverdriveServerTime = os.time() + def.Duration
	S.ProgressionService:ApplyCharacterStats(player)
	S.NetService:EffectAll({ Type = "Overdrive", Player = player, Duration = def.Duration })
	S.DataService:MarkDirty(player)
	task.delay(def.Duration + 0.05, function()
		if S.DataService:GetProfile(player) == profile then
			S.ProgressionService:ApplyCharacterStats(player)
		end
	end)
end

local function onAbility(player: Player, abilityId: any, aim: any)
	if typeof(abilityId) ~= "string" then
		return
	end
	local def = Config.Abilities[abilityId]
	if not def or not S.RateLimiter:Check(player, "Ability", 10, 14) then
		return
	end
	local profile = S.DataService:GetProfile(player)
	if not profile or profile.Data.Level < def.UnlockLevel then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	-- Cooldown (15% tolerance for network jitter)
	local now = os.clock()
	local cooldowns = profile.Runtime.Cooldowns
	if (cooldowns[abilityId] or 0) > now then
		return
	end
	cooldowns[abilityId] = now + def.Cooldown * 0.85

	if abilityId == "Overdrive" then
		handleOverdrive(player, profile)
		return
	end

	-- Aim: optional unit vector from the client; validated, falls back to facing.
	local aimDir = flatUnit(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	if typeof(aim) == "Vector3" and aim.X == aim.X and aim.Z == aim.Z and aim.Magnitude < 1.5 then
		aimDir = flatUnit(aim) or aimDir
	end

	local origin = root.Position
	local hits = {}
	local shapeRadius = if abilityId == "Slam" then def.Radius else def.Range
	for _, enemy in S.EnemyService:GetEnemiesNear(origin, shapeRadius + 2) do
		if isTargetInShape(abilityId, def, origin, aimDir, enemy.Root.Position, enemy.Radius) then
			local damage, crit = rollDamage(profile, def)
			local didHit = S.EnemyService:DamageEnemy(enemy.Model, player, damage)
			if didHit then
				table.insert(hits, { Pos = enemy.Root.Position, Amount = damage, Crit = crit })
			end
		end
	end

	-- PvP: only when both players stand inside the arena ring.
	if inArena(origin) then
		for _, other in Players:GetPlayers() do
			local oc = other.Character
			local oRoot = oc and oc:FindFirstChild("HumanoidRootPart") :: BasePart?
			local oHum = oc and oc:FindFirstChildOfClass("Humanoid")
			if other ~= player and oRoot and oHum and oHum.Health > 0 and inArena(oRoot.Position)
				and not oc:FindFirstChildOfClass("ForceField")
				and isTargetInShape(abilityId, def, origin, aimDir, oRoot.Position, 1.5) then
				local damage, crit = rollDamage(profile, def)
				damage = math.max(1, math.floor(damage * Config.PvP.DamageScale))
				local knockedOut = oHum.Health - damage <= 0
				oHum:TakeDamage(damage)
				table.insert(hits, { Pos = oRoot.Position, Amount = damage, Crit = crit })
				if knockedOut then
					profile.Data.ArenaKOs += 1
					S.DataService:MarkDirty(player)
					S.NetService:NotifyAll(("⚔️ %s knocked out %s in the Arena!"):format(player.DisplayName, other.DisplayName), "info")
				end
			end
		end
	end

	if abilityId == "Slam" then
		S.QuestService:Track(player, "UseSlam", 1)
	end

	S.NetService:EffectAll({
		Type = "Ability",
		Ability = abilityId,
		Player = player,
		Origin = origin,
		Aim = aimDir,
		Hits = hits,
	})
end

function CombatService:Start()
	Net.Event("Ability").OnServerEvent:Connect(onAbility)
end

return CombatService

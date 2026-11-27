-- ZoneService: zone unlocking + server-side enforcement + basic movement anti-cheat.
--
-- Gates are solid for everyone on the server. The client makes gates it has unlocked
-- non-collidable *locally* (characters are client-simulated, so that's enough to walk
-- through). Because an exploiter could do the same for locked gates, the server also
-- checks every player's position and sends trespassers back to the hub.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ZoneData = require(Shared.ZoneData)
local Format = require(Shared.Format)

local ZoneService = {}
local S

local lastPositions: { [Player]: { pos: Vector3, time: number, strikes: number } } = {}
local teleportGrace: { [Player]: number } = {}

function ZoneService:Init(services)
	S = services
end

function ZoneService:GetZoneIdAt(position: Vector3): string?
	return ZoneData.GetZoneIdAt(position)
end

-- Server-initiated teleports must go through here so the speed check ignores them.
function ZoneService:Teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if not character then
		return
	end
	teleportGrace[player] = os.clock() + 2
	lastPositions[player] = nil
	character:PivotTo(cframe)
end

function ZoneService:TryUnlock(player: Player, zoneId: string)
	local profile = S.DataService:GetProfile(player)
	local zone = ZoneData.ById[zoneId]
	if not profile or not zone then
		return
	end
	local d = profile.Data
	if d.UnlockedZones[zoneId] then
		return
	end
	-- Zones must be unlocked in order.
	local previous = ZoneData.Zones[zone.Index - 1]
	if previous and not d.UnlockedZones[previous.Id] then
		S.NetService:Notify(player, ("Unlock the %s first!"):format(previous.Name), "warn")
		return
	end
	if d.Level < zone.RequiredLevel then
		S.NetService:Notify(player, ("You need Level %d to enter the %s."):format(zone.RequiredLevel, zone.Name), "warn")
		return
	end
	if not S.ProgressionService:SpendCoins(player, zone.UnlockCost) then
		S.NetService:Notify(player, ("You need %s coins to unlock the %s."):format(Format.Commas(zone.UnlockCost), zone.Name), "warn")
		return
	end
	d.UnlockedZones[zoneId] = true
	S.NetService:Notify(player, ("🔓 %s unlocked!"):format(zone.Name), "levelup")
	S.NetService:NotifyAll(("%s unlocked the %s!"):format(player.DisplayName, zone.Name), "info")
	S.DataService:MarkDirty(player)
end

local function checkPlayers()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local profile = S.DataService:GetProfile(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not profile or not root or not humanoid or humanoid.Health <= 0 then
			lastPositions[player] = nil
			continue
		end
		local pos = root.Position

		-- 1) Zone lock enforcement
		local zoneId = ZoneData.GetZoneIdAt(pos)
		if zoneId and zoneId ~= "Hub" and not profile.Data.UnlockedZones[zoneId] then
			local zone = ZoneData.ById[zoneId]
			ZoneService:Teleport(player, CFrame.new(0, 4, zone.MaxZ + 12))
			S.NetService:Notify(player, ("The %s is locked!"):format(zone.Name), "warn")
			continue
		end

		-- 2) Horizontal speed check (catches teleport / speed exploits)
		if (teleportGrace[player] or 0) > now then
			lastPositions[player] = { pos = pos, time = now, strikes = 0 }
			continue
		end
		local last = lastPositions[player]
		if last then
			local dt = now - last.time
			local flat = Vector3.new(pos.X - last.pos.X, 0, pos.Z - last.pos.Z).Magnitude
			local allowed = (humanoid.WalkSpeed * 1.5 + 12) * dt + 6
			if flat > allowed then
				last.strikes += 1
				character:PivotTo(CFrame.new(last.pos) * root.CFrame.Rotation)
				if last.strikes >= 20 then
					player:Kick("Unusual movement detected.")
				end
				continue
			end
			last.pos, last.time = pos, now
			last.strikes = math.max(0, last.strikes - 0.1)
		else
			lastPositions[player] = { pos = pos, time = now, strikes = 0 }
		end
	end
end

function ZoneService:Start()
	for zoneId, gate in S.WorldBuilder.Gates do
		local prompt = gate:FindFirstChild("UnlockPrompt", true) :: ProximityPrompt
		prompt.Triggered:Connect(function(player)
			if S.RateLimiter:Check(player, "Unlock", 1, 3) then
				self:TryUnlock(player, zoneId)
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPositions[player] = nil
		teleportGrace[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			teleportGrace[player] = os.clock() + 3
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			teleportGrace[player] = os.clock() + 3
		end)
	end
	while true do
		task.wait(0.5)
		checkPlayers()
	end
end

return ZoneService

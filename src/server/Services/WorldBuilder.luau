-- WorldBuilder: procedurally builds the whole map at server start, so the game works
-- in an empty Baseplate place with no manual building. Everything is anchored and
-- built once; clients get it through normal replication.
--
-- Layout (top-down, players spawn in the Hub and walk toward -Z):
--
--   Z=+170 ┌──────────────── HUB ────────────────┐
--          │ [Garage1..6]                         │
--          │ Leaderboard   Spawn      PvP Arena   │
--          │      Shop            Upgrades        │
--   Z=-80  ├────────── SCRAPYARD (free) ─────────┤
--   Z=-300 ├══ gate ══ NEON FOUNDRY (Lv10) ══════┤
--   Z=-520 ├══ gate ══ STORM REACTOR (Lv25) ═════┤
--   Z=-740 └──────────────────────────────────────┘
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ZoneData = require(Shared.ZoneData)
local Format = require(Shared.Format)

local WorldBuilder = {}
WorldBuilder.Gates = {} :: { [string]: BasePart }
WorldBuilder.Plots = {} :: { Model }
WorldBuilder.Arena = { Center = Vector3.new(75, 0, 75), Radius = 22 }
WorldBuilder.SpawnCFrame = CFrame.new(0, 3, 55)

local PLOT_COUNT = 6
local THEME_DARK = Color3.fromRGB(34, 36, 48)
local THEME_TRIM = Color3.fromRGB(0, 214, 255)

local world: Folder

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function surfaceText(target: BasePart, face: Enum.NormalId, lines: { { text: string, size: number, color: Color3 } }, name: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name or "SurfaceGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = target
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. i
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, line.size * 1.25)
		label.Font = Enum.Font.FredokaOne
		label.TextSize = line.size
		label.TextColor3 = line.color
		label.Text = line.text
		label.TextStrokeTransparency = 0.6
		label.Parent = gui
	end
	return gui
end

local function billboard(adornee: Instance, text: string, color: Color3, offsetY: number, size: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 60)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = size or 32
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	return gui
end

local function marker(name: string, position: Vector3)
	part({
		Name = name,
		Size = Vector3.new(1, 1, 1),
		Position = position,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = world:FindFirstChild("Markers"),
	})
end

local function setupLighting()
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 135)
	Lighting.Ambient = Color3.fromRGB(40, 40, 55)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.6
	local function ensure(className: string, name: string)
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "TorqueAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(210, 170, 160)
	atmosphere.Decay = Color3.fromRGB(90, 70, 120)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.4
	local bloom = ensure("BloomEffect", "TorqueBloom") :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 26
	bloom.Threshold = 1.4
	local cc = ensure("ColorCorrectionEffect", "TorqueColor") :: ColorCorrectionEffect
	cc.Saturation = 0.15
	cc.Contrast = 0.08
	local rays = ensure("SunRaysEffect", "TorqueSunRays") :: SunRaysEffect
	rays.Intensity = 0.06
end

local function buildBoundaries()
	local lastZone = ZoneData.Zones[#ZoneData.Zones]
	local minZ, maxZ = lastZone.MinZ, ZoneData.HUB_MAX_Z
	local length = maxZ - minZ
	local midZ = (maxZ + minZ) / 2
	local half = ZoneData.WIDTH / 2
	for _, side in { -1, 1 } do
		part({
			Name = "SideWall",
			Size = Vector3.new(2, 60, length),
			Position = Vector3.new(side * (half + 1), 30, midZ),
			Material = Enum.Material.ForceField,
			Color = THEME_TRIM,
			Transparency = 0.2,
			CastShadow = false,
			Parent = world,
		})
		part({
			Name = "WallTrim",
			Size = Vector3.new(3, 1, length),
			Position = Vector3.new(side * (half + 1), 0.5, midZ),
			Material = Enum.Material.Neon,
			Color = THEME_TRIM,
			Parent = world,
		})
	end
	for _, z in { maxZ + 1, minZ - 1 } do
		part({
			Name = "EndWall",
			Size = Vector3.new(ZoneData.WIDTH + 4, 60, 2),
			Position = Vector3.new(0, 30, z),
			Material = Enum.Material.ForceField,
			Color = THEME_TRIM,
			Transparency = 0.2,
			CastShadow = false,
			Parent = world,
		})
	end
end

local function buildStation(name: string, position: Vector3, color: Color3, title: string, actionText: string, opensUI: string)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = world
	part({ Name = "Base", Size = Vector3.new(16, 1, 12), Position = position + Vector3.new(0, 0.5, 0), Color = THEME_DARK, Material = Enum.Material.DiamondPlate, Parent = model })
	local counter = part({ Name = "Counter", Size = Vector3.new(12, 4, 3), Position = position + Vector3.new(0, 3, 0), Color = Color3.fromRGB(50, 54, 72), Material = Enum.Material.Metal, Parent = model })
	part({ Name = "Trim", Size = Vector3.new(12.2, 0.4, 3.2), Position = position + Vector3.new(0, 5.1, 0), Color = color, Material = Enum.Material.Neon, Parent = model })
	for _, x in { -5.5, 5.5 } do
		part({ Name = "Post", Size = Vector3.new(1, 10, 1), Position = position + Vector3.new(x, 6, 3), Color = THEME_DARK, Material = Enum.Material.Metal, Parent = model })
	end
	local sign = part({ Name = "Sign", Size = Vector3.new(14, 4, 0.6), Position = position + Vector3.new(0, 12, 3), Color = Color3.fromRGB(20, 22, 32), Material = Enum.Material.SmoothPlastic, Parent = model })
	surfaceText(sign, Enum.NormalId.Front, { { text = title, size = 52, color = color } })
	surfaceText(sign, Enum.NormalId.Back, { { text = title, size = 52, color = color } })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 2
	light.Parent = sign
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = title
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensUI", opensUI)
	prompt.Parent = counter
	marker(name, position + Vector3.new(0, 3, -3))
	return model
end

local function buildLeaderboard()
	local board = part({
		Name = "KillsBoard",
		Size = Vector3.new(1, 26, 36),
		Position = Vector3.new(-104, 15, 70),
		Color = Color3.fromRGB(18, 20, 30),
		Material = Enum.Material.SmoothPlastic,
		Parent = world,
	})
	part({ Name = "BoardTrim", Size = Vector3.new(1.4, 27, 37), Position = Vector3.new(-104.4, 15, 70), Color = THEME_TRIM, Material = Enum.Material.Neon, Parent = world })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.14, 0)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.Text = "🏆 TOP BOT DESTROYERS"
	title.Parent = gui
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.BackgroundTransparency = if i % 2 == 0 then 1 else 0.85
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.BorderSizePixel = 0
		row.Position = UDim2.new(0.04, 0, 0.15 + (i - 1) * 0.083, 0)
		row.Size = UDim2.new(0.92, 0, 0.078, 0)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i <= 3 then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(230, 235, 255)
		row.Text = ("  #%d  ---"):format(i)
		row.Parent = gui
	end
end

local function buildArena()
	local arena = WorldBuilder.Arena
	local c = arena.Center
	part({
		ClassName = "Part",
		Name = "ArenaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, arena.Radius * 2 + 2, arena.Radius * 2 + 2),
		CFrame = CFrame.new(c + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 60, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = world,
	})
	local floor = part({
		ClassName = "Part",
		Name = "ArenaFloor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, arena.Radius * 2, arena.Radius * 2),
		CFrame = CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(40, 20, 30),
		Material = Enum.Material.DiamondPlate,
		Parent = world,
	})
	billboard(floor, "⚔️ PVP ARENA ⚔️", Color3.fromRGB(255, 90, 110), 9, 36)
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local pos = c + Vector3.new(math.cos(angle) * (arena.Radius + 1.5), 3, math.sin(angle) * (arena.Radius + 1.5))
		part({ Name = "ArenaPillar", Size = Vector3.new(1.5, 6, 1.5), Position = pos, Color = THEME_DARK, Material = Enum.Material.Metal, Parent = world })
		part({ Name = "ArenaPillarTop", Size = Vector3.new(1.7, 0.6, 1.7), Position = pos + Vector3.new(0, 3.2, 0), Color = Color3.fromRGB(255, 60, 90), Material = Enum.Material.Neon, Parent = world })
	end
end

local function buildPlots()
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	local spacing = 36
	for i = 1, PLOT_COUNT do
		local x = (i - (PLOT_COUNT + 1) / 2) * spacing
		local center = Vector3.new(x, 0, 135)
		local plot = Instance.new("Model")
		plot.Name = "Plot" .. i
		plot:SetAttribute("Index", i)
		plot.Parent = plotsFolder

		local base = part({ Name = "Base", Size = Vector3.new(32, 1, 32), Position = center + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(44, 48, 64), Material = Enum.Material.DiamondPlate, Parent = plot })
		plot.PrimaryPart = base
		for _, dx in { -16, 16 } do
			part({ Name = "Edge", Size = Vector3.new(0.6, 1.2, 32), Position = center + Vector3.new(dx, 0.6, 0), Color = THEME_TRIM, Material = Enum.Material.Neon, Parent = plot })
		end

		local sign = part({ Name = "Sign", Size = Vector3.new(20, 5, 0.6), Position = center + Vector3.new(0, 8, 16), Color = Color3.fromRGB(20, 22, 32), Parent = plot })
		surfaceText(sign, Enum.NormalId.Front, {
			{ text = "EMPTY GARAGE", size = 46, color = Color3.fromRGB(230, 235, 255) },
			{ text = "", size = 26, color = Color3.fromRGB(120, 255, 160) },
		}, "OwnerGui")
		for _, dx in { -9.5, 9.5 } do
			part({ Name = "SignPost", Size = Vector3.new(0.8, 8, 0.8), Position = center + Vector3.new(dx, 4, 16), Color = THEME_DARK, Material = Enum.Material.Metal, Parent = plot })
		end

		local pedestals = Instance.new("Folder")
		pedestals.Name = "Pedestals"
		pedestals.Parent = plot
		local slot = 0
		for _, dz in { -2, 8 } do
			for _, dx in { -10.5, -3.5, 3.5, 10.5 } do
				slot += 1
				part({
					Name = "Pedestal" .. slot,
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(2.4, 4, 4),
					CFrame = CFrame.new(center + Vector3.new(dx, 2.2, dz)) * CFrame.Angles(0, 0, math.rad(90)),
					Color = Color3.fromRGB(60, 64, 84),
					Material = Enum.Material.Metal,
					Parent = pedestals,
				})
			end
		end

		local collector = part({
			Name = "Collector",
			Size = Vector3.new(8, 0.6, 5),
			Position = center + Vector3.new(0, 1.2, -12),
			Color = Color3.fromRGB(60, 255, 130),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = plot,
		})
		local cg = billboard(collector, "💰 0", Color3.fromRGB(120, 255, 160), 3.5, 30)
		cg.Name = "AmountGui"
		local hint = billboard(collector, "STEP HERE TO COLLECT", Color3.fromRGB(220, 255, 230), 1.8, 16)
		hint.Name = "HintGui"
		part({ Name = "CollectorBase", Size = Vector3.new(9, 0.9, 6), Position = center + Vector3.new(0, 0.6, -12), Color = THEME_DARK, Material = Enum.Material.Metal, Parent = plot })

		plot:SetAttribute("Home", CFrame.lookAt(center + Vector3.new(0, 3, -6), center + Vector3.new(0, 3, -30)))
		table.insert(WorldBuilder.Plots, plot)
	end
end

local function buildHub()
	local hubLength = ZoneData.HUB_MAX_Z - ZoneData.HUB_MIN_Z
	part({
		Name = "HubFloor",
		Size = Vector3.new(ZoneData.WIDTH, 4, hubLength),
		Position = Vector3.new(0, -2, (ZoneData.HUB_MAX_Z + ZoneData.HUB_MIN_Z) / 2),
		Color = Color3.fromRGB(58, 62, 80),
		Material = Enum.Material.Concrete,
		Parent = world,
	})
	-- Glowing path from spawn to the Scrapyard
	part({ Name = "Path", Size = Vector3.new(14, 0.2, 120), Position = Vector3.new(0, 0.1, -20), Color = Color3.fromRGB(70, 76, 100), Material = Enum.Material.SmoothPlastic, Parent = world })
	for _, x in { -7.2, 7.2 } do
		part({ Name = "PathTrim", Size = Vector3.new(0.4, 0.3, 120), Position = Vector3.new(x, 0.15, -20), Color = THEME_TRIM, Material = Enum.Material.Neon, Parent = world })
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TorqueSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 55)
	spawn.Color = THEME_TRIM
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world

	-- Central decorative "torque engine": a giant gear the client spins (tag "SpinX").
	local gear = Instance.new("Model")
	gear.Name = "HubGear"
	gear.Parent = world
	local hubCore = part({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 16, 16),
		CFrame = CFrame.new(0, 14, 85) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(255, 140, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = gear,
	})
	gear.PrimaryPart = hubCore
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		part({
			Name = "GearTooth",
			Size = Vector3.new(2.2, 3, 3),
			CFrame = hubCore.CFrame * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 8.8, 0),
			Color = Color3.fromRGB(255, 160, 60),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = gear,
		})
	end
	CollectionService:AddTag(gear, "SpinX")
	local titleAnchor = part({ Name = "TitleAnchor", Size = Vector3.new(1, 1, 1), Position = Vector3.new(0, 25, 85), Transparency = 1, CanCollide = false, CanQuery = false, Parent = world })
	billboard(titleAnchor, "TORQUE", Color3.fromRGB(255, 200, 120), 0, 64)

	buildStation("Shop", Vector3.new(-40, 0, 10), Color3.fromRGB(255, 170, 40), "CRATE SHOP", "Open Shop", "Shop")
	buildStation("Upgrades", Vector3.new(40, 0, 10), Color3.fromRGB(80, 255, 140), "UPGRADES", "Upgrade", "Upgrades")
	buildLeaderboard()
	buildArena()
	buildPlots()
end

local function buildZone(zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.Id
	folder.Parent = world
	part({
		Name = "Floor",
		Size = Vector3.new(ZoneData.WIDTH, 4, ZoneData.ZONE_LENGTH),
		Position = Vector3.new(0, -2, zone.CenterZ),
		Color = zone.FloorColor,
		Material = zone.Material,
		Parent = folder,
	})
	-- Neon seam at the zone entrance
	part({ Name = "Seam", Size = Vector3.new(ZoneData.WIDTH, 0.3, 1), Position = Vector3.new(0, 0.15, zone.MaxZ), Color = zone.AccentColor, Material = Enum.Material.Neon, Parent = folder })

	-- Entrance arch with the zone name
	for _, x in { -20, 20 } do
		part({ Name = "ArchPillar", Size = Vector3.new(3, 20, 3), Position = Vector3.new(x, 10, zone.MaxZ - 3), Color = THEME_DARK, Material = Enum.Material.Metal, Parent = folder })
	end
	local beam = part({ Name = "ArchBeam", Size = Vector3.new(44, 4, 3), Position = Vector3.new(0, 21, zone.MaxZ - 3), Color = Color3.fromRGB(20, 22, 32), Parent = folder })
	surfaceText(beam, Enum.NormalId.Back, { { text = string.upper(zone.Name), size = 60, color = zone.AccentColor } })
	surfaceText(beam, Enum.NormalId.Front, { { text = string.upper(zone.Name), size = 60, color = zone.AccentColor } })

	-- Props are kept near the side walls so the fighting lane stays open.
	local rng = Random.new(zone.Index * 1000)
	for _ = 1, 22 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = side * rng:NextNumber(72, 102)
		local z = rng:NextNumber(zone.MinZ + 12, zone.MaxZ - 12)
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			-- Junk pile
			for j = 1, 3 do
				local size = Vector3.new(rng:NextNumber(3, 8), rng:NextNumber(2, 6), rng:NextNumber(3, 8))
				part({
					Name = "Junk",
					Size = size,
					CFrame = CFrame.new(x + rng:NextNumber(-3, 3), size.Y / 2 + (j - 1) * 1.5, z + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)),
					Color = zone.FloorColor:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0.05, 0.25)),
					Material = Enum.Material.CorrodedMetal,
					Parent = folder,
				})
			end
		elseif kind == 2 then
			-- Light pillar
			local h = rng:NextNumber(10, 22)
			part({ Name = "Pillar", Size = Vector3.new(3, h, 3), Position = Vector3.new(x, h / 2, z), Color = THEME_DARK, Material = Enum.Material.Metal, Parent = folder })
			local top = part({ Name = "PillarLight", Size = Vector3.new(3.4, 1, 3.4), Position = Vector3.new(x, h + 0.5, z), Color = zone.AccentColor, Material = Enum.Material.Neon, Parent = folder })
			local light = Instance.new("PointLight")
			light.Color = zone.AccentColor
			light.Range = 20
			light.Brightness = 1.5
			light.Shadows = false
			light.Parent = top
		else
			-- Floating crystal (bobs + spins on the client)
			local crystal = part({
				Name = "Crystal",
				Size = Vector3.new(2.5, 5, 2.5),
				CFrame = CFrame.new(x, rng:NextNumber(5, 9), z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(45)),
				Color = zone.AccentColor,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			CollectionService:AddTag(crystal, "Spin")
		end
	end

	marker(zone.Id, Vector3.new(0, 3, zone.MaxZ - 20))

	-- Gate for locked zones
	if zone.UnlockCost > 0 or zone.RequiredLevel > 1 then
		local gate = part({
			Name = zone.Id .. "Gate",
			Size = Vector3.new(ZoneData.WIDTH, 30, 2),
			Position = Vector3.new(0, 15, zone.MaxZ + 1),
			Color = zone.AccentColor,
			Material = Enum.Material.ForceField,
			Transparency = 0.1,
			CastShadow = false,
			Parent = world,
		})
		gate:SetAttribute("ZoneId", zone.Id)
		CollectionService:AddTag(gate, "ZoneGate")
		local lines = {
			{ text = "🔒 " .. string.upper(zone.Name), size = 70, color = zone.AccentColor },
			{ text = ("Requires Level %d  •  %s Coins"):format(zone.RequiredLevel, Format.Commas(zone.UnlockCost)), size = 40, color = Color3.fromRGB(255, 255, 255) },
			{ text = "Walk to the center of the gate to unlock", size = 28, color = Color3.fromRGB(200, 205, 225) },
		}
		surfaceText(gate, Enum.NormalId.Back, lines)
		surfaceText(gate, Enum.NormalId.Front, lines)
		local attachment = Instance.new("Attachment")
		attachment.Name = "PromptAttachment"
		attachment.Position = Vector3.new(0, -11, 0)
		attachment.Parent = gate
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UnlockPrompt"
		prompt.ActionText = ("Unlock (%s)"):format(Format.Short(zone.UnlockCost))
		prompt.ObjectText = zone.Name .. " • Lv " .. zone.RequiredLevel
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = attachment
		WorldBuilder.Gates[zone.Id] = gate
	end
end

function WorldBuilder:Init()
	-- Remove the template baseplate/spawn so our map is the only ground.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	world = Instance.new("Folder")
	world.Name = "World"
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = world
	local enemies = Instance.new("Folder")
	enemies.Name = "Enemies"
	enemies.Parent = world
	local fx = Instance.new("Folder")
	fx.Name = "ServerFX"
	fx.Parent = world

	setupLighting()
	buildBoundaries()
	buildHub()
	for _, zone in ZoneData.Zones do
		buildZone(zone)
	end
	workspace.FallenPartsDestroyHeight = -60
	world.Parent = workspace
	WorldBuilder.World = world
end

return WorldBuilder

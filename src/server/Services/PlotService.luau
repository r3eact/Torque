-- PlotService: each player gets a Garage plot in the hub. Cores on its pedestals
-- generate coins every second into the Collector pad; stepping on the pad banks them.
-- While offline, a Garage keeps earning at a reduced rate (capped) - a reason to return.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemData = require(Shared.ItemData)
local Format = require(Shared.Format)

local PlotService = {}
local S

local owners: { [Model]: Player } = {}
local plotOf: { [Player]: Model } = {}
local collectDebounce: { [Player]: number } = {}

function PlotService:Init(services)
	S = services
end

function PlotService:GetIncomePerSecond(profile): number
	local d = profile.Data
	local total = 0
	for _, uid in d.Displayed do
		local item = d.Inventory[uid]
		local core = item and ItemData.Cores[item.Id]
		if core then
			total += core.Income
		end
	end
	return total
end

function PlotService:GetPlot(player: Player): Model?
	return plotOf[player]
end

local function setSign(plot: Model, title: string, subtitle: string)
	local gui = (plot :: any).Sign.OwnerGui
	gui.Line1.Text = title
	gui.Line2.Text = subtitle
end

-- Rebuilds the floating core models above the pedestals.
function PlotService:RefreshDisplay(player: Player)
	local plot = plotOf[player]
	local profile = S.DataService:GetProfile(player)
	if not plot or not profile then
		return
	end
	local d = profile.Data
	local old = plot:FindFirstChild("DisplayedCores")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "DisplayedCores"
	local slots = Config.DisplaySlots(d.Level)
	for i = 1, Config.Player.MaxDisplaySlots do
		local pedestal = (plot :: any).Pedestals:FindFirstChild("Pedestal" .. i) :: BasePart
		pedestal.Color = if i <= slots then Color3.fromRGB(60, 64, 84) else Color3.fromRGB(30, 30, 36)
		pedestal.Material = if i <= slots then Enum.Material.Metal else Enum.Material.Slate
		local uid = d.Displayed[i]
		local item = uid and d.Inventory[uid]
		local core = item and ItemData.Cores[item.Id]
		if core then
			local gem = Instance.new("Part")
			gem.Name = "Core" .. i
			gem.Anchored = true
			gem.CanCollide = false
			gem.CanQuery = false
			gem.CanTouch = false
			gem.Size = Vector3.new(2, 2, 2)
			gem.Material = Enum.Material.Neon
			gem.Color = core.Color
			gem.CFrame = CFrame.new(pedestal.Position + Vector3.new(0, 3.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45))
			gem.Parent = folder
			CollectionService:AddTag(gem, "Spin")
			local light = Instance.new("PointLight")
			light.Color = core.Color
			light.Range = 10
			light.Brightness = 1.5
			light.Parent = gem
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(160, 40)
			gui.StudsOffset = Vector3.new(0, 2.4, 0)
			gui.MaxDistance = 60
			gui.LightInfluence = 0
			gui.Parent = gem
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.FredokaOne
			label.TextSize = 18
			label.TextColor3 = Config.Rarities[core.Rarity].Color
			label.TextStrokeTransparency = 0.3
			label.Text = ("%s\n+%s/s"):format(core.Name, Format.Short(core.Income))
			label.Parent = gui
		end
	end
	folder.Parent = plot
	setSign(plot, ("%s's GARAGE"):format(string.upper(player.DisplayName)), ("💰 %s / sec"):format(Format.Short(self:GetIncomePerSecond(profile))))
end

local function updateCollector(plot: Model, amount: number)
	local gui = (plot :: any).Collector.AmountGui
	local text = "💰 " .. Format.Short(amount)
	if gui.Label.Text ~= text then
		gui.Label.Text = text
	end
end

local function assignPlot(player: Player, profile)
	for _, plot in S.WorldBuilder.Plots do
		if not owners[plot] then
			owners[plot] = player
			plotOf[player] = plot
			player:SetAttribute("PlotIndex", plot:GetAttribute("Index"))
			-- Offline earnings
			local lastOnline = profile.LastOnline or 0
			if lastOnline > 0 then
				local away = math.min(os.time() - lastOnline, Config.Player.OfflineIncomeHours * 3600)
				local earned = math.floor(PlotService:GetIncomePerSecond(profile) * away * Config.Player.OfflineIncomeRate)
				if earned > 0 then
					profile.Data.PendingIncome += earned
					task.delay(3, function()
						if player.Parent then
							S.NetService:Notify(player, ("Your Garage earned %s coins while you were away! Go collect it."):format(Format.Commas(earned)), "reward")
						end
					end)
				end
			end
			PlotService:RefreshDisplay(player)
			updateCollector(plot, profile.Data.PendingIncome)
			-- Send the player home on their first spawn so they see their Garage.
			return
		end
	end
	S.NetService:Notify(player, "All Garages are taken on this server - your income is paused.", "warn")
end

local function releasePlot(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	owners[plot] = nil
	local cores = plot:FindFirstChild("DisplayedCores")
	if cores then
		cores:Destroy()
	end
	setSign(plot, "EMPTY GARAGE", "")
	updateCollector(plot, 0)
end

local function collect(player: Player)
	local profile = S.DataService:GetProfile(player)
	local plot = plotOf[player]
	if not profile or not plot then
		return
	end
	local amount = math.floor(profile.Data.PendingIncome)
	if amount <= 0 then
		return
	end
	profile.Data.PendingIncome -= amount
	S.ProgressionService:AddCoins(player, amount, false)
	S.QuestService:Track(player, "Collect", 1)
	updateCollector(plot, profile.Data.PendingIncome)
	S.NetService:Effect(player, { Type = "Collect", Pos = (plot :: any).Collector.Position, Amount = amount })
end

function PlotService:Start()
	S.DataService.ProfileLoaded:Connect(assignPlot)
	S.DataService.ProfileReleasing:Connect(releasePlot)

	for _, plot in S.WorldBuilder.Plots do
		local collector = (plot :: any).Collector :: BasePart
		collector.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or owners[plot] ~= player then
				return
			end
			local now = os.clock()
			if (collectDebounce[player] or 0) > now then
				return
			end
			collectDebounce[player] = now + 1
			collect(player)
		end)
	end

	S.NetService:Handle("TeleportHome", function(player)
		local plot = plotOf[player]
		if not plot then
			return { ok = false, msg = "You don't have a Garage on this server." }
		end
		if not S.RateLimiter:Check(player, "Home", 0.2, 1) then
			return { ok = false, msg = "Teleport is recharging..." }
		end
		S.ZoneService:Teleport(player, plot:GetAttribute("Home"))
		return { ok = true }
	end)

	Players.PlayerRemoving:Connect(function(player)
		collectDebounce[player] = nil
	end)

	-- Income tick
	while true do
		task.wait(1)
		for player, plot in plotOf do
			local profile = S.DataService:GetProfile(player)
			if profile then
				local income = self:GetIncomePerSecond(profile)
				if income > 0 then
					profile.Data.PendingIncome += income
					updateCollector(plot, profile.Data.PendingIncome)
				end
			end
		end
	end
end

return PlotService

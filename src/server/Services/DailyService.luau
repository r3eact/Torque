-- DailyService: 7-day login streak. Missing a day resets the streak to day 1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local QuestData = require(Shared.QuestData)
local ItemData = require(Shared.ItemData)

local DailyService = {}
local S

function DailyService:Init(services)
	S = services
end

function DailyService:Start()
	S.DataService.ProfileLoaded:Connect(function(player, profile)
		if profile.Data.Daily.LastClaimDay < Config.Day(os.time()) then
			task.delay(6, function()
				if player.Parent then
					S.NetService:Notify(player, "🎁 Your daily reward is ready!", "reward")
				end
			end)
		end
	end)

	S.NetService:Handle("ClaimDaily", function(player, profile)
		local daily = profile.Data.Daily
		local day = Config.Day(os.time())
		if daily.LastClaimDay == day then
			return { ok = false, msg = "Come back tomorrow!" }
		end
		local streak = if daily.LastClaimDay == day - 1 then daily.Streak % #QuestData.DailyRewards + 1 else 1
		local reward = QuestData.DailyRewards[streak]
		daily.LastClaimDay = day
		daily.Streak = streak
		local result = { ok = true, Day = streak, Items = {} }
		if reward.Coins then
			local scale = 1 + (profile.Data.Level - 1) * 0.1
			result.Coins = S.ProgressionService:AddCoins(player, reward.Coins * scale, false)
			result.msg = ("Day %d: +%d coins!"):format(streak, result.Coins)
		end
		if reward.Crate then
			for _ = 1, reward.Count or 1 do
				local coreId = S.ShopService:RollCrate(profile, reward.Crate)
				S.InventoryService:AddItem(player, coreId)
				table.insert(result.Items, coreId)
			end
			result.msg = ("Day %d: %d x %s!"):format(streak, reward.Count or 1, ItemData.Crates[reward.Crate].Name)
		end
		S.DataService:MarkDirty(player)
		return result
	end)
end

return DailyService

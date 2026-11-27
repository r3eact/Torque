-- Daily window: 7-day login streak calendar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local QuestData = require(Shared.QuestData)
local ItemData = require(Shared.ItemData)
local Format = require(Shared.Format)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme

return function(UI, C)
	local win = UI:CreateWindow("Daily", "🎁 DAILY REWARDS", T.Good)
	local body = win.Body
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 190), ZIndex = 22, Parent = body })
	UIKit.list(row, 8, true)
	local info = UIKit.label({ Text = "", TextSize = 18, TextColor3 = T.Muted, Position = UDim2.fromOffset(0, 206), Size = UDim2.new(1, 0, 0, 50), ZIndex = 22, Parent = body })
	local claimBtn
	claimBtn = UIKit.button({ Text = "CLAIM", TextSize = 26, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(260, 60), Color = T.Good, ZIndex = 22, Parent = body }, function()
		local result = C.ClientState:Call("ClaimDaily")
		if result.ok then
			if result.Items and #result.Items > 0 then
				UI:Close()
				for _, coreId in result.Items do
					UI.CrateReveal.Play(coreId, T.Good)
					UI.CrateReveal.WaitClosed()
				end
			else
				C.EffectsController:UpgradeBurst()
			end
			UI:Notify(result.msg or "Claimed!", "reward")
		elseif result.msg then
			UI:Notify(result.msg, "warn")
		end
	end)

	local function refresh(data)
		local today = Config.Day(data.ServerTime)
		local canClaim = data.Daily.LastClaimDay < today
		local continuing = data.Daily.LastClaimDay == today - 1
		local nextDay = if canClaim then (if continuing then data.Daily.Streak % #QuestData.DailyRewards + 1 else 1) else data.Daily.Streak
		UIKit.clear(row)
		local scale = 1 + (data.Level - 1) * 0.1
		for i, reward in QuestData.DailyRewards do
			local claimedTile = i < nextDay or (not canClaim and i == nextDay)
			local isToday = i == nextDay
			local tile = UIKit.panel({ LayoutOrder = i, Size = UDim2.fromOffset(98, 180), BackgroundColor3 = if claimedTile then T.Panel3 else T.Panel2, Radius = 14, ZIndex = 23, Parent = row })
			UIKit.stroke(tile, if isToday then T.Gold else T.Panel3, if isToday then 4 else 2)
			UIKit.label({ Text = "Day " .. i, Font = UIKit.Fonts.Title, TextSize = 20, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 24), ZIndex = 24, Parent = tile })
			local icon = if reward.Crate then "📦" else "🪙"
			UIKit.label({ Text = icon, TextSize = 40, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 56), ZIndex = 24, Parent = tile })
			local text = if reward.Crate then ("%dx %s"):format(reward.Count or 1, ItemData.Crates[reward.Crate].Name) else Format.Short(reward.Coins * scale)
			UIKit.label({ Text = text, TextSize = 14, Position = UDim2.fromOffset(4, 104), Size = UDim2.new(1, -8, 0, 40), ZIndex = 24, Parent = tile })
			if claimedTile then
				UIKit.label({ Text = "✔", TextSize = 28, TextColor3 = T.Good, Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 30), ZIndex = 24, Parent = tile })
			end
		end
		if canClaim then
			info.Text = if continuing or data.Daily.Streak == 0 then "Your reward is ready! Log in every day to build your streak." else "Streak reset - claim day 1 and keep it going this time!"
			claimBtn.Text = "CLAIM DAY " .. nextDay
			UIKit.setButtonColor(claimBtn, T.Good)
		else
			local nextReset = (today + 1) * 86400
			info.Text = ("Come back in %s for Day %d!"):format(Format.Time(nextReset - C.ClientState:ServerNow()), data.Daily.Streak % #QuestData.DailyRewards + 1)
			claimBtn.Text = "CLAIMED"
			UIKit.setButtonColor(claimBtn, T.Panel3)
		end
	end

	return { Window = win, Refresh = refresh }
end

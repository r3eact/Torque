-- Quests window: tutorial progress + 3 daily quests with claim buttons + stats.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local QuestData = require(Shared.QuestData)
local Format = require(Shared.Format)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme

return function(UI, C)
	local win = UI:CreateWindow("Quests", "📜 QUESTS", T.Gold)
	local body = win.Body
	local list = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -40),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 22,
		Parent = body,
	})
	UIKit.list(list, 10)
	local footer = UIKit.label({ Text = "", TextSize = 15, TextColor3 = T.Muted, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 30), ZIndex = 22, Parent = body })

	local function questRow(order: number, title: string, progress: number, target: number, rewardText: string, claimed: boolean, onClaim: (() -> ())?)
		local row = UIKit.panel({ LayoutOrder = order, Size = UDim2.new(1, -12, 0, 84), BackgroundColor3 = T.Panel2, Radius = 14, ZIndex = 23, Parent = list })
		UIKit.label({ Text = title, Font = UIKit.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -200, 0, 26), ZIndex = 24, Parent = row })
		UIKit.label({ Text = rewardText, TextSize = 14, TextColor3 = T.Gold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -200, 0, 18), ZIndex = 24, Parent = row })
		local _, set = UIKit.bar({ Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -200, 0, 14), Parent = row }, if progress >= target then T.Good else T.Accent)
		set(progress / target, true)
		UIKit.label({ Text = ("%s / %s"):format(Format.Short(progress), Format.Short(target)), TextSize = 13, TextColor3 = T.Muted, Position = UDim2.new(1, -184, 0, 54), Size = UDim2.fromOffset(60, 20), ZIndex = 24, Parent = row })
		if onClaim then
			local done = progress >= target
			UIKit.button({
				Text = if claimed then "✔ Claimed" elseif done then "CLAIM" else "In progress",
				TextSize = 17,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(120, 46),
				Color = if claimed then T.Panel3 elseif done then T.Good else T.Panel3,
				ZIndex = 24,
				Parent = row,
			}, function()
				if done and not claimed then
					onClaim()
				end
			end)
		end
	end

	local function refresh(data)
		list:ClearAllChildren()
		UIKit.list(list, 10)
		local order = 0
		if not data.Tutorial.Done then
			local step = QuestData.Tutorial[data.Tutorial.Step]
			if step then
				order += 1
				questRow(order, "⭐ " .. step.Text, data.Tutorial.Progress, step.Target, ("Tutorial %d/%d  •  %d coins"):format(data.Tutorial.Step, #QuestData.Tutorial, step.Reward), false, nil)
			end
		end
		local scale = QuestData.RewardScale(data.Level)
		for i, quest in data.Quests.Active do
			local def = QuestData.DailyById[quest.Id]
			if def then
				order += 1
				questRow(order, def.Text, quest.Progress, def.Target, ("🪙 %s   ✨ %s XP"):format(Format.Short(def.Coins * scale), Format.Short(def.XP * scale)), quest.Claimed, function()
					local result = C.ClientState:Call("ClaimQuest", i)
					UI:Notify(result.msg or (if result.ok then "Claimed!" else "Can't claim yet"), if result.ok then "reward" else "warn")
				end)
			end
		end
		local nextReset = (Config.Day(data.ServerTime) + 1) * 86400
		footer.Text = ("New quests in %s   •   Bots destroyed: %s   •   Bosses: %s   •   Arena KOs: %s"):format(
			Format.Time(nextReset - C.ClientState:ServerNow()),
			Format.Commas(data.TotalKills),
			Format.Commas(data.BossKills),
			Format.Commas(data.ArenaKOs)
		)
	end

	return { Window = win, Refresh = refresh }
end

-- QuestService: tutorial chain + daily quests. Other services report gameplay events
-- with QuestService:Track(player, event, amount); nothing here trusts the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local QuestData = require(Shared.QuestData)

local QuestService = {}
local S

local function today(): number
	return Config.Day(os.time())
end

function QuestService:Init(services)
	S = services
end

-- Rolls a fresh set of daily quests when the UTC day changes.
function QuestService:RefreshDailies(player: Player, profile)
	local quests = profile.Data.Quests
	if quests.Day == today() and #quests.Active > 0 then
		return
	end
	local rng = Random.new(today() * 7919 + player.UserId % 1000003)
	local pool = table.clone(QuestData.Daily)
	local active = {}
	for _ = 1, math.min(QuestData.DailyCount, #pool) do
		local def = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(active, { Id = def.Id, Progress = 0, Claimed = false })
	end
	profile.Data.Quests = { Day = today(), Active = active }
	S.DataService:MarkDirty(player)
end

function QuestService:IsTutorialStep(profile, event: string): boolean
	local t = profile.Data.Tutorial
	if t.Done then
		return false
	end
	local step = QuestData.Tutorial[t.Step]
	return step ~= nil and step.Event == event
end

local function advanceTutorial(player: Player, profile, event: string, amount: number)
	local t = profile.Data.Tutorial
	if t.Done then
		return
	end
	local step = QuestData.Tutorial[t.Step]
	if not step or step.Event ~= event then
		return
	end
	t.Progress += amount
	if t.Progress < step.Target then
		return
	end
	-- Step complete: advance first, then reward (rewarding can re-enter Track).
	t.Step += 1
	t.Progress = 0
	if t.Step > #QuestData.Tutorial then
		t.Done = true
	end
	S.NetService:Effect(player, { Type = "TutorialStep", Done = t.Done })
	S.ProgressionService:AddCoins(player, step.Reward, false)
	if t.Done then
		S.NetService:Notify(player, "Tutorial complete! Reach Level 10 to unlock the Neon Foundry.", "reward")
	else
		S.NetService:Notify(player, ("Step complete! +%d coins"):format(step.Reward), "reward")
	end
end

function QuestService:Track(player: Player, event: string, amount: number?)
	local profile = S.DataService:GetProfile(player)
	if not profile then
		return
	end
	local n = amount or 1
	advanceTutorial(player, profile, event, n)
	self:RefreshDailies(player, profile)
	for _, quest in profile.Data.Quests.Active do
		local def = QuestData.DailyById[quest.Id]
		if def and def.Event == event and not quest.Claimed and quest.Progress < def.Target then
			quest.Progress = math.min(def.Target, quest.Progress + n)
			if quest.Progress >= def.Target then
				S.NetService:Notify(player, ("Quest complete: %s - claim your reward!"):format(def.Text), "reward")
			end
		end
	end
	S.DataService:MarkDirty(player)
end

function QuestService:Start()
	S.DataService.ProfileLoaded:Connect(function(player, profile)
		self:RefreshDailies(player, profile)
	end)

	S.NetService:Handle("ClaimQuest", function(player, profile, index)
		if typeof(index) ~= "number" or index ~= math.floor(index) then
			return { ok = false }
		end
		self:RefreshDailies(player, profile)
		local quest = profile.Data.Quests.Active[index]
		if not quest then
			return { ok = false, msg = "Quest not found." }
		end
		local def = QuestData.DailyById[quest.Id]
		if quest.Claimed or quest.Progress < def.Target then
			return { ok = false, msg = "Quest not finished yet." }
		end
		quest.Claimed = true
		local scale = QuestData.RewardScale(profile.Data.Level)
		local coins = S.ProgressionService:AddCoins(player, def.Coins * scale, false)
		S.ProgressionService:AddXP(player, def.XP * scale)
		S.DataService:MarkDirty(player)
		return { ok = true, msg = ("+%d coins, +%d XP"):format(coins, math.floor(def.XP * scale)) }
	end)

	S.NetService:Handle("SkipTutorial", function(player, profile)
		profile.Data.Tutorial.Done = true
		S.DataService:MarkDirty(player)
		return { ok = true }
	end)
end

return QuestService

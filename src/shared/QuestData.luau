-- QuestData: the onboarding tutorial (a guided quest chain) and the daily quest pool.
-- Quest progress is driven entirely by server events: QuestService:Track(player, Event, amount)
local QuestData = {}

-- Tutorial: designed so a new player has fought, looted, equipped and earned income
-- within the first ~2 minutes. `Hint` tells the client where to point the guide beam.
QuestData.Tutorial = {
	{ Text = "Destroy 3 Scrap Bots in the Scrapyard", Event = "Kill", Target = 3, Reward = 100, Hint = "Scrapyard" },
	{ Text = "Open your FREE Scrap Crate at the Shop", Event = "OpenCrate", Target = 1, Reward = 50, Hint = "Shop" },
	{ Text = "Equip your new Core (Inventory)", Event = "Equip", Target = 1, Reward = 50, Hint = "Inventory" },
	{ Text = "Display a Core in your Garage (Inventory)", Event = "Display", Target = 1, Reward = 50, Hint = "Inventory" },
	{ Text = "Collect income from your Garage pad", Event = "Collect", Target = 1, Reward = 100, Hint = "Collector" },
	{ Text = "Buy an Upgrade at the Upgrade Station", Event = "Upgrade", Target = 1, Reward = 300, Hint = "Upgrades" },
}

-- Daily pool: 3 are picked per player per day. Rewards scale with level.
QuestData.Daily = {
	{ Id = "Kill50", Text = "Destroy 50 bots", Event = "Kill", Target = 50, Coins = 400, XP = 150 },
	{ Id = "Kill150", Text = "Destroy 150 bots", Event = "Kill", Target = 150, Coins = 1200, XP = 500 },
	{ Id = "Boss1", Text = "Help defeat a Boss", Event = "BossKill", Target = 1, Coins = 1500, XP = 800 },
	{ Id = "Earn2k", Text = "Earn 2,000 coins", Event = "EarnCoins", Target = 2000, Coins = 500, XP = 200 },
	{ Id = "Crate3", Text = "Open 3 crates", Event = "OpenCrate", Target = 3, Coins = 600, XP = 250 },
	{ Id = "Slam25", Text = "Use Torque Slam 25 times", Event = "UseSlam", Target = 25, Coins = 400, XP = 200 },
	{ Id = "Collect5", Text = "Collect Garage income 5 times", Event = "Collect", Target = 5, Coins = 300, XP = 150 },
	{ Id = "Upgrade3", Text = "Buy 3 upgrades", Event = "Upgrade", Target = 3, Coins = 500, XP = 200 },
}
QuestData.DailyCount = 3

QuestData.DailyById = {}
for _, q in QuestData.Daily do
	QuestData.DailyById[q.Id] = q
end

function QuestData.RewardScale(level: number): number
	return 1 + (level - 1) * 0.15
end

-- 7-day login streak. Coins scale with level; crates are rolled on the server.
QuestData.DailyRewards = {
	{ Coins = 250 },
	{ Coins = 500 },
	{ Crate = "Basic" },
	{ Coins = 1200 },
	{ Crate = "Basic", Count = 3 },
	{ Coins = 3000 },
	{ Crate = "Neon" },
}

return QuestData

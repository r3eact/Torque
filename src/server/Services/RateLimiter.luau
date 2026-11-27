-- RateLimiter: per-player token buckets. Every remote call spends a token; spammers
-- (auto-clickers, exploit scripts firing remotes in a loop) are silently dropped.
local Players = game:GetService("Players")

local RateLimiter = {}

local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

-- Returns true if the call is allowed. `rate` tokens refill per second, `burst` is the cap.
function RateLimiter:Check(player: Player, key: string, rate: number, burst: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local now = os.clock()
	local bucket = playerBuckets[key]
	if not bucket then
		bucket = { tokens = burst, last = now }
		playerBuckets[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.last) * rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter:Start()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return RateLimiter

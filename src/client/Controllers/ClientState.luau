-- ClientState: the client's read-only copy of its profile (pushed by DataSync) and a
-- safe wrapper for calling server Actions. The UI renders from this; it never
-- changes game state locally.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local ClientState = {}
ClientState.Data = nil :: any
ClientState.Changed = Signal.new()
ClientState.ServerOffset = 0

local actionRemote = Net.Function("Action")

-- Returns the server's response table; never throws.
function ClientState:Call(action: string, ...: any)
	local args = table.pack(...)
	local ok, result = pcall(function()
		return actionRemote:InvokeServer(action, table.unpack(args, 1, args.n))
	end)
	if not ok or typeof(result) ~= "table" then
		return { ok = false, msg = "Connection problem, try again." }
	end
	return result
end

function ClientState:ServerNow(): number
	return os.time() + self.ServerOffset
end

function ClientState:WaitForData()
	while not self.Data do
		self.Changed:Wait()
	end
	return self.Data
end

function ClientState:Init()
	Net.Event("DataSync").OnClientEvent:Connect(function(data)
		self.Data = data
		self.ServerOffset = (data.ServerTime or os.time()) - os.time()
		self.Changed:Fire(data)
	end)
end

function ClientState:Start()
	self:Call("Sync")
end

return ClientState

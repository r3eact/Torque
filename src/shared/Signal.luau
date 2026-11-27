-- Signal: a tiny event object for communication *inside* one side (server or client).
-- Network communication always goes through Net/RemoteEvents instead.
local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (...any) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} :: { [(...any) -> ()]: boolean } }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local handlers = self._handlers
	handlers[fn] = true
	return {
		Disconnect = function()
			handlers[fn] = nil
		end,
	}
end

-- Handlers run in their own thread so one erroring/yielding handler can't break the others.
function Signal:Fire(...: any)
	for fn in self._handlers do
		task.spawn(fn, ...)
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal

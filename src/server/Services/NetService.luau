-- NetService: the single router for client "Action" requests plus helpers for
-- server -> client messages (notifications and visual effects).
--
-- Every handler is called as handler(player, profile, ...args) and must return a
-- table { ok = boolean, msg = string?, ... }. Handlers MUST validate their args;
-- this router only guarantees the player is loaded and not spamming.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local NetService = {}

local handlers: { [string]: (Player, any, ...any) -> any } = {}
local S -- services table

function NetService:Init(services)
	S = services
end

function NetService:Handle(action: string, handler: (Player, any, ...any) -> any)
	assert(handlers[action] == nil, "Duplicate action handler: " .. action)
	handlers[action] = handler
end

function NetService:Notify(player: Player, text: string, kind: string?)
	Net.Event("Notify"):FireClient(player, text, kind or "info")
end

function NetService:NotifyAll(text: string, kind: string?)
	Net.Event("Notify"):FireAllClients(text, kind or "info")
end

function NetService:Effect(player: Player, payload: { [string]: any })
	Net.Event("Effect"):FireClient(player, payload)
end

function NetService:EffectAll(payload: { [string]: any })
	Net.Event("Effect"):FireAllClients(payload)
end

function NetService:Start()
	Net.Function("Action").OnServerInvoke = function(player: Player, action: any, ...: any)
		if typeof(action) ~= "string" then
			return { ok = false }
		end
		local handler = handlers[action]
		if not handler then
			return { ok = false }
		end
		if not S.RateLimiter:Check(player, "Action", 6, 12) then
			return { ok = false, msg = "Slow down!" }
		end
		local profile = S.DataService:GetProfile(player)
		if not profile then
			return { ok = false, msg = "Still loading your data..." }
		end
		local success, result = pcall(handler, player, profile, ...)
		if not success then
			warn(("[Torque] Action %s failed for %s: %s"):format(action, player.Name, tostring(result)))
			return { ok = false, msg = "Something went wrong." }
		end
		return result or { ok = true }
	end

	-- Lets a freshly started client ask for its data snapshot.
	self:Handle("Sync", function(p)
		S.DataService:MarkDirty(p)
		return { ok = true }
	end)
end

return NetService

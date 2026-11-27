-- Net: creates (server) or finds (client) every remote in one place.
--
-- SECURITY MODEL
--   * Client -> Server traffic only goes through two remotes:
--       Action  (RemoteFunction): menu actions like "OpenCrate", routed by NetService,
--                                 rate limited and type-checked before any handler runs.
--       Ability (RemoteEvent):    combat inputs; the server only receives *which* ability
--                                 and an aim direction. Hit detection, damage and rewards
--                                 are computed on the server.
--   * Server -> Client remotes (DataSync, Notify, Effect) are purely informational.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local EVENTS = { "DataSync", "Notify", "Effect", "Ability" }
local FUNCTIONS = { "Action" }

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net

-- SoundController: one-shot SFX (2D or positional) and optional background music,
-- respecting the player's volume settings.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local SoundController = {}
local C
local music: Sound? = nil

local function sfxVolume(): number
	local data = C.ClientState.Data
	return if data then data.Settings.Sfx else 0.8
end

function SoundController:Init(controllers)
	C = controllers
end

function SoundController:Play(name: string, position: Vector3?, volume: number?, pitch: number?)
	local id = Config.Sounds[name]
	local vol = sfxVolume()
	if not id or id == "" or vol <= 0 then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.6 * vol * (volume or 1)
	sound.PlaybackSpeed = pitch or 1
	local holder: Instance = SoundService
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 140
		holder = attachment
		task.delay(6, function()
			attachment:Destroy()
		end)
	end
	sound.Parent = holder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

function SoundController:Start()
	if Config.Sounds.Music ~= "" then
		local m = Instance.new("Sound")
		m.Name = "TorqueMusic"
		m.SoundId = Config.Sounds.Music
		m.Looped = true
		m.Volume = 0.2
		m.Parent = SoundService
		m:Play()
		music = m
	end
	C.ClientState.Changed:Connect(function(data)
		if music then
			music.Volume = 0.4 * data.Settings.Music
		end
	end)
end

return SoundController

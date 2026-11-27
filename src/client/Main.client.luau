-- Main (LocalScript in StarterPlayerScripts/Client)
-- Boots client controllers: require -> :Init(controllers) -> :Start()
local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"ClientState",
	"SoundController",
	"UIController",
	"EffectsController",
	"CombatController",
	"WorldController",
	"TutorialController",
}

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(Controllers:WaitForChild(name))
end
for _, name in ORDER do
	if controllers[name].Init then
		controllers[name]:Init(controllers)
	end
end
for _, name in ORDER do
	if controllers[name].Start then
		task.spawn(controllers[name].Start, controllers[name])
	end
end

-- Joue les effets sonores définis dans Config.Sounds.
-- Un son joué par le serveur est entendu par tous les joueurs, en 3D autour de sa source.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sfx = {}

local random = Random.new()

-- `target` : la pièce qui émet le son, ou une position dans le monde.
-- `strength` : intensité de 0 à 1 environ (un choc violent sonne plus fort).
function Sfx.play(name: string, target: BasePart | Vector3, strength: number?)
	local def = Config.Sounds[name]
	if not def or def.Id == "" then
		return
	end

	local parent: Instance
	local temporary: Instance? = nil
	if typeof(target) == "Vector3" then
		local anchor = Instance.new("Part")
		anchor.Name = "SourceSonore"
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CFrame = CFrame.new(target)
		anchor.Parent = workspace
		parent = anchor
		temporary = anchor
	else
		parent = target
	end

	local sound = Instance.new("Sound")
	sound.Name = "Sfx" .. name
	sound.SoundId = def.Id
	sound.Volume = def.Volume * math.clamp(strength or 1, 0.25, 1.5)
	sound.PlaybackSpeed = def.Pitch * random:NextNumber(0.92, 1.08)
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 90
	sound.Parent = parent
	sound:Play()

	Debris:AddItem(temporary or sound, 3)
end

return Sfx

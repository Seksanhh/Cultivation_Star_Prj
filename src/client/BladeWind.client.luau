-- Client : souffle de vent des lames (Config.BLADE_WIND).
-- Chaque arme tenue, la sienne comme celle des autres joueurs, porte une boucle de vent dont le
-- volume et la hauteur suivent la vitesse de sa pointe. Le calcul se fait sur chaque client, sans
-- passer par le réseau : le son réagit sans délai au geste.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local settings = Config.BLADE_WIND

local weaponsFolder = workspace:WaitForChild("Weapons")

local MAX_PLAUSIBLE_SPEED = 400 -- au-delà, l'arme a été téléportée (saisie, réapparition) : pas un geste

type Tracker = {
	blade: BasePart,
	sound: Sound,
	lastTip: Vector3?,
	level: number, -- 0 à 1, lissé
}

local trackers: { [Model]: Tracker } = {}
local random = Random.new()

-- La lame la plus longue de l'arme : c'est sa pointe qui va le plus vite.
local function longestBlade(weapon: Model): BasePart?
	local best: BasePart? = nil
	for _, part in weapon:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("IsBlade") and (not best or part.Size.Y > best.Size.Y) then
			best = part
		end
	end
	return best
end

local function holderVelocity(weapon: Model): Vector3
	local userId = weapon:GetAttribute("Holder")
	local holder = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local root = holder and holder.Character and holder.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.zero
end

local function startTracking(weapon: Model): Tracker?
	local blade = longestBlade(weapon)
	if not blade then
		return nil -- bouclier : pas de lame, pas de souffle
	end
	local sound = Instance.new("Sound")
	sound.Name = "VentLame"
	sound.SoundId = settings.SOUND
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMinDistance = 4
	sound.RollOffMaxDistance = 40
	sound.Parent = blade
	sound:Play()
	-- Départ au hasard dans la boucle : deux lames ne soufflent pas à l'unisson.
	sound.TimePosition = random:NextNumber(0, 20)
	return { blade = blade, sound = sound, lastTip = nil, level = 0 }
end

local function stopTracking(weapon: Model)
	local tracker = trackers[weapon]
	if tracker then
		trackers[weapon] = nil
		tracker.sound:Destroy()
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not settings.ENABLED or dt <= 0 then
		return
	end
	-- Suivre les armes tenues, oublier les autres (lâchées, rangées au fourreau, détruites).
	for weapon in trackers do
		if weapon.Parent ~= weaponsFolder or not weapon:GetAttribute("Holder") then
			stopTracking(weapon)
		end
	end
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:IsA("Model") and weapon:GetAttribute("Holder") and not trackers[weapon] then
			local tracker = startTracking(weapon)
			if tracker then
				trackers[weapon] = tracker
			end
		end
	end

	for weapon, tracker in trackers do
		local blade = tracker.blade
		local tip = blade.CFrame * Vector3.new(0, blade.Size.Y / 2, 0)
		local speed = 0
		if tracker.lastTip then
			-- Vitesse de la pointe par rapport au joueur qui la tient : marcher ne souffle pas.
			speed = ((tip - tracker.lastTip) / dt - holderVelocity(weapon)).Magnitude
			if speed > MAX_PLAUSIBLE_SPEED then
				speed = 0
			end
		end
		tracker.lastTip = tip

		local target = math.clamp((speed - settings.MIN_SPEED) / (settings.MAX_SPEED - settings.MIN_SPEED), 0, 1)
		if target > tracker.level then
			-- Le souffle monte tout de suite avec le geste...
			tracker.level = target
		else
			-- ...et retombe en douceur quand la lame ralentit.
			tracker.level = target + (tracker.level - target) * math.exp(-dt / settings.RELEASE_TIME)
		end

		local level = tracker.level
		tracker.sound.Volume = settings.VOLUME * level ^ 1.5
		tracker.sound.PlaybackSpeed = settings.PITCH_MIN + (settings.PITCH_MAX - settings.PITCH_MIN) * level
	end
end)

-- Client : léger tremblement de l'écran quand on bloque ou pare un coup de bandit.
-- Le serveur l'annonce par le remote Feedback, avec une intensité après la main,
-- la force et la durée de la vibration (les autres vibrations n'en ont pas et sont ignorées ici). Réglages : Config.CAMERA_SHAKE.
--
-- Le décalage est ajouté à la caméra juste avant l'affichage, après le suivi des mains
-- (VRClient) et le panneau de vie (Hud) : les mains, les armes et la vitesse des coups
-- ne tremblent donc pas. Il est retiré au début de l'image suivante, avant que les
-- scripts de caméra de Roblox ne relisent la caméra, pour que la vue ne dérive pas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local settings = Config.CAMERA_SHAKE

local feedbackRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Feedback") :: RemoteEvent

local shakeStart = 0
local shakeIntensity = 0
local phases = { 0, 0, 0 }
local appliedOffset = CFrame.identity

-- Intensité qui reste au tremblement en cours (1 au départ, 0 à la fin).
local function remaining(now: number): number
	local t = (now - shakeStart) / settings.DURATION
	if t >= 1 then
		return 0
	end
	return shakeIntensity * (1 - t) * (1 - t)
end

local function startShake(intensity: number)
	if not settings.ENABLED then
		return
	end
	if VRService.VREnabled then
		intensity *= settings.VR_SCALE
	end
	local now = os.clock()
	-- Un tremblement plus faible ne coupe pas un plus fort déjà en cours.
	if intensity <= 0 or intensity < remaining(now) then
		return
	end
	shakeStart = now
	shakeIntensity = intensity
	for i = 1, 3 do
		phases[i] = math.random() * math.pi * 2
	end
end

feedbackRemote.OnClientEvent:Connect(function(_side: any, _strength: any, _duration: any, shake: any)
	if typeof(shake) == "number" then
		startShake(math.clamp(shake, 0, 3))
	end
end)

-- Début de l'image : on retire le décalage de l'image précédente.
RunService:BindToRenderStep("VRMeleeShakeUndo", Enum.RenderPriority.First.Value, function()
	if appliedOffset ~= CFrame.identity then
		local camera = workspace.CurrentCamera
		camera.CFrame = camera.CFrame * appliedOffset:Inverse()
		appliedOffset = CFrame.identity
	end
end)

-- Juste avant l'affichage : on ajoute le décalage de cette image.
RunService:BindToRenderStep("VRMeleeShake", Enum.RenderPriority.Camera.Value + 3, function()
	local now = os.clock()
	local amount = remaining(now)
	if amount <= 0 then
		return
	end
	local amplitude = math.rad(settings.ANGLE) * amount
	local w = 2 * math.pi * settings.FREQUENCY * (now - shakeStart)
	local pitch = amplitude * math.sin(w + phases[1])
	local yaw = amplitude * 0.8 * math.sin(w * 1.31 + phases[2])
	local roll = amplitude * 0.5 * math.sin(w * 0.77 + phases[3])
	appliedOffset = CFrame.Angles(pitch, yaw, roll)
	local camera = workspace.CurrentCamera
	camera.CFrame = camera.CFrame * appliedOffset
end)

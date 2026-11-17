-- Commandes des techniques actives (voie des Arts).
--   Onde de Qi          : gâchette de la main qui tient l'arme        (clavier : F)
--   Rugissement du lion : bouton Y, manette gauche                    (clavier : R)
--   Pas de l'éclair     : bouton B, manette droite                    (clavier : C)
--   Épée volante        : bouton X, manette gauche, maintenu pour guider (clavier : V)
-- Le client ne fait que demander : le serveur vérifie la technique, le Qi et le délai.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local Skills = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skills"))

local player = Players.LocalPlayer
local useRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseTechnique") :: RemoteEvent
local weaponsFolder = workspace:WaitForChild("Weapons")

-- La technique est-elle débloquée, le Qi suffisant et le délai écoulé ?
-- Simple filtre pour ne pas envoyer de demandes inutiles.
local function ready(skillId: string): boolean
	local skill = Skills.ById[skillId]
	local settings = skill and skill.Active
	if not skill or not settings then
		return false
	end
	if not Skills.parse(player:GetAttribute("Skills"))[skillId] then
		return false
	end
	if (player:GetAttribute("Qi") or 0) < settings.QiCost then
		return false
	end
	local cooldownEnd = player:GetAttribute("Cooldown" .. skillId)
	return typeof(cooldownEnd) ~= "number" or workspace:GetServerTimeNow() >= cooldownEnd
end

local function holdsBlade(side: string): boolean
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:GetAttribute("Holder") == player.UserId and weapon:GetAttribute("HolderHand") == side then
			for _, part in weapon:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
					return true
				end
			end
		end
	end
	return false
end

local function qiWave(side: string?)
	-- Au clavier, on prend la main armée, la droite d'abord.
	local hand = side
	if not hand then
		hand = if holdsBlade("Right") then "Right" elseif holdsBlade("Left") then "Left" else nil
	end
	if hand and holdsBlade(hand) and ready("OndeDeQi") then
		useRemote:FireServer("OndeDeQi", hand)
	end
end

local function lionRoar()
	if ready("Rugissement") then
		useRemote:FireServer("Rugissement")
	end
end

local function lightningStep()
	if ready("Ruee") then
		-- Direction du regard (la tête dans le casque, la caméra sinon).
		local look = workspace.CurrentCamera:GetRenderCFrame().LookVector
		useRemote:FireServer("Ruee", look)
	end
end

---------------------------------------------------------------------------
-- Épée volante (御剑术)
-- Premier appui : l'épée apparaît. Bouton maintenu : elle vole vers le point que vise la main
-- gauche (le « doigt d'épée »), ou le regard sans casque. Bouton relâché : elle revient à l'épaule.
-- Double appui rapide : elle se dissipe.
---------------------------------------------------------------------------

local swordRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EpeeVolante") :: RemoteEvent
local DOUBLE_TAP = 0.35 -- secondes entre deux appuis pour congédier l'épée
local AIM_DISTANCE = 60 -- portée de la visée (studs)
local SEND_INTERVAL = 0.05 -- envoi du point visé au serveur, 20 fois par seconde

local guiding = false
local lastPress = 0
local lastSent = 0

-- Petite sphère de Qi, visible de ce joueur seul, à l'endroit visé.
local marker = Instance.new("Part")
marker.Name = "ViseeEpeeVolante"
marker.Shape = Enum.PartType.Ball
marker.Size = Vector3.new(0.5, 0.5, 0.5)
marker.Color = Color3.fromRGB(140, 220, 255)
marker.Material = Enum.Material.Neon
marker.Transparency = 0.3
marker.Anchored = true
marker.CanCollide = false
marker.CanQuery = false
marker.CanTouch = false
marker.CastShadow = false

local function swordActive(): boolean
	return player:GetAttribute("EpeeVolante") == true
end

-- Rayon de visée : la main gauche en VR (dans l'axe de la manette), le regard sinon.
local function aimRay(): (Vector3, Vector3)
	local camera = workspace.CurrentCamera
	if VRService.VREnabled then
		local tracked = VRService:GetUserCFrame(Enum.UserCFrame.LeftHand)
		local hand = camera.CFrame * CFrame.new(tracked.Position * camera.HeadScale) * tracked.Rotation
		return hand.Position, hand.LookVector
	end
	local view = camera:GetRenderCFrame()
	return view.Position, view.LookVector
end

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function aimPoint(): Vector3
	local ignored: { Instance } = { marker, weaponsFolder }
	for _, name in { "VRHands", "EpeesVolantes" } do
		local item = workspace:FindFirstChild(name)
		if item then
			table.insert(ignored, item)
		end
	end
	if player.Character then
		table.insert(ignored, player.Character)
	end
	aimParams.FilterDescendantsInstances = ignored
	local origin, direction = aimRay()
	local hit = workspace:Raycast(origin, direction * AIM_DISTANCE, aimParams)
	return if hit then hit.Position else origin + direction * AIM_DISTANCE * 0.6
end

local function startGuiding()
	local now = os.clock()
	if swordActive() and now - lastPress < DOUBLE_TAP then
		-- Double appui : l'épée se dissipe.
		swordRemote:FireServer("Dismiss")
		guiding = false
		lastPress = 0
		return
	end
	lastPress = now
	if not swordActive() then
		if not ready("EpeeVolante") then
			return
		end
		useRemote:FireServer("EpeeVolante")
	end
	guiding = true
end

local function stopGuiding()
	if guiding then
		guiding = false
		if swordActive() then
			swordRemote:FireServer("Release")
		end
	end
end

RunService.RenderStepped:Connect(function()
	if not guiding or not swordActive() then
		marker.Parent = nil
		return
	end
	local point = aimPoint()
	marker.Position = point
	marker.Parent = workspace
	local now = os.clock()
	if now - lastSent >= SEND_INTERVAL then
		lastSent = now
		swordRemote:FireServer("Guide", point)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.ButtonX or input.KeyCode == Enum.KeyCode.V then
		stopGuiding()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	local key = input.KeyCode
	if key == Enum.KeyCode.ButtonX then
		startGuiding()
		return
	end
	if key == Enum.KeyCode.ButtonR2 then
		qiWave("Right")
	elseif key == Enum.KeyCode.ButtonL2 then
		qiWave("Left")
	elseif key == Enum.KeyCode.ButtonY then
		lionRoar()
	elseif key == Enum.KeyCode.ButtonB then
		lightningStep()
	elseif not processed then
		if key == Enum.KeyCode.F then
			qiWave(nil)
		elseif key == Enum.KeyCode.R then
			lionRoar()
		elseif key == Enum.KeyCode.C then
			lightningStep()
		elseif key == Enum.KeyCode.V then
			startGuiding()
		end
	end
end)

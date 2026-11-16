-- Commandes des techniques actives (voie des Arts).
--   Onde de Qi          : gâchette de la main qui tient l'arme        (clavier : F)
--   Rugissement du lion : bouton Y, manette gauche                    (clavier : R)
--   Pas de l'éclair     : bouton B, manette droite                    (clavier : C)
-- Le client ne fait que demander : le serveur vérifie la technique, le Qi et le délai.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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

UserInputService.InputBegan:Connect(function(input, processed)
	local key = input.KeyCode
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
		end
	end
end)

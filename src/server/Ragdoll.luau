-- Ragdoll : à sa mort, un personnage (R15 ou R6) s'effondre de façon physique au lieu de
-- tomber en morceaux. Chaque articulation motorisée (Motor6D) est remplacée par une rotule
-- (BallSocketConstraint) aux angles limités comme ceux d'un vrai corps : le genou plie sans se
-- tordre, la tête bascule sans faire le tour du cou, etc.
--
-- Le Humanoid doit avoir BreakJointsOnDeath = false, sinon Roblox casse les articulations
-- avant qu'on les remplace.

local Players = game:GetService("Players")

local Ragdoll = {}

-- Limites par articulation, en degrés : { flexion maximale (cône), torsion maximale }.
-- Les noms R15 et R6 sont tous les deux présents.
local LIMITS: { [string]: { number } } = {
	Neck = { 40, 35 },
	Waist = { 30, 20 },
	LeftShoulder = { 85, 50 },
	RightShoulder = { 85, 50 },
	["Left Shoulder"] = { 85, 50 },
	["Right Shoulder"] = { 85, 50 },
	LeftElbow = { 75, 10 },
	RightElbow = { 75, 10 },
	LeftWrist = { 35, 20 },
	RightWrist = { 35, 20 },
	LeftHip = { 60, 20 },
	RightHip = { 60, 20 },
	["Left Hip"] = { 60, 20 },
	["Right Hip"] = { 60, 20 },
	LeftKnee = { 75, 8 },
	RightKnee = { 75, 8 },
	LeftAnkle = { 25, 10 },
	RightAnkle = { 25, 10 },
}
local DEFAULT_LIMIT = { 45, 20 }

-- Articulation entre la pièce racine invisible (HumanoidRootPart) et le buste : elle reste rigide,
-- pour que la pièce racine suive le corps au lieu de tomber seule.
local ROOT_JOINTS = { Root = true, RootJoint = true }

-- Poussée donnée au buste par le coup fatal (studs/s).
local KNOCKBACK = 16
local KNOCKBACK_UP = 6

-- Remplace une articulation motorisée par une rotule limitée.
local function toSocket(motor: Motor6D)
	local part0, part1 = motor.Part0, motor.Part1
	if not part0 or not part1 then
		return
	end
	local limit = LIMITS[motor.Name] or DEFAULT_LIMIT

	-- Les deux points d'attache coïncident dans la pose au moment de la mort : cette pose est le
	-- centre du cône de flexion.
	local a0 = Instance.new("Attachment")
	a0.Name = "Ragdoll" .. motor.Name
	a0.CFrame = motor.C0
	a0.Parent = part0
	local a1 = Instance.new("Attachment")
	a1.Name = "Ragdoll" .. motor.Name
	a1.CFrame = motor.C1
	a1.Parent = part1

	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "Ragdoll" .. motor.Name
	socket.Attachment0 = a0
	socket.Attachment1 = a1
	socket.LimitsEnabled = true
	socket.UpperAngle = limit[1]
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -limit[2]
	socket.TwistUpperAngle = limit[2]
	socket.MaxFrictionTorque = 4 -- un peu de raideur : le corps ne gigote pas comme un pantin
	socket.Parent = part1

	-- Deux pièces reliées ne se cognent pas entre elles (sinon le corps tremble).
	local noCollide = Instance.new("NoCollisionConstraint")
	noCollide.Part0 = part0
	noCollide.Part1 = part1
	noCollide.Parent = part1

	motor.Enabled = false
end

-- Direction du coup fatal : du dernier joueur qui a frappé vers le corps (à plat).
local function knockbackDirection(model: Model, from: Vector3): Vector3?
	local userId = model:GetAttribute("LastAttacker")
	local killer = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	local character = killer and killer.Character
	local killerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not killerRoot or not killerRoot:IsA("BasePart") then
		return nil
	end
	local away = from - killerRoot.Position
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.01 then
		return nil
	end
	return away.Unit
end

-- Fait s'effondrer `model`. Sans effet si le personnage est déjà en ragdoll.
function Ragdoll.apply(model: Model)
	if model:GetAttribute("Ragdoll") then
		return
	end
	model:SetAttribute("Ragdoll", true)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- Plus rien ne doit diriger le corps (orientation vers la cible, déplacements forcés).
	for _, item in model:GetDescendants() do
		if item:IsA("AlignOrientation") or item:IsA("AlignPosition") or item:IsA("LinearVelocity") or item:IsA("AngularVelocity") or item:IsA("VectorForce") or item:IsA("BodyMover") then
			item:Destroy()
		end
	end

	local bodyParts: { [BasePart]: boolean } = {}
	local torso: BasePart? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and item.Part0 and item.Part1 then
			bodyParts[item.Part0] = true
			bodyParts[item.Part1] = true
			if ROOT_JOINTS[item.Name] then
				-- La pièce racine reste soudée au buste, dans la position du moment.
				local weld = Instance.new("WeldConstraint")
				weld.Name = "RagdollRoot"
				weld.Part0 = item.Part0
				weld.Part1 = item.Part1
				weld.Parent = item.Part1
				item.Enabled = false
				torso = item.Part1
			else
				toSocket(item)
			end
		end
	end

	-- Les membres touchent le sol (les accessoires et l'arme, non). La pièce racine reste
	-- immatérielle : elle ne fait que suivre le buste.
	for part in bodyParts do
		if part == root then
			part.CanCollide = false
			part.Massless = true
		else
			part.CanCollide = true
		end
	end

	if humanoid then
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
	end

	-- La physique du corps reste sur le serveur, pour que tous les joueurs voient la même chute.
	for part in bodyParts do
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
	end

	-- Le corps part dans le sens du coup qui l'a tué.
	if torso then
		local direction = knockbackDirection(model, torso.Position)
		if direction then
			torso.AssemblyLinearVelocity += direction * KNOCKBACK + Vector3.new(0, KNOCKBACK_UP, 0)
		end
	end
end

return Ragdoll

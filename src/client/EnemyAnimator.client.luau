-- Animation du corps des bandits, calculée par chaque client à chaque image :
-- marche calée sur la vitesse réelle, balancement du bras libre, buste qui se penche et rebondit,
-- respiration à l'arrêt, tête qui suit le joueur, sursaut quand un coup porte.
-- Tout est lissé, et chaque bandit a son propre rythme. Les bras armés, eux, restent pilotés
-- par le serveur (ils comptent pour la parade).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local enemiesFolder = workspace:WaitForChild("Enemies")

local STRIDE = 5.2 -- distance parcourue (studs) pendant un cycle de marche complet
local LEG_SWING = 0.75 -- amplitude des jambes (radians) à pleine vitesse
local ARM_SWING = 0.55 -- amplitude du bras libre
local LEAN = 0.16 -- inclinaison du buste vers l'avant à pleine vitesse
local BOB = 0.12 -- rebond vertical du buste pendant la marche (studs)
local BREATH = 0.035 -- amplitude de la respiration à l'arrêt (studs)
local HEAD_TURN = math.rad(55) -- angle maximal dont la tête se tourne vers le joueur
local FLINCH = 0.3 -- recul du buste (radians) quand un coup porte
local ATTACK_LEAN = 0.2 -- inclinaison du buste (radians) quand il arme puis frappe

type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	rootJoint: Motor6D?,
	neck: Motor6D?,
	leftHip: Motor6D?,
	rightHip: Motor6D?,
	freeArm: Motor6D?,
	scale: number,
	phase: number, -- avancement du cycle de marche
	offset: number, -- décalage propre à ce bandit, pour qu'ils ne respirent pas à l'unisson
	amount: number, -- 0 = à l'arrêt, 1 = pleine vitesse (lissé)
	sideLean: number, -- inclinaison latérale (lissée) quand il marche de côté
	headYaw: number,
	flinch: number,
	attackLean: number,
	lastHealth: number,
}

local rigs: { [Model]: Rig } = {}
local random = Random.new()

-- Cherche une articulation par son nom R6 ou R15 (dans un corps R15, chaque articulation est rangée
-- dans la pièce qu'elle fait bouger, et non dans le buste).
local function findMotor(model: Model, r6Name: string, r15Name: string): Motor6D?
	for _, item in model:GetDescendants() do
		if (item.Name == r6Name or item.Name == r15Name) and item:IsA("Motor6D") then
			return item
		end
	end
	return nil
end

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	-- Le modèle arrive du serveur pièce par pièce : on attend l'essentiel.
	local humanoid = model:WaitForChild("Humanoid", 5)
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end
	task.wait(0.3) -- le temps que le reste du corps et les articulations suivent

	local rig: Rig = {
		model = model,
		humanoid = humanoid,
		root = root,
		rootJoint = findMotor(model, "RootJoint", "Root"),
		neck = findMotor(model, "Neck", "Neck"),
		leftHip = findMotor(model, "Left Hip", "LeftHip"),
		rightHip = findMotor(model, "Right Hip", "RightHip"),
		freeArm = if model:GetAttribute("FreeArm") then findMotor(model, "Left Shoulder", "LeftShoulder") else nil,
		scale = model:GetScale(),
		phase = random:NextNumber(0, math.pi * 2),
		offset = random:NextNumber(0, 10),
		amount = 0,
		sideLean = 0,
		headYaw = 0,
		flinch = 0,
		attackLean = 0,
		lastHealth = humanoid.Health,
	}
	rigs[model] = rig

	-- Un coup reçu fait sursauter le buste.
	humanoid.HealthChanged:Connect(function(health)
		if health < rig.lastHealth then
			rig.flinch = 1
		end
		rig.lastHealth = health
	end)
end

for _, model in enemiesFolder:GetChildren() do
	task.spawn(track, model)
end
enemiesFolder.ChildAdded:Connect(function(model)
	task.spawn(track, model)
end)
enemiesFolder.ChildRemoved:Connect(function(model)
	rigs[model :: Model] = nil
end)

-- Applique à une articulation une rotation (et un décalage) exprimés dans le repère de la pièce
-- qui la porte, quelle que soit l'orientation propre de l'articulation : la même formule vaut
-- pour le corps en blocs et pour le personnage du catalogue.
local function pose(motor: Motor6D?, offset: CFrame)
	if motor then
		local frame = motor.C0.Rotation
		motor.Transform = frame:Inverse() * offset * frame
	end
end

-- Lissage indépendant du nombre d'images par seconde.
local function smooth(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

RunService.Stepped:Connect(function(_, dt)
	local character = player.Character
	local playerHead = character and character:FindFirstChild("Head")
	local now = os.clock()

	for model, rig in rigs do
		if not model.Parent or rig.humanoid.Health <= 0 then
			rigs[model] = nil
			continue
		end
		local root = rig.root
		local scale = rig.scale

		-- Vitesse au sol, dans le repère du bandit : vers l'avant et de côté.
		local velocity = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
		local forward, sideways = -velocity.Z, velocity.X
		local speed = math.sqrt(forward * forward + sideways * sideways)
		local fullSpeed = math.max(rig.humanoid.WalkSpeed, 1)

		-- Le cycle avance avec la distance parcourue : les pieds suivent la vitesse réelle.
		rig.phase += speed * dt / (STRIDE * scale) * math.pi * 2
		rig.amount = smooth(rig.amount, math.clamp(speed / fullSpeed, 0, 1.2), 9, dt)
		rig.sideLean = smooth(rig.sideLean, math.clamp(sideways / fullSpeed, -1, 1), 6, dt)
		rig.flinch = smooth(rig.flinch, 0, 7, dt)

		local amount = rig.amount
		-- En marche arrière, les jambes tournent dans l'autre sens.
		local direction = if forward < -0.5 then -1 else 1
		local swing = math.sin(rig.phase) * LEG_SWING * amount * direction

		pose(rig.rightHip, CFrame.Angles(swing, 0, 0))
		pose(rig.leftHip, CFrame.Angles(-swing, 0, 0))
		-- Le bras libre balance à l'opposé de la jambe du même côté, avec un léger retard.
		pose(rig.freeArm, CFrame.Angles(math.sin(rig.phase - 0.3) * ARM_SWING * amount * direction, 0, 0))

		-- Buste : il rebondit deux fois par cycle, se penche dans le sens de la marche,
		-- respire à l'arrêt et recule quand un coup porte.
		local breath = math.sin((now + rig.offset) * 1.7) * BREATH * (1 - math.min(amount, 1))
		local bob = math.abs(math.sin(rig.phase)) * BOB * amount + breath
		-- Pendant une attaque, le serveur indique l'élan du buste : il recule quand le bandit arme
		-- son coup (valeur positive) et plonge vers l'avant à la frappe (valeur négative).
		local attackTarget = model:GetAttribute("AttackLean")
		rig.attackLean = smooth(rig.attackLean, if typeof(attackTarget) == "number" then attackTarget else 0, 14, dt)
		local lean = -LEAN * amount * direction + rig.flinch * FLINCH + rig.attackLean * ATTACK_LEAN
		local roll = -rig.sideLean * 0.12 + math.sin(rig.phase) * 0.04 * amount
		pose(rig.rootJoint, CFrame.new(0, bob * scale, 0) * CFrame.Angles(lean, 0, roll))

		-- La tête se tourne vers le joueur quand il est devant ou sur le côté.
		local targetYaw = 0
		if playerHead and playerHead:IsA("BasePart") then
			local toPlayer = root.CFrame:PointToObjectSpace(playerHead.Position)
			if toPlayer.Z < 2 then
				targetYaw = math.clamp(math.atan2(-toPlayer.X, -toPlayer.Z), -HEAD_TURN, HEAD_TURN)
			end
		end
		rig.headYaw = smooth(rig.headYaw, targetYaw, 5, dt)
		pose(rig.neck, CFrame.Angles(-lean * 0.6, rig.headYaw, 0))
	end
end)

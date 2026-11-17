-- Techniques actives de la voie des Arts : le joueur les déclenche, elles consomment du Qi.
-- Le serveur vérifie que la technique est débloquée, que le Qi suffit et que le délai est écoulé,
-- puis en applique les effets. Les réglages de chaque technique sont dans Skills.luau (champ Active).

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skills = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skills"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Progression = require(script.Parent:WaitForChild("Progression"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Techniques = {}

local weaponsFolder: Instance
local feedbackRemote: RemoteEvent

local qi: { [Player]: number } = {}
local readyAt: { [Player]: { [string]: number } } = {}

local QI_COLOR = Color3.fromRGB(140, 220, 255)

---------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------

local function setQi(player: Player, value: number)
	value = math.clamp(value, 0, Skills.QI_MAX)
	qi[player] = value
	-- L'attribut n'est renvoyé aux clients que si sa valeur arrondie change.
	local shown = math.floor(value)
	if player:GetAttribute("Qi") ~= shown then
		player:SetAttribute("Qi", shown)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Cibles vivantes (bandits, mannequins) dont une pièce est à moins de `radius` de `position`.
-- Les autres joueurs ne sont jamais visés.
local function targetsNear(position: Vector3, radius: number): { [Humanoid]: Model }
	local found: { [Humanoid]: Model } = {}
	for _, part in workspace:GetPartBoundsInRadius(position, radius) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				if humanoid.Health > 0 and not Players:GetPlayerFromCharacter(model) then
					found[humanoid] = model
				end
				break
			end
			model = model:FindFirstAncestorOfClass("Model")
		end
	end
	return found
end

local function strike(player: Player, humanoid: Humanoid, model: Model, damage: number)
	Progression.tag(model, player) -- pour l'expérience si la cible en meurt
	humanoid:TakeDamage(damage * Progression.damageMultiplier(player))
end

local function ghost(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

---------------------------------------------------------------------------
-- Onde de Qi (剑气) : une lame d'énergie part de l'arme, dans l'axe de la lame.
---------------------------------------------------------------------------

local function qiWave(player: Player, settings: { [string]: number }, side: any): boolean
	if side ~= "Left" and side ~= "Right" then
		return false
	end
	-- La lame de l'arme tenue dans cette main.
	local blade: BasePart? = nil
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:GetAttribute("Holder") == player.UserId and weapon:GetAttribute("HolderHand") == side then
			for _, part in weapon:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
					blade = part
					break
				end
			end
		end
	end
	if not blade then
		return false
	end

	local direction = blade.CFrame.UpVector
	local position = blade.CFrame * Vector3.new(0, blade.Size.Y / 2, 0)
	-- Un croissant vertical, fin dans le sens de la marche, orienté comme le plat de la lame.
	local orientation = CFrame.lookAt(Vector3.zero, direction, blade.CFrame.LookVector)

	local wave = ghost("OndeDeQi", Vector3.new(0.25, 5, 1.4), QI_COLOR)
	wave.Transparency = 0.25
	wave.CFrame = orientation + position
	local light = Instance.new("PointLight")
	light.Color = QI_COLOR
	light.Range = 14
	light.Brightness = 3
	light.Parent = wave
	wave.Parent = workspace

	Sfx.play("Metal", position, 1.2)
	feedbackRemote:FireClient(player, side, 0.9, 0.15)

	task.spawn(function()
		local travelled = 0
		local hit: { [Humanoid]: boolean } = {}
		while travelled < settings.Range and wave.Parent do
			local dt = RunService.Heartbeat:Wait()
			local step = settings.Speed * dt
			travelled += step
			position += direction * step
			wave.CFrame = orientation + position
			for humanoid, model in targetsNear(position, settings.Radius) do
				if not hit[humanoid] then
					hit[humanoid] = true
					strike(player, humanoid, model, settings.Damage)
					Sfx.play("Flesh", position, 1)
				end
			end
		end
		-- L'onde se dissipe.
		TweenService:Create(wave, TweenInfo.new(0.2), { Transparency = 1, Size = wave.Size * 1.6 }):Play()
		Debris:AddItem(wave, 0.25)
	end)
	return true
end

---------------------------------------------------------------------------
-- Rugissement du lion (狮子吼) : repousse et sonne les bandits autour du joueur.
---------------------------------------------------------------------------

local function lionRoar(player: Player, settings: { [string]: number }): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local center = root.Position

	for humanoid, model in targetsNear(center, settings.Radius) do
		strike(player, humanoid, model, settings.Damage)
		-- Les bandits lisent cet attribut et restent immobiles tant qu'il n'est pas dépassé.
		model:SetAttribute("StunnedUntil", os.clock() + settings.Stun)
		local targetRoot = model:FindFirstChild("HumanoidRootPart")
		if targetRoot and targetRoot:IsA("BasePart") and not targetRoot.Anchored then
			local away = (targetRoot.Position - center) * Vector3.new(1, 0, 1)
			local push = if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector
			targetRoot.AssemblyLinearVelocity = push * settings.Knockback + Vector3.new(0, 22, 0)
		end
	end

	-- Onde de choc dorée qui se dilate jusqu'au rayon de la technique.
	local gold = Color3.fromRGB(255, 205, 90)
	local shock = ghost("Rugissement", Vector3.new(2, 2, 2), gold)
	shock.Shape = Enum.PartType.Ball
	shock.Transparency = 0.5
	shock.CFrame = CFrame.new(center)
	shock.Parent = workspace
	local diameter = settings.Radius * 2
	TweenService:Create(shock, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(diameter, diameter, diameter),
		Transparency = 1,
	}):Play()
	Debris:AddItem(shock, 0.5)

	Sfx.play("Block", center, 1.5)
	feedbackRemote:FireClient(player, "Left", 1, 0.3)
	feedbackRemote:FireClient(player, "Right", 1, 0.3)
	return true
end

---------------------------------------------------------------------------
-- Pas de l'éclair (闪电步) : déplacement instantané dans la direction du regard.
---------------------------------------------------------------------------

local function lightningStep(player: Player, settings: { [string]: number }, direction: any): boolean
	local root = rootOf(player)
	if not root or typeof(direction) ~= "Vector3" then
		return false
	end
	local flat = direction * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.1 or flat.Magnitude ~= flat.Magnitude then
		return false
	end
	flat = flat.Unit

	-- On s'arrête avant un mur : seul le décor compte, pas les personnages ni les armes.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored: { Instance } = { weaponsFolder }
	for _, name in { "VRHands", "Enemies" } do
		local item = workspace:FindFirstChild(name)
		if item then
			table.insert(ignored, item)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignored, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignored

	local distance = settings.Distance
	local result = workspace:Raycast(root.Position, flat * distance, params)
	if result then
		distance = math.max(result.Distance - 2, 0)
	end
	if distance < 1 then
		return false
	end

	local from = root.Position
	local to = from + flat * distance
	root.CFrame = root.CFrame + flat * distance

	-- Traînée d'éclair entre le départ et l'arrivée.
	local streak = ghost("PasDeLEclair", Vector3.new(0.5, 3.5, distance), QI_COLOR)
	streak.Transparency = 0.35
	streak.CFrame = CFrame.lookAt((from + to) / 2, to)
	streak.Parent = workspace
	TweenService:Create(streak, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.05, 3.5, distance) }):Play()
	Debris:AddItem(streak, 0.4)

	Sfx.play("Grab", to, 1.2)
	feedbackRemote:FireClient(player, "Left", 0.6, 0.1)
	feedbackRemote:FireClient(player, "Right", 0.6, 0.1)
	return true
end

---------------------------------------------------------------------------
-- Épée volante (御剑术) : une épée de Qi qui flotte à l'épaule du joueur et vole là où il la guide.
-- Le client envoie le point visé (main gauche ou regard) tant que le joueur maintient le bouton ;
-- le serveur fait voler l'épée, la fait trancher et consomme le Qi.
---------------------------------------------------------------------------

type FlyingSword = {
	model: Model,
	position: Vector3,
	velocity: Vector3,
	rotation: CFrame, -- orientation actuelle (l'axe Y du repère = la pointe)
	guided: boolean,
	target: Vector3?,
	hits: { [Humanoid]: number }, -- prochain instant où chaque cible peut être de nouveau touchée
}

local swords: { [Player]: FlyingSword } = {}
local swordsFolder: Folder
local SWORD_SETTINGS = Skills.ById.EpeeVolante.Active :: { [string]: number }
local SWORD_REST = CFrame.new(-2, 2.4, 1.2) -- place de l'épée au repos, derrière l'épaule gauche
local SWORD_HIT_INTERVAL = 0.4 -- délai avant qu'une même cible puisse être de nouveau touchée
local SWORD_TIP = 3.85 -- distance du centre du manche à la pointe (modèle de l'épée)

-- Copie spectrale de l'épée (jian) de Config, entourée de Qi.
local function buildFlyingSword(): Model
	local model = Instance.new("Model")
	model.Name = "EpeeVolante"
	local core = Instance.new("Part")
	core.Name = "Coeur"
	core.Size = Vector3.new(0.2, 0.2, 0.2)
	core.Transparency = 1
	model.PrimaryPart = core
	core.Parent = model

	for _, info in Config.Weapons.Epee.Parts do
		if not info.Hidden then
			local part: BasePart
			if info.Wedge then
				part = Instance.new("WedgePart")
			else
				local block = Instance.new("Part")
				if info.Shape then
					block.Shape = info.Shape
				end
				part = block
			end
			part.Name = info.Name
			part.Size = info.Size
			part.Color = info.Color
			part.Material = info.Material
			part.Reflectance = info.Reflectance or 0
			part.CFrame = CFrame.new(info.Offset) * (info.Rotation or CFrame.new())
			part.Parent = model
		end
	end
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
		end
	end

	-- Halo, étincelles le long de la lame et traînée de Qi derrière elle.
	local light = Instance.new("PointLight")
	light.Color = QI_COLOR
	light.Range = 9
	light.Brightness = 2
	light.Parent = core
	local base = Instance.new("Attachment")
	base.Position = Vector3.new(0, 0.8, 0)
	base.Parent = core
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, SWORD_TIP, 0)
	tip.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = 0.25
	trail.MinLength = 0.05
	trail.Color = ColorSequence.new(QI_COLOR)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Parent = core
	local middle = Instance.new("Attachment")
	middle.Position = Vector3.new(0, 2.2, 0)
	middle.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(QI_COLOR)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Rate = 18
	sparks.Speed = NumberRange.new(0.5, 1.5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = middle
	return model
end

local function dismissSword(player: Player)
	local sword = swords[player]
	if not sword then
		return
	end
	swords[player] = nil
	player:SetAttribute("EpeeVolante", nil)
	-- L'épée se dissout en lumière.
	for _, item in sword.model:GetDescendants() do
		if item:IsA("BasePart") and item.Transparency < 1 then
			item.Material = Enum.Material.Neon
			item.Color = QI_COLOR
			TweenService:Create(item, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(sword.model, 0.35)
end

local function summonSword(player: Player): boolean
	local root = rootOf(player)
	if not root or swords[player] then
		return false
	end
	local model = buildFlyingSword()
	local start = (root.CFrame * SWORD_REST).Position
	model:PivotTo(CFrame.new(start))
	model.Parent = swordsFolder
	swords[player] = {
		model = model,
		position = start,
		velocity = Vector3.zero,
		rotation = CFrame.new(),
		guided = false,
		target = nil,
		hits = {},
	}
	player:SetAttribute("EpeeVolante", true)
	Sfx.play("Grab", start, 1.2)
	return true
end

-- Fait voler toutes les épées d'une image : direction, vitesse, orientation, coups et Qi.
local function updateSwords(dt: number)
	local settings = SWORD_SETTINGS
	local now = os.clock()
	for player, sword in swords do
		local root = rootOf(player)
		local remaining = (qi[player] or 0) - (if sword.guided then settings.GuideDrain else settings.Drain) * dt
		if not root or remaining <= 0 then
			setQi(player, math.max(remaining, 0))
			dismissSword(player)
			continue
		end
		setQi(player, remaining)

		-- Point visé : la cible guidée (sans s'éloigner du joueur au-delà de la portée), sinon
		-- sa place au repos, qui ondule doucement.
		local aim: Vector3
		if sword.guided and sword.target then
			local offset = sword.target - root.Position
			if offset.Magnitude > settings.Range then
				offset = offset.Unit * settings.Range
			end
			aim = root.Position + offset
		else
			aim = (root.CFrame * SWORD_REST).Position + Vector3.new(0, math.sin(now * 2) * 0.25, 0)
		end

		-- Pilotage : elle file vers le point visé et ralentit en arrivant.
		local toAim = aim - sword.position
		local distance = toAim.Magnitude
		local maxSpeed = if sword.guided then settings.MaxSpeed else math.max(settings.MaxSpeed * 0.6, root.AssemblyLinearVelocity.Magnitude + 20)
		local desired = if distance > 0.01 then toAim.Unit * math.min(maxSpeed, distance * 6) else Vector3.zero
		sword.velocity += (desired - sword.velocity) * math.min(1, dt * 10)
		sword.position += sword.velocity * dt
		local speed = sword.velocity.Magnitude

		-- Orientation : la pointe en avant quand elle vole ; au repos, debout, tournant lentement.
		local goal: CFrame
		if speed > 4 then
			local direction = sword.velocity.Unit
			local right = direction:Cross(Vector3.yAxis)
			if right.Magnitude < 0.05 then
				right = Vector3.xAxis
			end
			goal = CFrame.fromMatrix(Vector3.zero, right.Unit, direction)
		elseif sword.guided then
			goal = sword.rotation
		else
			goal = CFrame.Angles(0, now * 1.5, 0)
		end
		sword.rotation = sword.rotation:Lerp(goal, math.min(1, dt * 12))
		local frame = CFrame.new(sword.position) * sword.rotation
		sword.model:PivotTo(frame)

		-- La lame blesse ce qu'elle traverse assez vite. Plus elle va vite, plus elle fait mal.
		if speed >= settings.MinSpeed then
			local damage = settings.Damage * math.clamp(speed / 40, 0.5, 1.5)
			local tip = frame * Vector3.new(0, SWORD_TIP - 0.4, 0)
			local middle = frame * Vector3.new(0, 2.1, 0)
			for _, point in { tip, middle } do
				for humanoid, model in targetsNear(point, settings.HitRadius) do
					if now >= (sword.hits[humanoid] or 0) then
						sword.hits[humanoid] = now + SWORD_HIT_INTERVAL
						strike(player, humanoid, model, damage)
						Sfx.play("Flesh", point, 1)
						feedbackRemote:FireClient(player, "Left", 0.5, 0.08)
					end
				end
			end
		end
	end
end

local function onSwordCommand(player: Player, action: any, target: any)
	local sword = swords[player]
	if action == "Guide" and sword and typeof(target) == "Vector3" and target == target then
		sword.guided = true
		sword.target = target
	elseif action == "Release" and sword then
		sword.guided = false
		sword.target = nil
	elseif action == "Dismiss" then
		dismissSword(player)
	end
end

local HANDLERS: { [string]: (Player, { [string]: number }, any) -> boolean } = {
	OndeDeQi = qiWave,
	Rugissement = function(player, settings)
		return lionRoar(player, settings)
	end,
	Ruee = lightningStep,
	EpeeVolante = function(player)
		return summonSword(player)
	end,
}

---------------------------------------------------------------------------
-- Déclenchement
---------------------------------------------------------------------------

-- `argument` : la main ("Left" / "Right") pour l'Onde de Qi, la direction du regard pour le Pas de l'éclair.
function Techniques.use(player: Player, skillId: any, argument: any)
	local skill = if typeof(skillId) == "string" then Skills.ById[skillId] else nil
	local handler = skill and HANDLERS[skill.Id]
	local settings = skill and skill.Active
	if not skill or not handler or not settings then
		return
	end
	if not Progression.hasSkill(player, skill.Id) or not rootOf(player) then
		return
	end
	local cooldowns = readyAt[player]
	if not cooldowns or os.clock() < (cooldowns[skill.Id] or 0) then
		return
	end
	local current = qi[player] or 0
	if current < settings.QiCost then
		return
	end

	-- Le Qi n'est dépensé que si la technique a vraiment pu partir.
	if handler(player, settings, argument) then
		setQi(player, current - settings.QiCost)
		cooldowns[skill.Id] = os.clock() + settings.Cooldown
		player:SetAttribute("Cooldown" .. skill.Id, workspace:GetServerTimeNow() + settings.Cooldown)
	end
end

function Techniques.init(weapons: Instance, feedback: RemoteEvent, useRemote: RemoteEvent)
	weaponsFolder = weapons
	feedbackRemote = feedback

	local function onPlayerAdded(player: Player)
		readyAt[player] = {}
		player:SetAttribute("QiMax", Skills.QI_MAX)
		setQi(player, Skills.QI_MAX)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dismissSword(player)
		qi[player] = nil
		readyAt[player] = nil
	end)

	useRemote.OnServerEvent:Connect(Techniques.use)

	-- Épée volante : dossier des épées, canal de guidage et vol à chaque image.
	swordsFolder = Instance.new("Folder")
	swordsFolder.Name = "EpeesVolantes"
	swordsFolder.Parent = workspace
	local swordRemote = Instance.new("RemoteEvent")
	swordRemote.Name = "EpeeVolante" -- client → serveur : "Guide" (point visé), "Release", "Dismiss"
	swordRemote.Parent = useRemote.Parent
	swordRemote.OnServerEvent:Connect(onSwordCommand)
	RunService.Heartbeat:Connect(updateSwords)

	-- Le Qi se régénère en continu (sauf pendant qu'une épée volante l'entretient).
	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			for player, value in qi do
				if value < Skills.QI_MAX and not swords[player] then
					setQi(player, value + Skills.QI_REGEN * dt)
				end
			end
		end
	end)
end

return Techniques

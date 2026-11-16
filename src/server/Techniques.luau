-- Techniques actives de la voie des Arts : le joueur les déclenche, elles consomment du Qi.
-- Le serveur vérifie que la technique est débloquée, que le Qi suffit et que le délai est écoulé,
-- puis en applique les effets. Les réglages de chaque technique sont dans Skills.luau (champ Active).

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Skills = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skills"))
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

local HANDLERS: { [string]: (Player, { [string]: number }, any) -> boolean } = {
	OndeDeQi = qiWave,
	Rugissement = function(player, settings)
		return lionRoar(player, settings)
	end,
	Ruee = lightningStep,
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
		qi[player] = nil
		readyAt[player] = nil
	end)

	useRemote.OnServerEvent:Connect(Techniques.use)

	-- Le Qi se régénère en continu.
	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			for player, value in qi do
				if value < Skills.QI_MAX then
					setQi(player, value + Skills.QI_REGEN * dt)
				end
			end
		end
	end)
end

return Techniques

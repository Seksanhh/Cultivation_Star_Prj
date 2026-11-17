-- Serveur : crée les mains VR de chaque joueur, gère la saisie des armes et valide les coups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))
local Enemies = require(script.Parent:WaitForChild("Enemies"))
local Collisions = require(script.Parent:WaitForChild("Collisions"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Progression = require(script.Parent:WaitForChild("Progression"))
local Techniques = require(script.Parent:WaitForChild("Techniques"))

Progression.init()

---------------------------------------------------------------------------
-- Objets partagés
---------------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"

local function makeRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local grabRemote = makeRemote("Grab")
local releaseRemote = makeRemote("Release")
local hitRemote = makeRemote("Hit")
local feedbackRemote = makeRemote("Feedback") -- serveur → client : vibration (main, intensité, durée) et, après un blocage, tremblement de l'écran (intensité)
local unlockSkillRemote = makeRemote("UnlockSkill") -- client → serveur : débloquer une technique de cultivation
local useTechniqueRemote = makeRemote("UseTechnique") -- client → serveur : déclencher une technique active
remotes.Parent = ReplicatedStorage

local handsFolder = Instance.new("Folder")
handsFolder.Name = "VRHands"
handsFolder.Parent = workspace

local weaponsFolder = Instance.new("Folder")
weaponsFolder.Name = "Weapons"
weaponsFolder.Parent = workspace

---------------------------------------------------------------------------
-- Arène et armes
---------------------------------------------------------------------------

local weaponHomes: { [Model]: CFrame } = {}

do
	local homes = Arena.build(#Config.RACK)
	for i, typeName in Config.RACK do
		local weapon = Weapons.create(typeName, homes[i], weaponsFolder)
		weaponHomes[weapon] = homes[i]
	end
	Enemies.init(weaponsFolder, feedbackRemote)
	Techniques.init(weaponsFolder, feedbackRemote, useTechniqueRemote)

	-- Arbre de cultivation : il s'ouvre en interface (touche K, voir src/client/Skills.client.luau).
	-- L'effet de déblocage apparaît au-dessus de la tête du joueur.
	unlockSkillRemote.OnServerEvent:Connect(function(player, skillId: any)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		Progression.unlock(player, skillId, if head and head:IsA("BasePart") then head.Position + Vector3.new(0, 1.5, 0) else nil)
	end)
end

---------------------------------------------------------------------------
-- État des joueurs
---------------------------------------------------------------------------

type HeldState = { Left: Model?, Right: Model? }

local held: { [Player]: HeldState } = {}
local handModels: { [Player]: Model } = {}
local lastHits: { [Model]: { [Humanoid]: number } } = {}

local function getHand(player: Player, side: string): BasePart?
	local model = handModels[player]
	local hand = model and model:FindFirstChild(side)
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

local function release(player: Player, side: string)
	local state = held[player] :: any
	local weapon: Model? = state and state[side]
	if not state or not weapon then
		return
	end
	state[side] = nil

	local handle = weapon.PrimaryPart
	if handle then
		local weld = handle:FindFirstChild("GripWeld")
		if weld then
			weld:Destroy()
		end
	end
	Weapons.setHeld(weapon, false)
	weapon:SetAttribute("Holder", nil)
	weapon:SetAttribute("HolderHand", nil)
	weapon:SetAttribute("DroppedAt", os.clock())

	-- Le joueur garde la main sur la physique de l'arme pour que le lancer reste fluide.
	if handle and not handle.Anchored and handle:IsDescendantOf(workspace) and player.Parent then
		pcall(function()
			handle:SetNetworkOwner(player)
		end)
	end
end

local function releaseAll(player: Player)
	release(player, "Left")
	release(player, "Right")
end

local function destroyHands(player: Player)
	releaseAll(player)
	local model = handModels[player]
	if model then
		handModels[player] = nil
		model:Destroy()
	end
end

---------------------------------------------------------------------------
-- Mains VR
---------------------------------------------------------------------------

-- Chaque main est une pièce physique que le client du joueur pilote
-- en changeant la cible de ses contraintes Align*.
local function createHand(side: string, start: CFrame, parent: Model): Part
	local hand = Instance.new("Part")
	hand.Name = side
	hand.Size = Vector3.new(0.35, 0.3, 0.7)
	hand.Color = Color3.fromRGB(225, 200, 170)
	hand.Material = Enum.Material.SmoothPlastic
	hand.TopSurface = Enum.SurfaceType.Smooth
	hand.BottomSurface = Enum.SurfaceType.Smooth
	hand.CanCollide = false
	hand.CanQuery = false
	hand.CanTouch = false
	hand.CFrame = start

	local attachment = Instance.new("Attachment")
	attachment.Name = "Center"
	attachment.Parent = hand

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "AlignPosition"
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	-- Force limitée plutôt que rigide : une arme tenue s'arrête contre un mur au lieu de le traverser.
	alignPosition.RigidityEnabled = false
	alignPosition.MaxForce = 12000
	alignPosition.Responsiveness = 200
	alignPosition.Position = start.Position
	alignPosition.Parent = hand

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "AlignOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.RigidityEnabled = false
	alignOrientation.MaxTorque = 30000
	alignOrientation.Responsiveness = 200
	alignOrientation.CFrame = start.Rotation
	alignOrientation.Parent = hand

	hand.Parent = parent
	return hand
end

local function onCharacterAdded(player: Player, character: Model)
	destroyHands(player)

	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not root:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	if player.Character ~= character then
		return
	end
	-- Les armes tenues traversent les corps au lieu de les bousculer.
	Collisions.watch(character, Collisions.BODIES)

	local model = Instance.new("Model")
	model.Name = tostring(player.UserId)
	local left = createHand("Left", root.CFrame * CFrame.new(-1.2, 0, -1.2), model)
	local right = createHand("Right", root.CFrame * CFrame.new(1.2, 0, -1.2), model)
	model.Parent = handsFolder
	left:SetNetworkOwner(player)
	right:SetNetworkOwner(player)
	handModels[player] = model

	-- Les bras de l'avatar suivent les mains VR (cinématique inverse, avatars R15 seulement).
	-- Créés sur le serveur, ces contrôles sont vus par tous les joueurs.
	if Config.AVATAR_ARMS_FOLLOW_HANDS and humanoid.RigType == Enum.HumanoidRigType.R15 then
		for side, hand in { Left = left, Right = right } do
			local upperArm = character:WaitForChild(side .. "UpperArm", 5)
			local avatarHand = character:WaitForChild(side .. "Hand", 5)
			if upperArm and avatarHand and upperArm:IsA("BasePart") and avatarHand:IsA("BasePart") then
				local control = Instance.new("IKControl")
				control.Name = "VRArm" .. side
				control.Type = Enum.IKControlType.Transform
				control.ChainRoot = upperArm
				control.EndEffector = avatarHand
				control.Target = hand
				-- Les doigts de l'avatar (son axe -Y) pointent dans l'axe de la manette (-Z).
				control.Offset = CFrame.Angles(math.rad(90), 0, 0)
				control.SmoothTime = 0
				control.Parent = humanoid
				hand.Transparency = 1 -- la main de l'avatar remplace le bloc
			end
		end
	end

	humanoid.Died:Connect(function()
		if handModels[player] == model then
			destroyHands(player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	held[player] = {}
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	destroyHands(player)
	held[player] = nil
end)

---------------------------------------------------------------------------
-- Saisir / lâcher
---------------------------------------------------------------------------

local function isSide(value: any): boolean
	return value == "Left" or value == "Right"
end

local function isWeapon(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Model") and value.Parent == weaponsFolder
end

grabRemote.OnServerEvent:Connect(function(player, weapon: any, side: any)
	if not isSide(side) or not isWeapon(weapon) then
		return
	end
	local state = held[player] :: any
	if not state or state[side] or weapon:GetAttribute("Holder") then
		return
	end
	local hand = getHand(player, side)
	local handle: BasePart? = weapon.PrimaryPart
	local def = Config.Weapons[weapon:GetAttribute("WeaponType")]
	if not hand or not handle or not def then
		return
	end
	-- Marge généreuse : la position de la main vue par le serveur a un peu de retard.
	if (handle.Position - hand.Position).Magnitude > Config.GRAB_RADIUS + def.HandleLength / 2 + 4 then
		return
	end

	Weapons.setHeld(weapon, true)
	handle.Anchored = false
	handle.AssemblyLinearVelocity = Vector3.zero
	handle.AssemblyAngularVelocity = Vector3.zero
	weapon:PivotTo(hand.CFrame * Config.getGripCFrame(def))

	local weld = Instance.new("WeldConstraint")
	weld.Name = "GripWeld"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.Parent = handle

	state[side] = weapon
	weapon:SetAttribute("Holder", player.UserId)
	weapon:SetAttribute("HolderHand", side)
	hand:SetNetworkOwner(player)
	Sfx.play("Grab", handle, 1)

	-- Les bandits arrivent dès qu'un joueur a pris une arme.
	Enemies.start()
end)

releaseRemote.OnServerEvent:Connect(function(player, side: any)
	if isSide(side) then
		release(player, side)
	end
end)

---------------------------------------------------------------------------
-- Coups
---------------------------------------------------------------------------

local function findHumanoid(part: Instance): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function showDamage(part: BasePart, amount: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamagePopup"
	gui.Size = UDim2.fromScale(3, 1.5)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = tostring(math.round(amount))
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	gui.Parent = part
	Debris:AddItem(gui, 0.7)

	local target = part:FindFirstAncestorOfClass("Model")
	if target then
		local flash = Instance.new("Highlight")
		flash.Name = "HitFlash"
		flash.FillColor = Color3.fromRGB(255, 60, 60)
		flash.FillTransparency = 0.4
		flash.OutlineTransparency = 1
		flash.Parent = target
		Debris:AddItem(flash, 0.12)
	end
end

hitRemote.OnServerEvent:Connect(function(player, weapon: any, targetPart: any, speed: any)
	if not isWeapon(weapon) or weapon:GetAttribute("Holder") ~= player.UserId then
		return
	end
	if typeof(targetPart) ~= "Instance" or not targetPart:IsA("BasePart") or not targetPart:IsDescendantOf(workspace) then
		return
	end
	if typeof(speed) ~= "number" or speed ~= speed then
		return
	end
	local def = Config.Weapons[weapon:GetAttribute("WeaponType")]
	local hand = getHand(player, weapon:GetAttribute("HolderHand"))
	local humanoid = findHumanoid(targetPart)
	if not def or not hand or not humanoid or humanoid.Health <= 0 then
		return
	end

	local targetModel = humanoid.Parent
	if targetModel == player.Character then
		return
	end
	if not Config.PVP_ENABLED and targetModel and Players:GetPlayerFromCharacter(targetModel :: Model) then
		return
	end
	-- La cible doit être à portée d'arme de la main du joueur.
	if (targetPart.Position - hand.Position).Magnitude > 14 then
		return
	end
	if speed < def.MinSpeed then
		return
	end

	local now = os.clock()
	local perWeapon = lastHits[weapon]
	if not perWeapon then
		perWeapon = setmetatable({}, { __mode = "k" }) :: any
		lastHits[weapon] = perWeapon
	end
	local last = perWeapon[humanoid]
	if last and now - last < Config.HIT_COOLDOWN then
		return
	end
	perWeapon[humanoid] = now

	local scale = math.clamp(speed / Config.REFERENCE_SPEED, Config.MIN_DAMAGE_SCALE, Config.MAX_DAMAGE_SCALE)
	-- Le niveau du joueur augmente ses dégâts.
	local damage = def.Damage * scale * Progression.damageMultiplier(player)
	-- Riposte : un bandit sonné par une parade parfaite encaisse davantage.
	if targetModel and targetModel:GetAttribute("Vulnerable") then
		damage *= Config.RIPOSTE_MULTIPLIER + Progression.effect(player, "Riposte") -- Riposte du dragon
	end
	if targetModel then
		Progression.tag(targetModel, player)
	end
	humanoid:TakeDamage(damage)
	showDamage(targetPart, damage)
	Sfx.play("Flesh", targetPart, scale)
end)

---------------------------------------------------------------------------
-- Retour des armes abandonnées sur le râtelier
---------------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(3)
		for weapon, home in weaponHomes do
			local handle = weapon.PrimaryPart
			if handle and not weapon:GetAttribute("Holder") and not handle.Anchored then
				local droppedAt = weapon:GetAttribute("DroppedAt") or 0
				local fell = handle.Position.Y < -30
				if fell or os.clock() - droppedAt > Config.WEAPON_RETURN_TIME then
					handle.AssemblyLinearVelocity = Vector3.zero
					handle.AssemblyAngularVelocity = Vector3.zero
					handle.Anchored = true
					weapon:PivotTo(home)
					Weapons.setHeld(weapon, false)
				end
			end
		end
	end
end)

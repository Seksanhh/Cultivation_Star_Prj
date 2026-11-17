-- Serveur : crée les mains VR de chaque joueur, gère la saisie des armes et valide les coups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))
local Enemies = require(script.Parent:WaitForChild("Enemies"))
local Collisions = require(script.Parent:WaitForChild("Collisions"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Progression = require(script.Parent:WaitForChild("Progression"))
local Techniques = require(script.Parent:WaitForChild("Techniques"))
local Scabbard = require(script.Parent:WaitForChild("Scabbard"))
local Vfx = require(script.Parent:WaitForChild("Vfx"))
local Combos = require(script.Parent:WaitForChild("Combos"))
local Tribulation = require(script.Parent:WaitForChild("Tribulation"))

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
local punchRemote = makeRemote("Punch") -- client → serveur : coup à mains nues (main, pièce touchée, vitesse)
local qinggongRemote = makeRemote("Qinggong") -- client → serveur : mouvement de qinggong (type, Qi dépensé)
local comboRemote = makeRemote("Combo") -- client → serveur : combo de calligraphie reconnu (id, main)
local recallRemote = makeRemote("Recall") -- client → serveur : rappeler la dernière arme lancée dans une main
local sheatheRemote = makeRemote("Sheathe") -- client → serveur : dégainer / rengainer avec la main droite (clavier)
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
	Combos.init(weaponsFolder, feedbackRemote, comboRemote)
	Tribulation.init(weaponsFolder)

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
-- Arme personnelle de chaque joueur, rangée dans son fourreau à son apparition (Config.SCABBARD.START_WEAPON).
local personalWeapons: { [Player]: Model } = {}

local function getHand(player: Player, side: string): BasePart?
	local model = handModels[player]
	local hand = model and model:FindFirstChild(side)
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

-- Armes lancées en vol (Config.THROW) : le serveur simule leur vol et cherche ce qu'elles touchent.
type Flight = { thrower: Player, startedAt: number }
local flying: { [Model]: Flight } = {}
-- Dernière arme lancée par chaque joueur, que le rappel peut ramener.
local lastThrown: { [Player]: Model } = setmetatable({}, { __mode = "v" }) :: any

-- Lance l'arme (déjà détachée de la main) à la vitesse `velocity`.
local function launch(player: Player, weapon: Model, velocity: Vector3)
	local handle = weapon.PrimaryPart
	if not handle then
		return
	end
	-- En vol, l'arme traverse les corps comme une arme tenue : c'est la recherche de cibles
	-- qui décide du coup, et elle ne heurte pas son lanceur.
	Weapons.setHeld(weapon, true)
	pcall(function()
		handle:SetNetworkOwner(nil) -- le serveur simule le vol, pour que coup et rappel restent justes
	end)
	local speed = math.min(velocity.Magnitude * Config.THROW.BOOST, Config.THROW.MAX_SPEED)
	handle.AssemblyLinearVelocity = velocity.Unit * speed
	flying[weapon] = { thrower = player, startedAt = os.clock() }
	lastThrown[player] = weapon
end

-- Fin du vol : l'arme redevient une arme lâchée ordinaire, qui heurte et retombe.
local function land(weapon: Model)
	flying[weapon] = nil
	if not weapon:GetAttribute("Holder") then
		Weapons.setHeld(weapon, false)
	end
end

-- Lâche l'arme de cette main. Avec `allowSheathe`, une arme à lame lâchée près de l'entrée
-- du fourreau vide du joueur y est rangée au lieu de tomber. `throwVelocity` : vitesse de la
-- main au lâcher, mesurée par le client ; assez rapide, c'est un lancer.
local function release(player: Player, side: string, allowSheathe: boolean?, throwVelocity: Vector3?)
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

	if allowSheathe and handle and Scabbard.isSheathable(weapon) and Scabbard.isEmpty(player) then
		local mouth = Scabbard.mouthPosition(player)
		-- Le haut du manche (la garde) doit être près de l'entrée du fourreau.
		local guard = handle.CFrame * Vector3.new(0, handle.Size.Y / 2, 0)
		if mouth and (guard - mouth).Magnitude <= Config.SCABBARD.SHEATHE_RADIUS and Scabbard.sheathe(player, weapon) then
			Sfx.play("Sheathe", handle, 1)
			feedbackRemote:FireClient(player, side, 0.5, 0.1)
			return
		end
	end

	Weapons.setHeld(weapon, false)
	weapon:SetAttribute("Holder", nil)
	weapon:SetAttribute("HolderHand", nil)
	weapon:SetAttribute("DroppedAt", os.clock())

	if handle and not handle.Anchored and handle:IsDescendantOf(workspace) and player.Parent then
		if Config.THROW.ENABLED and throwVelocity and throwVelocity.Magnitude >= Config.THROW.MIN_SPEED then
			launch(player, weapon, throwVelocity)
			return
		end
		-- Le joueur garde la main sur la physique de l'arme pour que sa chute reste fluide.
		pcall(function()
			handle:SetNetworkOwner(player)
		end)
	end
end

local function releaseAll(player: Player)
	release(player, "Left")
	release(player, "Right")
end

-- Remet une arme à sa place : au râtelier pour une arme du râtelier ; une arme personnelle disparaît.
-- Définie plus bas, avec le retour automatique des armes abandonnées.
local returnWeapon: (weapon: Model) -> ()

local function destroyHands(player: Player)
	releaseAll(player)
	local model = handModels[player]
	if model then
		handModels[player] = nil
		model:Destroy()
	end
	-- Le fourreau disparaît avec le corps : l'arme qui y était rangée retourne à sa place.
	local sheathed = Scabbard.unequip(player)
	if sheathed then
		returnWeapon(sheathed)
	end
	local personal = personalWeapons[player]
	if personal then
		personalWeapons[player] = nil
		if personal.Parent and personal:GetAttribute("Holder") then
			-- Tenue par un autre joueur : elle devient une arme sans propriétaire.
			personal:SetAttribute("Owner", nil)
		elseif personal.Parent then
			personal:Destroy()
		end
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

	-- Fourreau à la hanche, avec l'arme de départ rangée dedans.
	if Config.SCABBARD.ENABLED then
		Scabbard.equip(player, root)
		local startType = Config.SCABBARD.START_WEAPON
		if startType and Config.Weapons[startType] then
			local personal = Weapons.create(startType, root.CFrame, weaponsFolder)
			personal:SetAttribute("Owner", player.UserId)
			personalWeapons[player] = personal
			Scabbard.sheathe(player, personal)
		end
	end

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

---------------------------------------------------------------------------
-- Frappe de dégainé (Config.IAI)
---------------------------------------------------------------------------

local function setTrailColor(weapon: Model, color: Color3)
	for _, item in weapon:GetDescendants() do
		if item:IsA("Trail") then
			item.Color = ColorSequence.new(color)
		end
	end
end

-- Lame de Qi dorée qui prolonge la pointe pendant la fenêtre : elle montre la portée en plus.
local iaiBlades: { [Model]: BasePart } = {}

local function removeIaiBlade(weapon: Model)
	local blade = iaiBlades[weapon]
	if blade then
		iaiBlades[weapon] = nil
		blade:Destroy()
	end
end

local function addIaiBlade(weapon: Model)
	removeIaiBlade(weapon)
	local longest: BasePart? = nil
	for _, part in weapon:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("IsBlade") and (not longest or part.Size.Y > longest.Size.Y) then
			longest = part
		end
	end
	if not longest then
		return
	end
	local bonus = Config.IAI.REACH_BONUS
	local glow = Instance.new("Part")
	glow.Name = "LameDeQiIai"
	glow.Size = Vector3.new(0.08, bonus, 0.22)
	glow.CFrame = longest.CFrame * CFrame.new(0, longest.Size.Y / 2 + bonus / 2, 0)
	-- Or doux, sans néon : la lame de Qi se devine sans éblouir.
	glow.Color = Color3.fromRGB(235, 200, 120)
	glow.Material = Enum.Material.SmoothPlastic
	glow.Reflectance = 0.15
	glow.Transparency = 0.55
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.Massless = true
	glow.CastShadow = false
	glow:SetAttribute("Decor", true) -- ornement : ne heurte jamais rien, même si l'arme change d'état
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = longest
	weld.Part1 = glow
	weld.Parent = glow
	glow.Parent = weapon
	iaiBlades[weapon] = glow
end

-- L'arme vient de sortir du fourreau : la fenêtre du coup de dégainé s'ouvre, traînée dorée
-- et lame de Qi qui allonge la portée.
local function startIaiWindow(weapon: Model)
	if not Config.IAI.ENABLED then
		return
	end
	local drawnAt = os.clock()
	weapon:SetAttribute("DrawnAt", drawnAt)
	setTrailColor(weapon, Config.IAI.TRAIL_COLOR)
	addIaiBlade(weapon)
	task.delay(Config.IAI.WINDOW, function()
		if weapon:GetAttribute("DrawnAt") == drawnAt then
			weapon:SetAttribute("DrawnAt", nil)
			removeIaiBlade(weapon)
		end
		setTrailColor(weapon, Config.TRAIL_COLOR)
	end)
end

-- Le coup porté est-il une frappe de dégainé ? La fenêtre ne sert qu'une fois.
local function consumeIai(weapon: Model, speed: number): boolean
	local drawnAt = weapon:GetAttribute("DrawnAt")
	if not drawnAt or os.clock() - drawnAt > Config.IAI.WINDOW or speed < Config.IAI.MIN_SPEED then
		return false
	end
	weapon:SetAttribute("DrawnAt", nil)
	setTrailColor(weapon, Config.TRAIL_COLOR)
	removeIaiBlade(weapon)
	return true
end

-- Effet de la frappe de dégainé : une fente dorée nette, un reflet et un éclair.
local function iaiVfx(position: Vector3)
	local gold = Color3.fromRGB(255, 215, 120)
	local anchor = Vfx.anchor("Iai", position, nil, 1)
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.Streak,
		Count = 2,
		Color = ColorSequence.new(Color3.new(1, 1, 1), gold),
		Size = Vfx.grow(9, 4),
		Transparency = Vfx.fadeAfter(0.4),
		Lifetime = NumberRange.new(0.3),
		Rotation = NumberRange.new(-35, 35),
		ZOffset = 1,
	})
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.Glint,
		Count = 1,
		Color = ColorSequence.new(gold),
		Size = Vfx.grow(6, 0),
		Transparency = Vfx.fadeAfter(0.3),
		Lifetime = NumberRange.new(0.35),
		ZOffset = 1.5,
	})
	Vfx.flashLight(anchor, gold, 16, 5, 0.3)
end

-- Met l'arme dans la main `side`. Avec `checkDistance`, la main doit être près du manche.
-- Une arme au fourreau ne peut être saisie que par son propriétaire : elle est alors dégainée.
local function grab(player: Player, weapon: Model, side: string, checkDistance: boolean): boolean
	local state = held[player] :: any
	if not state or state[side] or weapon:GetAttribute("Holder") then
		return false
	end
	local sheathedBy = weapon:GetAttribute("SheathedBy")
	if sheathedBy and sheathedBy ~= player.UserId then
		return false
	end
	local hand = getHand(player, side)
	local handle: BasePart? = weapon.PrimaryPart
	local def = Config.Weapons[weapon:GetAttribute("WeaponType")]
	if not hand or not handle or not def then
		return false
	end
	-- Marge généreuse : la position de la main vue par le serveur a un peu de retard.
	if checkDistance and (handle.Position - hand.Position).Magnitude > Config.GRAB_RADIUS + def.HandleLength / 2 + 4 then
		return false
	end
	if sheathedBy then
		Scabbard.unsheathe(player, weapon)
		startIaiWindow(weapon)
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
	return true
end

grabRemote.OnServerEvent:Connect(function(player, weapon: any, side: any)
	if isSide(side) and isWeapon(weapon) then
		grab(player, weapon, side, true)
	end
end)

releaseRemote.OnServerEvent:Connect(function(player, side: any, velocity: any)
	if isSide(side) then
		local throwVelocity = if typeof(velocity) == "Vector3" and velocity.Magnitude == velocity.Magnitude then velocity else nil
		release(player, side, true, throwVelocity)
	end
end)

-- Rappel (Config.RECALL) : la dernière arme lancée revient voler dans la main vide, contre du Qi.
local recalling: { [Model]: boolean } = {}

recallRemote.OnServerEvent:Connect(function(player, side: any)
	local settings = Config.RECALL
	local state = held[player] :: any
	local weapon = lastThrown[player]
	local hand = isSide(side) and getHand(player, side)
	if not settings.ENABLED or not state or state[side] or not weapon or not hand or recalling[weapon] then
		return
	end
	local handle = weapon.PrimaryPart
	if not handle or weapon.Parent ~= weaponsFolder or weapon:GetAttribute("Holder") or weapon:GetAttribute("SheathedBy") then
		return
	end
	-- Une arme déjà revenue au râtelier n'est plus « la sienne ».
	if handle.Anchored or (handle.Position - hand.Position).Magnitude > settings.RANGE then
		return
	end
	if not Techniques.spendQi(player, settings.QI_COST) then
		return
	end

	recalling[weapon] = true
	flying[weapon] = nil
	Weapons.setHeld(weapon, true) -- traverse les corps sur le chemin du retour
	pcall(function()
		handle:SetNetworkOwner(nil)
	end)
	handle.Anchored = true
	local def = Config.Weapons[weapon:GetAttribute("WeaponType")]
	local start = handle.CFrame
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local t = math.min(elapsed / settings.RETURN_TIME, 1)
		local eased = 1 - (1 - t) ^ 2
		local goal = hand.CFrame * (if def then Config.getGripCFrame(def) else CFrame.new())
		-- Vol en arc, l'arme tournoie sur elle-même jusqu'à se présenter dans le bon sens.
		local arc = Vector3.new(0, math.sin(math.pi * t) * 2, 0)
		local spin = CFrame.Angles(0, 0, (1 - eased) * math.pi * 4)
		local position = start.Position:Lerp(goal.Position, eased) + arc
		weapon:PivotTo(CFrame.new(position) * start.Rotation:Lerp(goal.Rotation, eased) * spin)
		if t >= 1 or not weapon.Parent or not hand.Parent then
			connection:Disconnect()
			recalling[weapon] = nil
			if weapon.Parent and hand.Parent and player.Parent then
				handle.Anchored = false
				if grab(player, weapon, side, false) then
					feedbackRemote:FireClient(player, side, 0.7, 0.12)
					return
				end
			end
			if handle.Parent then
				handle.Anchored = false
				Weapons.setHeld(weapon, false)
			end
		end
	end)
	Sfx.play("Grab", handle, 0.8)
end)

-- Clavier : la main droite rengaine son arme si elle entre au fourreau, sinon elle dégaine l'arme rangée.
sheatheRemote.OnServerEvent:Connect(function(player)
	local state = held[player] :: any
	if not state or not Config.SCABBARD.ENABLED then
		return
	end
	local inHand: Model? = state.Right
	if inHand then
		if Scabbard.isSheathable(inHand) and Scabbard.isEmpty(player) then
			local handle = inHand.PrimaryPart
			local weld = handle and handle:FindFirstChild("GripWeld")
			if weld then
				weld:Destroy()
			end
			state.Right = nil
			if Scabbard.sheathe(player, inHand) then
				if handle then
					Sfx.play("Sheathe", handle, 1)
				end
			else
				-- Impossible de la ranger : l'arme revient dans la main.
				grab(player, inHand, "Right", false)
			end
		end
		return
	end
	local sheathed = Scabbard.weaponOf(player)
	if sheathed then
		grab(player, sheathed, "Right", false)
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

-- `caption` : texte ajouté sous le nombre (« 居合 », nom d'un combo…), en `color`.
local function showDamage(part: BasePart, amount: number, caption: string?, color: Color3?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamagePopup"
	gui.Size = if caption then UDim2.fromScale(5, 2.4) else UDim2.fromScale(3, 1.5)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = tostring(math.round(amount)) .. (if caption then "\n" .. caption else "")
	label.TextColor3 = color or Color3.fromRGB(255, 220, 80)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	gui.Parent = part
	Debris:AddItem(gui, if caption then 1.2 else 0.7)

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

	-- Un maître d'armes pare les coups qui arrivent du côté de sa garde.
	if targetModel then
		local tip = targetPart.Position
		for _, part in weapon:GetChildren() do
			if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
				tip = part.CFrame * Vector3.new(0, part.Size.Y / 2, 0)
				break
			end
		end
		if Enemies.tryParry(targetModel :: Model, player, tip, weapon:GetAttribute("HolderHand")) then
			return
		end
	end

	local scale = math.clamp(speed / Config.REFERENCE_SPEED, Config.MIN_DAMAGE_SCALE, Config.MAX_DAMAGE_SCALE)
	-- Le niveau du joueur augmente ses dégâts.
	local damage = def.Damage * scale * Progression.damageMultiplier(player)
	-- Riposte : un bandit sonné par une parade parfaite encaisse davantage.
	if targetModel and targetModel:GetAttribute("Vulnerable") then
		damage *= Config.RIPOSTE_MULTIPLIER + Progression.effect(player, "Riposte") -- Riposte du dragon
	end
	-- Frappe de dégainé : le premier coup, dans la foulée du dégainé, est critique.
	local iai = consumeIai(weapon, speed)
	if iai then
		damage *= Config.IAI.MULTIPLIER
	end
	if targetModel then
		Progression.tag(targetModel, player)
	end
	humanoid:TakeDamage(damage)
	if iai then
		showDamage(targetPart, damage, "居合 Iai", Color3.fromRGB(255, 235, 150))
		iaiVfx(targetPart.Position)
		Sfx.play("Iai", targetPart, 1)
	else
		showDamage(targetPart, damage)
	end
	Sfx.play("Flesh", targetPart, scale)
end)

-- Coups à mains nues (Config.FIST) : une main vide frappe comme une petite arme.
local lastPunches: { [Player]: { [string]: { [Humanoid]: number } } } = setmetatable({}, { __mode = "k" }) :: any

punchRemote.OnServerEvent:Connect(function(player, side: any, targetPart: any, speed: any)
	local fist = Config.FIST
	if not fist.ENABLED or not isSide(side) then
		return
	end
	if typeof(targetPart) ~= "Instance" or not targetPart:IsA("BasePart") or not targetPart:IsDescendantOf(workspace) then
		return
	end
	if typeof(speed) ~= "number" or speed ~= speed or speed < fist.MIN_SPEED then
		return
	end
	-- La main doit être vide : une main qui tient une arme frappe avec l'arme.
	local state = held[player] :: any
	if not state or state[side] then
		return
	end
	local hand = getHand(player, side)
	local humanoid = findHumanoid(targetPart)
	if not hand or not humanoid or humanoid.Health <= 0 then
		return
	end
	local targetModel = humanoid.Parent
	if targetModel == player.Character then
		return
	end
	if not Config.PVP_ENABLED and targetModel and Players:GetPlayerFromCharacter(targetModel :: Model) then
		return
	end
	if (targetPart.Position - hand.Position).Magnitude > fist.REACH then
		return
	end

	local now = os.clock()
	local perPlayer = lastPunches[player]
	if not perPlayer then
		perPlayer = {}
		lastPunches[player] = perPlayer
	end
	local perHand = perPlayer[side]
	if not perHand then
		perHand = setmetatable({}, { __mode = "k" }) :: any
		perPlayer[side] = perHand
	end
	local last = perHand[humanoid]
	if last and now - last < Config.HIT_COOLDOWN then
		return
	end
	perHand[humanoid] = now

	local scale = math.clamp(speed / Config.REFERENCE_SPEED, Config.MIN_DAMAGE_SCALE, Config.MAX_DAMAGE_SCALE)
	local damage = fist.DAMAGE * scale * Progression.damageMultiplier(player)
	if targetModel and targetModel:GetAttribute("Vulnerable") then
		damage *= Config.RIPOSTE_MULTIPLIER + Progression.effect(player, "Riposte") -- Riposte du dragon
	end
	if targetModel then
		Progression.tag(targetModel, player)
	end
	humanoid:TakeDamage(damage)
	showDamage(targetPart, damage)
	Sfx.play("Punch", targetPart, scale)

	-- Comme prendre une arme, un premier coup de poing lance les vagues de bandits.
	Enemies.start()
end)

-- Qinggong (Config.QINGGONG) : le client applique le mouvement, le serveur dépense le Qi et montre
-- un anneau de Qi sous les pieds, vu par tous, au double saut et au saut depuis un mur.
qinggongRemote.OnServerEvent:Connect(function(player, kind: any, amount: any)
	local settings = Config.QINGGONG
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not settings.ENABLED or typeof(amount) ~= "number" or amount ~= amount or not root or not root:IsA("BasePart") then
		return
	end
	if kind == "DoubleJump" then
		Techniques.addQi(player, -settings.DOUBLE_JUMP_QI)
	elseif kind == "WallRun" then
		Techniques.addQi(player, -math.clamp(amount, 0, settings.WALL_RUN_QI_PER_SECOND * 0.6))
		return
	elseif kind == "Glide" then
		Techniques.addQi(player, -math.clamp(amount, 0, settings.GLIDE_QI_PER_SECOND * 0.6))
		return
	elseif kind ~= "WallKick" then
		return
	end
	local anchor = Vfx.anchor("Qinggong", root.Position - Vector3.new(0, 2.5, 0), Vector3.yAxis, 1)
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.Ring,
		Count = 1,
		Color = ColorSequence.new(Color3.fromRGB(170, 230, 255)),
		Size = Vfx.grow(1, 6),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(0.35),
		Speed = NumberRange.new(0.5),
		Direction = Enum.NormalId.Front,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
	})
	Sfx.play("Dash", root, 0.6)
end)

-- Vol des armes lancées : la première cible traversée par une lame est touchée, puis l'arme
-- perd son élan et retombe. Après FLIGHT_TIME, ou trop lente, elle redevient une arme lâchée.
local flightParams = OverlapParams.new()
flightParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.Heartbeat:Connect(function()
	for weapon, flight in flying do
		local handle = weapon.PrimaryPart
		if not handle or not weapon.Parent or weapon:GetAttribute("Holder") then
			flying[weapon] = nil
			continue
		end
		local speed = handle.AssemblyLinearVelocity.Magnitude
		if os.clock() - flight.startedAt > Config.THROW.FLIGHT_TIME or speed < 5 then
			land(weapon)
			continue
		end
		local def = Config.Weapons[weapon:GetAttribute("WeaponType")]
		local thrower = flight.thrower
		local ignored: { Instance } = { weaponsFolder, handsFolder, Vfx.folder }
		if thrower.Character then
			table.insert(ignored, thrower.Character)
		end
		flightParams.FilterDescendantsInstances = ignored
		for _, blade in weapon:GetChildren() do
			if not (blade:IsA("BasePart") and blade:GetAttribute("IsBlade")) then
				continue
			end
			for _, hit in workspace:GetPartsInPart(blade, flightParams) do
				local humanoid = findHumanoid(hit)
				local targetModel = humanoid and humanoid.Parent
				if not humanoid or humanoid.Health <= 0 or not targetModel then
					continue
				end
				if not Config.PVP_ENABLED and Players:GetPlayerFromCharacter(targetModel :: Model) then
					continue
				end
				-- Le maître d'armes dévie aussi une arme lancée du côté de sa garde.
				if Enemies.tryParry(targetModel :: Model, thrower, blade.Position, nil) then
					handle.AssemblyLinearVelocity = -handle.AssemblyLinearVelocity * 0.2 + Vector3.new(0, 15, 0)
					land(weapon)
					break
				end
				local scale = math.clamp(speed / Config.REFERENCE_SPEED, Config.MIN_DAMAGE_SCALE, Config.MAX_DAMAGE_SCALE)
				local damage = (if def then def.Damage else 10) * Config.THROW.DAMAGE_SCALE * scale * Progression.damageMultiplier(thrower)
				if targetModel:GetAttribute("Vulnerable") then
					damage *= Config.RIPOSTE_MULTIPLIER + Progression.effect(thrower, "Riposte")
				end
				Progression.tag(targetModel, thrower)
				humanoid:TakeDamage(damage)
				showDamage(hit, damage, "投 Lancer", Color3.fromRGB(190, 230, 255))
				Sfx.play("Flesh", hit, scale)
				-- L'arme s'arrête dans la cible et tombe à ses pieds.
				handle.AssemblyLinearVelocity *= 0.1
				handle.AssemblyAngularVelocity = Vector3.zero
				land(weapon)
				Enemies.start()
				break
			end
			if not flying[weapon] then
				break
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Retour des armes abandonnées sur le râtelier
---------------------------------------------------------------------------

returnWeapon = function(weapon: Model)
	local home = weaponHomes[weapon]
	local handle = weapon.PrimaryPart
	if not home or not handle then
		weapon:Destroy()
		return
	end
	handle.AssemblyLinearVelocity = Vector3.zero
	handle.AssemblyAngularVelocity = Vector3.zero
	handle.Anchored = true
	weapon:PivotTo(home)
	Weapons.setHeld(weapon, false)
end

-- Arme personnelle abandonnée : elle revient au fourreau de son propriétaire s'il est vide,
-- sinon elle disparaît (une arme sans propriétaire disparaît aussi).
local function returnPersonal(weapon: Model)
	local ownerId = weapon:GetAttribute("Owner")
	local owner = if typeof(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	if owner and personalWeapons[owner] == weapon and Scabbard.isEmpty(owner) and Scabbard.sheathe(owner, weapon) then
		return
	end
	if owner and personalWeapons[owner] == weapon then
		personalWeapons[owner] = nil
	end
	weapon:Destroy()
end

task.spawn(function()
	while true do
		task.wait(3)
		for _, weapon in weaponsFolder:GetChildren() do
			local handle = weapon:IsA("Model") and weapon.PrimaryPart
			if handle and not weaponHomes[weapon] and not weapon:GetAttribute("Holder") and not weapon:GetAttribute("SheathedBy") then
				local droppedAt = weapon:GetAttribute("DroppedAt") or 0
				if handle.Position.Y < -30 or os.clock() - droppedAt > Config.WEAPON_RETURN_TIME then
					returnPersonal(weapon)
				end
			end
		end
		for weapon, home in weaponHomes do
			local handle = weapon.PrimaryPart
			if handle and not weapon:GetAttribute("Holder") and not weapon:GetAttribute("SheathedBy") and not handle.Anchored then
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

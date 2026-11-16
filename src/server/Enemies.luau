-- Bandits qui attaquent les joueurs par vagues.
-- Ils poursuivent le joueur le plus proche, lèvent leur sabre (la lame s'illumine : c'est le signal),
-- puis frappent. Le joueur peut parer en plaçant sa propre lame sur la trajectoire.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Collisions = require(script.Parent:WaitForChild("Collisions"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))
local Progression = require(script.Parent:WaitForChild("Progression"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Enemies = {}

---------------------------------------------------------------------------
-- Réglages
---------------------------------------------------------------------------

-- Équipement des bandits, par type d'arme (les formes viennent de Config.Weapons).
--   Damage      : dégâts infligés au joueur par coup
--   AttackRange : distance à laquelle le bandit s'arrête pour frapper
--   StrikeRange : distance maximale à laquelle le coup porte
--   Windup      : temps entre l'arme levée et le coup (la fenêtre pour parer, bloquer ou reculer)
--   Cooldown    : temps entre deux attaques
--   WalkSpeed   : vitesse de marche (le joueur marche à 16)
--   Attacks     : coups que le bandit sait donner (un nom répété sort plus souvent)
type Loadout = {
	Damage: number,
	AttackRange: number,
	StrikeRange: number,
	Windup: number,
	Cooldown: number,
	WalkSpeed: number,
	Attacks: { string },
}

-- Les coups possibles. Les directions sont vues du bandit.
--   Roll        : inclinaison du plan de coupe (0 = vertical, 45° = diagonal, 90° = horizontal)
--   Raise       : angle du bras pendant l'armement (0 = le long du corps, 1,57 = tendu devant, 3 = au-dessus de la tête)
--   Finish      : angle du bras à la fin du coup
--   Thrust      : true pour un estoc (la pointe vers l'avant, le bras se détend)
--   DamageScale : multiplicateur des dégâts de l'arme
--   WindupScale : multiplicateur du temps d'armement de l'arme
--   Reach       : portée ajoutée à celle de l'arme (studs)
type Attack = {
	Roll: number,
	Raise: number,
	Finish: number,
	Thrust: boolean?,
	DamageScale: number,
	WindupScale: number,
	Reach: number,
}

local ATTACKS: { [string]: Attack } = {
	-- Coup vertical de haut en bas.
	Fendant = { Roll = 0, Raise = 2.9, Finish = 0.3, DamageScale = 1, WindupScale = 1, Reach = 0 },
	-- Diagonale qui descend de son épaule droite vers sa hanche gauche.
	DiagonaleDroite = { Roll = math.rad(-45), Raise = 2.7, Finish = 0.3, DamageScale = 1, WindupScale = 1, Reach = 0 },
	-- Diagonale qui descend de son épaule gauche vers sa hanche droite.
	DiagonaleGauche = { Roll = math.rad(45), Raise = 2.7, Finish = 0.3, DamageScale = 1, WindupScale = 1, Reach = 0 },
	-- Coup horizontal de sa droite vers sa gauche.
	Fauchage = { Roll = math.rad(90), Raise = -0.5, Finish = 2, DamageScale = 0.9, WindupScale = 1, Reach = 0 },
	-- Coup horizontal en revers, de sa gauche vers sa droite.
	Revers = { Roll = math.rad(90), Raise = 2.6, Finish = 1, DamageScale = 0.9, WindupScale = 1, Reach = 0 },
	-- Coup vertical de bas en haut.
	Montant = { Roll = 0, Raise = -0.5, Finish = 2, DamageScale = 0.8, WindupScale = 0.9, Reach = 0 },
	-- Estoc : plus rapide à partir et plus long, mais un peu moins fort.
	Estoc = { Roll = 0, Raise = 1, Finish = 1.45, Thrust = true, DamageScale = 0.85, WindupScale = 0.85, Reach = 1.5 },
}

local THRUST_PULL = 0.6 -- recul de l'épaule pendant l'armement d'un estoc (studs)
local THRUST_PUSH = 0.9 -- avancée de l'épaule quand l'estoc part (studs)

local LOADOUTS: { [string]: Loadout } = {
	-- Rapide et nerveux, mais il doit venir au contact et frappe faiblement. Il pique surtout.
	Dague = {
		Damage = 7, AttackRange = 4, StrikeRange = 5.5, Windup = 0.4, Cooldown = 1.2, WalkSpeed = 14,
		Attacks = { "Estoc", "Estoc", "Estoc", "DiagonaleDroite", "DiagonaleGauche", "Revers" },
	},
	-- Équilibré : tous les coups.
	Epee = {
		Damage = 12, AttackRange = 5, StrikeRange = 7, Windup = 0.6, Cooldown = 2, WalkSpeed = 11,
		Attacks = { "Fendant", "DiagonaleDroite", "DiagonaleGauche", "Fauchage", "Revers", "Montant", "Estoc", "Estoc" },
	},
	-- Longue portée et gros dégâts, mais lent à armer.
	EpeeLongue = {
		Damage = 20, AttackRange = 6.5, StrikeRange = 8.5, Windup = 0.85, Cooldown = 2.6, WalkSpeed = 9,
		Attacks = { "Fendant", "DiagonaleDroite", "DiagonaleGauche", "Fauchage", "Revers", "Estoc" },
	},
	-- Proche de l'épée, un peu plus fort et plus porté sur les coups de taille.
	Sabre = {
		Damage = 13, AttackRange = 5, StrikeRange = 7, Windup = 0.55, Cooldown = 1.9, WalkSpeed = 11.5,
		Attacks = { "Fendant", "DiagonaleDroite", "DiagonaleGauche", "Fauchage", "Revers", "Montant" },
	},
	-- La plus longue allonge : il pique de loin, mais il est vulnérable une fois au contact.
	Lance = {
		Damage = 16, AttackRange = 8, StrikeRange = 10.5, Windup = 0.7, Cooldown = 2.2, WalkSpeed = 10,
		Attacks = { "Estoc", "Estoc", "Estoc", "Fauchage", "Fendant" },
	},
	-- Arme lourde à longue portée : de grands coups de taille, très lents à armer.
	Guandao = {
		Damage = 28, AttackRange = 7.5, StrikeRange = 9.5, Windup = 1.1, Cooldown = 3.2, WalkSpeed = 8,
		Attacks = { "Fendant", "DiagonaleDroite", "DiagonaleGauche", "Fauchage", "Revers" },
	},
	-- Longue portée et coups rapides, mais faibles.
	Baton = {
		Damage = 9, AttackRange = 7, StrikeRange = 9, Windup = 0.5, Cooldown = 1.5, WalkSpeed = 12,
		Attacks = { "Fendant", "DiagonaleDroite", "DiagonaleGauche", "Fauchage", "Revers", "Montant", "Estoc" },
	},
	-- Le plus lent et le plus dangereux : son coup se voit venir de loin. Une hache ne pique pas.
	Hache = {
		Damage = 24, AttackRange = 5.5, StrikeRange = 7.5, Windup = 1, Cooldown = 3, WalkSpeed = 8.5,
		Attacks = { "Fendant", "Fendant", "DiagonaleDroite", "DiagonaleGauche", "Fauchage", "Revers" },
	},
}

-- Ordre d'apparition des armes : chaque vague en ajoute une, puis elles sont tirées au hasard.
local WEAPON_ORDER = { "Epee", "Dague", "Sabre", "Hache", "Lance", "EpeeLongue", "Baton", "Guandao" }
-- Bandits à deux armes : seuls ceux dont l'arme principale se tient à une main (dague, épée).
local DUAL_CHANCE = 0.4 -- probabilité qu'un tel bandit porte une seconde arme
local DUAL_FIRST_WAVE = 2 -- pas de bandit à deux armes avant cette vague
local OFFHAND_WEAPONS = { "Dague", "Epee", "Sabre" } -- armes possibles dans la main gauche
local DUAL_COOLDOWN_SCALE = 0.65 -- multiplicateur du temps entre deux attaques
-- Niveaux : chaque bandit a un niveau, affiché au-dessus de sa tête, qui fixe ses points de vie
-- et sa vitesse d'attaque. Le niveau suit le numéro de la vague, à LEVEL_SPREAD près.
local MAX_LEVEL = 10
local LEVEL_SPREAD = 1 -- écart aléatoire autour du numéro de la vague (0 = tous au même niveau)
local BASE_HEALTH = 50 -- points de vie au niveau 1
local HEALTH_PER_LEVEL = 0.15 -- +15 % de points de vie par niveau (niveau 10 : 118)
-- +7 % de vitesse d'attaque par niveau (niveau 10 : ×1,63). Elle raccourcit le temps d'armement
-- et le temps entre deux attaques : un bandit de haut niveau laisse moins de temps pour parer.
local ATTACK_SPEED_PER_LEVEL = 0.07
local DAMAGE_PER_LEVEL = 0.1 -- +10 % de dégâts par niveau (niveau 10 : ×1,9)
local MIN_WINDUP = 0.25 -- temps d'armement minimal (s), pour que le coup reste lisible
local PARRY_DISTANCE = 3.5 -- distance entre les deux lames pour que la parade compte
local STAGGER_TIME = 1.2 -- temps pendant lequel un bandit paré reste sonné
-- Parade parfaite : le joueur frappe activement le sabre au moment où le coup part,
-- au lieu de simplement laisser sa lame sur la trajectoire.
local PERFECT_WINDOW = 0.15 -- durée (s) avant le coup pendant laquelle la lame du bandit devient blanche
local PERFECT_PARRY_SPEED = 12 -- vitesse minimale (studs/s) de la lame du joueur pendant cette fenêtre
local PERFECT_PARRY_DAMAGE = 20 -- dégâts renvoyés au bandit
local PERFECT_STAGGER_TIME = 2.5 -- temps pendant lequel le bandit reste sonné et vulnérable
local SHIELD_BLOCK_DISTANCE = 4.5 -- distance entre le bouclier et le sabre pour que le blocage compte
local SHIELD_STAGGER_TIME = 0.5 -- un blocage au bouclier sonne moins longtemps qu'une parade
local MAX_ENEMIES = 5
local WAVE_PAUSE = 6

-- Tenues du catalogue Roblox portées par les bandits. Chaque bandit en tire une au hasard.
--   Shirt, Pants : numéros des vêtements (le nombre dans l'adresse de la page du catalogue)
--   Hat          : couvre-chef du catalogue ; sans lui, le bandit garde son chapeau de paille
--   Face         : accessoire de visage
--   MinLevel     : niveau minimal du bandit pour porter cette tenue
-- Mettre USE_CATALOG_OUTFITS à false pour revenir aux bandits en blocs.
local USE_CATALOG_OUTFITS = true

type Outfit = {
	Name: string,
	Shirt: number,
	Pants: number,
	Hat: number?,
	Face: number?,
	MinLevel: number?,
}

local OUTFITS: { Outfit } = {
	-- « Black Samurai Robes with armored sleeves » + « Samurai (Shogun) Pants »
	{ Name = "Rônin noir", Shirt = 6523934448, Pants = 5666905795 },
	-- « White Samurai Robe » (haut et bas)
	{ Name = "Robe blanche", Shirt = 6238966041, Pants = 6940703426 },
	-- « Foggy White & Grey Kimono » (haut et bas) + « Deluxe Bandit Mask » (Roblox)
	{ Name = "Brigand masqué", Shirt = 7456262449, Pants = 7456298584, Face = 93050572 },
	-- « Ninja Suit of Darkness » + « Ninja Pants of Darkness » + « Ninja Mask of Shadows » (Roblox)
	{ Name = "Ombre", Shirt = 11404365, Pants = 11404375, Hat = 1309911, MinLevel = 2 },
	-- « Classic Roblox OG Red Ninja » (haut et bas) + « Ninja Mask of Fire » (Roblox)
	{ Name = "Assassin rouge", Shirt = 7743066694, Pants = 9572296500, Hat = 124745856, MinLevel = 4 },
	-- « Classic Shadow Black Ninja Old Samurai Assassin » (haut et bas) + « Samurai Helmet » (Roblox)
	{ Name = "Capitaine", Shirt = 9572711986, Pants = 9572709674, Hat = 8569514, MinLevel = 6 },
}

-- Gestes d'attaque.
local STRIKE_TIME = 0.16 -- durée de la frappe elle-même (s) : le bras accélère jusqu'à l'impact
local WRIST_COCK = 0.3 -- le poignet se casse vers l'arrière pendant l'armement (radians)
local WRIST_SNAP = 0.28 -- puis fouette vers l'avant à l'impact
local FOLLOW_THROUGH = 0.22 -- le bras dépasse sa cible de cet angle, emporté par l'élan
local GUARD_RETURN_TIME = 0.6 -- durée du retour en garde

-- Allure des bandits.
local TURN_SPEED = 7 -- vitesse maximale de pivotement (radians par seconde)
local TURN_RESPONSIVENESS = 14 -- souplesse du pivotement (plus bas = plus lent à se tourner)
local FLANK_ANGLE = 40 -- angle maximal (degrés) dont un bandit contourne le joueur en approchant
local CIRCLE_STEP = 25 -- entre deux attaques, il vise un point décalé de cet angle autour du joueur
local CIRCLE_SPEED = 0.4 -- part de sa vitesse de marche pendant qu'il tourne autour du joueur

-- Boss : un chef de guerre géant qui clôt chaque cycle de vagues.
local BOSS_EVERY = 5 -- un boss après les vagues 5, 10, 15...
local BOSS_NAME = "Seigneur de guerre"
local BOSS_WEAPON = "Guandao"
local BOSS_SCALE = 1.6 -- taille par rapport à un bandit
local BOSS_HEALTH = 600 -- points de vie du premier boss
local BOSS_HEALTH_PER_CYCLE = 0.5 -- +50 % de points de vie à chaque boss suivant
local BOSS_DAMAGE = 26 -- dégâts d'un coup d'arme, avant le bonus de niveau
local BOSS_COOLDOWN = 2.4 -- temps entre deux coups d'arme
local BOSS_WALK_SPEED = 9
local BOSS_XP_MULTIPLIER = 6 -- il rapporte l'expérience de six bandits de son niveau
local BOSS_SLAM_RADIUS = 13 -- rayon de la frappe au sol (studs)
local BOSS_SLAM_WINDUP = 1.4 -- temps pour sortir du disque ou sauter
local BOSS_SLAM_DAMAGE = 30 -- avant le bonus de niveau
local BOSS_SLAM_COOLDOWN = 9
local BOSS_MINIONS = 2 -- renforts appelés à mi-vie
local BOSS_ENRAGE_SPEED = 1.35 -- multiplicateur de vitesse d'attaque sous 30 % de vie

-- Points d'apparition, devant la grande salle.
local SPAWN_POINTS = {
	Vector3.new(0, 0, -22),
	Vector3.new(-12, 0, -22),
	Vector3.new(12, 0, -22),
	Vector3.new(-22, 0, -18),
	Vector3.new(22, 0, -18),
}

local ROBE = Color3.fromRGB(38, 32, 48)
local TROUSERS = Color3.fromRGB(25, 22, 30)
local SKIN = Color3.fromRGB(215, 180, 140)
local STRAW = Color3.fromRGB(200, 170, 100)

local folder: Folder
local weaponsFolder: Instance
local feedbackRemote: RemoteEvent
local started = false
local random = Random.new()

---------------------------------------------------------------------------
-- Construction d'un bandit
---------------------------------------------------------------------------

local function limb(name: string, size: Vector3, color: Color3, parent: Model): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Fabric
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function joint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.MaxVelocity = 0.15
	motor.Parent = part0
	return motor
end

-- Accessoire soudé à une partie du corps, sans masse ni collision.
-- `wedge` : true pour une pièce en biseau (pointe de lame).
local function accessory(name: string, size: Vector3, color: Color3, material: Enum.Material, attachTo: BasePart, offset: CFrame, parent: Model, wedge: boolean?): Part
	local part = (if wedge then Instance.new("WedgePart") else Instance.new("Part")) :: any
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false -- les lames des joueurs ne doivent pas « toucher » un accessoire
	part.CanTouch = false
	part.Massless = true
	part.Parent = parent

	local weld = Instance.new("Weld")
	weld.Part0 = attachTo
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	return part
end

type Enemy = {
	model: Model,
	humanoid: Humanoid,
	root: Part,
	level: number,
	attackSpeed: number, -- multiplicateur tiré du niveau (1 au niveau 1)
	loadout: Loadout, -- équipement de l'arme principale : portée d'approche, cadence, vitesse de marche
	hands: { Hand }, -- une main armée, ou deux pour un bandit à deux armes
	nextHand: number, -- main qui portera la prochaine attaque
	freeArm: Motor6D?, -- bras gauche quand il est vide : il se balance pendant la marche
	facing: AlignOrientation, -- oriente le corps vers sa cible, en douceur
	walkSpeed: number, -- vitesse de marche propre à ce bandit
	flank: number, -- de -1 à 1 : de quel côté et à quel point il contourne le joueur
	isBoss: boolean,
	xpLevels: number, -- l'expérience donnée vaut celle d'un bandit de ce niveau
	tick: ((Enemy) -> ())?, -- comportement propre (attaques spéciales du boss), appelé à chaque tour de boucle
	leftHip: Motor6D,
	rightHip: Motor6D,
}

-- Une main armée et son arme.
type Hand = {
	side: number, -- 1 = main droite, -1 = main gauche (les gestes sont en miroir)
	scale: number, -- taille du bandit : les articulations d'un géant sont plus écartées
	arm: Motor6D,
	wrist: Weld, -- soudure du manche dans la main : la faire tourner oriente la lame
	gripOffset: number,
	blade: Part, -- la pièce tranchante de l'arme
	bladeColor: Color3,
	loadout: Loadout, -- dégâts, portée et coups de cette arme
	lastAttack: string?,
	pose: ArmPose, -- pose actuelle du bras
	motion: ArmMotion?, -- geste en cours
}

type ArmPose = { angle: number, roll: number, push: number, wrist: number }
type ArmMotion = {
	from: ArmPose,
	to: ArmPose,
	start: number,
	duration: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
}

local QUARTER = math.pi / 2
local GUARD_ANGLE = 0.6 -- angle du bras armé au repos

-- Attache d'une épaule armée (`side` : 1 = droite, -1 = gauche). `roll` incline le plan dans lequel
-- le bras tourne (0 = d'avant en arrière, 90° = à l'horizontale) ; `push` décale l'épaule (- = vers l'avant).
-- `scale` : taille du bandit (1 par défaut, plus pour un boss).
local function shoulderC0(side: number, roll: number, push: number, scale: number?): CFrame
	local s = scale or 1
	return CFrame.new(side * s, 0.5 * s, push * s) * CFrame.Angles(0, 0, side * roll) * CFrame.Angles(0, side * QUARTER, 0)
end


-- Position du manche dans la main. À `wrist` = 0 la lame pointe devant le bras pendant ;
-- une valeur négative la rabat vers l'axe du bras (pour pointer en avant, bras tendu).
local function gripC0(gripOffset: number, wrist: number, scale: number?): CFrame
	local s = scale or 1
	return CFrame.new(0, -0.9 * s, 0) * CFrame.Angles(-QUARTER + wrist, 0, 0) * CFrame.new(0, -gripOffset * s, 0)
end

---------------------------------------------------------------------------
-- Gestes du bras armé
---------------------------------------------------------------------------

-- La pose d'un bras armé tient en quatre nombres, que l'on fait évoluer selon des courbes
-- d'accélération et de freinage : le bras ne part ni ne s'arrête d'un coup.
--   angle : élévation du bras (0 = le long du corps, 1,57 = tendu devant, 3 = au-dessus de la tête)
--   roll  : inclinaison du plan de coupe (0 = vertical, 90° = horizontal)
--   push  : décalage de l'épaule (- = vers l'avant)
--   wrist : flexion du poignet (+ = la lame traîne en arrière, - = elle se rabat vers l'avant)
local movingHands: { [Hand]: boolean } = {}

local function applyPose(hand: Hand)
	local pose = hand.pose
	-- Le moteur de l'épaule gauche tourne dans l'autre sens : `side` rétablit le signe.
	hand.arm.C0 = shoulderC0(hand.side, pose.roll, pose.push, hand.scale) * CFrame.Angles(0, 0, hand.side * pose.angle)
	hand.wrist.C0 = gripC0(hand.gripOffset, pose.wrist, hand.scale)
end

-- Amène le bras vers `target` en `duration` secondes. Les valeurs absentes de `target` ne changent pas.
-- Un nouveau geste remplace celui en cours, en partant de la pose du moment : jamais de saut.
local function moveArm(hand: Hand, target: { [string]: number }, duration: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local from = table.clone(hand.pose)
	local to: ArmPose = {
		angle = target.angle or from.angle,
		roll = target.roll or from.roll,
		push = target.push or from.push,
		wrist = target.wrist or from.wrist,
	}
	if duration <= 0 then
		hand.pose = to
		hand.motion = nil
		movingHands[hand] = nil
		applyPose(hand)
		return
	end
	hand.motion = {
		from = from,
		to = to,
		start = os.clock(),
		duration = duration,
		style = style or Enum.EasingStyle.Sine,
		direction = direction or Enum.EasingDirection.InOut,
	}
	movingHands[hand] = true
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for hand in movingHands do
		local motion = hand.motion
		if not motion or not hand.arm.Parent then
			movingHands[hand] = nil
			continue
		end
		local alpha = math.clamp((now - motion.start) / motion.duration, 0, 1)
		-- La courbe peut dépasser 1 (style Back) : le bras dépasse sa cible puis y revient.
		local eased = TweenService:GetValue(alpha, motion.style, motion.direction)
		local from, to = motion.from, motion.to
		hand.pose = {
			angle = from.angle + (to.angle - from.angle) * eased,
			roll = from.roll + (to.roll - from.roll) * eased,
			push = from.push + (to.push - from.push) * eased,
			wrist = from.wrist + (to.wrist - from.wrist) * eased,
		}
		applyPose(hand)
		if alpha >= 1 then
			hand.motion = nil
			movingHands[hand] = nil
		end
	end
end)

-- Construit une arme dans la main d'un bandit, avec les mêmes pièces que celle des joueurs.
-- Le manche est tourné pour que la lame (son axe +Y) pointe vers l'avant du bras.
-- Les autres pièces sont soudées au manche : tourner le poignet oriente toute l'arme.
local function equip(model: Model, arm: BasePart, shoulder: Motor6D, side: number, weaponType: string): Hand
	local def = Config.Weapons[weaponType]
	local loadout = LOADOUTS[weaponType]
	assert(def and loadout, "Arme de bandit inconnue : " .. weaponType)

	local handle = accessory("Manche", Vector3.new(0.28, def.HandleLength, 0.28), def.HandleColor or Color3.fromRGB(105, 70, 40), def.HandleMaterial or Enum.Material.Wood, arm, gripC0(def.GripOffset, 0), model)
	local wrist = handle:FindFirstChildOfClass("Weld") :: Weld
	local blade: Part? = nil
	for _, info in def.Parts do
		local offset = CFrame.new(info.Offset) * (info.Rotation or CFrame.new())
		local part = accessory(info.Name, info.Size, info.Color, info.Material, handle, offset, model, info.Wedge)
		part.Reflectance = info.Reflectance or 0
		if info.Shape and not info.Wedge then
			part.Shape = info.Shape
		end
		if info.Blade and not blade then
			blade = part
		end
	end
	assert(blade, "L'arme " .. weaponType .. " n'a pas de lame")
	Weapons.addTrail(blade)

	local hand: Hand = {
		side = side,
		scale = 1,
		arm = shoulder,
		wrist = wrist,
		gripOffset = def.GripOffset,
		blade = blade,
		bladeColor = blade.Color,
		loadout = loadout,
		lastAttack = nil,
		pose = { angle = GUARD_ANGLE, roll = 0, push = 0, wrist = 0 },
		motion = nil,
	}
	applyPose(hand)
	return hand
end

-- Le corps d'un bandit, avant qu'on lui donne ses armes.
type Body = {
	model: Model,
	humanoid: Humanoid,
	root: Part,
	head: BasePart,
	leftArm: BasePart,
	rightArm: BasePart,
	leftShoulder: Motor6D,
	rightShoulder: Motor6D,
	leftHip: Motor6D,
	rightHip: Motor6D,
	strawHat: boolean, -- true : on lui ajoute le chapeau de paille
}

-- Corps en blocs, entièrement construit par script. Il sert tant que les tenues du catalogue
-- ne sont pas chargées, ou si leur chargement échoue.
local function blockBody(): Body
	local model = Instance.new("Model")
	model.Name = "Bandit"

	local root = limb("HumanoidRootPart", Vector3.new(2, 2, 1), ROBE, model)
	root.Transparency = 1
	root.CanQuery = false
	local torso = limb("Torso", Vector3.new(2, 2, 1), ROBE, model)
	local head = limb("Head", Vector3.new(1.2, 1.2, 1.2), SKIN, model)
	head.Material = Enum.Material.SmoothPlastic
	local leftArm = limb("Left Arm", Vector3.new(1, 2, 1), ROBE, model)
	local rightArm = limb("Right Arm", Vector3.new(1, 2, 1), ROBE, model)
	local leftLeg = limb("Left Leg", Vector3.new(1, 2, 1), TROUSERS, model)
	local rightLeg = limb("Right Leg", Vector3.new(1, 2, 1), TROUSERS, model)

	joint("RootJoint", root, torso, CFrame.new(), CFrame.new())
	joint("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.6, 0))
	local rightShoulder = joint("Right Shoulder", torso, rightArm, shoulderC0(1, 0, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, QUARTER, 0))
	local leftShoulder = joint("Left Shoulder", torso, leftArm, shoulderC0(-1, 0, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -QUARTER, 0))
	local rightHip = joint("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0) * CFrame.Angles(0, QUARTER, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, QUARTER, 0))
	local leftHip = joint("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0) * CFrame.Angles(0, -QUARTER, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -QUARTER, 0))

	-- Ceinture rouge.
	accessory("Ceinture", Vector3.new(2.1, 0.4, 1.1), Color3.fromRGB(150, 38, 32), Enum.Material.Fabric, torso, CFrame.new(0, -0.6, 0), model)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		leftArm = leftArm,
		rightArm = rightArm,
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		leftHip = leftHip,
		rightHip = rightHip,
		strawHat = true,
	}
end

-- Modèles habillés, un par tenue, fabriqués une seule fois puis copiés à chaque apparition.
local outfitTemplates: { [Outfit]: Model } = {}
local readyOutfits: { Outfit } = {}

-- Demande à Roblox un personnage R6 portant chaque tenue. L'appel télécharge les vêtements :
-- il prend un instant et peut échouer (objet retiré du catalogue, pas de connexion).
local function loadOutfits()
	if not USE_CATALOG_OUTFITS then
		return
	end
	for _, outfit in OUTFITS do
		task.spawn(function()
			local description = Instance.new("HumanoidDescription")
			description.Shirt = outfit.Shirt
			description.Pants = outfit.Pants
			if outfit.Hat then
				description.HatAccessory = tostring(outfit.Hat)
			end
			if outfit.Face then
				description.FaceAccessory = tostring(outfit.Face)
			end
			description.HeadColor = SKIN
			description.TorsoColor = SKIN
			description.LeftArmColor = SKIN
			description.RightArmColor = SKIN
			description.LeftLegColor = SKIN
			description.RightLegColor = SKIN

			local ok, result = pcall(function()
				return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
			end)
			if ok and result then
				outfitTemplates[outfit] = result
				table.insert(readyOutfits, outfit)
			else
				warn("[Enemies] Tenue « " .. outfit.Name .. " » indisponible : " .. tostring(result))
			end
		end)
	end
end

-- Tire une tenue prête parmi celles que le niveau du bandit autorise, ou nil s'il n'y en a pas.
local function pickOutfit(level: number): Outfit?
	local candidates = {}
	for _, outfit in readyOutfits do
		if level >= (outfit.MinLevel or 1) then
			table.insert(candidates, outfit)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[random:NextInteger(1, #candidates)]
end

-- La tenue prête qui demande le niveau le plus élevé (celle du boss), ou nil.
local function bestOutfit(): Outfit?
	local best: Outfit? = nil
	for _, outfit in readyOutfits do
		if not best or (outfit.MinLevel or 1) > (best.MinLevel or 1) then
			best = outfit
		end
	end
	return best
end

-- Copie le personnage habillé d'une tenue et y retrouve les articulations dont le combat a besoin.
-- Renvoie nil si le modèle n'a pas la forme attendue.
local function dressedBody(outfit: Outfit): Body?
	local template = outfitTemplates[outfit]
	if not template then
		return nil
	end
	local model = template:Clone()
	model.Name = "Bandit"

	-- Les scripts d'un personnage de joueur (animations, régénération de la vie) ne servent pas ici.
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	-- Sans animateur Roblox : les articulations sont pilotées par nos scripts.
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local torso = model:FindFirstChild("Torso")
	local head = model:FindFirstChild("Head")
	local leftArm = model:FindFirstChild("Left Arm")
	local rightArm = model:FindFirstChild("Right Arm")
	local function motor(name: string): Motor6D?
		local found = torso and torso:FindFirstChild(name)
		return if found and found:IsA("Motor6D") then found else nil
	end
	local leftShoulder, rightShoulder = motor("Left Shoulder"), motor("Right Shoulder")
	local leftHip, rightHip = motor("Left Hip"), motor("Right Hip")

	if not (humanoid and root and root:IsA("Part") and head and head:IsA("BasePart")
		and leftArm and leftArm:IsA("BasePart") and rightArm and rightArm:IsA("BasePart")
		and leftShoulder and rightShoulder and leftHip and rightHip) then
		model:Destroy()
		return nil
	end

	-- Mêmes réglages d'articulations que le corps en blocs.
	leftShoulder.C0 = shoulderC0(-1, 0, 0)
	rightShoulder.C0 = shoulderC0(1, 0, 0)
	for _, motorJoint in { leftShoulder, rightShoulder, leftHip, rightHip } do
		motorJoint.MaxVelocity = 0.15
	end
	root.CanQuery = false

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		leftArm = leftArm,
		rightArm = rightArm,
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		leftHip = leftHip,
		rightHip = rightHip,
		strawHat = outfit.Hat == nil, -- pas de chapeau de paille par-dessus un masque ou un casque
	}
end

-- `offhandType` : arme tenue dans la main gauche, pour un bandit à deux armes.
-- `boss` : fait du bandit un géant aux points de vie et à l'équipement propres.
type BossBuild = { Name: string, Scale: number, Health: number, Loadout: Loadout }

local function buildEnemy(position: Vector3, level: number, weaponType: string, offhandType: string?, boss: BossBuild?): Enemy
	local def = Config.Weapons[weaponType]
	local loadout = LOADOUTS[weaponType]
	assert(def and loadout, "Arme de bandit inconnue : " .. weaponType)
	local health = math.round(BASE_HEALTH * (1 + HEALTH_PER_LEVEL * (level - 1)))
	local attackSpeed = 1 + ATTACK_SPEED_PER_LEVEL * (level - 1)
	local scale = 1
	if boss then
		loadout = boss.Loadout
		health = boss.Health
		scale = boss.Scale
	end

	-- Corps habillé d'une tenue du catalogue si une est prête, sinon corps en blocs.
	-- Le boss porte la tenue la plus prestigieuse disponible.
	local outfit = if boss then bestOutfit() else pickOutfit(level)
	local body = (if outfit then dressedBody(outfit) else nil) or blockBody()
	local model, root, head = body.model, body.root, body.head
	local leftArm, rightArm = body.leftArm, body.rightArm
	local leftShoulder, rightShoulder = body.leftShoulder, body.rightShoulder
	local leftHip, rightHip = body.leftHip, body.rightHip

	if body.strawHat then
		-- Chapeau de paille conique.
		local flat = CFrame.Angles(0, 0, QUARTER)
		local brim = accessory("Chapeau", Vector3.new(0.25, 3, 3), STRAW, Enum.Material.Wood, head, CFrame.new(0, 0.7, 0) * flat, model)
		brim.Shape = Enum.PartType.Cylinder
		local crown = accessory("Chapeau", Vector3.new(0.5, 1.5, 1.5), STRAW, Enum.Material.Wood, head, CFrame.new(0, 1, 0) * flat, model)
		crown.Shape = Enum.PartType.Cylinder
	end

	-- Arme principale dans la main droite, et parfois une seconde dans la main gauche.
	local hands = { equip(model, rightArm, rightShoulder, 1, weaponType) }
	local displayName = def.DisplayName
	if offhandType then
		table.insert(hands, equip(model, leftArm, leftShoulder, -1, offhandType))
		displayName ..= " + " .. Config.Weapons[offhandType].DisplayName
	end

	local humanoid = body.humanoid
	humanoid.DisplayName = "Niv. " .. level .. " · " .. (if boss then boss.Name else "Bandit") .. " · " .. displayName
	humanoid.MaxHealth = health
	humanoid.Health = health
	-- Chaque bandit marche à une allure légèrement différente : ils n'avancent pas au pas cadencé.
	local walkSpeed = loadout.WalkSpeed * random:NextNumber(0.92, 1.08)
	humanoid.WalkSpeed = walkSpeed
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn

	-- Le corps s'oriente par une contrainte souple plutôt que par la rotation automatique du Humanoid :
	-- il pivote progressivement vers sa cible et peut marcher de côté en la regardant.
	humanoid.AutoRotate = false
	local pivot = Instance.new("Attachment")
	pivot.Name = "Pivot"
	pivot.Parent = root
	local facing = Instance.new("AlignOrientation")
	facing.Name = "Orientation"
	facing.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facing.Attachment0 = pivot
	facing.RigidityEnabled = false
	facing.MaxTorque = math.huge
	facing.MaxAngularVelocity = TURN_SPEED
	facing.Responsiveness = TURN_RESPONSIVENESS
	facing.CFrame = CFrame.Angles(0, math.pi, 0)
	facing.Parent = root

	-- Indique aux clients que le bras gauche est libre et peut se balancer pendant la marche.
	model:SetAttribute("FreeArm", offhandType == nil)

	model.PrimaryPart = root
	if boss then
		-- Le géant : tout le modèle est agrandi, armes et articulations comprises.
		model:ScaleTo(scale)
		for _, hand in hands do
			hand.scale = scale
			hand.loadout = loadout
		end
		-- Un personnage R6 agrandi s'enfonce dans le sol : on relève ses hanches d'autant que ses jambes ont grandi.
		humanoid.HipHeight = 2 * (scale - 1)
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.NameDisplayDistance = 200
		humanoid.HealthDisplayDistance = 200

		local aura = Instance.new("Highlight")
		aura.Name = "AuraBoss"
		aura.FillTransparency = 1
		aura.OutlineColor = Color3.fromRGB(255, 70, 50)
		aura.DepthMode = Enum.HighlightDepthMode.Occluded
		aura.Parent = model
	end
	Collisions.assign(model, Collisions.BODIES)
	root.CFrame = CFrame.new(position + Vector3.new(0, 3 * scale, 0)) * CFrame.Angles(0, math.pi, 0) -- face au sud, vers les joueurs
	model.Parent = folder

	-- La physique du bandit reste sur le serveur.
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		level = level,
		attackSpeed = attackSpeed,
		loadout = loadout,
		hands = hands,
		nextHand = 1,
		freeArm = if offhandType then nil else leftShoulder,
		facing = facing,
		walkSpeed = walkSpeed,
		flank = random:NextNumber(-1, 1),
		isBoss = boss ~= nil,
		xpLevels = level,
		tick = nil,
		leftHip = leftHip,
		rightHip = rightHip,
	}
end

---------------------------------------------------------------------------
-- Comportement
---------------------------------------------------------------------------

local function nearestPlayer(position: Vector3): (Player?, Humanoid?, BasePart?, number)
	local bestPlayer, bestHumanoid, bestRoot = nil, nil, nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestPlayer, bestHumanoid, bestRoot, bestDistance = player, humanoid, root, distance
			end
		end
	end
	return bestPlayer, bestHumanoid, bestRoot, bestDistance
end

-- Cherche ce qui arrête le coup du bandit, au moment où il part.
--  "Shield" : un bouclier tenu du côté du bandit, près de son sabre.
--  "Parry"  : une lame du joueur tout près du sabre.
-- Renvoie aussi la main qui a bloqué, pour la faire vibrer, et le plateau du bouclier s'il y en a un.
local function findBlock(player: Player, blade: BasePart, enemyRoot: BasePart, targetRoot: BasePart): (string?, string?, BasePart?)
	local toEnemy = enemyRoot.Position - targetRoot.Position
	local towardEnemy = if toEnemy.Magnitude > 0.1 then toEnemy.Unit else Vector3.zero
	local parrySide: string? = nil

	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:GetAttribute("Holder") == player.UserId then
			local side = weapon:GetAttribute("HolderHand")
			for _, part in weapon:GetChildren() do
				if part:IsA("BasePart") then
					local distance = (part.Position - blade.Position).Magnitude
					if part:GetAttribute("IsShield") then
						-- Un bouclier tenu dans le dos ou sur le côté opposé ne protège pas.
						local facesEnemy = (part.Position - targetRoot.Position):Dot(towardEnemy) > 0.5
						if distance <= SHIELD_BLOCK_DISTANCE and facesEnemy then
							return "Shield", side, part
						end
					elseif part:GetAttribute("IsBlade") and distance <= PARRY_DISTANCE then
						parrySide = side
					end
				end
			end
		end
	end

	if parrySide then
		return "Parry", parrySide, nil
	end
	return nil, nil, nil
end

-- Vitesse de pointe, à cet instant, des lames du joueur proches du sabre.
-- La vitesse est prise par rapport au corps du joueur : courir ne compte pas comme un geste.
local function playerBladeSpeed(player: Player, blade: BasePart, targetRoot: BasePart): number
	local peak = 0
	local rootVelocity = targetRoot.AssemblyLinearVelocity
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:GetAttribute("Holder") == player.UserId then
			for _, part in weapon:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
					if (part.Position - blade.Position).Magnitude <= PARRY_DISTANCE + 2 then
						local tip = part.CFrame * Vector3.new(0, part.Size.Y / 2, 0)
						local speed = (part:GetVelocityAtPosition(tip) - rootVelocity).Magnitude
						peak = math.max(peak, speed)
					end
				end
			end
		end
	end
	return peak
end

-- La même mesure, en gardant le maximum observé pendant `duration` secondes.
local function samplePlayerBladeSpeed(player: Player, blade: BasePart, targetRoot: BasePart, duration: number): number
	local peak = 0
	local elapsed = 0
	while elapsed < duration do
		elapsed += task.wait()
		peak = math.max(peak, playerBladeSpeed(player, blade, targetRoot))
	end
	return peak
end

type StrikeResult = {
	speed: number, -- vitesse maximale de la lame du joueur pendant le coup
	kind: string?, -- "Shield", "Parry" ou nil
	side: string?, -- main qui a bloqué
	shield: BasePart?,
	contact: Vector3, -- où la lame du bandit a été arrêtée (ou sa position finale)
}

-- Suit le coup pendant toute sa course : comme la lame balaie une trajectoire différente
-- selon l'angle du coup, le blocage compte dès qu'elle croise une lame ou un bouclier du joueur.
local function watchStrike(player: Player, blade: BasePart, enemyRoot: BasePart, targetRoot: BasePart, duration: number): StrikeResult
	local result: StrikeResult = { speed = 0, kind = nil, side = nil, shield = nil, contact = blade.Position }
	local elapsed = 0
	while elapsed < duration do
		elapsed += task.wait()
		result.speed = math.max(result.speed, playerBladeSpeed(player, blade, targetRoot))
		-- Le bouclier l'emporte sur une parade vue plus tôt dans la course.
		if result.kind ~= "Shield" then
			local kind, side, shield = findBlock(player, blade, enemyRoot, targetRoot)
			if kind == "Shield" or (kind and not result.kind) then
				result.kind, result.side, result.shield = kind, side, shield
				result.contact = blade.Position
			end
		end
	end
	if not result.kind then
		result.contact = blade.Position
	end
	return result
end


-- Oriente le bandit vers `position`. Une contrainte le fait pivoter progressivement,
-- au lieu de le retourner d'un coup.
local function faceToward(enemy: Enemy, position: Vector3)
	local from = enemy.root.Position
	local flat = Vector3.new(position.X, from.Y, position.Z)
	if (flat - from).Magnitude > 0.1 then
		enemy.facing.CFrame = CFrame.lookAt(from, flat).Rotation
	end
end

-- Tire un coup au hasard parmi ceux de l'arme, en évitant de répéter le précédent.
local function pickAttack(hand: Hand): Attack
	local names = hand.loadout.Attacks
	local name = names[random:NextInteger(1, #names)]
	if name == hand.lastAttack then
		name = names[random:NextInteger(1, #names)]
	end
	hand.lastAttack = name
	return ATTACKS[name]
end

-- Effet visuel de la parade parfaite, au point de contact des lames :
-- une gerbe d'étincelles, une onde de choc qui se dilate et un éclair de lumière.
local function perfectParryVfx(position: Vector3)
	local white = Color3.fromRGB(255, 255, 255)
	local gold = Color3.fromRGB(255, 205, 90)

	local anchor = Instance.new("Part")
	anchor.Name = "ParadeParfaite"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = folder

	-- Étincelles projetées dans toutes les directions, qui retombent en s'éteignant.
	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Rate = 0
	sparks.Color = ColorSequence.new(white, gold)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.25, 0.6)
	sparks.Speed = NumberRange.new(18, 36)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 3
	sparks.Acceleration = Vector3.new(0, -35, 0)
	sparks.Parent = anchor
	sparks:Emit(50)

	-- Éclair de lumière qui s'éteint vite.
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 26
	light.Brightness = 6
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()

	-- Onde de choc : une sphère lumineuse qui se dilate en devenant transparente.
	local wave = Instance.new("Part")
	wave.Name = "OndeDeChoc"
	wave.Shape = Enum.PartType.Ball
	wave.Size = Vector3.new(1, 1, 1)
	wave.Color = white
	wave.Material = Enum.Material.Neon
	wave.Transparency = 0.25
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false
	wave.CastShadow = false
	wave.CFrame = CFrame.new(position)
	wave.Parent = folder
	TweenService:Create(wave, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(13, 13, 13),
		Transparency = 1,
	}):Play()

	Debris:AddItem(wave, 0.5)
	Debris:AddItem(anchor, 1.2)
end

-- Effet visuel du blocage au bouclier, sur le plateau : des éclats de bois qui volent
-- et un anneau d'impact plaqué contre le bouclier, tourné vers l'attaquant (`normal`).
local function blockVfx(position: Vector3, normal: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "Blocage"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = folder

	-- Éclats de bois et poussière : plus gros, plus lents et plus lourds que des étincelles.
	local chips = Instance.new("ParticleEmitter")
	chips.Enabled = false
	chips.Rate = 0
	chips.Color = ColorSequence.new(Color3.fromRGB(215, 180, 125), Color3.fromRGB(120, 85, 50))
	chips.LightEmission = 0.1
	chips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.15) })
	chips.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	chips.Lifetime = NumberRange.new(0.3, 0.6)
	chips.Speed = NumberRange.new(6, 14)
	chips.SpreadAngle = Vector2.new(180, 180)
	chips.Rotation = NumberRange.new(0, 360)
	chips.RotSpeed = NumberRange.new(-300, 300)
	chips.Drag = 2
	chips.Acceleration = Vector3.new(0, -45, 0)
	chips.Parent = anchor
	chips:Emit(22)

	-- Anneau d'impact : un disque clair qui s'élargit sur la face du bouclier en s'effaçant.
	local ring = Instance.new("Part")
	ring.Name = "AnneauImpact"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, 1.5, 1.5)
	ring.Color = Color3.fromRGB(255, 240, 210)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	-- L'axe d'un cylindre est son axe X : on l'aligne sur la direction de l'attaquant.
	local facing = if normal.Magnitude > 0.1 then normal.Unit else Vector3.zAxis
	ring.CFrame = CFrame.lookAt(position, position + facing) * CFrame.Angles(0, math.rad(90), 0)
	ring.Parent = folder
	TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.12, 7, 7),
		Transparency = 1,
	}):Play()

	Debris:AddItem(ring, 0.4)
	Debris:AddItem(anchor, 1)
end

-- Effet visuel de la parade normale : une petite gerbe d'étincelles orangées et un bref éclat,
-- volontairement plus discret que celui de la parade parfaite (pas d'onde de choc).
local function parryVfx(position: Vector3)
	local yellow = Color3.fromRGB(255, 235, 150)
	local orange = Color3.fromRGB(255, 140, 50)

	local anchor = Instance.new("Part")
	anchor.Name = "Parade"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = folder

	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Rate = 0
	sparks.Color = ColorSequence.new(yellow, orange)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(10, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 4
	sparks.Acceleration = Vector3.new(0, -35, 0)
	sparks.Parent = anchor
	sparks:Emit(18)

	local light = Instance.new("PointLight")
	light.Color = orange
	light.Range = 12
	light.Brightness = 3
	light.Parent = anchor
	TweenService:Create(light, TweenInfo.new(0.2), { Brightness = 0 }):Play()

	Debris:AddItem(anchor, 0.8)
end

local function attack(enemy: Enemy, player: Player, targetHumanoid: Humanoid, targetRoot: BasePart)
	-- Un bandit à deux armes frappe d'une main puis de l'autre.
	local hand = enemy.hands[enemy.nextHand]
	enemy.nextHand = enemy.nextHand % #enemy.hands + 1
	local root, humanoid, blade = enemy.root, enemy.humanoid, hand.blade

	-- Se tourne vers la cible (en pivotant, sans à-coup) et lève le sabre :
	-- la lame s'illumine pour prévenir le joueur.
	humanoid:MoveTo(root.Position)
	faceToward(enemy, targetRoot.Position)
	-- La pose d'armement dépend du coup choisi : c'est elle qui annonce d'où il viendra.
	local style = pickAttack(hand)
	-- Plus le niveau est élevé, plus l'armement est court.
	local windup = math.max(hand.loadout.Windup * style.WindupScale / enemy.attackSpeed, MIN_WINDUP)
	-- Sens du coup : +1 si le bras descend (fendant), -1 s'il monte (montant, fauchage).
	local sweep = if style.Finish < style.Raise then 1 else -1

	-- 1. Armement : le bras monte sur presque toute la durée, en accélérant puis en freinant,
	--    le poignet se casse vers l'arrière et le buste recule. Rien ne reste figé.
	local raiseTime = math.max(windup - PERFECT_WINDOW, 0.12)
	if style.Thrust then
		-- Estoc : l'épaule recule, le poignet garde la pointe tournée vers la cible.
		moveArm(hand, { angle = style.Raise, roll = 0, push = THRUST_PULL, wrist = -style.Raise }, raiseTime)
	else
		moveArm(hand, { angle = style.Raise, roll = style.Roll, push = 0.15, wrist = WRIST_COCK * sweep }, raiseTime)
	end
	enemy.model:SetAttribute("AttackLean", 0.6)
	blade.Material = Enum.Material.Neon
	blade.Color = Color3.fromRGB(255, 140, 60)
	task.wait(raiseTime)
	if humanoid.Health <= 0 then
		enemy.model:SetAttribute("AttackLean", 0)
		return
	end

	-- 2. Prise d'élan : la lame vire au blanc (fenêtre de parade parfaite) pendant que le bras
	--    recule encore un peu, comme un ressort que l'on tend.
	blade.Color = Color3.fromRGB(255, 255, 255)
	moveArm(hand, { angle = style.Raise + (if style.Thrust then -0.1 else 0.14 * sweep) }, PERFECT_WINDOW, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	enemy.model:SetAttribute("AttackLean", 1)
	local playerSpeed = samplePlayerBladeSpeed(player, blade, targetRoot, PERFECT_WINDOW)
	if humanoid.Health <= 0 then
		enemy.model:SetAttribute("AttackLean", 0)
		return
	end

	-- 3. Frappe : le bras accélère jusqu'à l'impact, le poignet fouette vers l'avant,
	--    l'épaule et le buste accompagnent.
	if style.Thrust then
		-- Le bras se détend : l'épaule avance et la pointe file droit devant.
		moveArm(hand, { angle = style.Finish, push = -THRUST_PUSH, wrist = -style.Finish }, STRIKE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	else
		moveArm(hand, { angle = style.Finish, push = -0.25, wrist = -WRIST_SNAP * sweep }, STRIKE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	enemy.model:SetAttribute("AttackLean", -1)
	local strike = watchStrike(player, blade, root, targetRoot, STRIKE_TIME + 0.02)
	playerSpeed = math.max(playerSpeed, strike.speed)
	blade.Material = Enum.Material.Metal
	blade.Color = hand.bladeColor
	if humanoid.Health <= 0 then
		enemy.model:SetAttribute("AttackLean", 0)
		return
	end

	-- 4. Accompagnement : emporté par son élan, le bras dépasse la cible en ralentissant.
	--    Une parade ou un blocage remplacent ce geste par un recul, plus bas.
	if not style.Thrust then
		moveArm(hand, { angle = style.Finish - FOLLOW_THROUGH * sweep }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	local offset = targetRoot.Position - root.Position
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	local inFront = flatOffset.Magnitude < 1 or flatOffset.Unit:Dot(root.CFrame.LookVector) > 0.3
	if targetHumanoid.Health > 0 and offset.Magnitude <= hand.loadout.StrikeRange + style.Reach and inFront then
		local blockKind, blockSide, shieldPart = strike.kind, strike.side, strike.shield
		if blockKind == "Shield" then
			-- Le bouclier encaisse : pas de dégâts, le bandit est brièvement repoussé.
			if shieldPart then
				blockVfx(shieldPart.Position, root.Position - shieldPart.Position)
			end
			Sfx.play("Block", strike.contact, 1)
			feedbackRemote:FireClient(player, blockSide, 1, 0.2)
			-- L'arme rebondit sur le bouclier : le bras est renvoyé, dépasse, puis se stabilise.
			moveArm(hand, { angle = 1.6, push = 0.2, wrist = 0 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			enemy.model:SetAttribute("AttackLean", 0.8)
			task.wait(SHIELD_STAGGER_TIME)
		elseif blockKind == "Parry" and playerSpeed >= PERFECT_PARRY_SPEED then
			-- Parade parfaite : le coup est renvoyé, le bandit est blessé, sonné longtemps
			-- et vulnérable (les coups qu'il reçoit pendant ce temps sont multipliés).
			perfectParryVfx(strike.contact)
			Sfx.play("PerfectParry", strike.contact, 1.5)
			feedbackRemote:FireClient(player, blockSide, 1, 0.3)
			-- Le sabre est rejeté en arrière, le buste part avec.
			moveArm(hand, { angle = 3.1, push = 0.3, wrist = WRIST_COCK }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			enemy.model:SetAttribute("AttackLean", 1.6)
			Progression.tag(enemy.model, player)
			humanoid:TakeDamage(PERFECT_PARRY_DAMAGE + Progression.effect(player, "ParryDamage")) -- Cœur d'épée

			if humanoid.Health > 0 then
				enemy.model:SetAttribute("Vulnerable", true)
				local glow = Instance.new("Highlight")
				glow.Name = "Vulnerable"
				glow.FillColor = Color3.fromRGB(255, 215, 110)
				glow.FillTransparency = 0.6
				glow.OutlineColor = Color3.fromRGB(255, 240, 180)
				glow.Parent = enemy.model
				task.wait(PERFECT_STAGGER_TIME + Progression.effect(player, "ParryStun"))
				glow:Destroy()
				enemy.model:SetAttribute("Vulnerable", nil)
			end
		elseif blockKind == "Parry" then
			parryVfx(strike.contact)
			Sfx.play("Parry", strike.contact, 1)
			feedbackRemote:FireClient(player, blockSide, 0.8, 0.12)
			-- Le sabre est repoussé vers le haut.
			moveArm(hand, { angle = 2.2, push = 0.15, wrist = 0.15 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			enemy.model:SetAttribute("AttackLean", 1)
			task.wait(STAGGER_TIME)
		else
			local levelScale = 1 + DAMAGE_PER_LEVEL * (enemy.level - 1)
			-- Les techniques du Corps du joueur réduisent les dégâts reçus.
			local taken = Progression.damageTakenMultiplier(player)
			targetHumanoid:TakeDamage(hand.loadout.Damage * style.DamageScale * levelScale * taken)
			Sfx.play("Hurt", targetRoot, 1)
		end
	end

	-- 5. Retour en garde, sans hâte : départ et arrivée en douceur.
	task.wait(0.25)
	enemy.model:SetAttribute("AttackLean", 0)
	moveArm(hand, { angle = GUARD_ANGLE, roll = 0, push = 0, wrist = 0 }, GUARD_RETURN_TIME)
end

local function run(enemy: Enemy)
	local humanoid, root = enemy.humanoid, enemy.root
	local nextAttack = os.clock() + 1
	local lastPosition = root.Position
	local stuckTime = 0

	while humanoid.Health > 0 and enemy.model.Parent do
		local dt = task.wait(0.12)
		if humanoid.Health <= 0 or not enemy.model.Parent then
			break
		end

		-- Sonné par une technique du joueur (Rugissement du lion) : il ne bouge ni n'attaque.
		-- Un boss est trop massif pour être sonné ainsi.
		local stunnedUntil = enemy.model:GetAttribute("StunnedUntil")
		if not enemy.isBoss and typeof(stunnedUntil) == "number" and os.clock() < stunnedUntil then
			humanoid:MoveTo(root.Position)
			lastPosition = root.Position
			continue
		end

		-- Attaques spéciales du boss.
		if enemy.tick then
			enemy.tick(enemy)
			if humanoid.Health <= 0 then
				break
			end
		end

		local player, targetHumanoid, targetRoot, distance = nearestPlayer(root.Position)
		if targetRoot then
			-- Il garde les yeux sur sa cible et pivote en douceur, qu'il marche ou non.
			faceToward(enemy, targetRoot.Position)
		end
		if player and targetHumanoid and targetRoot and distance > enemy.loadout.AttackRange then
			humanoid.WalkSpeed = enemy.walkSpeed
			-- Il n'arrive pas en ligne droite : chaque bandit vise un point décalé autour du joueur,
			-- ce qui les fait arriver en arc et encercler leur cible au lieu de s'empiler.
			local destination = targetRoot.Position
			local away = (root.Position - targetRoot.Position) * Vector3.new(1, 0, 1)
			if away.Magnitude > 0.5 and distance < 30 then
				local direction = CFrame.Angles(0, math.rad(FLANK_ANGLE) * enemy.flank, 0):VectorToWorldSpace(away.Unit)
				destination = targetRoot.Position + direction * enemy.loadout.AttackRange * 0.8
			end
			humanoid:MoveTo(destination)
			-- Bloqué contre un obstacle (le leitai, le râtelier) : il saute par-dessus.
			if (root.Position - lastPosition).Magnitude < 0.1 then
				stuckTime += dt
				if stuckTime > 0.5 then
					humanoid.Jump = true
					stuckTime = 0
				end
			else
				stuckTime = 0
			end
		else
			stuckTime = 0
			if player and targetHumanoid and targetRoot and os.clock() < nextAttack then
				-- Entre deux attaques, il ne reste pas planté : il tourne lentement autour du joueur.
				local away = (root.Position - targetRoot.Position) * Vector3.new(1, 0, 1)
				if away.Magnitude > 0.5 then
					local side = if enemy.flank >= 0 then 1 else -1
					local direction = CFrame.Angles(0, math.rad(CIRCLE_STEP) * side, 0):VectorToWorldSpace(away.Unit)
					humanoid.WalkSpeed = enemy.walkSpeed * CIRCLE_SPEED
					humanoid:MoveTo(targetRoot.Position + direction * enemy.loadout.AttackRange * 0.85)
				end
			else
				humanoid:MoveTo(root.Position)
			end
			if player and targetHumanoid and targetRoot and os.clock() >= nextAttack then
				attack(enemy, player, targetHumanoid, targetRoot)
				-- Avec deux armes, les coups s'enchaînent plus vite.
				local cooldown = enemy.loadout.Cooldown / enemy.attackSpeed
				if #enemy.hands > 1 then
					cooldown *= DUAL_COOLDOWN_SCALE
				end
				nextAttack = os.clock() + cooldown
			end
		end

		-- La marche, la respiration et les réactions sont animées par chaque client, image par image
		-- (voir src/client/EnemyAnimator.client.luau) : le serveur ne pilote que les bras armés.

		lastPosition = root.Position
	end
end

---------------------------------------------------------------------------
-- Vagues
---------------------------------------------------------------------------

local function announce(text: string)
	local anchor = Instance.new("Part")
	anchor.Name = "Annonce"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(0, 14, 0)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(24, 6)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 215, 110)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	anchor.Parent = folder
	Debris:AddItem(anchor, 4)
end

-- Tire au sort une seconde arme pour la main gauche, ou nil.
-- Seules les armes à une main se portent par paire : ni l'épée longue ni la hache.
local function pickOffhand(weaponType: string, wave: number): string?
	if Config.Weapons[weaponType].TwoHanded or wave < DUAL_FIRST_WAVE then
		return nil
	end
	if random:NextNumber() >= DUAL_CHANCE then
		return nil
	end
	return OFFHAND_WEAPONS[random:NextInteger(1, #OFFHAND_WEAPONS)]
end

-- Niveau d'un bandit de la vague `wave` : le numéro de la vague, à LEVEL_SPREAD près.
-- La première vague reste au niveau 1.
local function pickLevel(wave: number): number
	if wave <= 1 then
		return 1
	end
	return math.clamp(wave + random:NextInteger(-LEVEL_SPREAD, LEVEL_SPREAD), 1, MAX_LEVEL)
end

local function spawnEnemy(position: Vector3, weaponType: string, wave: number, onGone: () -> ())
	local enemy = buildEnemy(position, pickLevel(wave), weaponType, pickOffhand(weaponType, wave))
	local gone = false
	local function finish()
		if gone then
			return
		end
		gone = true
		-- Le joueur qui l'a blessé en dernier gagne de l'expérience (rien s'il est tombé dans le vide).
		if enemy.humanoid.Health <= 0 then
			Progression.creditKill(enemy.model, enemy.xpLevels, enemy.root.Position)
		end
		onGone()
		Debris:AddItem(enemy.model, 3)
	end
	enemy.humanoid.Died:Connect(finish)
	-- Filet de sécurité : un bandit tombé dans le vide est supprimé par le moteur.
	enemy.model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			finish()
		end
	end)
	task.spawn(run, enemy)
end

---------------------------------------------------------------------------
-- Boss
---------------------------------------------------------------------------

-- Frappe au sol : un disque rouge s'étend sous le boss pendant qu'il lève son arme, puis l'onde part.
-- On l'évite en sortant du disque ou en sautant au bon moment.
local function groundSlam(enemy: Enemy)
	local root, humanoid = enemy.root, enemy.humanoid
	local hand = enemy.hands[1]
	-- Le sol est sous ses pieds : une demi-hauteur de torse plus la longueur des jambes.
	local ground = root.Position - Vector3.new(0, root.Size.Y / 2 + 2 * hand.scale - 0.15, 0)
	humanoid:MoveTo(root.Position)

	-- Avertissement : le disque grandit jusqu'au rayon de l'onde.
	local warning = Instance.new("Part")
	warning.Name = "ZoneDeFrappe"
	warning.Shape = Enum.PartType.Cylinder
	warning.Size = Vector3.new(0.15, 2, 2)
	warning.Color = Color3.fromRGB(255, 50, 40)
	warning.Material = Enum.Material.Neon
	warning.Transparency = 0.55
	warning.Anchored = true
	warning.CanCollide = false
	warning.CanQuery = false
	warning.CanTouch = false
	warning.CastShadow = false
	warning.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, QUARTER) -- cylindre couché à plat
	warning.Parent = folder
	local diameter = BOSS_SLAM_RADIUS * 2
	TweenService:Create(warning, TweenInfo.new(BOSS_SLAM_WINDUP, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.15, diameter, diameter),
	}):Play()

	-- L'arme monte lentement au-dessus de la tête pendant tout l'avertissement.
	moveArm(hand, { angle = 3, roll = 0, push = 0.2, wrist = WRIST_COCK }, BOSS_SLAM_WINDUP)
	enemy.model:SetAttribute("AttackLean", 1)
	hand.blade.Material = Enum.Material.Neon
	hand.blade.Color = Color3.fromRGB(255, 60, 40)
	task.wait(BOSS_SLAM_WINDUP)
	warning:Destroy()
	hand.blade.Material = Enum.Material.Metal
	hand.blade.Color = hand.bladeColor
	if humanoid.Health <= 0 then
		return
	end
	-- L'arme s'abat en accélérant.
	moveArm(hand, { angle = 0.2, push = -0.25, wrist = -WRIST_SNAP }, STRIKE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	enemy.model:SetAttribute("AttackLean", -1.2)
	task.wait(STRIKE_TIME)

	-- L'onde : une sphère aplatie qui se dilate, et les dégâts aux joueurs restés au sol dans le disque.
	local shock = Instance.new("Part")
	shock.Name = "OndeDeFrappe"
	shock.Shape = Enum.PartType.Ball
	shock.Size = Vector3.new(3, 3, 3)
	shock.Color = Color3.fromRGB(255, 120, 60)
	shock.Material = Enum.Material.Neon
	shock.Transparency = 0.4
	shock.Anchored = true
	shock.CanCollide = false
	shock.CanQuery = false
	shock.CanTouch = false
	shock.CastShadow = false
	shock.CFrame = CFrame.new(ground)
	shock.Parent = folder
	TweenService:Create(shock, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(diameter, diameter, diameter),
		Transparency = 1,
	}):Play()
	Debris:AddItem(shock, 0.45)
	Sfx.play("Block", ground, 1.5)

	local levelScale = 1 + DAMAGE_PER_LEVEL * (enemy.level - 1)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local targetHumanoid = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		if targetHumanoid and targetHumanoid.Health > 0 and targetRoot and targetRoot:IsA("BasePart") then
			local offset = targetRoot.Position - ground
			local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			-- Un joueur en l'air (saut) passe au-dessus de l'onde.
			local airborne = targetHumanoid.FloorMaterial == Enum.Material.Air and offset.Y > 4.5
			if flatDistance <= BOSS_SLAM_RADIUS and not airborne then
				targetHumanoid:TakeDamage(BOSS_SLAM_DAMAGE * levelScale * Progression.damageTakenMultiplier(player))
				Sfx.play("Hurt", targetRoot, 1)
				feedbackRemote:FireClient(player, "Left", 1, 0.3)
				feedbackRemote:FireClient(player, "Right", 1, 0.3)
			end
		end
	end

	task.wait(0.5)
	enemy.model:SetAttribute("AttackLean", 0)
	moveArm(hand, { angle = GUARD_ANGLE, roll = 0, push = 0, wrist = 0 }, GUARD_RETURN_TIME)
end

-- Fait apparaître le boss de la vague `wave`. `onGone` est appelé à sa mort.
local function spawnBoss(wave: number, onGone: () -> ())
	local cycle = math.max(math.floor(wave / BOSS_EVERY), 1)
	local level = math.clamp(wave, 1, MAX_LEVEL)
	local base = LOADOUTS[BOSS_WEAPON]
	local loadout: Loadout = {
		Damage = BOSS_DAMAGE,
		AttackRange = base.AttackRange * BOSS_SCALE,
		StrikeRange = base.StrikeRange * BOSS_SCALE,
		Windup = base.Windup,
		Cooldown = BOSS_COOLDOWN,
		WalkSpeed = BOSS_WALK_SPEED,
		Attacks = base.Attacks,
	}
	local enemy = buildEnemy(SPAWN_POINTS[1], level, BOSS_WEAPON, nil, {
		Name = BOSS_NAME,
		Scale = BOSS_SCALE,
		Health = math.round(BOSS_HEALTH * (1 + BOSS_HEALTH_PER_CYCLE * (cycle - 1))),
		Loadout = loadout,
	})
	enemy.xpLevels = level * BOSS_XP_MULTIPLIER

	local nextSlam = os.clock() + BOSS_SLAM_COOLDOWN / 2
	local summoned = false
	local enraged = false
	enemy.tick = function(self: Enemy)
		local humanoid, root = self.humanoid, self.root
		local ratio = humanoid.Health / humanoid.MaxHealth

		-- À mi-vie, il appelle des renforts.
		if not summoned and ratio <= 0.5 then
			summoned = true
			announce(BOSS_NAME .. " appelle des renforts !")
			for i = 1, BOSS_MINIONS do
				local side = if i % 2 == 0 then 1 else -1
				local position = root.Position * Vector3.new(1, 0, 1) + root.CFrame.RightVector * side * (5 + i)
				spawnEnemy(position, WEAPON_ORDER[random:NextInteger(1, #WEAPON_ORDER)], math.max(wave - 2, 1), function() end)
			end
		end

		-- Presque vaincu, il entre en rage : plus rapide, jusqu'à la fin.
		if not enraged and ratio <= 0.3 then
			enraged = true
			announce(BOSS_NAME .. " entre en rage !")
			self.attackSpeed *= BOSS_ENRAGE_SPEED
			self.walkSpeed *= 1.25
			local aura = self.model:FindFirstChild("AuraBoss")
			if aura and aura:IsA("Highlight") then
				aura.FillColor = Color3.fromRGB(255, 40, 30)
				aura.FillTransparency = 0.7
			end
		end

		-- Frappe au sol, quand un joueur est assez près pour être menacé.
		if os.clock() >= nextSlam then
			local _, _, _, distance = nearestPlayer(root.Position)
			if distance <= BOSS_SLAM_RADIUS + 4 then
				groundSlam(self)
				local cooldown = BOSS_SLAM_COOLDOWN
				if enraged then
					cooldown *= 0.7
				end
				nextSlam = os.clock() + cooldown
			end
		end
	end

	local gone = false
	local function finish()
		if gone then
			return
		end
		gone = true
		if enemy.humanoid.Health <= 0 then
			Progression.creditKill(enemy.model, enemy.xpLevels, enemy.root.Position)
		end
		onGone()
		Debris:AddItem(enemy.model, 4)
	end
	enemy.humanoid.Died:Connect(finish)
	enemy.model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			finish()
		end
	end)
	task.spawn(run, enemy)
end

-- `feedback` : RemoteEvent qui fait vibrer la manette du joueur quand il bloque ou pare.
function Enemies.init(weapons: Instance, feedback: RemoteEvent)
	weaponsFolder = weapons
	feedbackRemote = feedback
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	-- Les tenues se chargent en arrière-plan : elles sont prêtes avant la première vague.
	loadOutfits()
end

-- Lance les vagues. Sans effet si elles tournent déjà.
function Enemies.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		local wave = 0
		while true do
			wave += 1
			announce("Vague " .. wave)
			task.wait(2)

			local count = math.min(wave, MAX_ENEMIES)
			local alive = count
			for i = 1, count do
				-- Premières vagues : une arme de plus à chaque vague. Ensuite : au hasard.
				local weaponType
				if wave <= #WEAPON_ORDER then
					-- Le premier bandit porte l'arme nouvelle de la vague, les suivants les précédentes.
					weaponType = WEAPON_ORDER[wave - (i - 1) % wave]
				else
					weaponType = WEAPON_ORDER[random:NextInteger(1, #WEAPON_ORDER)]
				end
				spawnEnemy(SPAWN_POINTS[i], weaponType, wave, function()
					alive -= 1
				end)
				task.wait(0.4)
			end

			while alive > 0 do
				task.wait(0.5)
			end

			-- Un boss clôt chaque cycle de vagues.
			if wave % BOSS_EVERY == 0 then
				task.wait(3)
				announce("首领 · " .. BOSS_NAME)
				task.wait(2.5)
				local bossAlive = true
				spawnBoss(wave, function()
					bossAlive = false
				end)
				while bossAlive do
					task.wait(0.5)
				end
				announce(BOSS_NAME .. " est vaincu !")
				task.wait(4)
			end
			task.wait(WAVE_PAUSE)
		end
	end)
end

return Enemies

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
local Ragdoll = require(script.Parent:WaitForChild("Ragdoll"))
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

-- Classes de bandits. Chacune a ses armes, ses tenues (table OUTFITS), ses corps et ses forces.
--   MinWave       : première vague où elle apparaît (le premier ennemi de cette vague en est un)
--   Weight        : poids au tirage dans sa première vague ; WeightPerWave l'ajuste à chaque vague
--   Weapons       : armes possibles, avec leur poids au tirage et leur vague d'apparition
--   DualChance    : probabilité de porter une seconde arme (armes à une main seulement), tirée dans Offhand
--   *Scale        : multiplicateurs de points de vie, dégâts, vitesse d'attaque, vitesse de marche, expérience
--   StrawHat      : chapeau de paille quand la tenue n'a ni masque ni casque
--   Bodies        : noms des corps réalistes (BODY_SHAPES) qu'elle peut avoir ; tous si absent
type WeaponChoice = { Weapon: string, Weight: number, MinWave: number? }
type EnemyClass = {
	Id: string,
	Name: string,
	MinWave: number,
	Weight: number,
	WeightPerWave: number,
	Weapons: { WeaponChoice },
	DualChance: number,
	Offhand: { string }?,
	HealthScale: number,
	DamageScale: number,
	AttackSpeedScale: number,
	WalkSpeedScale: number,
	XpScale: number,
	DashRate: number, -- fréquence des dashs (1 = normale, 0 = jamais)
	StrawHat: boolean,
	Bodies: { string }?,
}

local CLASSES: { EnemyClass } = {
	-- Paysans enrôlés de force : outils de la ferme, peu de vie, coups lents et faibles.
	-- Nombreux au début, de plus en plus rares ensuite.
	{
		Id = "Fermier", Name = "Fermier", MinWave = 1, Weight = 4, WeightPerWave = -0.4,
		Weapons = {
			{ Weapon = "Baton", Weight = 3 },
			{ Weapon = "Dague", Weight = 1 },
			{ Weapon = "Hache", Weight = 2, MinWave = 3 },
		},
		DualChance = 0,
		HealthScale = 0.8, DamageScale = 0.8, AttackSpeedScale = 0.9, WalkSpeedScale = 0.95, XpScale = 0.75,
		DashRate = 0.35, -- un paysan ne sait guère esquiver
		StrawHat = true,
		Bodies = { "Homme", "Corps de base 2" },
	},
	-- Bretteurs et soldats déserteurs : épées et armes d'hast, parfois une seconde lame.
	{
		Id = "Combattant", Name = "Combattant", MinWave = 2, Weight = 3, WeightPerWave = 0.2,
		Weapons = {
			{ Weapon = "Epee", Weight = 3 },
			{ Weapon = "Sabre", Weight = 3 },
			{ Weapon = "Lance", Weight = 2, MinWave = 4 },
			{ Weapon = "EpeeLongue", Weight = 2, MinWave = 5 },
			{ Weapon = "Guandao", Weight = 1, MinWave = 7 },
		},
		DualChance = 0.4,
		Offhand = { "Epee", "Sabre" },
		HealthScale = 1, DamageScale = 1, AttackSpeedScale = 1, WalkSpeedScale = 1, XpScale = 1,
		DashRate = 1,
		StrawHat = true,
	},
	-- Moines guerriers : le bâton avant tout, résistants et vifs, mais frappent moins fort. Crâne rasé.
	{
		Id = "Moine", Name = "Moine", MinWave = 3, Weight = 2, WeightPerWave = 0.15,
		Weapons = {
			{ Weapon = "Baton", Weight = 4 },
			{ Weapon = "Lance", Weight = 1, MinWave = 5 },
		},
		DualChance = 0,
		HealthScale = 1.15, DamageScale = 0.9, AttackSpeedScale = 1.15, WalkSpeedScale = 1.1, XpScale = 1.2,
		DashRate = 1.2,
		StrawHat = false,
		Bodies = { "Corps de base 1", "Corps de base 2" },
	},
	-- Assassins masqués : dagues, souvent une dans chaque main. Fragiles, mais très rapides.
	{
		Id = "Assassin", Name = "Assassin", MinWave = 4, Weight = 1.5, WeightPerWave = 0.15,
		Weapons = {
			{ Weapon = "Dague", Weight = 3 },
			{ Weapon = "Sabre", Weight = 1 },
		},
		DualChance = 0.75,
		Offhand = { "Dague" },
		HealthScale = 0.75, DamageScale = 1.1, AttackSpeedScale = 1.25, WalkSpeedScale = 1.2, XpScale = 1.1,
		DashRate = 2, -- toujours en mouvement
		StrawHat = false,
		Bodies = { "Corps de base 1", "Corps de base 2" },
	},
}

local CLASS_BY_ID: { [string]: EnemyClass } = {}
for _, class in CLASSES do
	CLASS_BY_ID[class.Id] = class
end
local BOSS_CLASS = "Combattant" -- le boss porte la tenue la plus prestigieuse de cette classe

-- Bandits à deux armes : seuls ceux dont l'arme principale se tient à une main.
local DUAL_FIRST_WAVE = 2 -- pas de bandit à deux armes avant cette vague
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
-- Vitesse d'attaque de départ des bandits ordinaires (le boss garde la sienne) : ×1,3 = armement
-- et temps entre deux attaques environ 23 % plus courts. Se cumule avec le bonus de niveau.
local BASE_ATTACK_SPEED = 1.3
local DAMAGE_PER_LEVEL = 0.1 -- +10 % de dégâts par niveau (niveau 10 : ×1,9)
local MIN_WINDUP = 0.25 -- temps d'armement minimal (s), pour que le coup reste lisible
local PARRY_DISTANCE = 3.5 -- distance entre les deux lames pour que la parade compte
local STAGGER_TIME = 1.2 -- temps pendant lequel un bandit paré reste sonné
-- Parade parfaite : le joueur frappe activement le sabre au moment où le coup part,
-- au lieu de simplement laisser sa lame sur la trajectoire.
local PERFECT_WINDOW = 0.15 -- durée (s) avant le coup pendant laquelle la lame du bandit devient blanche
local PERFECT_PARRY_SPEED = 12 -- vitesse minimale (studs/s) de la lame du joueur pendant cette fenêtre
local PERFECT_PARRY_DAMAGE = 20 -- dégâts renvoyés au bandit
local PERFECT_STAGGER_TIME = 0.6 -- temps pendant lequel le bandit reste sonné et vulnérable
local SHIELD_BLOCK_DISTANCE = 4.5 -- distance entre le bouclier et le sabre pour que le blocage compte
local SHIELD_STAGGER_TIME = 0.5 -- un blocage au bouclier sonne moins longtemps qu'une parade
local MAX_ENEMIES = 5
local WAVE_PAUSE = 6

-- Tenues du catalogue Roblox portées par les bandits. Chaque bandit en tire une de sa classe au hasard.
--   Class        : classe qui porte cette tenue (voir CLASSES)
--   Shirt, Pants : numéros des vêtements (le nombre dans l'adresse de la page du catalogue)
--   Hat          : couvre-chef du catalogue ; sans lui, le bandit garde le chapeau de paille si sa classe en porte
--   Face         : accessoire de visage
--   MinLevel     : niveau minimal du bandit pour porter cette tenue
-- Mettre USE_CATALOG_OUTFITS à false pour revenir aux bandits en blocs.
local USE_CATALOG_OUTFITS = true

type Outfit = {
	Name: string,
	Class: string,
	Shirt: number,
	Pants: number,
	Hat: number?,
	Face: number?,
	MinLevel: number?,
	Custom: boolean?, -- modèle 3D importé (ServerStorage.BanditModels) plutôt que tenue du catalogue
}

local OUTFITS: { Outfit } = {
	-- Fermiers : habits de paysan (haut « + » et bas « - » d'un même créateur), sous le chapeau de paille.
	{ Name = "Paysan", Class = "Fermier", Shirt = 9313401861, Pants = 9313405331 }, -- « Paysan » (Winterhall)
	{ Name = "Paysan en toile", Class = "Fermier", Shirt = 4972468540, Pants = 4972371861 }, -- « Vêtements de paysan »
	{ Name = "Paysan rapiécé", Class = "Fermier", Shirt = 4646368942, Pants = 4646372722 }, -- « Paysan » (Blotnik)

	-- Combattants.
	-- « Black Samurai Robes with armored sleeves » + « Samurai (Shogun) Pants »
	{ Name = "Rônin noir", Class = "Combattant", Shirt = 6523934448, Pants = 5666905795 },
	-- « White Samurai Robe » (haut et bas)
	{ Name = "Robe blanche", Class = "Combattant", Shirt = 6238966041, Pants = 6940703426 },
	-- « Foggy White & Grey Kimono » (haut et bas) + « Deluxe Bandit Mask » (Roblox)
	{ Name = "Brigand masqué", Class = "Combattant", Shirt = 7456262449, Pants = 7456298584, Face = 93050572 },
	-- « Classic Shadow Black Ninja Old Samurai Assassin » (haut et bas) + « Samurai Helmet » (Roblox)
	{ Name = "Capitaine", Class = "Combattant", Shirt = 9572711986, Pants = 9572709674, Hat = 8569514, MinLevel = 6 },

	-- Moines : robes « Moine Shaolin » (Dimbo's Apparel), la rouge pour les plus aguerris.
	{ Name = "Moine safran", Class = "Moine", Shirt = 120586814747060, Pants = 128745458661099 },
	{ Name = "Moine brun", Class = "Moine", Shirt = 111462365570728, Pants = 82924987994787 },
	{ Name = "Moine gris", Class = "Moine", Shirt = 128076986857660, Pants = 86720590692463 },
	{ Name = "Moine rouge", Class = "Moine", Shirt = 113215206048423, Pants = 81801145364561, MinLevel = 6 },

	-- Assassins.
	-- « Ninja Suit of Darkness » + « Ninja Pants of Darkness » + « Ninja Mask of Shadows » (Roblox)
	{ Name = "Ombre", Class = "Assassin", Shirt = 11404365, Pants = 11404375, Hat = 1309911 },
	-- « Classic Roblox OG Red Ninja » (haut et bas) + « Ninja Mask of Fire » (Roblox)
	{ Name = "Assassin rouge", Class = "Assassin", Shirt = 7743066694, Pants = 9572296500, Hat = 124745856, MinLevel = 6 },
}

-- Corps réalistes (R15, membres arrondis et visage animé) sur lesquels on enfile les tenues.
-- Tous publiés par Roblox lui-même : ils ne disparaîtront pas du catalogue. Les numéros sont ceux
-- des pièces du corps (pas du lot), relevés sur la page de chaque lot du catalogue.
-- Chaque tenue est préparée sur chaque corps : un même habit peut apparaître sur deux silhouettes.
-- Mettre USE_REALISTIC_BODIES à false pour revenir aux personnages R6 (carrés).
local USE_REALISTIC_BODIES = true

type BodyShape = {
	Name: string,
	Head: number,
	Torso: number,
	LeftArm: number,
	RightArm: number,
	LeftLeg: number,
	RightLeg: number,
	Mood: number?, -- animation du visage
	Eyebrows: number?,
	BodyTypeScale: number?, -- 0 = proportions classiques, 1 = proportions réalistes
	ProportionScale: number?, -- 0 = carrure large, 1 = élancée
	HeightScale: number?,
	WidthScale: number?,
}

-- Visage d'homme animé (lot « Visage d'homme », Roblox).
local MAN_HEAD, MAN_MOOD, MAN_BROWS = 10725826963, 10725833199, 10725837187

local BODY_SHAPES: { BodyShape } = {
	-- Lot « Homme » (Roblox, gratuit)
	{
		Name = "Homme",
		Head = MAN_HEAD, Mood = MAN_MOOD, Eyebrows = MAN_BROWS,
		Torso = 86500008, LeftArm = 86500054, RightArm = 86500036, LeftLeg = 86500064, RightLeg = 86500078,
	},
	-- Lot « Corps de base - Charlie » (Roblox, gratuit), avec le visage d'homme
	{
		Name = "Corps de base 1",
		Head = MAN_HEAD, Mood = MAN_MOOD, Eyebrows = MAN_BROWS,
		Torso = 11572083496, LeftArm = 11572074613, RightArm = 11572079320, LeftLeg = 11572076845, RightLeg = 11572081357,
		BodyTypeScale = 1, ProportionScale = 0,
	},
	-- Lot « Corps de base - Parker » (Roblox, gratuit), avec le visage d'homme
	{
		Name = "Corps de base 2",
		Head = MAN_HEAD, Mood = MAN_MOOD, Eyebrows = MAN_BROWS,
		Torso = 11584241181, LeftArm = 11584231502, RightArm = 11584238141, LeftLeg = 11584235843, RightLeg = 11584239464,
		BodyTypeScale = 1, ProportionScale = 0, WidthScale = 1.05,
	},
}

-- Modèles 3D importés (personnages Sketchfab préparés avec tools/blender, puis passés dans
-- Avatar Setup de Studio). Ils sont rangés dans ServerStorage → dossier BanditModels :
--   - un modèle nommé d'après une classe (« Fermier », « Combattant », « Moine », « Assassin »),
--     ou un dossier à ce nom contenant plusieurs modèles (le bandit en tire un au hasard) ;
--   - un modèle (ou dossier) « Boss » pour le Seigneur de guerre.
-- Chaque modèle doit être un personnage R15 complet : Humanoid, HumanoidRootPart, Head, LeftHand,
-- RightHand et les articulations LeftShoulder et RightShoulder (c'est ce que produit Avatar Setup).
-- Un modèle incomplet est ignoré, avec un avertissement dans la fenêtre Sortie.
-- Une classe qui a un modèle 3D ne porte plus que lui si PREFER_CUSTOM_MODELS est vrai ;
-- sinon il s'ajoute aux tenues du catalogue au tirage. Les classes sans modèle gardent leurs tenues.
local USE_CUSTOM_MODELS = true
local PREFER_CUSTOM_MODELS = true
local CUSTOM_MODELS_FOLDER = "BanditModels"
local CUSTOM_BOSS_NAME = "Boss"
-- Taille des modèles 3D, du dessous des pieds au sommet de la tête (studs). Un corps réaliste
-- du catalogue mesure environ 5,6 studs ; les décors au-dessus de la tête (étendards) ne comptent pas.
local CUSTOM_MODEL_HEIGHT = 5.6

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

-- Dash : une brusque accélération au ras du sol, sur quelques mètres. Trois usages :
--   ruée      : il comble d'un coup la distance qui le sépare du joueur ;
--   esquive   : touché, il bondit en arrière (en biais) pour reprendre ses distances ;
--   pas chassé : en tournant autour du joueur, il fait un brusque écart de côté.
-- Les chances sont tirées à chaque tour de boucle (0,12 s), multipliées par la fréquence de la classe.
local DASH_SPEED = 55 -- studs/s
local DASH_DISTANCE = 12 -- distance maximale d'un dash (studs)
local DASH_COOLDOWN = 3.5 -- délai minimal entre deux dashs (secondes, divisé par la fréquence de la classe)
local DASH_CLOSE_MIN_GAP = 7 -- ruée : seulement s'il est au moins à cette distance au-delà de sa portée
local DASH_CLOSE_MAX_DISTANCE = 26 -- ruée : pas plus loin que cela du joueur
local DASH_CLOSE_CHANCE = 0.1
local DASH_SIDE_CHANCE = 0.04
local DASH_DODGE_CHANCE = 0.4 -- juste après avoir été touché
local DASH_SIDE_DISTANCE = 7
-- Dashs latéraux :
--   esquive réflexe : une lame de joueur arrive vite tout près de lui, il s'écarte du côté opposé ;
--   zigzag          : en approchant, il fait des écarts de côté (en avançant un peu) pour être
--                     plus difficile à cueillir.
local DASH_EVADE_CHANCE = 0.3
local DASH_EVADE_BLADE_SPEED = 18 -- vitesse de lame (studs/s) qu'il perçoit comme une menace
local DASH_EVADE_RANGE = 8 -- distance de la lame à son corps (studs)
local DASH_ZIGZAG_CHANCE = 0.06
local DASH_ZIGZAG_DISTANCE = 8
local DASH_ZIGZAG_FORWARD = 0.5 -- part d'avancée dans un écart de zigzag (0 = purement latéral)
local DASH_DODGE_DISTANCE = 9
local BOSS_DASH_RATE = 0.5

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
	damageScale: number, -- multiplicateur de dégâts de sa classe
	dashRate: number, -- fréquence de ses dashs (voir DASH_* et DashRate des classes)
	tick: ((Enemy) -> ())?, -- comportement propre (attaques spéciales du boss), appelé à chaque tour de boucle
}

-- Une main armée et son arme.
type Hand = {
	side: number, -- 1 = main droite, -1 = main gauche (les gestes sont en miroir)
	scale: number, -- taille du bandit : les articulations d'un géant sont plus écartées
	arm: Motor6D,
	wrist: Weld, -- soudure du manche dans la main : la faire tourner oriente la lame
	gripOffset: number,
	-- Corps R15 : position de l'épaule dans le haut du buste (taille 1). nil pour un corps R6.
	pivot: Vector3?,
	gripY: number, -- hauteur du manche par rapport au centre de la pièce qui le tient (bras R6 ou main R15)
	blade: Part, -- la pièce tranchante de l'arme (zone de frappe invisible)
	-- Acier visible de la lame, avec son aspect d'origine : il s'illumine pendant les attaques.
	glow: { [BasePart]: { color: Color3, material: Enum.Material } },
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
-- `gripY` : hauteur de la prise par rapport au centre de la pièce tenue (-0,9 dans un bras R6).
local R6_GRIP_Y = -0.9
local function gripC0(gripOffset: number, wrist: number, scale: number?, gripY: number?): CFrame
	local s = scale or 1
	return CFrame.new(0, (gripY or R6_GRIP_Y) * s, 0) * CFrame.Angles(-QUARTER + wrist, 0, 0) * CFrame.new(0, -gripOffset * s, 0)
end

-- Attache côté bras de l'épaule R6, droite puis gauche. Les gestes sont calculés pour un corps R6 ;
-- pour un corps R15, on en tire l'orientation du bras par rapport au buste, que l'on rapporte à son épaule.
local R6_ARM_C1_INVERSE = {
	[1] = (CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, QUARTER, 0)):Inverse(),
	[-1] = (CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -QUARTER, 0)):Inverse(),
}

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
	local c0 = shoulderC0(hand.side, pose.roll, pose.push, hand.scale) * CFrame.Angles(0, 0, hand.side * pose.angle)
	local pivot = hand.pivot
	if pivot then
		-- Corps R15 : même orientation du bras que le geste R6, autour de la vraie épaule.
		-- Le bras R15 au repos pend le long du buste sans rotation, comme le bras R6 à angle nul.
		local s = hand.scale
		local rotation = (c0 * R6_ARM_C1_INVERSE[hand.side]).Rotation
		c0 = CFrame.new(pivot * s + Vector3.new(0, 0, pose.push * s)) * rotation * hand.arm.C1.Rotation
	end
	hand.arm.C0 = c0
	hand.wrist.C0 = gripC0(hand.gripOffset, pose.wrist, hand.scale, hand.gripY)
end

-- Illumine l'acier de la lame (couleur donnée), ou lui rend son aspect d'origine (nil).
local function setGlow(hand: Hand, color: Color3?)
	for part, original in hand.glow do
		part.Material = if color then Enum.Material.Neon else original.material
		part.Color = color or original.color
	end
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
-- `grip` : la pièce qui tient l'arme (le bras R6, ou la main R15).
-- `pivot`, `gripY` : voir le type Hand.
local function equip(model: Model, grip: BasePart, shoulder: Motor6D, side: number, weaponType: string, pivot: Vector3?, gripY: number): Hand
	local def = Config.Weapons[weaponType]
	local loadout = LOADOUTS[weaponType]
	assert(def and loadout, "Arme de bandit inconnue : " .. weaponType)

	local handle = accessory("Manche", Vector3.new(0.28, def.HandleLength, 0.28), def.HandleColor or Config.HANDLE_WOOD, def.HandleMaterial or Enum.Material.Wood, grip, gripC0(def.GripOffset, 0, 1, gripY), model)
	handle.Transparency = 1 -- le manche rond visible est la pièce « Fut » de Config
	local wrist = handle:FindFirstChildOfClass("Weld") :: Weld
	local blade: Part? = nil
	local glow = {}
	for _, info in def.Parts do
		local offset = CFrame.new(info.Offset) * (info.Rotation or CFrame.new())
		local part = accessory(info.Name, info.Size, info.Color, info.Material, handle, offset, model, info.Wedge)
		part.Reflectance = info.Reflectance or 0
		part.Transparency = if info.Hidden then 1 else 0
		if info.Shape and not info.Wedge then
			part.Shape = info.Shape
		end
		if info.Blade and not blade then
			blade = part
		end
		if info.Glow or (info.Blade and not info.Hidden) then
			glow[part] = { color = part.Color, material = part.Material }
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
		pivot = pivot,
		gripY = gripY,
		blade = blade,
		glow = glow,
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
	leftGrip: BasePart, -- pièce qui tient l'arme : le bras (R6) ou la main (R15)
	rightGrip: BasePart,
	leftShoulder: Motor6D,
	rightShoulder: Motor6D,
	leftPivot: Vector3?, -- position des épaules dans le haut du buste (R15 seulement)
	rightPivot: Vector3?,
	gripY: number, -- hauteur de la prise par rapport au centre de la pièce qui tient l'arme
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
	-- Visage classique livré avec Roblox, pour qu'un corps de secours ne soit jamais sans visage.
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	local leftArm = limb("Left Arm", Vector3.new(1, 2, 1), ROBE, model)
	local rightArm = limb("Right Arm", Vector3.new(1, 2, 1), ROBE, model)
	local leftLeg = limb("Left Leg", Vector3.new(1, 2, 1), TROUSERS, model)
	local rightLeg = limb("Right Leg", Vector3.new(1, 2, 1), TROUSERS, model)

	joint("RootJoint", root, torso, CFrame.new(), CFrame.new())
	joint("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.6, 0))
	local rightShoulder = joint("Right Shoulder", torso, rightArm, shoulderC0(1, 0, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, QUARTER, 0))
	local leftShoulder = joint("Left Shoulder", torso, leftArm, shoulderC0(-1, 0, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -QUARTER, 0))
	joint("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0) * CFrame.Angles(0, QUARTER, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, QUARTER, 0))
	joint("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0) * CFrame.Angles(0, -QUARTER, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -QUARTER, 0))

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
		leftGrip = leftArm,
		rightGrip = rightArm,
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		leftPivot = nil,
		rightPivot = nil,
		gripY = R6_GRIP_Y,
		strawHat = true,
	}
end

-- Modèles habillés, fabriqués une seule fois puis copiés à chaque apparition : pour chaque tenue,
-- un modèle par corps réaliste (ou un seul personnage R6 si les corps réalistes sont désactivés).
local outfitTemplates: { [Outfit]: { Model } } = {}
local readyOutfits: { Outfit } = {}

-- `withBrows` : ajoute les sourcils du corps (accessoire). Sans effet si le corps n'en a pas.
local function describe(outfit: Outfit, shape: BodyShape?, withBrows: boolean): HumanoidDescription
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
	if shape then
		description.Head = shape.Head
		description.Torso = shape.Torso
		description.LeftArm = shape.LeftArm
		description.RightArm = shape.RightArm
		description.LeftLeg = shape.LeftLeg
		description.RightLeg = shape.RightLeg
		description.MoodAnimation = shape.Mood or 0
		description.BodyTypeScale = shape.BodyTypeScale or description.BodyTypeScale
		description.ProportionScale = shape.ProportionScale or description.ProportionScale
		description.HeightScale = shape.HeightScale or 1
		description.WidthScale = shape.WidthScale or 1

		-- Les sourcils n'ont pas de propriété dédiée : ils s'ajoutent à la liste des accessoires,
		-- avec le chapeau et le masque déjà déclarés ci-dessus.
		if withBrows and shape.Eyebrows then
			local brows = shape.Eyebrows
			pcall(function()
				local accessories = description:GetAccessories(true)
				table.insert(accessories, {
					AssetId = brows,
					AccessoryType = Enum.AccessoryType.Eyebrow,
					IsLayered = false,
				})
				-- SetAccessories exige un ordre pour chaque accessoire (sinon : « Input table missing Order! »).
				for index, entry in accessories do
					if entry.Order == nil then
						entry.Order = index
					end
				end
				description:SetAccessories(accessories, true)
			end)
		end
	end
	return description
end

-- Ajoute un modèle prêt pour une tenue ; la tenue devient tirable dès son premier modèle.
local function addTemplate(outfit: Outfit, model: Model)
	local list = outfitTemplates[outfit]
	if not list then
		list = {}
		outfitTemplates[outfit] = list
		table.insert(readyOutfits, outfit)
	end
	table.insert(list, model)
end

-- Demande à Roblox un personnage portant chaque tenue, sur chaque corps. L'appel télécharge
-- les vêtements et le corps : il prend un instant et peut échouer (objet retiré, pas de connexion).
local function loadOutfits()
	if not USE_CATALOG_OUTFITS then
		return
	end
	for _, outfit in OUTFITS do
		-- Corps réalistes permis à la classe de la tenue (tous si elle n'en précise pas).
		local class = CLASS_BY_ID[outfit.Class]
		local shapes: { BodyShape | false } = {}
		if USE_REALISTIC_BODIES then
			for _, shape in BODY_SHAPES do
				if not (class and class.Bodies) or table.find(class.Bodies, shape.Name) then
					table.insert(shapes, shape)
				end
			end
		end
		if #shapes == 0 then
			shapes = { false }
		end
		for _, shape in shapes do
			task.spawn(function()
				local realistic = if shape then shape else nil
				local rigType = if realistic then Enum.HumanoidRigType.R15 else Enum.HumanoidRigType.R6
				local function create(withBrows: boolean)
					return pcall(function()
						return Players:CreateHumanoidModelFromDescription(describe(outfit, realistic, withBrows), rigType)
					end)
				end
				local ok, result = create(true)
				if not ok and realistic and realistic.Eyebrows then
					-- Les sourcils ne doivent pas coûter le corps entier : on réessaie sans eux.
					ok, result = create(false)
				end
				if ok and result then
					addTemplate(outfit, result)
				else
					local label = outfit.Name .. (if realistic then " / " .. realistic.Name else "")
					warn("[Enemies] Tenue « " .. label .. " » indisponible : " .. tostring(result))
				end
			end)
		end
	end
end

-- Tire une tenue prête de la classe, parmi celles que le niveau du bandit autorise, ou nil s'il n'y en a pas.
-- Avec PREFER_CUSTOM_MODELS, une classe qui a un modèle 3D prêt ne tire que parmi ses modèles 3D.
local function pickOutfit(level: number, classId: string): Outfit?
	local candidates, custom = {}, {}
	for _, outfit in readyOutfits do
		if outfit.Class == classId and level >= (outfit.MinLevel or 1) then
			table.insert(candidates, outfit)
			if outfit.Custom then
				table.insert(custom, outfit)
			end
		end
	end
	if PREFER_CUSTOM_MODELS and #custom > 0 then
		candidates = custom
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[random:NextInteger(1, #candidates)]
end

-- La tenue du boss : son modèle 3D (« Boss ») s'il y en a un de prêt, sinon la tenue prête de la
-- classe qui demande le niveau le plus élevé, ou nil.
local function bestOutfit(classId: string): Outfit?
	local bossModels = {}
	for _, outfit in readyOutfits do
		if outfit.Custom and outfit.Class == CUSTOM_BOSS_NAME then
			table.insert(bossModels, outfit)
		end
	end
	if #bossModels > 0 then
		return bossModels[random:NextInteger(1, #bossModels)]
	end
	local best: Outfit? = nil
	for _, outfit in readyOutfits do
		if outfit.Class == classId and (not best or (outfit.MinLevel or 1) > (best.MinLevel or 1)) then
			best = outfit
		end
	end
	return best
end

local function findMotor(model: Model, name: string): Motor6D?
	for _, item in model:GetDescendants() do
		if item.Name == name and item:IsA("Motor6D") then
			return item
		end
	end
	return nil
end

local function findPart(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- Copie un personnage habillé d'une tenue (sur un corps tiré au hasard) et y retrouve les
-- articulations dont le combat a besoin. Renvoie nil si le modèle n'a pas la forme attendue.
local function dressedBody(outfit: Outfit): Body?
	local templates = outfitTemplates[outfit]
	if not templates or #templates == 0 then
		return nil
	end
	local model = templates[random:NextInteger(1, #templates)]:Clone()
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
	local head = findPart(model, "Head")
	local r15 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R15

	-- R15 : l'arme est soudée dans la main, et le bras entier (haut, avant-bras, main) suit l'épaule.
	-- R6 : l'arme est soudée au bras d'une seule pièce.
	local leftGrip = findPart(model, if r15 then "LeftHand" else "Left Arm")
	local rightGrip = findPart(model, if r15 then "RightHand" else "Right Arm")
	local leftShoulder = findMotor(model, if r15 then "LeftShoulder" else "Left Shoulder")
	local rightShoulder = findMotor(model, if r15 then "RightShoulder" else "Right Shoulder")

	if not (humanoid and root and root:IsA("Part") and head and leftGrip and rightGrip and leftShoulder and rightShoulder) then
		model:Destroy()
		return nil
	end

	local leftPivot, rightPivot, gripY = nil, nil, R6_GRIP_Y
	if r15 then
		-- Position d'origine des épaules, que les gestes reprennent comme point de rotation.
		leftPivot = leftShoulder.C0.Position
		rightPivot = rightShoulder.C0.Position
		-- Le manche passe dans la paume, un peu sous le centre de la main.
		gripY = -rightGrip.Size.Y * 0.2
		-- Coudes et poignets droits : le bras reste tendu, comme un bras R6.
		for _, name in { "LeftElbow", "RightElbow", "LeftWrist", "RightWrist" } do
			local motor = findMotor(model, name)
			if motor then
				motor.Transform = CFrame.new()
			end
		end
	else
		-- Mêmes réglages d'articulations que le corps en blocs.
		leftShoulder.C0 = shoulderC0(-1, 0, 0)
		rightShoulder.C0 = shoulderC0(1, 0, 0)
	end
	root.CanQuery = false

	return {
		model = model,
		humanoid = humanoid,
		root = root,
		head = head,
		leftGrip = leftGrip,
		rightGrip = rightGrip,
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		leftPivot = leftPivot,
		rightPivot = rightPivot,
		gripY = gripY,
		-- Pas de chapeau de paille par-dessus un masque, un casque ou un modèle 3D (il a sa propre tête).
		strawHat = outfit.Hat == nil and not outfit.Custom,
	}
end

-- Prépare la copie d'un modèle 3D importé : pièces libres (Studio ancre les maillages importés),
-- taille ramenée à CUSTOM_MODEL_HEIGHT, hauteur des hanches recalculée. Renvoie nil s'il n'est pas utilisable.
local function prepareCustomModel(source: Model): (Model?, string?)
	local model = source:Clone()
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = false
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = findPart(model, "Head")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		model:Destroy()
		return nil, "pas de Humanoid R15 (passe le modèle dans Avatar Setup)"
	end
	if not (root and root:IsA("BasePart") and head) then
		model:Destroy()
		return nil, "il manque HumanoidRootPart ou Head"
	end
	model.PrimaryPart = root

	-- Hauteur du corps seul : du dessous des pieds au sommet de la tête.
	local function feetBottom(): number
		local bottom = math.huge
		for _, name in { "LeftFoot", "RightFoot" } do
			local foot = findPart(model, name)
			if foot then
				bottom = math.min(bottom, foot.Position.Y - foot.Size.Y / 2)
			end
		end
		if bottom == math.huge then
			local cframe, size = model:GetBoundingBox()
			bottom = cframe.Position.Y - size.Y / 2
		end
		return bottom
	end
	local height = head.Position.Y + head.Size.Y / 2 - feetBottom()
	if height <= 0.1 then
		model:Destroy()
		return nil, "taille illisible (tête sous les pieds ?)"
	end
	model:ScaleTo(model:GetScale() * CUSTOM_MODEL_HEIGHT / height)

	-- R15 : la hauteur des hanches est l'écart entre le bas du HumanoidRootPart et le sol.
	humanoid.HipHeight = math.max(0, root.Position.Y - root.Size.Y / 2 - feetBottom())
	return model, nil
end

-- Charge les modèles 3D de ServerStorage.BanditModels comme des tenues à part entière.
-- Chaque modèle est essayé une fois : s'il n'a pas la forme attendue, il est écarté avec un avertissement.
local function loadCustomModels()
	if not USE_CUSTOM_MODELS then
		return
	end
	local container = game:GetService("ServerStorage"):FindFirstChild(CUSTOM_MODELS_FOLDER)
	if not container then
		print("[Enemies] Pas de dossier ServerStorage." .. CUSTOM_MODELS_FOLDER .. " : les bandits gardent les tenues du catalogue.")
		return
	end
	local loaded: { string } = {}
	for _, entry in container:GetChildren() do
		local classId = entry.Name
		if classId ~= CUSTOM_BOSS_NAME and not CLASS_BY_ID[classId] then
			warn("[Enemies] Modèle 3D « " .. classId .. " » ignoré : le nom doit être une classe (Fermier, Combattant, Moine, Assassin) ou Boss")
			continue
		end
		local sources = if entry:IsA("Model") then { entry } else entry:GetChildren()
		for _, source in sources do
			if not source:IsA("Model") then
				continue
			end
			local label = classId .. " / " .. source.Name
			local model, problem = prepareCustomModel(source)
			if not model then
				warn("[Enemies] Modèle 3D « " .. label .. " » ignoré : " .. tostring(problem))
				continue
			end
			local outfit: Outfit = { Name = "Modèle 3D " .. source.Name, Class = classId, Shirt = 0, Pants = 0, Custom = true }
			addTemplate(outfit, model)
			-- Essai : le modèle doit offrir tout ce dont le combat a besoin (mains, épaules).
			local trial = dressedBody(outfit)
			if trial then
				trial.model:Destroy()
				table.insert(loaded, label)
			else
				outfitTemplates[outfit] = nil
				table.remove(readyOutfits, table.find(readyOutfits, outfit))
				model:Destroy()
				warn("[Enemies] Modèle 3D « " .. label .. " » ignoré : il manque LeftHand, RightHand, LeftShoulder ou RightShoulder, ou le HumanoidRootPart n'est pas une Part")
			end
		end
	end
	if #loaded > 0 then
		print("[Enemies] Modèles 3D prêts (" .. #loaded .. ") : " .. table.concat(loaded, ", "))
	elseif #container:GetChildren() == 0 then
		print("[Enemies] Dossier ServerStorage." .. CUSTOM_MODELS_FOLDER .. " vide : les bandits gardent les tenues du catalogue.")
	else
		warn("[Enemies] Aucun modèle 3D utilisable dans ServerStorage." .. CUSTOM_MODELS_FOLDER)
	end
end

-- `offhandType` : arme tenue dans la main gauche, pour un bandit à deux armes.
-- `boss` : fait du bandit un géant aux points de vie et à l'équipement propres.
type BossBuild = { Name: string, Scale: number, Health: number, Loadout: Loadout }

-- `class` : classe du bandit (forces, tenue). Le boss garde ses propres forces.
local function buildEnemy(position: Vector3, level: number, class: EnemyClass, weaponType: string, offhandType: string?, boss: BossBuild?): Enemy
	local def = Config.Weapons[weaponType]
	local loadout = LOADOUTS[weaponType]
	assert(def and loadout, "Arme de bandit inconnue : " .. weaponType)
	local health = math.round(BASE_HEALTH * (1 + HEALTH_PER_LEVEL * (level - 1)) * class.HealthScale)
	local attackSpeed = (1 + ATTACK_SPEED_PER_LEVEL * (level - 1)) * BASE_ATTACK_SPEED * class.AttackSpeedScale
	local damageScale = class.DamageScale
	local walkScale = class.WalkSpeedScale
	local scale = 1
	if boss then
		loadout = boss.Loadout
		health = boss.Health
		scale = boss.Scale
		attackSpeed = 1 + ATTACK_SPEED_PER_LEVEL * (level - 1)
		damageScale, walkScale = 1, 1
	end

	-- Corps habillé d'une tenue de sa classe si une est prête, sinon corps en blocs.
	-- Le boss porte la tenue la plus prestigieuse de sa classe.
	local outfit = if boss then bestOutfit(class.Id) else pickOutfit(level, class.Id)
	local body = (if outfit then dressedBody(outfit) else nil) or blockBody()
	local model, root, head = body.model, body.root, body.head
	local leftShoulder, rightShoulder = body.leftShoulder, body.rightShoulder
	model:SetAttribute("Class", class.Id)

	if body.strawHat and class.StrawHat then
		-- Chapeau de paille conique.
		local flat = CFrame.Angles(0, 0, QUARTER)
		local brim = accessory("Chapeau", Vector3.new(0.25, 3, 3), STRAW, Enum.Material.Wood, head, CFrame.new(0, 0.7, 0) * flat, model)
		brim.Shape = Enum.PartType.Cylinder
		local crown = accessory("Chapeau", Vector3.new(0.5, 1.5, 1.5), STRAW, Enum.Material.Wood, head, CFrame.new(0, 1, 0) * flat, model)
		crown.Shape = Enum.PartType.Cylinder
	end

	-- Arme principale dans la main droite, et parfois une seconde dans la main gauche.
	local hands = { equip(model, body.rightGrip, rightShoulder, 1, weaponType, body.rightPivot, body.gripY) }
	local displayName = def.DisplayName
	if offhandType then
		table.insert(hands, equip(model, body.leftGrip, leftShoulder, -1, offhandType, body.leftPivot, body.gripY))
		displayName ..= " + " .. Config.Weapons[offhandType].DisplayName
	end

	local humanoid = body.humanoid
	humanoid.DisplayName = "Niv. " .. level .. " · " .. (if boss then boss.Name else class.Name) .. " · " .. displayName
	humanoid.MaxHealth = health
	humanoid.Health = health
	-- Chaque bandit marche à une allure légèrement différente : ils n'avancent pas au pas cadencé.
	local walkSpeed = loadout.WalkSpeed * walkScale * random:NextNumber(0.92, 1.08)
	humanoid.WalkSpeed = walkSpeed
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	-- À sa mort, le corps passe en ragdoll (module Ragdoll) au lieu de tomber en morceaux.
	humanoid.BreakJointsOnDeath = false

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
		local hipHeight = humanoid.HipHeight
		model:ScaleTo(scale)
		for _, hand in hands do
			hand.scale = scale
			hand.loadout = loadout
		end
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			-- R15 : la hauteur des hanches grandit avec les jambes.
			humanoid.HipHeight = hipHeight * scale
		else
			-- Un personnage R6 agrandi s'enfonce dans le sol : on relève ses hanches d'autant que ses jambes ont grandi.
			humanoid.HipHeight = 2 * (scale - 1)
		end
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
		xpLevels = if boss then level else level * class.XpScale,
		dashRate = if boss then BOSS_DASH_RATE else class.DashRate,
		damageScale = damageScale,
		tick = nil,
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
	setGlow(hand, Color3.fromRGB(255, 140, 60))
	task.wait(raiseTime)
	if humanoid.Health <= 0 then
		enemy.model:SetAttribute("AttackLean", 0)
		return
	end

	-- 2. Prise d'élan : la lame vire au blanc (fenêtre de parade parfaite) pendant que le bras
	--    recule encore un peu, comme un ressort que l'on tend.
	setGlow(hand, Color3.fromRGB(255, 255, 255))
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
	setGlow(hand, nil)
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
			feedbackRemote:FireClient(player, blockSide, 1, 0.2, Config.CAMERA_SHAKE.SHIELD)
			-- L'arme rebondit sur le bouclier : le bras est renvoyé, dépasse, puis se stabilise.
			moveArm(hand, { angle = 1.6, push = 0.2, wrist = 0 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			enemy.model:SetAttribute("AttackLean", 0.8)
			task.wait(SHIELD_STAGGER_TIME)
		elseif blockKind == "Parry" and playerSpeed >= PERFECT_PARRY_SPEED then
			-- Parade parfaite : le coup est renvoyé, le bandit est blessé, sonné longtemps
			-- et vulnérable (les coups qu'il reçoit pendant ce temps sont multipliés).
			perfectParryVfx(strike.contact)
			Sfx.play("PerfectParry", strike.contact, 1.5)
			feedbackRemote:FireClient(player, blockSide, 1, 0.3, Config.CAMERA_SHAKE.PERFECT_PARRY)
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
			feedbackRemote:FireClient(player, blockSide, 0.8, 0.12, Config.CAMERA_SHAKE.PARRY)
			-- Le sabre est repoussé vers le haut.
			moveArm(hand, { angle = 2.2, push = 0.15, wrist = 0.15 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			enemy.model:SetAttribute("AttackLean", 1)
			task.wait(STAGGER_TIME)
		else
			local levelScale = (1 + DAMAGE_PER_LEVEL * (enemy.level - 1)) * enemy.damageScale
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

-- Petit nuage de poussière soulevé aux pieds par un dash.
local function dustPuff(root: BasePart, scale: number)
	local anchor = Instance.new("Attachment")
	anchor.Name = "PoussiereDash"
	anchor.Position = Vector3.new(0, -2.6 * scale, 0)
	anchor.Parent = root
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(190, 170, 140))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * scale), NumberSequenceKeypoint.new(1, 2.6 * scale) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.4, 0.7)
	dust.Speed = NumberRange.new(3, 6)
	dust.SpreadAngle = Vector2.new(180, 15)
	dust.Acceleration = Vector3.new(0, 2, 0)
	dust.Rate = 0
	dust.Parent = anchor
	dust:Emit(14)
	Debris:AddItem(anchor, 1)
end

-- Traînée laissée par le corps pendant un dash : un voile clair tendu de la tête aux genoux,
-- qui s'étire derrière le bandit puis s'efface.
local DASH_TRAIL_LIFETIME = 0.3
local DASH_TRAIL_COLOR = Color3.fromRGB(235, 225, 210)

local function dashTrail(root: BasePart, scale: number, duration: number)
	local top = Instance.new("Attachment")
	top.Name = "TraineeDashHaut"
	top.Position = Vector3.new(0, 1.6 * scale, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TraineeDashBas"
	bottom.Position = Vector3.new(0, -1.8 * scale, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "TraineeDash"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = DASH_TRAIL_LIFETIME
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(DASH_TRAIL_COLOR)
	trail.LightEmission = 0.4
	trail.LightInfluence = 0.3
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	trail.Parent = root

	-- À la fin du dash, la traînée cesse de s'allonger et ses derniers segments s'effacent.
	task.delay(duration, function()
		trail.Enabled = false
	end)
	Debris:AddItem(trail, duration + DASH_TRAIL_LIFETIME + 0.1)
	Debris:AddItem(top, duration + DASH_TRAIL_LIFETIME + 0.1)
	Debris:AddItem(bottom, duration + DASH_TRAIL_LIFETIME + 0.1)
end

-- Lance un dash dans la direction `direction` (à plat) sur au plus `distance` studs.
-- Le dash est raccourci devant un mur et annulé s'il finirait dans le vide.
-- Renvoie sa durée, ou nil s'il n'a pas eu lieu.
local function dash(enemy: Enemy, direction: Vector3, distance: number): number?
	local root = enemy.root
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.01 then
		return nil
	end
	direction = direction.Unit
	local scale = enemy.model:GetScale()

	local ignored: { Instance } = { folder, weaponsFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignored, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignored

	-- Un mur sur le trajet : il s'arrête avant.
	local margin = 1.5 * scale
	local wall = workspace:Raycast(root.Position, direction * (distance + margin), params)
	if wall then
		distance = wall.Distance - margin
	end
	if distance < 3 then
		return nil
	end
	-- Pas de sol à l'arrivée (bord de l'arène) : pas de dash.
	local landing = root.Position + direction * distance
	if not workspace:Raycast(landing, Vector3.new(0, -8 * scale, 0), params) then
		return nil
	end

	local duration = distance / DASH_SPEED
	local attachment = Instance.new("Attachment")
	attachment.Name = "Dash"
	attachment.Parent = root
	-- Vitesse imposée à l'horizontale seulement : la gravité garde la main sur l'axe vertical.
	local push = Instance.new("LinearVelocity")
	push.Name = "Dash"
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	push.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	push.VectorVelocity = direction * DASH_SPEED
	push.Parent = root
	Debris:AddItem(push, duration)
	Debris:AddItem(attachment, duration)

	enemy.humanoid:MoveTo(landing)
	dustPuff(root, scale)
	dashTrail(root, scale, duration)
	Sfx.play("Dash", root, 1)
	return duration
end

-- Cherche une lame de joueur qui fend l'air près de `position`. Renvoie la position de sa pointe.
local function incomingBlade(position: Vector3, range: number): Vector3?
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:IsA("Model") and weapon:GetAttribute("Holder") then
			for _, part in weapon:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
					local tip = part.CFrame * Vector3.new(0, part.Size.Y / 2, 0)
					if (tip - position).Magnitude <= range and part:GetVelocityAtPosition(tip).Magnitude >= DASH_EVADE_BLADE_SPEED then
						return tip
					end
				end
			end
		end
	end
	return nil
end

local function run(enemy: Enemy)
	local humanoid, root = enemy.humanoid, enemy.root
	local nextAttack = os.clock() + 1
	local lastPosition = root.Position
	local stuckTime = 0

	-- Dash : prochain dash permis, fin du dash en cours, et esquive à tenter après un coup reçu.
	local nextDash = os.clock() + random:NextNumber(1, 3)
	local dashUntil = 0
	local wantsDodge = false
	local lastEvadeRoll = 0
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth and health > 0 then
			wantsDodge = true
		end
		lastHealth = health
	end)
	local function tryDash(chance: number, direction: Vector3, distance: number): boolean
		if enemy.dashRate <= 0 or os.clock() < nextDash or random:NextNumber() >= math.min(chance * enemy.dashRate, 0.9) then
			return false
		end
		local duration = dash(enemy, direction, distance)
		if not duration then
			return false
		end
		dashUntil = os.clock() + duration
		nextDash = os.clock() + DASH_COOLDOWN / enemy.dashRate * random:NextNumber(0.8, 1.25)
		return true
	end

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
			wantsDodge = false
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

		-- En plein dash : on le laisse filer.
		if os.clock() < dashUntil then
			lastPosition = root.Position
			continue
		end

		-- Il vient d'être touché : il bondit parfois en arrière, en biais, pour reprendre ses distances.
		if wantsDodge then
			wantsDodge = false
			if targetRoot then
				local away = (root.Position - targetRoot.Position) * Vector3.new(1, 0, 1)
				local angle = math.rad(random:NextNumber(20, 45)) * (if random:NextNumber() < 0.5 then 1 else -1)
				if away.Magnitude > 0.1 and tryDash(DASH_DODGE_CHANCE, CFrame.Angles(0, angle, 0):VectorToWorldSpace(away.Unit), DASH_DODGE_DISTANCE) then
					nextAttack = math.max(nextAttack, os.clock() + 0.6)
					lastPosition = root.Position
					continue
				end
			end
		end

		-- Esquive réflexe : une lame arrive vite sur lui, il s'écarte d'un dash latéral, du côté opposé.
		if targetRoot and enemy.dashRate > 0 and os.clock() >= nextDash then
			local tip = incomingBlade(root.Position, DASH_EVADE_RANGE * enemy.model:GetScale())
			-- Une seule tentative par coup : la lame reste menaçante sur plusieurs tours de boucle.
			if tip and os.clock() - lastEvadeRoll < 0.5 then
				tip = nil
			end
			if tip then
				lastEvadeRoll = os.clock()
				local toTarget = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
				if toTarget.Magnitude > 0.1 then
					local right = toTarget.Unit:Cross(Vector3.yAxis)
					local side = if (tip - root.Position):Dot(right) > 0 then -1 else 1
					if tryDash(DASH_EVADE_CHANCE, right * side, DASH_SIDE_DISTANCE) then
						lastPosition = root.Position
						continue
					end
				end
			end
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
			-- Ruée : encore loin de sa portée, il comble la distance d'un coup (sans dépasser sa portée).
			local gap = distance - enemy.loadout.AttackRange
			if gap > DASH_CLOSE_MIN_GAP and distance < DASH_CLOSE_MAX_DISTANCE
				and tryDash(DASH_CLOSE_CHANCE, destination - root.Position, math.min(DASH_DISTANCE, gap - 2)) then
				stuckTime = 0
				lastPosition = root.Position
				continue
			end
			-- Zigzag : un écart de côté en avançant, quand il n'est plus très loin.
			if gap > 3 and distance < 20 then
				local forward = (targetRoot.Position - root.Position) * Vector3.new(1, 0, 1)
				if forward.Magnitude > 0.1 then
					forward = forward.Unit
					local side = forward:Cross(Vector3.yAxis) * (if random:NextNumber() < 0.5 then 1 else -1)
					local zigzag = math.min(DASH_ZIGZAG_DISTANCE, gap - 1)
					if tryDash(DASH_ZIGZAG_CHANCE, side + forward * DASH_ZIGZAG_FORWARD, zigzag) then
						stuckTime = 0
						lastPosition = root.Position
						continue
					end
				end
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
					-- Pas chassé : un brusque écart de côté, jamais juste avant d'attaquer.
					local sideways = away.Unit:Cross(Vector3.yAxis) * (if random:NextNumber() < 0.5 then 1 else -1)
					if nextAttack - os.clock() > 0.5 and tryDash(DASH_SIDE_CHANCE, sideways, DASH_SIDE_DISTANCE) then
						lastPosition = root.Position
						continue
					end
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

-- Tire au sort une seconde arme pour la main gauche, parmi celles de la classe, ou nil.
-- Seules les armes à une main se portent par paire : ni l'épée longue ni la hache.
local function pickOffhand(class: EnemyClass, weaponType: string, wave: number): string?
	local offhand = class.Offhand
	if not offhand or #offhand == 0 or Config.Weapons[weaponType].TwoHanded or wave < DUAL_FIRST_WAVE then
		return nil
	end
	if random:NextNumber() >= class.DualChance then
		return nil
	end
	return offhand[random:NextInteger(1, #offhand)]
end

-- Tire un élément d'une liste selon les poids donnés par `weightOf` (les poids nuls sont ignorés).
local function weightedPick<T>(items: { T }, weightOf: (T) -> number): T?
	local total = 0
	for _, item in items do
		total += math.max(weightOf(item), 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	for _, item in items do
		roll -= math.max(weightOf(item), 0)
		if roll <= 0 then
			return item
		end
	end
	return items[#items]
end

-- Tire la classe d'un bandit de la vague `wave` parmi celles déjà apparues.
local function pickClass(wave: number): EnemyClass
	local class = weightedPick(CLASSES, function(candidate: EnemyClass)
		if wave < candidate.MinWave then
			return 0
		end
		-- Une classe déjà apparue garde toujours une petite chance d'être tirée.
		return math.max(candidate.Weight + candidate.WeightPerWave * (wave - candidate.MinWave), 0.5)
	end)
	return class or CLASSES[1]
end

-- Tire l'arme principale d'un bandit de cette classe, parmi celles que la vague autorise.
local function pickWeapon(class: EnemyClass, wave: number): string
	local choice = weightedPick(class.Weapons, function(candidate: WeaponChoice)
		return if wave >= (candidate.MinWave or 1) then candidate.Weight else 0
	end)
	return if choice then choice.Weapon else class.Weapons[1].Weapon
end

-- Niveau d'un bandit de la vague `wave` : le numéro de la vague, à LEVEL_SPREAD près.
-- La première vague reste au niveau 1.
local function pickLevel(wave: number): number
	if wave <= 1 then
		return 1
	end
	return math.clamp(wave + random:NextInteger(-LEVEL_SPREAD, LEVEL_SPREAD), 1, MAX_LEVEL)
end

-- Durée pendant laquelle le corps d'un bandit reste au sol avant de s'effacer (secondes).
local CORPSE_TIME = 6
local BOSS_CORPSE_TIME = 10
local CORPSE_FADE = 1.2

-- Mort d'un bandit : le corps s'effondre (ragdoll), ses armes lui tombent des mains,
-- puis il s'efface doucement au bout de `corpseTime` secondes.
local function collapse(enemy: Enemy, corpseTime: number)
	local model = enemy.model
	enemy.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- plus de nom ni de barre de vie
	Ragdoll.apply(model)

	for _, hand in enemy.hands do
		local handle = hand.wrist.Part1
		hand.wrist:Destroy()
		if handle then
			-- Seul le manche (invisible) heurte le sol ; le reste de l'arme y est soudé.
			handle.CanCollide = true
			handle.Massless = false
			pcall(function()
				handle:SetNetworkOwner(nil)
			end)
		end
	end

	task.delay(corpseTime, function()
		if not model.Parent then
			return
		end
		local fade = TweenInfo.new(CORPSE_FADE)
		for _, item in model:GetDescendants() do
			if (item:IsA("BasePart") or item:IsA("Decal")) and item.Transparency < 1 then
				TweenService:Create(item, fade, { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(model, corpseTime + CORPSE_FADE + 0.1)
end

local function spawnEnemy(position: Vector3, class: EnemyClass, wave: number, onGone: () -> ())
	local weaponType = pickWeapon(class, wave)
	local enemy = buildEnemy(position, pickLevel(wave), class, weaponType, pickOffhand(class, weaponType, wave))
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
		if enemy.model.Parent then
			collapse(enemy, CORPSE_TIME)
		end
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
	setGlow(hand, Color3.fromRGB(255, 60, 40))
	task.wait(BOSS_SLAM_WINDUP)
	warning:Destroy()
	setGlow(hand, nil)
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
	local enemy = buildEnemy(SPAWN_POINTS[1], level, CLASS_BY_ID[BOSS_CLASS], BOSS_WEAPON, nil, {
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
				local minionWave = math.max(wave - 2, 1)
				spawnEnemy(position, pickClass(minionWave), minionWave, function() end)
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
		if enemy.model.Parent then
			collapse(enemy, BOSS_CORPSE_TIME)
		end
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
	-- Les modèles 3D importés sont déjà dans la place : ils sont prêts tout de suite.
	loadCustomModels()
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
			-- Une classe qui fait son entrée dans cette vague ouvre la marche ; les autres bandits
			-- sont tirés au hasard parmi les classes déjà apparues.
			local newcomer: EnemyClass? = nil
			for _, class in CLASSES do
				if class.MinWave == wave and wave > 1 then
					newcomer = class
					break
				end
			end
			announce("Vague " .. wave .. (if newcomer then " · nouveaux ennemis : " .. newcomer.Name .. "s" else ""))
			task.wait(2)

			local count = math.min(wave, MAX_ENEMIES)
			local alive = count
			for i = 1, count do
				local class = if i == 1 and newcomer then newcomer else pickClass(wave)
				spawnEnemy(SPAWN_POINTS[i], class, wave, function()
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

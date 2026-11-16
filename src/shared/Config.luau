-- Réglages partagés entre le serveur et le client.
-- Toutes les distances sont en studs (1 mètre réel ≈ 3,6 studs en VR).

local Config = {}

-- Distance maximale entre la main et le manche pour saisir une arme.
Config.GRAB_RADIUS = 2.2

-- false : il faut garder la gâchette de préhension (grip) enfoncée pour tenir l'arme.
-- true  : un appui saisit, un second appui lâche.
Config.GRIP_TOGGLE = false

-- Inclinaison de la lame par rapport à l'axe "pointeur" de la manette, en degrés.
-- 90 = lame perpendiculaire à la manette, 0 = lame dans l'axe du pointeur.
Config.GRIP_PITCH_DEG = 50

-- Vitesse de la lame (studs/s) qui donne exactement les dégâts de base.
Config.REFERENCE_SPEED = 25

-- Multiplicateur de dégâts minimal et maximal selon la vitesse du coup.
-- Dégâts = dégâts de base × (vitesse du coup / vitesse de référence), bornés par ces deux valeurs.
Config.MIN_DAMAGE_SCALE = 0.3
Config.MAX_DAMAGE_SCALE = 2.5

-- Multiplicateur de dégâts sur un bandit rendu vulnérable par une parade parfaite.
Config.RIPOSTE_MULTIPLIER = 2

-- Délai minimal entre deux coups de la même arme sur la même cible (secondes).
Config.HIT_COOLDOWN = 0.35

-- Les joueurs peuvent-ils se blesser entre eux ?
Config.PVP_ENABLED = true

-- Une arme lâchée retourne sur le râtelier après ce délai (secondes).
Config.WEAPON_RETURN_TIME = 40

-- Effets sonores.
-- Pour en changer un, ouvre la Toolbox de Studio (onglet Audio), choisis un son
-- et remplace Id par "rbxassetid://NUMERO".
-- Sons de la bibliothèque audio Roblox, publiés par ProSoundEffects (catalogue sous licence Roblox,
-- utilisable dans tous les jeux). Le nom d'origine de chaque son est indiqué en commentaire.
Config.Sounds = {
	-- Arme contre arme ou contre du métal — « Shield Clang As Hit Metal Sword Hubcap 1 »
	Metal = { Id = "rbxassetid://9119072660", Pitch = 1, Volume = 1 },
	-- Arme contre le décor — « Wood Impacts 3 »
	Thud = { Id = "rbxassetid://9120916241", Pitch = 1, Volume = 0.9 },
	-- Coup qui touche une cible — « Boxing Hits 14 »
	Flesh = { Id = "rbxassetid://9113573976", Pitch = 1, Volume = 1 },
	-- Parade réussie — « Shield Clang As Hit Metal Sword Hubcap 2 »
	Parry = { Id = "rbxassetid://9119072674", Pitch = 1.1, Volume = 1.2 },
	-- Parade parfaite — le même tintement que Metal, plus aigu et plus fort
	PerfectParry = { Id = "rbxassetid://9119072660", Pitch = 1.5, Volume = 1.5 },
	-- Coup arrêté par un bouclier — « Wood Impact 18 »
	Block = { Id = "rbxassetid://9120908635", Pitch = 0.9, Volume = 1.4 },
	-- Arme saisie — « Sword Draw Clang Unsheathing Two Sabers 30 »
	Grab = { Id = "rbxassetid://9119744718", Pitch = 1, Volume = 0.6 },
	-- Passage de niveau — son livré avec Roblox
	LevelUp = { Id = "rbxasset://sounds/victory.wav", Pitch = 1, Volume = 0.8 },
	Hurt = { Id = "rbxasset://sounds/ouch.ogg", Pitch = 1, Volume = 0.8 }, -- joueur blessé
}

-- Vitesse de choc minimale (studs/s) pour qu'une collision d'arme fasse du bruit.
Config.COLLISION_SOUND_MIN_SPEED = 5

-- Avatar Roblox du joueur.
-- SHOW_AVATAR : en vue à la première personne, Roblox cache le corps du joueur ; true le rend
-- visible (sauf la tête et les accessoires, qui boucheraient la vue).
Config.SHOW_AVATAR = true
-- AVATAR_ARMS_FOLLOW_HANDS : les bras de l'avatar suivent les manettes, et les mains en forme
-- de bloc sont cachées. Ne fonctionne qu'avec un avatar R15 ; en R6, les blocs restent visibles.
Config.AVATAR_ARMS_FOLLOW_HANDS = true

-- Barres de vie et d'expérience, affichées dans le monde pour être lisibles en VR.
Config.HUD = {
	ENABLED = true,
	-- "Hand" : le panneau flotte au-dessus de la main gauche (il faut la lever pour le lire).
	-- "Head" : le panneau reste devant le regard, en bas du champ de vision.
	ANCHOR = "Hand",
	WIDTH = 1, -- largeur du panneau en studs (1 stud ≈ 28 cm en VR)
	HEIGHT = 0.5,
	HAND_HEIGHT = 0.55, -- hauteur du panneau au-dessus de la main (studs)
	HEAD_OFFSET = Vector3.new(0, -1.1, -3), -- position devant les yeux en mode "Head" (droite, haut, -avant)
}

-- Niveau des joueurs. L'expérience (XP) se gagne en tuant des bandits.
Config.PlayerLevel = {
	MAX_LEVEL = 20,
	XP_PER_LEVEL = 100, -- XP pour passer au niveau suivant = cette valeur × niveau actuel
	XP_PER_ENEMY_LEVEL = 30, -- XP donnée par un bandit = cette valeur × son niveau
	BASE_HEALTH = 100, -- points de vie au niveau 1
	HEALTH_PER_LEVEL = 10, -- points de vie gagnés par niveau
	DAMAGE_PER_LEVEL = 0.08, -- +8 % de dégâts par niveau
	SAVE = true, -- conserver le niveau et l'XP d'une partie à l'autre
	DATASTORE_NAME = "PlayerLevels_v1", -- changer ce nom remet tous les joueurs au niveau 1
	AUTOSAVE_INTERVAL = 120, -- secondes entre deux sauvegardes automatiques
}

-- Traînée derrière les lames en mouvement (armes des joueurs et des bandits).
-- Durée de vie en secondes : plus elle est longue, plus la traînée s'étire.
Config.TRAIL_LIFETIME = 0.18
Config.TRAIL_COLOR = Color3.fromRGB(235, 240, 255)

export type WeaponPart = {
	Name: string,
	Size: Vector3,
	Offset: Vector3, -- position du centre de la pièce par rapport au centre du manche (Y = vers la lame)
	Color: Color3,
	Material: Enum.Material,
	Blade: boolean?, -- true : cette pièce inflige des dégâts
	Shield: boolean?, -- true : cette pièce bloque les attaques
	Shape: Enum.PartType?, -- forme de la pièce (bloc par défaut)
	Rotation: CFrame?, -- rotation de la pièce par rapport au manche
	Wedge: boolean?, -- true : pièce en biseau (pointe de lame, corne de hache)
	Decor: boolean?, -- true : ornement sans collision (pompon, cordon)
	Reflectance: number?, -- brillance, de 0 à 1
}

export type WeaponDef = {
	DisplayName: string,
	Damage: number, -- dégâts à la vitesse de référence
	MinSpeed: number, -- vitesse minimale de la lame pour que le coup compte
	TwoHanded: boolean, -- la seconde main peut guider l'arme
	HandleLength: number,
	GripOffset: number, -- position de la main le long du manche (0 = centre, + = vers la lame)
	GripPitchDeg: number?, -- inclinaison propre à cet objet ; sinon Config.GRIP_PITCH_DEG
	HandleColor: Color3?, -- couleur du manche (bois brun par défaut)
	HandleMaterial: Enum.Material?, -- matière du manche (bois par défaut)
	Parts: { WeaponPart },
}

local STEEL = Color3.fromRGB(205, 210, 220)
local BRIGHT_STEEL = Color3.fromRGB(230, 233, 240)
local DARK_STEEL = Color3.fromRGB(80, 84, 94)
local BRONZE = Color3.fromRGB(150, 110, 60)
local BRASS = Color3.fromRGB(200, 165, 80)
local GOLD = Color3.fromRGB(190, 150, 60)
local JADE = Color3.fromRGB(70, 150, 115)
local SILK_RED = Color3.fromRGB(175, 30, 30)

local METAL = Enum.Material.Metal
local BLADE_SHINE = 0.25
local HALF_TURN_Y = CFrame.Angles(0, math.pi, 0)
local HALF_TURN_X = CFrame.Angles(math.pi, 0, 0)

-- Pointe symétrique d'une lame à deux tranchants : deux biseaux qui se rejoignent dans l'axe.
-- `y` : hauteur où la pointe commence ; `height` : sa longueur ; `width` : largeur de la lame.
local function addPoint(parts: { WeaponPart }, y: number, height: number, width: number, thickness: number)
	table.insert(parts, {
		Name = "Pointe",
		Size = Vector3.new(thickness, height, width / 2),
		Offset = Vector3.new(0, y + height / 2, -width / 4),
		Color = STEEL,
		Material = METAL,
		Wedge = true,
		Reflectance = BLADE_SHINE,
	})
	table.insert(parts, {
		Name = "Pointe",
		Size = Vector3.new(thickness, height, width / 2),
		Offset = Vector3.new(0, y + height / 2, width / 4),
		Color = STEEL,
		Material = METAL,
		Wedge = true,
		Rotation = HALF_TURN_Y,
		Reflectance = BLADE_SHINE,
	})
end

-- Bishou (匕首) : dague droite à deux tranchants, pommeau en anneau.
local dagueParts: { WeaponPart } = {
	{ Name = "Anneau", Size = Vector3.new(0.08, 0.4, 0.4), Offset = Vector3.new(0, -0.58, 0), Color = BRONZE, Material = METAL, Shape = Enum.PartType.Cylinder },
	{ Name = "Garde", Size = Vector3.new(0.24, 0.12, 0.5), Offset = Vector3.new(0, 0.46, 0), Color = BRONZE, Material = METAL },
	{ Name = "Lame", Size = Vector3.new(0.06, 1.05, 0.26), Offset = Vector3.new(0, 1.045, 0), Color = STEEL, Material = METAL, Blade = true, Reflectance = BLADE_SHINE },
	{ Name = "Arete", Size = Vector3.new(0.09, 1, 0.05), Offset = Vector3.new(0, 1.02, 0), Color = BRIGHT_STEEL, Material = METAL, Reflectance = BLADE_SHINE },
}
addPoint(dagueParts, 1.57, 0.45, 0.26, 0.06)

-- Jian (剑) : épée droite à deux tranchants, garde courte en bronze, pommeau incrusté de jade
-- et pompon de soie rouge.
local epeeParts: { WeaponPart } = {
	{ Name = "Pommeau", Size = Vector3.new(0.3, 0.24, 0.5), Offset = Vector3.new(0, -0.67, 0), Color = BRONZE, Material = METAL },
	{ Name = "Jade", Size = Vector3.new(0.33, 0.12, 0.2), Offset = Vector3.new(0, -0.67, 0), Color = JADE, Material = Enum.Material.SmoothPlastic, Reflectance = 0.15 },
	{ Name = "Cordon", Size = Vector3.new(0.05, 0.6, 0.05), Offset = Vector3.new(0, -1.09, 0), Color = SILK_RED, Material = Enum.Material.Fabric, Decor = true },
	{ Name = "Pompon", Size = Vector3.new(0.16, 0.45, 0.16), Offset = Vector3.new(0, -1.6, 0), Color = SILK_RED, Material = Enum.Material.Fabric, Decor = true },
	{ Name = "Garde", Size = Vector3.new(0.26, 0.16, 0.95), Offset = Vector3.new(0, 0.63, 0), Color = BRONZE, Material = METAL },
	{ Name = "Garde", Size = Vector3.new(0.34, 0.26, 0.42), Offset = Vector3.new(0, 0.63, 0), Color = BRONZE, Material = METAL },
	{ Name = "Lame", Size = Vector3.new(0.07, 2.7, 0.32), Offset = Vector3.new(0, 2.06, 0), Color = STEEL, Material = METAL, Blade = true, Reflectance = BLADE_SHINE },
	{ Name = "Arete", Size = Vector3.new(0.1, 2.6, 0.06), Offset = Vector3.new(0, 2.01, 0), Color = BRIGHT_STEEL, Material = METAL, Reflectance = BLADE_SHINE },
}
addPoint(epeeParts, 3.41, 0.5, 0.32, 0.07)

-- Changdao (长刀) : long sabre à deux mains, à un seul tranchant (côté -Z), garde ronde en laiton.
local epeeLongueParts: { WeaponPart } = {
	{ Name = "Pommeau", Size = Vector3.new(0.36, 0.22, 0.36), Offset = Vector3.new(0, -1.05, 0), Color = BRASS, Material = METAL },
	{ Name = "Garde", Size = Vector3.new(0.12, 0.95, 0.95), Offset = Vector3.new(0, 1, 0), Color = BRASS, Material = METAL, Shape = Enum.PartType.Cylinder, Rotation = CFrame.Angles(0, 0, math.rad(90)) },
	{ Name = "Collet", Size = Vector3.new(0.15, 0.3, 0.46), Offset = Vector3.new(0, 1.21, 0), Color = BRASS, Material = METAL },
	{ Name = "Lame", Size = Vector3.new(0.09, 3.6, 0.42), Offset = Vector3.new(0, 2.86, 0), Color = STEEL, Material = METAL, Blade = true, Reflectance = BLADE_SHINE },
	{ Name = "Dos", Size = Vector3.new(0.13, 3.6, 0.1), Offset = Vector3.new(0, 2.86, 0.17), Color = DARK_STEEL, Material = METAL },
	-- La pointe remonte du tranchant vers le dos de la lame.
	{ Name = "Pointe", Size = Vector3.new(0.09, 0.75, 0.42), Offset = Vector3.new(0, 5.035, 0), Color = STEEL, Material = METAL, Wedge = true, Reflectance = BLADE_SHINE },
}

-- Fu (斧) : hache de guerre au fer en croissant, pointe au sommet, houppe de soie rouge sous le fer.
-- Le fer dépasse vers l'avant (-Z), côté tranchant.
local hacheParts: { WeaponPart } = {
	{ Name = "Fer", Size = Vector3.new(0.1, 1, 0.6), Offset = Vector3.new(0, 0.95, -0.5), Color = STEEL, Material = METAL, Blade = true, Reflectance = BLADE_SHINE },
	{ Name = "Corne", Size = Vector3.new(0.1, 0.4, 0.6), Offset = Vector3.new(0, 1.65, -0.5), Color = STEEL, Material = METAL, Wedge = true, Rotation = HALF_TURN_Y, Reflectance = BLADE_SHINE },
	{ Name = "Corne", Size = Vector3.new(0.1, 0.4, 0.6), Offset = Vector3.new(0, 0.25, -0.5), Color = STEEL, Material = METAL, Wedge = true, Rotation = HALF_TURN_X, Reflectance = BLADE_SHINE },
	{ Name = "Douille", Size = Vector3.new(0.36, 0.7, 0.36), Offset = Vector3.new(0, 0.95, 0), Color = DARK_STEEL, Material = METAL },
	{ Name = "Marteau", Size = Vector3.new(0.24, 0.4, 0.3), Offset = Vector3.new(0, 0.95, 0.32), Color = DARK_STEEL, Material = METAL },
	{ Name = "Pique", Size = Vector3.new(0.08, 0.45, 0.18), Offset = Vector3.new(0, 1.52, 0), Color = STEEL, Material = METAL, Reflectance = BLADE_SHINE },
	{ Name = "Houppe", Size = Vector3.new(0.42, 0.35, 0.42), Offset = Vector3.new(0, 0.42, 0), Color = SILK_RED, Material = Enum.Material.Fabric, Decor = true },
	{ Name = "Bague", Size = Vector3.new(0.34, 0.14, 0.34), Offset = Vector3.new(0, -1.25, 0), Color = BRASS, Material = METAL },
}

-- Dao (刀) : sabre à une main, à un seul tranchant (côté -Z), lame qui s'élargit vers la pointe,
-- garde ronde, pommeau en anneau et foulard de soie rouge.
local sabreParts: { WeaponPart } = {
	{ Name = "Anneau", Size = Vector3.new(0.08, 0.36, 0.36), Offset = Vector3.new(0, -0.66, 0), Color = BRASS, Material = METAL, Shape = Enum.PartType.Cylinder },
	{ Name = "Foulard", Size = Vector3.new(0.04, 0.8, 0.22), Offset = Vector3.new(0, -1.2, 0), Color = SILK_RED, Material = Enum.Material.Fabric, Decor = true },
	{ Name = "Garde", Size = Vector3.new(0.1, 0.75, 0.75), Offset = Vector3.new(0, 0.55, 0), Color = BRASS, Material = METAL, Shape = Enum.PartType.Cylinder, Rotation = CFrame.Angles(0, 0, math.rad(90)) },
	{ Name = "Lame", Size = Vector3.new(0.08, 2.2, 0.42), Offset = Vector3.new(0, 1.7, 0), Color = STEEL, Material = METAL, Blade = true, Reflectance = BLADE_SHINE },
	{ Name = "Dos", Size = Vector3.new(0.12, 2.2, 0.09), Offset = Vector3.new(0, 1.7, 0.17), Color = DARK_STEEL, Material = METAL },
	{ Name = "Ventre", Size = Vector3.new(0.08, 0.9, 0.5), Offset = Vector3.new(0, 2.35, -0.04), Color = STEEL, Material = METAL, Reflectance = BLADE_SHINE },
	{ Name = "Pointe", Size = Vector3.new(0.08, 0.6, 0.5), Offset = Vector3.new(0, 3.1, -0.04), Color = STEEL, Material = METAL, Wedge = true, Reflectance = BLADE_SHINE },
}

-- Qiang (枪) : lance à hampe de bois clair, fer en feuille de saule et houppe de crin rouge
-- sous le fer (elle servait à brouiller la vue de l'adversaire).
local lanceParts: { WeaponPart } = {
	{ Name = "Talon", Size = Vector3.new(0.34, 0.3, 0.34), Offset = Vector3.new(0, -3.3, 0), Color = BRASS, Material = METAL },
	{ Name = "Houppe", Size = Vector3.new(0.5, 0.4, 0.5), Offset = Vector3.new(0, 2.9, 0), Color = SILK_RED, Material = Enum.Material.Fabric, Decor = true },
	{ Name = "Douille", Size = Vector3.new(0.34, 0.3, 0.34), Offset = Vector3.new(0, 3.2, 0), Color = BRASS, Material = METAL },
	{ Name = "Fer", Size = Vector3.new(0.08, 0.6, 0.3), Offset = Vector3.new(0, 3.65, 0), Color = STEEL, Material = METAL, Blade = true, Reflectance = BLADE_SHINE },
	{ Name = "Arete", Size = Vector3.new(0.12, 0.6, 0.06), Offset = Vector3.new(0, 3.65, 0), Color = BRIGHT_STEEL, Material = METAL, Reflectance = BLADE_SHINE },
}
addPoint(lanceParts, 3.95, 0.6, 0.3, 0.08)

-- Guandao (偃月刀) : lourde lame de sabre en croissant montée sur une hampe, avec un crochet
-- au dos de la lame, une houppe rouge et une pointe de contrepoids au talon. Tranchant côté -Z.
local guandaoParts: { WeaponPart } = {
	{ Name = "Contrepoids", Size = Vector3.new(0.12, 0.6, 0.2), Offset = Vector3.new(0, -3.05, 0), Color = STEEL, Material = METAL },
	{ Name = "Talon", Size = Vector3.new(0.36, 0.25, 0.36), Offset = Vector3.new(0, -2.7, 0), Color = BRASS, Material = METAL },
	{ Name = "Houppe", Size = Vector3.new(0.5, 0.4, 0.5), Offset = Vector3.new(0, 2.45, 0), Color = SILK_RED, Material = Enum.Material.Fabric, Decor = true },
	{ Name = "Collet", Size = Vector3.new(0.4, 0.35, 0.5), Offset = Vector3.new(0, 2.78, 0), Color = BRASS, Material = METAL },
	{ Name = "Lame", Size = Vector3.new(0.1, 1.8, 0.7), Offset = Vector3.new(0, 3.85, -0.2), Color = STEEL, Material = METAL, Blade = true, Reflectance = BLADE_SHINE },
	{ Name = "Dos", Size = Vector3.new(0.14, 1.8, 0.1), Offset = Vector3.new(0, 3.85, 0.12), Color = DARK_STEEL, Material = METAL },
	{ Name = "Crochet", Size = Vector3.new(0.1, 0.25, 0.35), Offset = Vector3.new(0, 4.3, 0.32), Color = STEEL, Material = METAL },
	{ Name = "Pointe", Size = Vector3.new(0.1, 0.9, 0.7), Offset = Vector3.new(0, 5.2, -0.2), Color = STEEL, Material = METAL, Wedge = true, Reflectance = BLADE_SHINE },
}

-- Gun (棍) : bâton long, ferré aux deux bouts. Ce sont les embouts qui frappent.
local batonParts: { WeaponPart } = {
	{ Name = "Embout", Size = Vector3.new(0.34, 0.7, 0.34), Offset = Vector3.new(0, 2.75, 0), Color = DARK_STEEL, Material = METAL, Blade = true },
	{ Name = "Embout", Size = Vector3.new(0.34, 0.7, 0.34), Offset = Vector3.new(0, -2.75, 0), Color = DARK_STEEL, Material = METAL, Blade = true },
	{ Name = "Bague", Size = Vector3.new(0.32, 0.12, 0.32), Offset = Vector3.new(0, 2.3, 0), Color = BRASS, Material = METAL },
	{ Name = "Bague", Size = Vector3.new(0.32, 0.12, 0.32), Offset = Vector3.new(0, -2.3, 0), Color = BRASS, Material = METAL },
}

local weapons: { [string]: WeaponDef } = {
	Sabre = {
		DisplayName = "Sabre",
		Damage = 28,
		MinSpeed = 10,
		TwoHanded = false,
		HandleLength = 1,
		GripOffset = 0,
		HandleColor = Color3.fromRGB(60, 35, 25), -- cuir brun
		HandleMaterial = Enum.Material.Fabric,
		Parts = sabreParts,
	},

	Lance = {
		DisplayName = "Lance",
		Damage = 30,
		MinSpeed = 9,
		TwoHanded = true,
		HandleLength = 6.3,
		GripOffset = -1.2, -- tenue vers l'arrière de la hampe, pour l'allonge
		HandleColor = Color3.fromRGB(195, 165, 115), -- bois clair
		Parts = lanceParts,
	},

	Guandao = {
		DisplayName = "Guandao",
		Damage = 45,
		MinSpeed = 8,
		TwoHanded = true,
		HandleLength = 5.2,
		GripOffset = -0.8,
		HandleColor = Color3.fromRGB(70, 30, 25), -- bois sombre laqué
		Parts = guandaoParts,
	},

	Baton = {
		DisplayName = "Bâton",
		Damage = 18,
		MinSpeed = 8,
		TwoHanded = true,
		HandleLength = 5.2,
		GripOffset = 0,
		HandleColor = Color3.fromRGB(150, 110, 65), -- bois ciré
		Parts = batonParts,
	},

	Dague = {
		DisplayName = "Dague",
		Damage = 12,
		MinSpeed = 8,
		TwoHanded = false,
		HandleLength = 0.8,
		GripOffset = 0,
		HandleColor = Color3.fromRGB(45, 35, 30), -- cordelette sombre
		HandleMaterial = Enum.Material.Fabric,
		Parts = dagueParts,
	},

	Epee = {
		DisplayName = "Épée",
		Damage = 25,
		MinSpeed = 11,
		TwoHanded = false,
		HandleLength = 1.1,
		GripOffset = 0,
		HandleColor = Color3.fromRGB(95, 40, 30), -- bois de rose
		Parts = epeeParts,
	},

	EpeeLongue = {
		DisplayName = "Épée longue",
		Damage = 40,
		MinSpeed = 9,
		TwoHanded = true,
		HandleLength = 1.9,
		GripOffset = 0.45,
		HandleColor = Color3.fromRGB(35, 30, 32), -- tresse de soie noire
		HandleMaterial = Enum.Material.Fabric,
		Parts = epeeLongueParts,
	},

	Hache = {
		DisplayName = "Hache",
		Damage = 35,
		MinSpeed = 10,
		TwoHanded = true,
		HandleLength = 2.6,
		GripOffset = -0.6,
		HandleColor = Color3.fromRGB(115, 30, 25), -- laque rouge
		Parts = hacheParts,
	},

	-- Bouclier rond en rotin (tengpai). Il n'inflige pas de dégâts : il bloque.
	-- La poignée est verticale dans la main et le plateau fait face à la direction pointée par la manette.
	Bouclier = {
		DisplayName = "Bouclier",
		Damage = 0,
		MinSpeed = math.huge,
		TwoHanded = false,
		HandleLength = 0.9,
		GripOffset = 0,
		GripPitchDeg = 78,
		Parts = {
			{ Name = "Plateau", Size = Vector3.new(0.3, 3.6, 3.6), Offset = Vector3.new(0, 0, -0.6), Color = Color3.fromRGB(150, 105, 55), Material = Enum.Material.WoodPlanks, Shape = Enum.PartType.Cylinder, Rotation = CFrame.Angles(0, math.rad(90), 0), Shield = true },
			{ Name = "Cerclage", Size = Vector3.new(0.2, 3.8, 3.8), Offset = Vector3.new(0, 0, -0.55), Color = Color3.fromRGB(105, 25, 25), Material = Enum.Material.Wood, Shape = Enum.PartType.Cylinder, Rotation = CFrame.Angles(0, math.rad(90), 0) },
			{ Name = "Umbo", Size = Vector3.new(0.3, 1, 1), Offset = Vector3.new(0, 0, -0.85), Color = GOLD, Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder, Rotation = CFrame.Angles(0, math.rad(90), 0) },
			{ Name = "Sangle", Size = Vector3.new(0.18, 0.18, 0.5), Offset = Vector3.new(0, 0.38, -0.25), Color = DARK_STEEL, Material = Enum.Material.Metal },
			{ Name = "Sangle", Size = Vector3.new(0.18, 0.18, 0.5), Offset = Vector3.new(0, -0.38, -0.25), Color = DARK_STEEL, Material = Enum.Material.Metal },
		},
	},
}

Config.Weapons = weapons

-- Armes posées sur le râtelier au démarrage, dans l'ordre.
Config.RACK = {
	"Bouclier", "Bouclier", "Dague", "Dague", "Epee", "Epee", "Sabre", "Sabre",
	"EpeeLongue", "Hache", "Lance", "Lance", "Guandao", "Baton",
}

-- Rotation qui amène l'axe du manche (+Y) vers le haut et l'avant de la main.
Config.GRIP_ROTATION = CFrame.Angles(math.rad(Config.GRIP_PITCH_DEG - 90), 0, 0)

-- CFrame du manche exprimé dans le repère de la main.
function Config.getGripCFrame(def: WeaponDef): CFrame
	local rotation = Config.GRIP_ROTATION
	if def.GripPitchDeg then
		rotation = CFrame.Angles(math.rad(def.GripPitchDeg - 90), 0, 0)
	end
	return rotation * CFrame.new(0, -def.GripOffset, 0)
end

return Config

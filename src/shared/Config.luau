-- Réglages partagés entre le serveur et le client.
-- Toutes les distances sont en studs (1 mètre réel ≈ 3,6 studs en VR).

local Config = {}

-- Distance maximale entre la main et le manche pour saisir une arme.
Config.GRAB_RADIUS = 2.2

-- false : il faut garder la gâchette de préhension (grip) enfoncée pour tenir l'arme.
-- true  : un appui saisit, un second appui lâche.
Config.GRIP_TOGGLE = false

-- Suivi des mains et de l'arme tenue :
-- "Exact"    : la main (et l'arme) colle à la manette à chaque image, en position et en rotation
--              (6 degrés de liberté, sans retard ni ballant). L'arme peut traverser les murs.
-- "Physique" : la main est tirée vers la manette par des forces limitées ; une arme s'arrête
--              contre un mur, mais elle traîne un peu derrière les gestes rapides.
Config.HAND_TRACKING = "Exact"

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
	-- Dash d'un bandit — son de fente livré avec Roblox
	Dash = { Id = "rbxasset://sounds/swordlunge.wav", Pitch = 0.75, Volume = 0.7 },
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

-- Léger tremblement de l'écran quand on bloque ou pare un coup de bandit.
-- La caméra oscille de quelques dixièmes de degré, puis l'oscillation s'éteint.
-- En VR, bouger la vue sans que la tête bouge peut donner la nausée : VR_SCALE l'atténue (0 la coupe).
Config.CAMERA_SHAKE = {
	ENABLED = true,
	ANGLE = 0.5, -- amplitude maximale en degrés, pour une intensité de 1
	DURATION = 0.18, -- secondes
	FREQUENCY = 30, -- oscillations par seconde
	VR_SCALE = 0.4, -- multiplicateur appliqué avec un casque
	-- Intensité selon la façon dont le coup est arrêté.
	SHIELD = 1,
	PARRY = 0.6,
	PERFECT_PARRY = 1.2,
}

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
	Hidden: boolean?, -- true : pièce invisible (zone de frappe recouverte par le modèle détaillé)
	Glow: boolean?, -- true : acier de la lame, qui s'illumine quand un bandit prépare son coup
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
	HandleDiameter: number?, -- diamètre visible du manche rond (0,24 par défaut)
	Parts: { WeaponPart },
}

local STEEL = Color3.fromRGB(196, 202, 212)
local BRIGHT_STEEL = Color3.fromRGB(232, 236, 243) -- fil du tranchant, poli
local SPINE_STEEL = Color3.fromRGB(150, 156, 168) -- dos de lame, plus terne
local DARK_STEEL = Color3.fromRGB(70, 74, 84)
local BRONZE = Color3.fromRGB(150, 110, 60)
local BRASS = Color3.fromRGB(200, 165, 80)
local GOLD = Color3.fromRGB(190, 150, 60)
local JADE = Color3.fromRGB(70, 150, 115)
local SILK_RED = Color3.fromRGB(175, 30, 30)
local CORD_DARK = Color3.fromRGB(28, 22, 20)

local METAL = Enum.Material.Metal
local SMOOTH = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.Fabric
local CYLINDER = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball

local BLADE_SHINE = 0.2
local EDGE_SHINE = 0.4
local HALF_TURN_Y = CFrame.Angles(0, math.pi, 0)
local HALF_TURN_X = CFrame.Angles(math.pi, 0, 0)
-- Un cylindre Roblox est couché le long de son axe X : cette rotation le dresse le long du manche (Y).
local ALONG_Y = CFrame.Angles(0, 0, math.rad(90))

-- Couleur du manche quand l'arme n'en précise pas.
Config.HANDLE_WOOD = Color3.fromRGB(105, 70, 40)

---------------------------------------------------------------------------
-- Outils de construction des modèles
--
-- Repère du manche : Y = le long de l'arme (vers la lame), Z = largeur de la lame (le tranchant
-- d'une lame à un seul tranchant est côté -Z), X = épaisseur.
--
-- Les pièces qui portent les dégâts (Blade) sont des boîtes simples et invisibles : la détection
-- des coups reste exactement la même. Ce qu'on voit, ce sont des pièces d'ornement sans collision
-- posées par-dessus : arête centrale, biseaux du tranchant, gorge, courbure, etc.
---------------------------------------------------------------------------

-- Ajoute une pièce placée par un CFrame complet (relatif au centre du manche).
local function add(parts: { WeaponPart }, name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material, extra: { [string]: any }?)
	local part: any = {
		Name = name,
		Size = size,
		Offset = frame.Position,
		Rotation = frame.Rotation,
		Color = color,
		Material = material,
	}
	if extra then
		for key, value in extra do
			part[key] = value
		end
	end
	table.insert(parts, part)
end

-- Ornement : sans collision ni masse.
local DECOR = { Decor = true }
-- Acier visible d'une lame : sans collision, et il s'illumine quand un bandit prépare son coup.
local STEEL_LOOK = { Decor = true, Glow = true, Reflectance = BLADE_SHINE }
local EDGE_LOOK = { Decor = true, Glow = true, Reflectance = EDGE_SHINE }

-- Zone de frappe invisible.
local function hitbox(parts: { WeaponPart }, name: string, size: Vector3, offset: Vector3)
	add(parts, name, size, CFrame.new(offset), STEEL, METAL, { Blade = true, Hidden = true })
end

-- Orientation d'un biseau (WedgePart) : la longueur du biseau suit la lame, sa face pleine touche
-- le cœur de la lame et sa pente descend jusqu'au fil. « UP » couvre la face +X, « DOWN » la face -X ;
-- « BACK » sert au second tranchant (côté +Z).
local EDGE_FRONT_UP = CFrame.Angles(0, 0, -math.pi / 2)
local EDGE_FRONT_DOWN = CFrame.Angles(0, 0, math.pi / 2)
local EDGE_BACK_UP = HALF_TURN_X * EDGE_FRONT_UP
local EDGE_BACK_DOWN = HALF_TURN_X * EDGE_FRONT_DOWN

-- Tranchant : deux biseaux dos à dos qui amincissent la lame jusqu'au fil.
-- `z` : centre du biseau dans la largeur ; `width` : largeur du biseau ; `thickness` : épaisseur
-- de la lame là où le biseau commence.
local function bevel(parts: { WeaponPart }, frame: CFrame, length: number, z: number, width: number, thickness: number, back: boolean)
	local size = Vector3.new(length, thickness / 2, width)
	add(parts, "Tranchant", size, frame * CFrame.new(thickness / 4, 0, z) * (if back then EDGE_BACK_UP else EDGE_FRONT_UP), BRIGHT_STEEL, SMOOTH, EDGE_LOOK)
	add(parts, "Tranchant", size, frame * CFrame.new(-thickness / 4, 0, z) * (if back then EDGE_BACK_DOWN else EDGE_FRONT_DOWN), BRIGHT_STEEL, SMOOTH, EDGE_LOOK)
end

-- Tronçon de lame à deux tranchants : section en losange, avec une arête au centre.
local function doubleSegment(parts: { WeaponPart }, frame: CFrame, length: number, width: number, thickness: number)
	local ridge = width * 0.28
	local side = (width - ridge) / 2
	add(parts, "Arete", Vector3.new(thickness, length, ridge), frame, STEEL, METAL, STEEL_LOOK)
	bevel(parts, frame, length, -(ridge + side) / 2, side, thickness, false)
	bevel(parts, frame, length, (ridge + side) / 2, side, thickness, true)
end

-- Tronçon de lame à un seul tranchant : dos épais en +Z, plat de lame (avec gorge éventuelle),
-- puis biseau jusqu'au fil en -Z. `spineZ` : position du dos dans la largeur.
local function singleSegment(parts: { WeaponPart }, frame: CFrame, length: number, width: number, thickness: number, spineZ: number, fuller: boolean)
	local spine = math.min(width * 0.18, 0.08)
	local flat = width * 0.42
	local edge = width - spine - flat
	local flatThickness = thickness * 0.85
	add(parts, "Dos", Vector3.new(thickness, length, spine), frame * CFrame.new(0, 0, spineZ - spine / 2), SPINE_STEEL, METAL, STEEL_LOOK)
	add(parts, "Plat", Vector3.new(flatThickness, length, flat), frame * CFrame.new(0, 0, spineZ - spine - flat / 2), STEEL, METAL, STEEL_LOOK)
	if fuller then
		-- Gorge (gouttière) : un sillon sombre sur chaque face, près du dos.
		add(parts, "Gorge", Vector3.new(flatThickness + 0.012, length, flat * 0.28), frame * CFrame.new(0, 0, spineZ - spine - flat * 0.3), DARK_STEEL, METAL, STEEL_LOOK)
	end
	bevel(parts, frame, length, spineZ - spine - flat - edge / 2, edge, flatThickness, false)
end

type BladeSpec = {
	y: number, -- départ de la lame le long du manche
	length: number,
	width: number, -- largeur à la base
	tipWidth: number, -- largeur juste avant la pointe
	thickness: number,
	segments: number, -- nombre de tronçons (plus il y en a, plus la courbe est lisse)
	curve: number?, -- courbure totale en degrés, vers le dos de la lame
	single: boolean?, -- un seul tranchant (côté -Z)
	spineZ: number?, -- position du dos (lame à un seul tranchant)
	fuller: boolean?,
}

-- Construit une lame tronçon par tronçon et renvoie le repère de son extrémité (où poser la pointe)
-- ainsi que le repère du centre de chaque tronçon.
local function blade(parts: { WeaponPart }, spec: BladeSpec): (CFrame, { CFrame })
	local frame = CFrame.new(0, spec.y, 0)
	local step = spec.length / spec.segments
	local turn = math.rad(spec.curve or 0) / spec.segments
	local centers = {}
	for i = 1, spec.segments do
		frame *= CFrame.Angles(turn / 2, 0, 0)
		local center = frame * CFrame.new(0, step / 2, 0)
		local width = spec.width + (spec.tipWidth - spec.width) * (i - 0.5) / spec.segments
		-- Les tronçons se chevauchent un peu pour ne laisser aucune fente dans la courbe.
		local length = step * (if turn ~= 0 then 1.06 else 1.002)
		if spec.single then
			singleSegment(parts, center, length, width, spec.thickness, spec.spineZ or width / 2, spec.fuller == true)
		else
			doubleSegment(parts, center, length, width, spec.thickness)
		end
		table.insert(centers, center)
		frame *= CFrame.new(0, step, 0) * CFrame.Angles(turn / 2, 0, 0)
	end
	return frame, centers
end

-- Pointe symétrique d'une lame à deux tranchants : deux biseaux qui se rejoignent dans l'axe.
-- `frame` : base de la pointe (la pointe part vers +Y de ce repère).
local function point(parts: { WeaponPart }, frame: CFrame, height: number, width: number, thickness: number, extra: { [string]: any }?)
	local look = extra or EDGE_LOOK
	local size = Vector3.new(thickness, height, width / 2)
	add(parts, "Pointe", size, frame * CFrame.new(0, height / 2, -width / 4), BRIGHT_STEEL, SMOOTH, look)
	add(parts, "Pointe", size, frame * CFrame.new(0, height / 2, width / 4) * HALF_TURN_Y, BRIGHT_STEEL, SMOOTH, look)
end

-- Pointe d'une lame à un seul tranchant : le fil remonte en courbe vers le dos.
local function clipPoint(parts: { WeaponPart }, frame: CFrame, height: number, width: number, thickness: number, spineZ: number)
	add(parts, "Pointe", Vector3.new(thickness * 0.85, height, width), frame * CFrame.new(0, height / 2, spineZ - width / 2), STEEL, METAL, STEEL_LOOK)
	-- Fil poli le long de la pente, de chaque côté.
	local slope = math.sqrt(height * height + width * width)
	local angle = math.atan2(width, height)
	add(parts, "Tranchant", Vector3.new(thickness * 0.9, slope, 0.035), frame * CFrame.new(0, height / 2, spineZ - width / 2) * CFrame.Angles(angle, 0, 0), BRIGHT_STEEL, SMOOTH, EDGE_LOOK)
end

-- Bague ronde autour du manche.
local function collar(parts: { WeaponPart }, name: string, y: number, diameter: number, height: number, color: Color3, extra: { [string]: any }?)
	local options: { [string]: any } = { Shape = CYLINDER }
	if extra then
		for key, value in extra do
			options[key] = value
		end
	end
	add(parts, name, Vector3.new(height, diameter, diameter), CFrame.new(0, y, 0) * ALONG_Y, color, METAL, options)
end

-- Anneau (pommeau en anneau) dans le plan de la lame, fait de petits segments.
local function ring(parts: { WeaponPart }, name: string, center: CFrame, radius: number, thickness: number, color: Color3)
	local segments = 10
	local chord = 2 * radius * math.sin(math.pi / segments) * 1.18
	for i = 0, segments - 1 do
		local frame = center * CFrame.Angles(2 * math.pi * i / segments, 0, 0) * CFrame.new(0, radius, 0)
		add(parts, name, Vector3.new(thickness, thickness, chord), frame, color, METAL, DECOR)
	end
end

-- Tressage de la poignée : des tours de cordon croisés, légèrement inclinés dans un sens puis
-- dans l'autre, qui dessinent le motif en losanges des poignées tressées.
local function wrap(parts: { WeaponPart }, y0: number, y1: number, diameter: number, color: Color3)
	local count = math.max(2, math.floor((y1 - y0) / 0.12))
	for i = 0, count - 1 do
		local y = y0 + (i + 0.5) * (y1 - y0) / count
		local tilt = if i % 2 == 0 then 0.22 else -0.22
		add(parts, "Tresse", Vector3.new(0.045, diameter + 0.03, diameter + 0.03), CFrame.new(0, y, 0) * CFrame.Angles(tilt, 0, 0) * ALONG_Y, color, FABRIC, DECOR)
	end
end

-- Houppe de crin ou de soie : des brins qui pendent en s'écartant autour de la hampe.
local function tassel(parts: { WeaponPart }, y: number, radius: number, length: number, strands: number)
	add(parts, "Noeud", Vector3.new(0.12, radius * 2 + 0.12, radius * 2 + 0.12), CFrame.new(0, y, 0) * ALONG_Y, SILK_RED, FABRIC, DECOR)
	for i = 1, strands do
		local frame = CFrame.new(0, y, 0)
			* CFrame.Angles(0, 2 * math.pi * i / strands, 0)
			* CFrame.new(0, 0, radius)
			* CFrame.Angles(math.rad(-16), 0, 0)
			* CFrame.new(0, -length / 2, 0)
		add(parts, "Houppe", Vector3.new(0.06, length, 0.06), frame, SILK_RED, FABRIC, DECOR)
	end
end

-- Cordon et pompon accrochés au pommeau.
local function pompon(parts: { WeaponPart }, y: number, cord: number)
	add(parts, "Cordon", Vector3.new(0.04, cord, 0.04), CFrame.new(0, y - cord / 2, 0), SILK_RED, FABRIC, DECOR)
	add(parts, "Noeud", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0, y - cord, 0), SILK_RED, FABRIC, { Decor = true, Shape = BALL })
	tassel(parts, y - cord - 0.06, 0.04, 0.4, 6)
end

---------------------------------------------------------------------------
-- Modèles
---------------------------------------------------------------------------

-- Bishou (匕首) : dague droite à deux tranchants, à arête centrale, garde à boules et pommeau
-- en anneau.
local dagueParts: { WeaponPart } = {}
hitbox(dagueParts, "Lame", Vector3.new(0.06, 1.05, 0.26), Vector3.new(0, 1.045, 0))
ring(dagueParts, "Anneau", CFrame.new(0, -0.6, 0), 0.15, 0.06, BRONZE)
collar(dagueParts, "Bague", -0.42, 0.27, 0.07, BRONZE)
collar(dagueParts, "Virole", 0.4, 0.26, 0.07, BRONZE)
wrap(dagueParts, -0.36, 0.34, 0.24, CORD_DARK)
add(dagueParts, "Garde", Vector3.new(0.18, 0.1, 0.42), CFrame.new(0, 0.46, 0), BRONZE, METAL)
add(dagueParts, "Quillon", Vector3.new(0.13, 0.13, 0.13), CFrame.new(0, 0.46, -0.22), BRONZE, METAL, { Shape = BALL })
add(dagueParts, "Quillon", Vector3.new(0.13, 0.13, 0.13), CFrame.new(0, 0.46, 0.22), BRONZE, METAL, { Shape = BALL })
do
	local tip = blade(dagueParts, { y = 0.5, length = 1.07, width = 0.26, tipWidth = 0.21, thickness = 0.06, segments = 3 })
	point(dagueParts, tip, 0.42, 0.21, 0.05)
end

-- Jian (剑) : épée droite à deux tranchants, lame effilée à arête centrale, garde en « montagne »
-- de bronze incrustée de jade, pommeau rond et pompon de soie rouge.
local epeeParts: { WeaponPart } = {}
hitbox(epeeParts, "Lame", Vector3.new(0.07, 2.7, 0.32), Vector3.new(0, 2.06, 0))
add(epeeParts, "Pommeau", Vector3.new(0.2, 0.4, 0.4), CFrame.new(0, -0.7, 0), BRONZE, METAL, { Shape = CYLINDER })
add(epeeParts, "Jade", Vector3.new(0.24, 0.2, 0.2), CFrame.new(0, -0.7, 0), JADE, SMOOTH, { Shape = CYLINDER, Reflectance = 0.15 })
collar(epeeParts, "Virole", -0.55, 0.27, 0.08, BRONZE)
collar(epeeParts, "Virole", 0.55, 0.27, 0.08, BRONZE)
wrap(epeeParts, -0.5, 0.5, 0.25, Color3.fromRGB(60, 25, 20))
add(epeeParts, "Garde", Vector3.new(0.28, 0.2, 0.36), CFrame.new(0, 0.64, 0), BRONZE, METAL)
-- Ailes de la garde : elles s'abaissent du centre vers les côtés.
add(epeeParts, "Garde", Vector3.new(0.24, 0.17, 0.3), CFrame.new(0, 0.625, -0.33), BRONZE, METAL, { Wedge = true })
add(epeeParts, "Garde", Vector3.new(0.24, 0.17, 0.3), CFrame.new(0, 0.625, 0.33) * HALF_TURN_Y, BRONZE, METAL, { Wedge = true })
add(epeeParts, "Jade", Vector3.new(0.3, 0.11, 0.11), CFrame.new(0, 0.64, 0), JADE, SMOOTH, { Decor = true, Shape = CYLINDER, Reflectance = 0.15 })
pompon(epeeParts, -0.9, 0.3)
do
	local tip = blade(epeeParts, { y = 0.74, length = 2.67, width = 0.32, tipWidth = 0.26, thickness = 0.07, segments = 4 })
	point(epeeParts, tip, 0.45, 0.26, 0.06)
end

-- Dao (刀) : sabre à une main, courbe, à un seul tranchant (côté -Z), lame qui s'élargit vers la
-- pointe, garde en disque, pommeau en anneau et foulard de soie rouge.
local sabreParts: { WeaponPart } = {}
hitbox(sabreParts, "Lame", Vector3.new(0.08, 2.2, 0.42), Vector3.new(0, 1.7, 0))
ring(sabreParts, "Anneau", CFrame.new(0, -0.7, 0), 0.16, 0.06, BRASS)
add(sabreParts, "Foulard", Vector3.new(0.03, 0.8, 0.22), CFrame.new(0, -1.25, 0.04) * CFrame.Angles(0.12, 0, 0), SILK_RED, FABRIC, DECOR)
collar(sabreParts, "Virole", -0.5, 0.26, 0.08, BRASS)
wrap(sabreParts, -0.45, 0.45, 0.24, Color3.fromRGB(45, 28, 20))
add(sabreParts, "Garde", Vector3.new(0.08, 0.72, 0.72), CFrame.new(0, 0.55, 0) * ALONG_Y, BRASS, METAL, { Shape = CYLINDER })
add(sabreParts, "Collet", Vector3.new(0.07, 0.36, 0.36), CFrame.new(0, 0.62, 0) * ALONG_Y, BRASS, METAL, { Shape = CYLINDER })
do
	local spec = { y = 0.65, length = 2.45, width = 0.36, tipWidth = 0.48, thickness = 0.08, segments = 6, curve = 12, single = true, spineZ = 0.2, fuller = true }
	local tip = blade(sabreParts, spec)
	clipPoint(sabreParts, tip, 0.45, spec.tipWidth, spec.thickness, spec.spineZ)
end

-- Changdao (长刀) : long sabre à deux mains, légèrement courbe, à un seul tranchant (côté -Z),
-- garde ronde en laiton, longue poignée tressée.
local epeeLongueParts: { WeaponPart } = {}
hitbox(epeeLongueParts, "Lame", Vector3.new(0.09, 3.6, 0.42), Vector3.new(0, 2.86, 0))
collar(epeeLongueParts, "Pommeau", -1.02, 0.32, 0.16, BRASS, { Shape = CYLINDER })
wrap(epeeLongueParts, -0.92, 0.92, 0.25, CORD_DARK)
add(epeeLongueParts, "Garde", Vector3.new(0.1, 0.9, 0.9), CFrame.new(0, 1, 0) * ALONG_Y, BRASS, METAL, { Shape = CYLINDER })
add(epeeLongueParts, "Garde", Vector3.new(0.05, 0.98, 0.98), CFrame.new(0, 1, 0) * ALONG_Y, DARK_STEEL, METAL, { Decor = true, Shape = CYLINDER })
add(epeeLongueParts, "Collet", Vector3.new(0.13, 0.26, 0.4), CFrame.new(0, 1.18, 0), BRASS, METAL)
do
	local spec = { y = 1.05, length = 3.85, width = 0.4, tipWidth = 0.34, thickness = 0.09, segments = 7, curve = 8, single = true, spineZ = 0.2, fuller = true }
	local tip = blade(epeeLongueParts, spec)
	clipPoint(epeeLongueParts, tip, 0.55, spec.tipWidth, spec.thickness, spec.spineZ)
end

-- Fu (斧) : hache de guerre au fer en croissant, pointe au sommet, houppe de soie rouge sous le fer.
-- Le fer dépasse vers l'avant (-Z), côté tranchant.
local hacheParts: { WeaponPart } = {}
hitbox(hacheParts, "Fer", Vector3.new(0.1, 1, 0.6), Vector3.new(0, 0.95, -0.5))
singleSegment(hacheParts, CFrame.new(0, 0.95, 0), 1, 0.62, 0.12, -0.18, false)
add(hacheParts, "Corne", Vector3.new(0.09, 0.4, 0.6), CFrame.new(0, 1.65, -0.5) * HALF_TURN_Y, STEEL, METAL, STEEL_LOOK)
add(hacheParts, "Corne", Vector3.new(0.09, 0.4, 0.6), CFrame.new(0, 0.25, -0.5) * HALF_TURN_X, STEEL, METAL, STEEL_LOOK)
add(hacheParts, "Douille", Vector3.new(0.36, 0.7, 0.36), CFrame.new(0, 0.95, 0), DARK_STEEL, METAL)
for _, y in { 0.75, 1.15 } do
	for _, x in { 0.19, -0.19 } do
		add(hacheParts, "Rivet", Vector3.new(0.08, 0.08, 0.08), CFrame.new(x, y, 0), BRASS, METAL, { Decor = true, Shape = BALL })
	end
end
add(hacheParts, "Marteau", Vector3.new(0.24, 0.4, 0.3), CFrame.new(0, 0.95, 0.32), DARK_STEEL, METAL)
point(hacheParts, CFrame.new(0, 1.3, 0), 0.5, 0.2, 0.08, STEEL_LOOK)
tassel(hacheParts, 0.56, 0.1, 0.45, 8)
collar(hacheParts, "Bague", -1.25, 0.32, 0.14, BRASS)
wrap(hacheParts, -1.1, -0.2, 0.25, CORD_DARK)

-- Qiang (枪) : lance à hampe de bois clair, fer en feuille de saule et houppe de crin rouge
-- sous le fer (elle servait à brouiller la vue de l'adversaire).
local lanceParts: { WeaponPart } = {}
hitbox(lanceParts, "Fer", Vector3.new(0.08, 0.6, 0.3), Vector3.new(0, 3.65, 0))
collar(lanceParts, "Talon", -3.18, 0.3, 0.28, BRASS)
point(lanceParts, CFrame.new(0, -3.32, 0) * HALF_TURN_X, 0.2, 0.22, 0.2, DECOR)
tassel(lanceParts, 3.08, 0.12, 0.6, 10)
collar(lanceParts, "Douille", 3.26, 0.3, 0.3, BRASS)
collar(lanceParts, "Col", 3.46, 0.2, 0.12, DARK_STEEL)
do
	local tip = blade(lanceParts, { y = 3.52, length = 0.43, width = 0.2, tipWidth = 0.3, thickness = 0.08, segments = 2 })
	point(lanceParts, tip, 0.62, 0.3, 0.07)
end
for _, y in { -1.6, -0.8 } do
	collar(lanceParts, "Bague", y, 0.29, 0.06, Color3.fromRGB(110, 30, 25), DECOR)
end

-- Guandao (偃月刀) : lourde lame de sabre en croissant montée sur une hampe, avec un crochet
-- au dos de la lame, une houppe rouge et une pointe de contrepoids au talon. Tranchant côté -Z.
local guandaoParts: { WeaponPart } = {}
hitbox(guandaoParts, "Lame", Vector3.new(0.1, 1.8, 0.7), Vector3.new(0, 3.85, -0.2))
point(guandaoParts, CFrame.new(0, -2.82, 0) * HALF_TURN_X, 0.55, 0.2, 0.12, DECOR)
collar(guandaoParts, "Talon", -2.7, 0.34, 0.25, BRASS)
tassel(guandaoParts, 2.5, 0.13, 0.55, 10)
add(guandaoParts, "Collet", Vector3.new(0.38, 0.35, 0.48), CFrame.new(0, 2.78, 0), BRASS, METAL)
add(guandaoParts, "Collet", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 2.78, 0.26), BRASS, METAL, { Decor = true, Shape = BALL })
do
	local spec = { y = 2.95, length = 1.9, width = 0.6, tipWidth = 0.78, thickness = 0.1, segments = 6, curve = 24, single = true, spineZ = 0.12, fuller = true }
	local tip, centers = blade(guandaoParts, spec)
	clipPoint(guandaoParts, tip, 0.8, spec.tipWidth, spec.thickness, spec.spineZ)
	-- Crochet au dos de la lame.
	local back = centers[3] * CFrame.new(0, 0, spec.spineZ + 0.12)
	add(guandaoParts, "Crochet", Vector3.new(0.09, 0.3, 0.24), back * HALF_TURN_Y, SPINE_STEEL, METAL, STEEL_LOOK)
end
for _, y in { -0.6, 0.6 } do
	collar(guandaoParts, "Bague", y, 0.28, 0.07, GOLD, DECOR)
end

-- Gun (棍) : bâton long, ferré aux deux bouts. Ce sont les embouts qui frappent.
local batonParts: { WeaponPart } = {}
hitbox(batonParts, "Embout", Vector3.new(0.34, 0.7, 0.34), Vector3.new(0, 2.75, 0))
hitbox(batonParts, "Embout", Vector3.new(0.34, 0.7, 0.34), Vector3.new(0, -2.75, 0))
for _, sign in { 1, -1 } do
	collar(batonParts, "Ferrure", sign * 2.75, 0.32, 0.7, DARK_STEEL, { Decor = true, Glow = true })
	collar(batonParts, "Cerclage", sign * 2.45, 0.37, 0.06, DARK_STEEL, DECOR)
	collar(batonParts, "Cerclage", sign * 3.05, 0.37, 0.06, DARK_STEEL, DECOR)
	collar(batonParts, "Bague", sign * 2.3, 0.31, 0.12, BRASS)
	collar(batonParts, "Bague", sign * 0.55, 0.28, 0.05, Color3.fromRGB(110, 30, 25), DECOR)
end

-- Tengpai (藤牌) : bouclier rond en rotin tressé en spirale, cerclé de laque rouge, umbo doré.
local SHIELD_FACE = CFrame.Angles(0, math.rad(90), 0) -- couche le disque face à -Z
local shieldParts: { WeaponPart } = {
	{ Name = "Plateau", Size = Vector3.new(0.3, 3.6, 3.6), Offset = Vector3.new(0, 0, -0.6), Color = Color3.fromRGB(150, 105, 55), Material = Enum.Material.WoodPlanks, Shape = CYLINDER, Rotation = SHIELD_FACE, Shield = true },
	{ Name = "Cerclage", Size = Vector3.new(0.2, 3.8, 3.8), Offset = Vector3.new(0, 0, -0.55), Color = Color3.fromRGB(105, 25, 25), Material = Enum.Material.Wood, Shape = CYLINDER, Rotation = SHIELD_FACE },
	{ Name = "Umbo", Size = Vector3.new(0.3, 1, 1), Offset = Vector3.new(0, 0, -0.85), Color = GOLD, Material = METAL, Shape = CYLINDER, Rotation = SHIELD_FACE },
	{ Name = "Sangle", Size = Vector3.new(0.18, 0.18, 0.5), Offset = Vector3.new(0, 0.38, -0.25), Color = DARK_STEEL, Material = METAL },
	{ Name = "Sangle", Size = Vector3.new(0.18, 0.18, 0.5), Offset = Vector3.new(0, -0.38, -0.25), Color = DARK_STEEL, Material = METAL },
}
-- Spires de rotin : des anneaux concentriques de teintes alternées sur la face avant.
for i, diameter in { 3.3, 2.85, 2.4, 1.95, 1.5 } do
	local color = if i % 2 == 0 then Color3.fromRGB(165, 120, 65) else Color3.fromRGB(125, 85, 45)
	add(shieldParts, "Rotin", Vector3.new(0.012, diameter, diameter), CFrame.new(0, 0, -0.756 - i * 0.004) * SHIELD_FACE, color, Enum.Material.Wood, { Decor = true, Shape = CYLINDER })
end
-- Clous de laiton autour du cerclage.
for i = 1, 16 do
	local angle = 2 * math.pi * i / 16
	add(shieldParts, "Clou", Vector3.new(0.1, 0.1, 0.1), CFrame.new(math.cos(angle) * 1.72, math.sin(angle) * 1.72, -0.68), BRASS, METAL, { Decor = true, Shape = BALL })
end
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
		Parts = shieldParts,
	},
}

-- Manche rond : le manche réel est une boîte (pratique pour la prise en main et les calculs),
-- rendue invisible ; on voit à sa place un cylindre de la même longueur.
for _, def in weapons do
	local diameter = def.HandleDiameter or 0.24
	table.insert(def.Parts, 1, {
		Name = "Fut",
		Size = Vector3.new(def.HandleLength, diameter, diameter),
		Offset = Vector3.zero,
		Rotation = ALONG_Y,
		Color = def.HandleColor or Config.HANDLE_WOOD,
		Material = def.HandleMaterial or Enum.Material.Wood,
		Shape = CYLINDER,
		Decor = true,
	})
end
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

-- Combos de calligraphie : enchaîner les bons traits de lame trace un caractère chinois dans l'air
-- et libère son effet. Partagé entre le client (qui reconnaît les traits) et le serveur (qui
-- applique l'effet, avec son délai de recharge).
--
-- Traits reconnus, vus depuis le joueur (le sens gauche/droite est celui de son regard) :
--   "V"  : vertical, de haut en bas (fendant)
--   "H"  : horizontal, dans un sens ou dans l'autre (fauchage, revers)
--   "DG" : diagonale qui descend vers la gauche
--   "DD" : diagonale qui descend vers la droite
--   "E"  : estoc, la pointe part droit devant

local Calligraphy = {}

-- Un trait : un geste de lame assez rapide (pointe au-dessus de STROKE_SPEED) et assez long.
Calligraphy.STROKE_SPEED = 11 -- studs/s
Calligraphy.MIN_LENGTH = 1.2 -- longueur minimale d'un estoc (studs)
Calligraphy.MIN_PLANAR = 1.6 -- longueur minimale d'un trait tracé face au joueur (studs) : les petits gestes ne comptent pas
-- Un geste qui monte (lame ramenée en garde entre deux traits) n'est jamais un trait :
-- en calligraphie, les traits descendent ou vont de côté.
Calligraphy.MAX_RISE = 0.3 -- part maximale de montée dans un trait horizontal
Calligraphy.MAX_GAP = 2.5 -- temps maximal entre deux traits d'un même caractère (s)
-- Un trait parasite (lame repositionnée un peu vite) glissé dans le caractère est toléré.
Calligraphy.ALLOW_EXTRA_STROKE = true
-- Tolérance d'angle : un trait est « vertical » ou « horizontal » à moins de 35° près ;
-- entre les deux, c'est une diagonale.
Calligraphy.STRAIGHT_TOLERANCE = 35 -- degrés
-- true : chaque trait lu (ou refusé, avec son déplacement) s'écrit dans la fenêtre Sortie.
Calligraphy.DEBUG = false

-- Nom des traits, comme en calligraphie chinoise, pour l'affichage.
Calligraphy.STROKE_NAMES = {
	V = "竖", -- shù : vertical
	H = "横", -- héng : horizontal
	DG = "丿", -- piě : descend vers la gauche
	DD = "㇏", -- nà : descend vers la droite
	E = "点", -- diǎn : estoc
}

export type Combo = {
	Id: string,
	Char: string, -- caractère tracé dans l'air
	Name: string,
	Strokes: { string },
	Cooldown: number, -- secondes
	Description: string,
	-- Réglages de l'effet (dégâts, portée…), lus par le serveur.
	Damage: number?,
	Range: number?,
	Width: number?,
	Radius: number?,
	Stun: number?,
	Heal: number?, -- fraction des points de vie maximaux
	Qi: number?,
}

Calligraphy.Combos = {
	{
		Id = "Croix",
		Char = "十",
		Name = "Croix du sabre",
		Strokes = { "V", "H" },
		Cooldown = 4,
		Description = "Le caractère file vers la cible en fendant tout sur son passage, puis éclate en croix.",
		Damage = 30,
		Range = 18,
		Width = 7,
	},
	{
		Id = "Homme",
		Char = "人",
		Name = "Souffle de l'homme",
		Strokes = { "DG", "DD" },
		Cooldown = 10,
		Description = "Le souffle se rassemble : rend des points de vie et du Qi.",
		Heal = 0.15,
		Qi = 20,
	},
	{
		Id = "Riviere",
		Char = "川",
		Name = "Trois cascades",
		Strokes = { "V", "V", "V" },
		Cooldown = 6,
		Description = "Trois lames tombent l'une après l'autre sur une ligne devant le joueur.",
		Damage = 22,
		Range = 18,
		Width = 4,
	},
	{
		Id = "Grand",
		Char = "大",
		Name = "Grande onde",
		Strokes = { "H", "DG", "DD" },
		Cooldown = 12,
		Description = "Une onde de Qi part du joueur, blesse, repousse et sonne tout autour.",
		Damage = 35,
		Radius = 14,
		Stun = 1.2,
	},
	{
		Id = "Percee",
		Char = "刺",
		Name = "Percée du dragon",
		Strokes = { "E", "E", "E" },
		Cooldown = 7,
		Description = "Trois estocs : un trait de Qi transperce tout sur une longue ligne droite.",
		Damage = 28,
		Range = 24,
		Width = 3,
	},
} :: { Combo }

Calligraphy.ById = {} :: { [string]: Combo }
for _, combo in Calligraphy.Combos do
	Calligraphy.ById[combo.Id] = combo
end

-- Classe un trait d'après son déplacement dans le repère du regard du joueur
-- (x vers sa droite, y vers le haut, z vers l'avant). Renvoie nil si le geste est ambigu.
function Calligraphy.classify(x: number, y: number, z: number): string?
	local length = math.sqrt(x * x + y * y + z * z)
	if length < Calligraphy.MIN_LENGTH then
		return nil
	end
	local ax, ay, az = math.abs(x) / length, math.abs(y) / length, math.abs(z) / length
	-- Estoc : la pointe part droit devant, sans descendre franchement (sinon c'est un fendant vers l'avant).
	if z > 0 and az >= 0.8 and ay <= 0.45 then
		return "E"
	end
	-- Le geste se lit dans le plan face au joueur.
	local planar = math.sqrt(x * x + y * y)
	if planar < Calligraphy.MIN_PLANAR then
		return nil
	end
	local px, py = x / planar, y / planar
	if py > Calligraphy.MAX_RISE then
		return nil -- la lame remonte : ce n'est pas un trait
	end
	local straight = math.cos(math.rad(Calligraphy.STRAIGHT_TOLERANCE))
	if py <= -straight then
		return "V"
	end
	if math.abs(px) >= straight then
		return "H"
	end
	-- Diagonale descendante (vers le bas, entre la verticale et l'horizontale).
	if py < -0.2 then
		return if px < 0 then "DG" else "DD"
	end
	return nil
end

-- Les traits du combo se lisent-ils à la fin de `strokes` ? Le dernier trait doit être le dernier
-- du combo. Avec `skips` = 1, un trait parasite peut s'être glissé entre chaque paire de traits du combo.
local function endsWith(strokes: { string }, wanted: { string }, skips: number): boolean
	local i = #strokes
	for j = #wanted, 1, -1 do
		if i < 1 then
			return false
		end
		if strokes[i] == wanted[j] then
			i -= 1
		elseif j < #wanted and skips > 0 and i > 1 and strokes[i - 1] == wanted[j] then
			-- Trait parasite entre deux traits du combo : on le saute.
			i -= 2
		else
			return false
		end
	end
	return true
end

-- Le combo dont les traits terminent `strokes`, ou nil. Une suite exacte l'emporte sur une suite
-- avec un trait parasite ; à égalité, le combo le plus long l'emporte.
function Calligraphy.match(strokes: { string }): Combo?
	local tolerances = if Calligraphy.ALLOW_EXTRA_STROKE then { 0, 1 } else { 0 }
	for _, skips in tolerances do
		local best: Combo? = nil
		for _, combo in Calligraphy.Combos do
			if (not best or #combo.Strokes > #best.Strokes) and endsWith(strokes, combo.Strokes, skips) then
				best = combo
			end
		end
		if best then
			return best
		end
	end
	return nil
end

return Calligraphy

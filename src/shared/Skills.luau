-- Arbre de cultivation : les techniques que le joueur débloque avec ses points de Qi.
-- Partagé entre le serveur (qui valide et applique les effets) et le client (qui affiche l'arbre).

local Skills = {}

-- Points de Qi gagnés à chaque niveau : 19 au niveau 20, pour un arbre qui en coûte 25.
-- Il faut donc choisir ses voies.
Skills.POINTS_PER_LEVEL = 1

-- Royaumes de cultivation : le nom du palier atteint par le joueur selon son niveau.
Skills.REALMS = {
	{ MinLevel = 1, Name = "Raffinement du Qi", Hanzi = "炼气" },
	{ MinLevel = 5, Name = "Établissement des fondations", Hanzi = "筑基" },
	{ MinLevel = 9, Name = "Noyau d'or", Hanzi = "金丹" },
	{ MinLevel = 13, Name = "Âme naissante", Hanzi = "元婴" },
	{ MinLevel = 17, Name = "Transformation divine", Hanzi = "化神" },
}

-- Effets possibles d'une technique (ils s'additionnent entre techniques) :
--   Health      : points de vie maximaux en plus
--   Damage      : dégâts infligés en plus (0.15 = +15 %)
--   DamageTaken : dégâts reçus en moins (0.15 = -15 %)
--   Regen       : points de vie regagnés par seconde
--   Riposte     : ajouté au multiplicateur de riposte sur un bandit vulnérable
--   ParryDamage : dégâts en plus renvoyés par une parade parfaite
--   ParryStun   : secondes en plus pendant lesquelles un bandit paré parfaitement reste sonné
--   Speed       : vitesse de marche en plus (0.2 = +20 %)
--   Jump        : hauteur de saut en plus (0.3 = +30 %)
--   Xp          : expérience gagnée en plus (0.25 = +25 %)
--   KillHeal    : part des points de vie maximaux rendue à chaque bandit tué
export type Skill = {
	Id: string,
	Name: string,
	Hanzi: string,
	Path: string, -- "Racine", "Corps", "Lame", "Souffle" ou "Arts"
	Description: string,
	Cost: number, -- points de Qi
	MinLevel: number,
	Requires: string?, -- technique à posséder d'abord
	Column: number, -- position dans l'arbre, de -1.5 (gauche) à 1.5 (droite) ; 0 = centre
	Row: number, -- 0 = racine, puis 1, 2, 3 vers le haut
	Effects: { [string]: number },
	-- Technique active : coût en Qi, délai entre deux usages (s) et réglages propres à la technique.
	Active: { [string]: number }?,
}

-- Réserve de Qi qui alimente les techniques actives.
Skills.QI_MAX = 100
Skills.QI_REGEN = 6 -- Qi regagné par seconde

local list: { Skill } = {
	{
		Id = "Eveil", Name = "Éveil du Qi", Hanzi = "气感", Path = "Racine",
		Description = "Tu sens le Qi circuler dans tes méridiens. +10 PV, +5 % de dégâts. Ouvre les trois voies.",
		Cost = 1, MinLevel = 2, Column = 0, Row = 0,
		Effects = { Health = 10, Damage = 0.05 },
	},

	-- Voie du Corps (炼体) : encaisser.
	{
		Id = "PeauDeFer", Name = "Chemise de fer", Hanzi = "铁布衫", Path = "Corps",
		Description = "Ta peau durcit comme le métal. -15 % de dégâts reçus.",
		Cost = 1, MinLevel = 2, Requires = "Eveil", Column = -1.5, Row = 1,
		Effects = { DamageTaken = 0.15 },
	},
	{
		Id = "CorpsDeJade", Name = "Corps de jade", Hanzi = "玉体", Path = "Corps",
		Description = "Tes os et tes tendons sont purifiés. +40 PV.",
		Cost = 2, MinLevel = 5, Requires = "PeauDeFer", Column = -1.5, Row = 2,
		Effects = { Health = 40 },
	},
	{
		Id = "CorpsDeDiamant", Name = "Corps de diamant", Hanzi = "金刚不坏", Path = "Corps",
		Description = "Corps indestructible. -15 % de dégâts reçus en plus, et tu regagnes 2 PV par seconde.",
		Cost = 3, MinLevel = 9, Requires = "CorpsDeJade", Column = -1.5, Row = 3,
		Effects = { DamageTaken = 0.15, Regen = 2 },
	},

	-- Voie de la Lame (剑道) : frapper.
	{
		Id = "Tranchant", Name = "Intention de l'épée", Hanzi = "剑意", Path = "Lame",
		Description = "Ta volonté prolonge ta lame. +15 % de dégâts.",
		Cost = 1, MinLevel = 2, Requires = "Eveil", Column = -0.5, Row = 1,
		Effects = { Damage = 0.15 },
	},
	{
		Id = "Riposte", Name = "Riposte du dragon", Hanzi = "龙反击", Path = "Lame",
		Description = "Tu punis la moindre ouverture. Les coups sur un bandit vulnérable font ×3 au lieu de ×2.",
		Cost = 2, MinLevel = 5, Requires = "Tranchant", Column = -0.5, Row = 2,
		Effects = { Riposte = 1 },
	},
	{
		Id = "CoeurEpee", Name = "Cœur d'épée", Hanzi = "剑心", Path = "Lame",
		Description = "L'épée et l'esprit ne font qu'un. La parade parfaite renvoie 25 dégâts de plus et sonne 1 s de plus.",
		Cost = 3, MinLevel = 9, Requires = "Riposte", Column = -0.5, Row = 3,
		Effects = { ParryDamage = 25, ParryStun = 1 },
	},

	-- Voie du Souffle (气功) : se mouvoir et progresser.
	{
		Id = "PasLeger", Name = "Pas léger", Hanzi = "轻功", Path = "Souffle",
		Description = "Ton corps devient léger comme une plume. +20 % de vitesse, +30 % de hauteur de saut.",
		Cost = 1, MinLevel = 2, Requires = "Eveil", Column = 0.5, Row = 1,
		Effects = { Speed = 0.2, Jump = 0.3 },
	},
	{
		Id = "Meditation", Name = "Méditation", Hanzi = "打坐", Path = "Souffle",
		Description = "Chaque combat nourrit ta compréhension. +25 % d'expérience.",
		Cost = 2, MinLevel = 5, Requires = "PasLeger", Column = 0.5, Row = 2,
		Effects = { Xp = 0.25 },
	},
	{
		Id = "Absorption", Name = "Absorption du Qi", Hanzi = "吸星大法", Path = "Souffle",
		Description = "Tu aspires le Qi des vaincus. Chaque bandit tué te rend 15 % de tes PV.",
		Cost = 3, MinLevel = 9, Requires = "Meditation", Column = 0.5, Row = 3,
		Effects = { KillHeal = 0.15 },
	},

	-- Voie des Arts (武技) : techniques actives, que le joueur déclenche et qui consomment du Qi.
	{
		Id = "OndeDeQi", Name = "Onde de Qi", Hanzi = "剑气", Path = "Arts",
		Description = "Projette une lame d'énergie dans l'axe de ton arme. 30 dégâts à tout ce qu'elle traverse. Gâchette de la main armée (F au clavier).",
		Cost = 1, MinLevel = 2, Requires = "Eveil", Column = 1.5, Row = 1,
		Effects = {},
		Active = { QiCost = 30, Cooldown = 1.5, Damage = 30, Range = 45, Speed = 70, Radius = 3 },
	},
	{
		Id = "Rugissement", Name = "Rugissement du lion", Hanzi = "狮子吼", Path = "Arts",
		Description = "Un cri chargé de Qi repousse et sonne 2 s tous les bandits autour de toi, et leur inflige 12 dégâts. Bouton Y (R au clavier).",
		Cost = 2, MinLevel = 5, Requires = "OndeDeQi", Column = 1.5, Row = 2,
		Effects = {},
		Active = { QiCost = 50, Cooldown = 8, Damage = 12, Radius = 14, Stun = 2, Knockback = 45 },
	},
	{
		Id = "Ruee", Name = "Pas de l'éclair", Hanzi = "闪电步", Path = "Arts",
		Description = "Tu franchis 16 studs en un instant dans la direction de ton regard. Bouton B (C au clavier).",
		Cost = 3, MinLevel = 9, Requires = "Rugissement", Column = 1.5, Row = 3,
		Effects = {},
		Active = { QiCost = 25, Cooldown = 3, Distance = 16 },
	},
}

Skills.List = list

local byId: { [string]: Skill } = {}
for _, skill in list do
	byId[skill.Id] = skill
end
Skills.ById = byId

-- Royaume atteint au niveau `level`.
function Skills.realm(level: number): { MinLevel: number, Name: string, Hanzi: string }
	local current = Skills.REALMS[1]
	for _, realm in Skills.REALMS do
		if level >= realm.MinLevel then
			current = realm
		end
	end
	return current
end

-- Points de Qi gagnés en tout au niveau `level`.
function Skills.totalPoints(level: number): number
	return (level - 1) * Skills.POINTS_PER_LEVEL
end

-- Points dépensés pour un ensemble de techniques ({ [Id] = true }).
function Skills.spentPoints(owned: { [string]: boolean }): number
	local spent = 0
	for id in owned do
		local skill = byId[id]
		if skill then
			spent += skill.Cost
		end
	end
	return spent
end

-- Le joueur peut-il débloquer cette technique ? Renvoie aussi la raison du refus, pour l'affichage.
function Skills.canUnlock(skill: Skill, level: number, owned: { [string]: boolean }): (boolean, string?)
	if owned[skill.Id] then
		return false, "Déjà acquise"
	end
	if skill.Requires and not owned[skill.Requires] then
		return false, "Demande : " .. byId[skill.Requires].Name
	end
	if level < skill.MinLevel then
		return false, "Demande le niveau " .. skill.MinLevel
	end
	if Skills.totalPoints(level) - Skills.spentPoints(owned) < skill.Cost then
		return false, "Pas assez de points de Qi"
	end
	return true, nil
end

-- Transforme l'attribut « Skills » du joueur ("Eveil,Tranchant") en ensemble.
function Skills.parse(text: any): { [string]: boolean }
	local owned = {}
	if typeof(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			if byId[id] then
				owned[id] = true
			end
		end
	end
	return owned
end

return Skills

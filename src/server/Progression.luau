-- Niveau des joueurs : l'expérience gagnée en tuant des bandits fait monter de niveau,
-- et chaque niveau augmente les points de vie et les dégâts du joueur.
-- Le niveau et l'expérience sont sauvegardés dans un DataStore et retrouvés à la partie suivante.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Progression = {}

local Skills = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Skills"))

local settings = Config.PlayerLevel

-- `skills` : techniques de cultivation débloquées ({ [Id] = true }).
-- `canSave` : false si la lecture de la sauvegarde a échoué. Dans ce cas on n'écrit rien,
-- pour ne pas remplacer une vraie progression par un niveau 1.
type Stats = { level: number, xp: number, skills: { [string]: boolean }, canSave: boolean }

local stats: { [Player]: Stats } = {}

-- Valeurs par défaut d'un personnage Roblox.
local BASE_WALK_SPEED = 16
local BASE_JUMP_POWER = 50
local BASE_JUMP_HEIGHT = 7.2

---------------------------------------------------------------------------
-- Sauvegarde
---------------------------------------------------------------------------

local store: DataStore? = nil
if settings.SAVE then
	-- Échoue dans Studio si le jeu n'est pas publié ou si l'accès aux API est désactivé.
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(settings.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Progression] Sauvegarde indisponible, les niveaux ne seront pas conservés : " .. tostring(result))
	end
end

local function storeKey(userId: number): string
	return "Player_" .. userId
end

-- Lit la sauvegarde d'un joueur. Renvoie (réussite, niveau, xp, techniques).
local function load(userId: number): (boolean, number, number, { [string]: boolean })
	if not store then
		return false, 1, 0, {}
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(storeKey(userId))
		end)
		if ok then
			if typeof(result) == "table" and typeof(result.level) == "number" and typeof(result.xp) == "number" then
				local level = math.clamp(math.floor(result.level), 1, settings.MAX_LEVEL)
				-- On ne garde que les techniques qui existent encore et que les points permettent.
				local skills = {}
				if typeof(result.skills) == "table" then
					for _, id in result.skills do
						if typeof(id) == "string" and Skills.ById[id] then
							skills[id] = true
						end
					end
				end
				if Skills.spentPoints(skills) > Skills.totalPoints(level) then
					skills = {}
				end
				return true, level, math.max(result.xp, 0), skills
			end
			return true, 1, 0, {} -- première visite
		end
		warn("[Progression] Lecture de la sauvegarde échouée (essai " .. attempt .. ") : " .. tostring(result))
		task.wait(2)
	end
	return false, 1, 0, {}
end

local function save(userId: number, data: Stats)
	if not store or not data.canSave then
		return
	end
	local skillList = {}
	for id in data.skills do
		table.insert(skillList, id)
	end
	local ok, message = pcall(function()
		(store :: DataStore):SetAsync(storeKey(userId), { level = data.level, xp = data.xp, skills = skillList })
	end)
	if not ok then
		warn("[Progression] Écriture de la sauvegarde échouée : " .. tostring(message))
	end
end

-- Expérience à gagner pour passer du niveau `level` au suivant.
local function xpNeeded(level: number): number
	return settings.XP_PER_LEVEL * level
end

-- Somme d'un effet (voir Skills.luau) sur les techniques débloquées.
local function effectOf(data: Stats?, key: string): number
	local total = 0
	if data then
		for id in data.skills do
			local skill = Skills.ById[id]
			if skill and skill.Effects[key] then
				total += skill.Effects[key]
			end
		end
	end
	return total
end

local function maxHealth(data: Stats): number
	return settings.BASE_HEALTH + settings.HEALTH_PER_LEVEL * (data.level - 1) + effectOf(data, "Health")
end

-- Recopie les valeurs dans le tableau des scores et dans des attributs du joueur
-- (Level, XP, XPNeeded), lisibles par un script client pour un affichage.
local function publish(player: Player)
	local data = stats[player]
	if not data then
		return
	end
	player:SetAttribute("Level", data.level)
	player:SetAttribute("XP", data.xp)
	player:SetAttribute("XPNeeded", xpNeeded(data.level))
	-- Techniques débloquées ("Eveil,Tranchant") et points de Qi restants, pour l'arbre et le HUD.
	local owned = {}
	for id in data.skills do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("Skills", table.concat(owned, ","))
	player:SetAttribute("SkillPoints", Skills.totalPoints(data.level) - Skills.spentPoints(data.skills))

	local board = player:FindFirstChild("leaderstats")
	if board then
		local level = board:FindFirstChild("Niveau")
		local xp = board:FindFirstChild("XP")
		if level and level:IsA("IntValue") then
			level.Value = data.level
		end
		if xp and xp:IsA("IntValue") then
			xp.Value = data.xp
		end
	end
end

local function applyHealth(player: Player, heal: boolean)
	local data = stats[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.MaxHealth = maxHealth(data)
	if heal then
		humanoid.Health = humanoid.MaxHealth
	end
	-- Pas léger : vitesse et saut.
	humanoid.WalkSpeed = BASE_WALK_SPEED * (1 + effectOf(data, "Speed"))
	local jump = 1 + effectOf(data, "Jump")
	humanoid.JumpPower = BASE_JUMP_POWER * math.sqrt(jump) -- la hauteur varie comme le carré de la puissance
	humanoid.JumpHeight = BASE_JUMP_HEIGHT * jump
end

-- Texte flottant qui monte en s'effaçant.
local function popup(position: Vector3, text: string, color: Color3, size: number, duration: number)
	local anchor = Instance.new("Part")
	anchor.Name = "Progression"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size * 4, size)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui

	anchor.Parent = workspace
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = CFrame.new(position + Vector3.new(0, 2, 0)) }):Play()
	TweenService:Create(label, TweenInfo.new(duration * 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, duration * 0.6), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, duration + 0.1)
end

-- Annonce du passage de niveau : un texte devant le joueur (visible dans le casque),
-- un halo doré, une colonne de particules et un son.
local function levelUpEffects(player: Player, level: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local gold = Color3.fromRGB(255, 215, 110)

	local front = root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 1.5, 0)
	popup(front, "Niveau " .. level .. " !", gold, 1.6, 2.5)
	-- Entrée dans un nouveau royaume de cultivation.
	local realm = Skills.realm(level)
	if realm.MinLevel == level and level > 1 then
		popup(front + Vector3.new(0, -1.6, 0), realm.Hanzi .. "  " .. realm.Name, Color3.fromRGB(120, 235, 180), 1.2, 3.5)
	end

	local glow = Instance.new("Highlight")
	glow.Name = "LevelUp"
	glow.FillColor = gold
	glow.FillTransparency = 0.5
	glow.OutlineColor = Color3.fromRGB(255, 240, 180)
	glow.Parent = character
	TweenService:Create(glow, TweenInfo.new(1.2), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(glow, 1.3)

	local attachment = Instance.new("Attachment")
	attachment.Name = "LevelUp"
	attachment.Position = Vector3.new(0, -2.5, 0)
	attachment.Parent = root

	local sparks = Instance.new("ParticleEmitter")
	sparks.Enabled = false
	sparks.Rate = 0
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), gold)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.6, 1.1)
	sparks.Speed = NumberRange.new(8, 14)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Drag = 1
	sparks.Parent = attachment
	sparks:Emit(40)
	Debris:AddItem(attachment, 1.5)

	Sfx.play("LevelUp", root, 1)
end

function Progression.getLevel(player: Player): number
	local data = stats[player]
	return if data then data.level else 1
end

-- Multiplicateur appliqué aux dégâts des coups du joueur.
function Progression.damageMultiplier(player: Player): number
	return 1 + settings.DAMAGE_PER_LEVEL * (Progression.getLevel(player) - 1) + effectOf(stats[player], "Damage")
end

-- Somme d'un effet de cultivation pour ce joueur (clés décrites dans Skills.luau).
function Progression.effect(player: Player, key: string): number
	return effectOf(stats[player], key)
end

-- Le joueur a-t-il débloqué cette technique ?
function Progression.hasSkill(player: Player, skillId: string): boolean
	local data = stats[player]
	return data ~= nil and data.skills[skillId] == true
end

-- Multiplicateur appliqué aux dégâts que le joueur reçoit (Chemise de fer, Corps de diamant).
function Progression.damageTakenMultiplier(player: Player): number
	return math.clamp(1 - effectOf(stats[player], "DamageTaken"), 0.2, 1)
end

-- Débloque une technique de cultivation si le joueur en remplit les conditions.
-- `at` : position de l'orbe sur la stèle, pour l'effet visuel.
function Progression.unlock(player: Player, skillId: any, at: Vector3?): boolean
	local data = stats[player]
	local skill = if typeof(skillId) == "string" then Skills.ById[skillId] else nil
	if not data or not skill then
		return false
	end
	if not Skills.canUnlock(skill, data.level, data.skills) then
		return false
	end

	data.skills[skill.Id] = true
	publish(player)
	applyHealth(player, false)

	local jade = Color3.fromRGB(120, 235, 180)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		popup(at or (root.Position + Vector3.new(0, 4, 0)), skill.Hanzi .. "  " .. skill.Name, jade, 1.3, 2.5)
		Sfx.play("LevelUp", root, 0.8)

		local glow = Instance.new("Highlight")
		glow.Name = "Cultivation"
		glow.FillColor = jade
		glow.FillTransparency = 0.55
		glow.OutlineColor = jade
		glow.Parent = character
		TweenService:Create(glow, TweenInfo.new(1.2), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
		Debris:AddItem(glow, 1.3)
	end
	task.spawn(save, player.UserId, data)
	return true
end

-- Donne de l'expérience au joueur. `at` : endroit où afficher le gain (le bandit tué).
function Progression.addXp(player: Player, amount: number, at: Vector3?)
	local data = stats[player]
	if not data or amount <= 0 then
		return
	end

	amount *= 1 + effectOf(data, "Xp") -- Méditation
	local leveled = false
	if data.level < settings.MAX_LEVEL then
		data.xp += amount
		while data.level < settings.MAX_LEVEL and data.xp >= xpNeeded(data.level) do
			data.xp -= xpNeeded(data.level)
			data.level += 1
			leveled = true
		end
		if data.level >= settings.MAX_LEVEL then
			data.xp = 0
		end
	end
	publish(player)

	if at then
		local text = "+" .. math.round(amount) .. " XP"
		if data.level < settings.MAX_LEVEL then
			text ..= "  (" .. math.floor(data.xp) .. " / " .. xpNeeded(data.level) .. ")"
		end
		popup(at + Vector3.new(0, 3, 0), text, Color3.fromRGB(150, 220, 255), 1, 1.6)
	end

	if leveled then
		-- Monter de niveau augmente les points de vie maximaux et soigne complètement.
		applyHealth(player, true)
		levelUpEffects(player, data.level)
	end
end

-- Retient qui a blessé un bandit en dernier : c'est lui qui recevra l'expérience.
function Progression.tag(target: Instance, player: Player)
	target:SetAttribute("LastAttacker", player.UserId)
end

-- À appeler quand un bandit de niveau `enemyLevel` meurt.
function Progression.creditKill(target: Instance, enemyLevel: number, at: Vector3)
	local userId = target:GetAttribute("LastAttacker")
	local killer = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if killer then
		Progression.addXp(killer, settings.XP_PER_ENEMY_LEVEL * enemyLevel, at)
		-- Absorption du Qi : chaque bandit tué rend une part des points de vie.
		local heal = effectOf(stats[killer], "KillHeal")
		local character = killer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if heal > 0 and humanoid and humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.Health + humanoid.MaxHealth * heal, humanoid.MaxHealth)
		end
	end
end

local joined: { [Player]: boolean } = {}

local function onPlayerAdded(player: Player)
	if joined[player] then
		return
	end
	joined[player] = true

	-- Niveau 1 en attendant la sauvegarde : le joueur peut déjà se battre,
	-- et l'expérience gagnée pendant la lecture s'ajoute à celle retrouvée.
	local data: Stats = { level = 1, xp = 0, skills = {}, canSave = false }
	stats[player] = data
	task.spawn(function()
		local ok, level, xp, skills = load(player.UserId)
		if stats[player] ~= data then
			return -- le joueur est parti pendant la lecture
		end
		-- Expérience gagnée avant la fin de la lecture (niveaux déjà franchis compris).
		local earned = data.xp
		for passed = 1, data.level - 1 do
			earned += xpNeeded(passed)
		end
		data.level = level
		data.xp = xp
		data.skills = skills
		data.canSave = ok
		publish(player)
		applyHealth(player, true)
		if earned > 0 then
			Progression.addXp(player, earned)
		end
	end)

	local board = Instance.new("Folder")
	board.Name = "leaderstats"
	local level = Instance.new("IntValue")
	level.Name = "Niveau"
	level.Parent = board
	local xp = Instance.new("IntValue")
	xp.Name = "XP"
	xp.Parent = board
	board.Parent = player
	publish(player)

	player.CharacterAdded:Connect(function(character)
		-- Les points de vie du niveau sont rétablis à chaque réapparition.
		character:WaitForChild("Humanoid", 10)
		applyHealth(player, true)
	end)
	if player.Character then
		applyHealth(player, true)
	end
end

function Progression.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local data = stats[player]
		stats[player] = nil
		joined[player] = nil
		if data then
			save(player.UserId, data)
		end
	end)

	-- Corps de diamant : régénération continue des points de vie.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, data in stats do
				local regen = effectOf(data, "Regen")
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if regen > 0 and humanoid and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
					humanoid.Health = math.min(humanoid.Health + regen, humanoid.MaxHealth)
				end
			end
		end
	end)

	-- Sauvegarde régulière, pour ne pas tout perdre si le serveur plante.
	task.spawn(function()
		while true do
			task.wait(settings.AUTOSAVE_INTERVAL)
			for player, data in stats do
				task.spawn(save, player.UserId, data)
			end
		end
	end)

	-- À la fermeture du serveur, on attend que toutes les sauvegardes soient écrites.
	game:BindToClose(function()
		local pending = 0
		for player, data in stats do
			pending += 1
			task.spawn(function()
				save(player.UserId, data)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return Progression

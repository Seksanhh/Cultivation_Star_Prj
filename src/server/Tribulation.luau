-- Tribulation céleste (天劫, Config.TRIBULATION) : pour consolider un nouveau royaume de cultivation,
-- le joueur doit survivre à une série d'éclairs. Elle attend qu'il n'y ait plus de bandit en jeu,
-- met les vagues en pause, assombrit le ciel, puis fait tomber la foudre là où se tient le joueur.
--   - Chaque éclair est annoncé par un cercle violet au sol qui se resserre (WARNING secondes).
--   - Sortir du cercle l'évite. Lever sa lame pointe vers le ciel au-dessus de la tête, au moment
--     où il tombe, l'absorbe : pas de dégâts, du Qi en plus.
--   - Survivre jusqu'au dernier éclair consolide le royaume (bonus permanent de vie et de dégâts).
--   - Mourir l'interrompt : elle revient RETRY_DELAY secondes après la réapparition.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Skills = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skills"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Vfx = require(script.Parent:WaitForChild("Vfx"))
local Progression = require(script.Parent:WaitForChild("Progression"))
local Enemies = require(script.Parent:WaitForChild("Enemies"))
local Techniques = require(script.Parent:WaitForChild("Techniques"))

local Tribulation = {}

local settings = Config.TRIBULATION
local VIOLET = Color3.fromRGB(190, 150, 255)
local BOLT = Color3.fromRGB(215, 205, 255)

local weaponsFolder: Instance
local running: { [Player]: boolean } = {}
local queued: { [Player]: boolean } = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function body(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

-- Sol sous un point (pour poser le cercle d'avertissement).
local function groundBelow(position: Vector3, player: Player): Vector3
	local ignored: { Instance } = { Vfx.folder, weaponsFolder }
	for _, name in { "Enemies", "VRHands", "Projectiles", "Scabbards" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(ignored, found)
		end
	end
	if player.Character then
		table.insert(ignored, player.Character)
	end
	rayParams.FilterDescendantsInstances = ignored
	local result = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), rayParams)
	return if result then result.Position else position - Vector3.new(0, 3, 0)
end

-- Ciel d'orage : l'éclairage vire au violet sombre pendant la tribulation.
local function darkenSky(on: boolean)
	local tint = Lighting:FindFirstChild("Tribulation")
	if on and not tint then
		tint = Instance.new("ColorCorrectionEffect")
		tint.Name = "Tribulation"
		tint.Parent = Lighting
	end
	if tint and tint:IsA("ColorCorrectionEffect") then
		local goal = if on
			then { TintColor = Color3.fromRGB(150, 140, 200), Brightness = -0.15, Contrast = 0.15, Saturation = -0.3 }
			else { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 }
		TweenService:Create(tint, TweenInfo.new(2), goal):Play()
		if not on then
			Debris:AddItem(tint, 2.1)
		end
	end
end

-- La lame du joueur est-elle levée, pointe vers le ciel, au-dessus de sa tête ?
local function bladeRaised(player: Player): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return false
	end
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:GetAttribute("Holder") == player.UserId then
			for _, part in weapon:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
					local tip = part.CFrame * Vector3.new(0, part.Size.Y / 2, 0)
					local upward = part.CFrame.UpVector.Y > 0.6
					local flat = (tip - head.Position) * Vector3.new(1, 0, 1)
					if upward and tip.Y > head.Position.Y + 0.5 and flat.Magnitude < 3.5 then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Cercle d'avertissement : un disque violet qui se resserre jusqu'à la frappe.
local function warningCircle(at: Vector3, duration: number)
	local disc = Instance.new("Part")
	disc.Name = "CercleFoudre"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.12, settings.RADIUS * 2.6, settings.RADIUS * 2.6)
	disc.CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = VIOLET
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.6
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Parent = Vfx.folder
	TweenService:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(0.12, settings.RADIUS * 2, settings.RADIUS * 2),
		Transparency = 0.25,
	}):Play()
	Debris:AddItem(disc, duration + 0.1)
	Sfx.play("ThunderWarning", at, 0.8)
end

-- L'éclair : une colonne de lumière qui tombe du ciel, un éclair de lumière et le tonnerre.
local function boltVisual(at: Vector3)
	local height = 90
	local column = Instance.new("Part")
	column.Name = "Eclair"
	column.Size = Vector3.new(0.9, height, 0.9)
	column.CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0))
	column.Color = BOLT
	column.Material = Enum.Material.Neon
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Parent = Vfx.folder
	TweenService:Create(column, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.1, height, 0.1) }):Play()
	Debris:AddItem(column, 0.4)

	local anchor = Vfx.anchor("ImpactFoudre", at + Vector3.new(0, 0.5, 0), nil, 1.2)
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.Burst,
		Count = 1,
		Color = ColorSequence.new(BOLT),
		Size = Vfx.grow(4, 12),
		Transparency = Vfx.fadeAfter(0.2),
		Lifetime = NumberRange.new(0.3),
	})
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.Streak,
		Count = 24,
		Color = ColorSequence.new(Color3.new(1, 1, 1), VIOLET),
		Size = Vfx.grow(1.4, 0.1),
		Lifetime = NumberRange.new(0.2, 0.45),
		Speed = NumberRange.new(16, 34),
		Spread = Vector2.new(80, 80),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NumberRange.new(0),
		Acceleration = Vector3.new(0, -40, 0),
	})
	Vfx.flashLight(anchor, BOLT, 40, 8, 0.4)
	Sfx.play("Thunder", at, 1)
end

local function absorbVisual(player: Player)
	local _, root = body(player)
	if not root then
		return
	end
	local anchor = Vfx.anchor("FoudreAbsorbee", root.Position + Vector3.new(0, 3, 0), nil, 1.2)
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.ShockRing,
		Count = 1,
		Color = ColorSequence.new(VIOLET),
		Size = Vfx.grow(1, 9),
		Transparency = Vfx.fadeAfter(0.3),
		Lifetime = NumberRange.new(0.4),
	})
	Progression.popupFor(player, "Foudre absorbée  +" .. settings.ABSORB_QI .. " Qi", VIOLET, 1, 1.5)
end

local function run(player: Player, realm: { MinLevel: number, Name: string, Hanzi: string })
	running[player] = true

	-- Elle attend que les bandits en jeu soient tous tombés, puis fige les vagues.
	while Enemies.activeCount() > 0 and player.Parent do
		task.wait(1)
	end
	if not player.Parent or not body(player) then
		running[player] = nil
		return
	end
	Enemies.setPaused(true)
	darkenSky(true)
	Enemies.announce("天劫 · Tribulation céleste — " .. realm.Hanzi .. " " .. realm.Name)
	local _, startRoot = body(player)
	if startRoot then
		Sfx.play("ThunderRumble", startRoot, 1)
	end
	task.wait(3)

	local realmIndex = 0
	for i, entry in Skills.REALMS do
		if entry.MinLevel == realm.MinLevel then
			realmIndex = i - 1
		end
	end
	local bolts = settings.BOLTS + settings.BOLTS_PER_REALM * math.max(realmIndex - 1, 0)
	local survived = true
	for n = 1, bolts do
		local humanoid, root = body(player)
		if not humanoid or not root or not player.Parent then
			survived = false
			break
		end
		-- La foudre vise le joueur, parfois un peu devant lui s'il court.
		local lead = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * (if n % 3 == 0 then 0.6 else 0)
		local target = groundBelow(root.Position + lead, player)
		warningCircle(target, settings.WARNING)
		task.wait(settings.WARNING)

		humanoid, root = body(player)
		if not humanoid or not root then
			survived = false
			break
		end
		boltVisual(target)
		local flat = (root.Position - target) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= settings.RADIUS then
			if bladeRaised(player) then
				Techniques.addQi(player, settings.ABSORB_QI)
				absorbVisual(player)
			else
				humanoid:TakeDamage(humanoid.MaxHealth * settings.DAMAGE * Progression.damageTakenMultiplier(player))
				Sfx.play("Hurt", root, 1)
			end
		end
		if humanoid.Health <= 0 then
			survived = false
			break
		end
		local progress = n / bolts
		task.wait(settings.INTERVAL + (settings.MIN_INTERVAL - settings.INTERVAL) * progress)
	end

	darkenSky(false)
	Enemies.setPaused(false)
	running[player] = nil
	if survived and player.Parent and body(player) then
		Progression.consolidate(player, realm.MinLevel)
		Enemies.announce("Percée ! " .. realm.Hanzi .. " " .. realm.Name)
		Progression.popupFor(player, "+" .. math.round(settings.DAMAGE_BONUS * 100) .. " % dégâts · +" .. settings.HEALTH_BONUS .. " PV",
			Color3.fromRGB(120, 235, 180), 1.1, 3)
		Techniques.addQi(player, 1000)
	elseif player.Parent then
		Enemies.announce("La tribulation a été plus forte… elle reviendra.")
	end
end

-- Demande une tribulation pour ce joueur s'il a un royaume à consolider. `delay` : attente avant.
function Tribulation.request(player: Player, delay: number?)
	if not settings.ENABLED or running[player] or queued[player] then
		return
	end
	queued[player] = true
	task.delay(delay or 0, function()
		queued[player] = nil
		local realm = Progression.pendingRealm(player)
		if realm and player.Parent and not running[player] then
			run(player, realm)
		end
	end)
end

function Tribulation.init(weapons: Instance)
	weaponsFolder = weapons
	-- Seuil d'un royaume atteint : la tribulation commence dès que les bandits en jeu sont tombés.
	Progression.realmReached:Connect(function(player)
		Tribulation.request(player, 2)
	end)
	-- Échec ou départ précédent : elle revient après la réapparition.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			Tribulation.request(player, settings.RETRY_DELAY)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		running[player] = nil
		queued[player] = nil
	end)
end

return Tribulation

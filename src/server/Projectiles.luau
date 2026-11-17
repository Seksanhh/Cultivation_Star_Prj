-- Projectiles des bandits : flèches des archers et couteaux des lanceurs.
-- Le serveur fait voler chaque projectile image par image (avec une légère chute) et regarde,
-- sur le trajet parcouru pendant l'image :
--   1. s'il croise la lame d'une arme tenue par un joueur : il est coupé net (geste rapide)
--      ou dévié (lame immobile), sans dégâts ;
--   2. s'il croise un bouclier tenu : il s'y plante, sans dégâts ;
--   3. sinon, s'il touche un joueur : dégâts ; ou le décor : il s'y plante (flèche) ou tombe (couteau).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Vfx = require(script.Parent:WaitForChild("Vfx"))
local Progression = require(script.Parent:WaitForChild("Progression"))

local Projectiles = {}

local CUT_SPEED = 12 -- vitesse de la lame (studs/s) au-delà de laquelle le projectile est coupé, pas seulement dévié
local LIFETIME = 4 -- un projectile qui n'a rien touché disparaît après ce temps (s)
local STUCK_TIME = 5 -- temps pendant lequel une flèche reste plantée (s)

local WOOD = Color3.fromRGB(150, 110, 70)
local STEEL = Color3.fromRGB(205, 210, 220)
local FEATHER = Color3.fromRGB(170, 40, 35)

export type Kind = "Arrow" | "Knife"

type Shot = {
	model: Model,
	kind: Kind,
	position: Vector3,
	velocity: Vector3,
	damage: number,
	gravity: number,
	spin: number,
	age: number,
}

local shots: { Shot } = {}
local weaponsFolder: Instance
local feedbackRemote: RemoteEvent
local ignoredFolders: { Instance } = {}

local folder = Instance.new("Folder")
folder.Name = "Projectiles"
folder.Parent = workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function piece(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

-- Modèle du projectile, pointe vers -Z (l'avant d'un CFrame.lookAt).
local function build(kind: Kind): Model
	local model = Instance.new("Model")
	model.Name = if kind == "Arrow" then "Fleche" else "Couteau"
	local core: Part
	if kind == "Arrow" then
		core = piece(model, "Hampe", Vector3.new(0.07, 0.07, 2.6), CFrame.new(), WOOD, Enum.Material.Wood)
		piece(model, "Pointe", Vector3.new(0.14, 0.04, 0.3), CFrame.new(0, 0, -1.4), STEEL, Enum.Material.Metal)
		piece(model, "Plume", Vector3.new(0.02, 0.22, 0.45), CFrame.new(0, 0.08, 1.05), FEATHER, Enum.Material.Fabric)
		piece(model, "Plume", Vector3.new(0.22, 0.02, 0.45), CFrame.new(0.08, 0, 1.05), FEATHER, Enum.Material.Fabric)
	else
		core = piece(model, "Lame", Vector3.new(0.04, 0.2, 0.75), CFrame.new(0, 0, -0.2), STEEL, Enum.Material.Metal)
		piece(model, "Manche", Vector3.new(0.08, 0.1, 0.4), CFrame.new(0, 0, 0.37), Color3.fromRGB(35, 30, 30), Enum.Material.Fabric)
	end
	model.PrimaryPart = core

	-- Traînée claire : en VR, elle aide à voir arriver le projectile.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.05, 0)
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.05, 0)
	a1.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.15
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 210))
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.LightEmission = 0.6
	trail.Parent = core

	model.Parent = folder
	return model
end

-- Distance la plus courte entre les segments [p1, q1] et [p2, q2].
local function segmentDistance(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): number
	local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t
	if a <= 1e-6 and e <= 1e-6 then
		return r.Magnitude
	end
	if a <= 1e-6 then
		s, t = 0, math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= 1e-6 then
			s, t = math.clamp(-c / a, 0, 1), 0
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = if denom > 1e-6 then math.clamp((b * f - c * e) / denom, 0, 1) else 0
			t = (b * s + f) / e
			if t < 0 then
				t, s = 0, math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t, s = 1, math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	return ((p1 + d1 * s) - (p2 + d2 * t)).Magnitude
end

-- Une lame ou un bouclier tenu par un joueur croise-t-il le trajet [from, to] ?
-- Renvoie le joueur, la main, "Blade" ou "Shield", la pièce et la vitesse de la lame.
local function findGuard(from: Vector3, to: Vector3): (Player?, string?, string?, BasePart?, number)
	for _, weapon in weaponsFolder:GetChildren() do
		local holderId = weapon:GetAttribute("Holder")
		if not holderId then
			continue
		end
		for _, part in weapon:GetChildren() do
			if not part:IsA("BasePart") then
				continue
			end
			local holder = Players:GetPlayerByUserId(holderId)
			local side = weapon:GetAttribute("HolderHand")
			if part:GetAttribute("IsShield") then
				local radius = math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2 + 0.3
				if segmentDistance(from, to, part.Position, part.Position) <= radius then
					return holder, side, "Shield", part, 0
				end
			elseif part:GetAttribute("IsBlade") then
				local half = part.CFrame.UpVector * (part.Size.Y / 2)
				local reach = math.max(part.Size.X, part.Size.Z) / 2 + 0.45
				if segmentDistance(from, to, part.Position - half, part.Position + half) <= reach then
					local tip = part.Position + half
					return holder, side, "Blade", part, part:GetVelocityAtPosition(tip).Magnitude
				end
			end
		end
	end
	return nil, nil, nil, nil, 0
end

local function sparks(position: Vector3, color: Color3, count: number)
	local anchor = Vfx.anchor("ProjectileArrete", position, nil, 1)
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.Streak,
		Count = count,
		Color = ColorSequence.new(Color3.new(1, 1, 1), color),
		Size = Vfx.grow(0.9, 0.1),
		Lifetime = NumberRange.new(0.15, 0.35),
		Speed = NumberRange.new(10, 22),
		Spread = Vector2.new(180, 180),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NumberRange.new(0),
		Drag = 4,
		Acceleration = Vector3.new(0, -35, 0),
	})
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.Glint,
		Count = 1,
		Color = ColorSequence.new(color),
		Size = Vfx.grow(2.5, 0),
		Transparency = Vfx.fadeAfter(0.3),
		Lifetime = NumberRange.new(0.2),
	})
end

-- Le projectile n'est plus dangereux : il tombe en tournoyant (coupé ou dévié), ou reste planté.
local function drop(shot: Shot, mode: "Fall" | "Stick" | "Cut")
	local model = shot.model
	if mode == "Stick" then
		Debris:AddItem(model, STUCK_TIME)
		return
	end
	if mode == "Cut" then
		-- Coupé en deux : chaque moitié part de son côté.
		for i, part in model:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = true
				part.AssemblyLinearVelocity = shot.velocity.Unit * 4 + Vector3.new((i % 2 * 2 - 1) * 6, 8, 0)
				part.AssemblyAngularVelocity = Vector3.new(15, 5, 0)
			end
		end
	else
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = true
			end
		end
		local core = model.PrimaryPart
		if core then
			-- Dévié : il rebondit vers le haut et sur le côté.
			core.AssemblyLinearVelocity = -shot.velocity * 0.15 + Vector3.new(0, 14, 0)
			core.AssemblyAngularVelocity = Vector3.new(20, 0, 10)
		end
		-- Les pièces doivent rester ensemble pour tomber d'un bloc.
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part ~= core and core then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = core
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	Debris:AddItem(model, 3)
end

local function playerOf(part: Instance): (Player?, Humanoid?)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return Players:GetPlayerFromCharacter(model), humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

local function step(dt: number)
	for i = #shots, 1, -1 do
		local shot = shots[i]
		shot.age += dt
		if shot.age > LIFETIME or not shot.model.Parent then
			table.remove(shots, i)
			shot.model:Destroy()
			continue
		end
		shot.velocity += Vector3.new(0, -shot.gravity * dt, 0)
		local from = shot.position
		local to = from + shot.velocity * dt

		-- 1-2. Une lame ou un bouclier sur le trajet arrête le projectile.
		local holder, side, guard, guardPart, bladeSpeed = findGuard(from, to)
		if guard and guardPart then
			table.remove(shots, i)
			local contact = guardPart.Position
			if guard == "Shield" then
				shot.model:PivotTo(CFrame.lookAt(contact, contact + shot.velocity))
				Sfx.play("Block", contact, 0.8)
				drop(shot, "Fall")
				if holder and side then
					feedbackRemote:FireClient(holder, side, 0.8, 0.12, Config.CAMERA_SHAKE.SHIELD * 0.6)
				end
			elseif bladeSpeed >= CUT_SPEED then
				sparks(to, Color3.fromRGB(255, 215, 120), 16)
				Sfx.play("PerfectParry", to, 1)
				drop(shot, "Cut")
				if holder and side then
					feedbackRemote:FireClient(holder, side, 1, 0.15, Config.CAMERA_SHAKE.PARRY)
				end
			else
				sparks(to, Color3.fromRGB(255, 150, 60), 8)
				Sfx.play("Parry", to, 0.8)
				drop(shot, "Fall")
				if holder and side then
					feedbackRemote:FireClient(holder, side, 0.7, 0.1, Config.CAMERA_SHAKE.PARRY * 0.6)
				end
			end
			continue
		end

		-- 3. Joueur ou décor.
		local ignored = table.clone(ignoredFolders)
		table.insert(ignored, folder)
		table.insert(ignored, weaponsFolder)
		rayParams.FilterDescendantsInstances = ignored
		local result = workspace:Raycast(from, to - from, rayParams)
		if result then
			table.remove(shots, i)
			local target, humanoid = playerOf(result.Instance)
			shot.model:PivotTo(CFrame.lookAt(result.Position, result.Position + shot.velocity))
			if target and humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(shot.damage * Progression.damageTakenMultiplier(target))
				Sfx.play("Hurt", result.Position, 1)
				shot.model:Destroy()
			elseif humanoid then
				-- Un autre bandit ou un mannequin : le projectile s'y plante sans le blesser.
				drop(shot, "Stick")
			elseif shot.kind == "Arrow" then
				Sfx.play("Thud", result.Position, 0.6)
				drop(shot, "Stick")
			else
				Sfx.play("Metal", result.Position, 0.5)
				drop(shot, "Fall")
			end
			continue
		end

		shot.position = to
		local orientation = CFrame.lookAt(to, to + shot.velocity)
		if shot.spin ~= 0 then
			-- Le couteau tournoie autour de son axe transversal.
			orientation *= CFrame.Angles(shot.age * shot.spin, 0, 0)
		end
		shot.model:PivotTo(orientation)
	end
end

-- Tire un projectile de `origin` vers `target` à la vitesse `speed`. `lead` : vitesse de la cible,
-- pour viser là où elle sera (un tir parfait serait impossible à éviter : on n'anticipe qu'à moitié).
function Projectiles.fire(kind: Kind, origin: Vector3, target: Vector3, lead: Vector3, speed: number, damage: number, spread: number?)
	local gravity = if kind == "Arrow" then 18 else 10
	local travel = (target - origin).Magnitude / speed
	local aim = target + lead * travel * 0.5 + Vector3.new(0, 0.5 * gravity * travel * travel, 0)
	local direction = (aim - origin).Unit
	if spread and spread > 0 then
		direction = (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(
			math.rad((math.random() * 2 - 1) * spread),
			math.rad((math.random() * 2 - 1) * spread),
			0
		)).LookVector
	end
	local model = build(kind)
	model:PivotTo(CFrame.lookAt(origin, origin + direction))
	table.insert(shots, {
		model = model,
		kind = kind,
		position = origin,
		velocity = direction * speed,
		damage = damage,
		gravity = gravity,
		spin = if kind == "Knife" then 25 else 0,
		age = 0,
	})
	-- Le sifflement voyage avec le projectile : on l'entend arriver.
	Sfx.play(if kind == "Arrow" then "ArrowShot" else "KnifeThrow", model.PrimaryPart :: BasePart, 1)
end

-- `ignore` : dossiers que les projectiles traversent (les bandits eux-mêmes, les effets…).
function Projectiles.init(weapons: Instance, feedback: RemoteEvent, ignore: { Instance })
	weaponsFolder = weapons
	feedbackRemote = feedback
	ignoredFolders = ignore
	RunService.Heartbeat:Connect(step)
end

return Projectiles

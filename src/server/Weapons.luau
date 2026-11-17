-- Construit les modèles d'armes à partir des définitions de Config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Collisions = require(script.Parent:WaitForChild("Collisions"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Weapons = {}

-- Traînée lumineuse derrière une lame en mouvement, tendue entre sa base et sa pointe.
-- Sa longueur suit la vitesse : presque invisible sur un geste lent, large sur un vrai coup.
function Weapons.addTrail(blade: BasePart)
	local half = blade.Size.Y / 2
	-- Une pièce large (le fer de la hache) laisse sa traînée le long du tranchant, côté -Z.
	local edge = if blade.Size.Z > blade.Size.Y * 0.5 then -blade.Size.Z / 2 else 0

	local base = Instance.new("Attachment")
	base.Name = "TraineeBase"
	base.Position = Vector3.new(0, -half, edge)
	base.Parent = blade

	local tip = Instance.new("Attachment")
	tip.Name = "TraineePointe"
	tip.Position = Vector3.new(0, half, edge)
	tip.Parent = blade

	local trail = Instance.new("Trail")
	trail.Name = "Trainee"
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = Config.TRAIL_LIFETIME
	trail.MinLength = 0.05
	trail.Color = ColorSequence.new(Config.TRAIL_COLOR)
	trail.LightEmission = 0.8
	trail.LightInfluence = 0
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	trail.Parent = blade
end

function Weapons.create(typeName: string, home: CFrame, parent: Instance): Model
	local def = Config.Weapons[typeName]
	assert(def, "Arme inconnue : " .. typeName)

	local model = Instance.new("Model")
	model.Name = typeName

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.28, def.HandleLength, 0.28)
	handle.Color = def.HandleColor or Config.HANDLE_WOOD
	handle.Material = def.HandleMaterial or Enum.Material.Wood
	handle.Transparency = 1 -- on voit à sa place le manche rond (pièce « Fut » de Config)
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Anchored = true -- ancrée tant qu'elle est sur le râtelier
	handle.CFrame = home
	handle.Parent = model

	for _, info in def.Parts do
		local part: BasePart
		if info.Wedge then
			part = Instance.new("WedgePart")
		else
			local block = Instance.new("Part")
			if info.Shape then
				block.Shape = info.Shape
			end
			part = block
		end
		part.Name = info.Name
		part.Size = info.Size
		part.Color = info.Color
		part.Material = info.Material
		part.Reflectance = info.Reflectance or 0
		part.Transparency = if info.Hidden then 1 else 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if info.Decor then
			-- Ornement : il suit l'arme sans rien heurter ni peser.
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = true
			part:SetAttribute("Decor", true)
		end
		part.CFrame = home * CFrame.new(info.Offset) * (info.Rotation or CFrame.new())
		if info.Blade then
			part:SetAttribute("IsBlade", true)
			Weapons.addTrail(part)
		end
		if info.Shield then
			part:SetAttribute("IsShield", true)
		end
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end

	model.PrimaryPart = handle
	model:SetAttribute("WeaponType", typeName)
	model.Parent = parent

	-- Bruit d'impact quand l'arme heurte le décor ou une autre arme.
	local lastSound = 0
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") then
			local part = item
			part.Touched:Connect(function(other)
				local now = os.clock()
				if now - lastSound < 0.15 then
					return
				end
				-- On ignore l'arme elle-même, ce qui n'est pas solide (mains, feuillages) et les corps.
				if other:IsDescendantOf(model) or not other.CanCollide or other.CollisionGroup == Collisions.BODIES then
					return
				end
				local point = part.Position
				local speed = (part:GetVelocityAtPosition(point) - other:GetVelocityAtPosition(point)).Magnitude
				if speed < Config.COLLISION_SOUND_MIN_SPEED then
					return
				end
				lastSound = now
				local metal = other.Material == Enum.Material.Metal or other:IsDescendantOf(parent)
				Sfx.play(if metal then "Metal" else "Thud", part, speed / Config.REFERENCE_SPEED)
			end)
		end
	end

	return model
end

-- Une arme tenue passe dans le groupe qui traverse les corps ; une arme libre redevient normale.
-- Dans les deux cas elle reste solide.
function Weapons.setHeld(weapon: Model, isHeld: boolean)
	local group = if isHeld then Collisions.HELD else Collisions.DEFAULT
	for _, item in weapon:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = not item:GetAttribute("Decor")
			item.CollisionGroup = group
		end
	end
end

return Weapons

-- Fourreau porté à la hanche gauche de chaque joueur (Config.SCABBARD).
-- Il est construit par script, soudé au HumanoidRootPart, et peut contenir une arme à lame
-- (dague, épée, sabre). Le fourreau s'ajuste à la longueur et à la largeur de la lame rangée.
--
-- Une arme au fourreau est soudée au joueur : elle ne heurte rien, ne pèse rien, ne déclenche
-- aucun bruit de choc, et seul son propriétaire peut la saisir (attribut SheathedBy).
-- Ce module ne gère que le fourreau et l'arme rangée ; les mains et la saisie restent dans Main.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))

local Scabbard = {}

local settings = Config.SCABBARD

local LACQUER = Color3.fromRGB(92, 26, 22) -- laque rouge sombre
local BRASS = Color3.fromRGB(181, 140, 60)
local MOUTH_GAP = 0.15 -- la garde de l'arme s'arrête juste devant l'entrée du fourreau
local EMPTY_LENGTH = 3 -- longueur d'un fourreau construit sans arme (studs)

type Fit = { length: number, width: number, depth: number }
type State = {
	root: BasePart,
	model: Model,
	fit: Fit,
	weapon: Model?,
}

local states: { [Player]: State } = {}
local fits: { [string]: Fit } = {}

local folder = Instance.new("Folder")
folder.Name = "Scabbards"
folder.Parent = workspace

-- Repère du fourreau par rapport au HumanoidRootPart : origine à l'entrée, axe Y vers la pointe.
local function mountFrame(): CFrame
	local direction = settings.DIRECTION.Unit
	local right = Vector3.xAxis - direction * Vector3.xAxis:Dot(direction)
	return CFrame.fromMatrix(settings.MOUTH_OFFSET, right.Unit, direction)
end

local function frameOf(state: State): CFrame
	return state.root.CFrame * mountFrame()
end

-- Mesure la lame d'une arme dans le repère de son manche : longueur au-delà du manche,
-- largeur et épaisseur. Le résultat est gardé par type d'arme.
local function measure(weapon: Model): Fit
	local typeName = weapon:GetAttribute("WeaponType")
	local cached = typeName and fits[typeName]
	if cached then
		return cached
	end
	local handle = weapon.PrimaryPart :: BasePart
	local top, halfX, halfZ = handle.Size.Y / 2, 0.1, 0.08
	for _, part in weapon:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
			local relative = handle.CFrame:ToObjectSpace(part.CFrame)
			local half = part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local corner = relative * Vector3.new(half.X * x, half.Y * y, half.Z * z)
						top = math.max(top, corner.Y)
						halfX = math.max(halfX, math.abs(corner.X))
						halfZ = math.max(halfZ, math.abs(corner.Z))
					end
				end
			end
		end
	end
	local fit = {
		length = math.max(0.8, top - handle.Size.Y / 2 - MOUTH_GAP + 0.15),
		width = halfX * 2 + 0.14,
		depth = halfZ * 2 + 0.12,
	}
	if typeName then
		fits[typeName] = fit
	end
	return fit
end

local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, state: State)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = cframe
	part.Parent = state.model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = state.root
	weld.Part1 = part
	weld.Parent = part
end

-- (Re)construit le fourreau à la taille `fit` : corps laqué, embouchure, deux bagues et bouterolle en laiton.
local function build(state: State, fit: Fit)
	state.model:ClearAllChildren()
	state.fit = fit
	local frame = frameOf(state)
	local w, d, l = fit.width, fit.depth, fit.length
	piece("Corps", Vector3.new(w, l, d), frame * CFrame.new(0, l / 2, 0), LACQUER, Enum.Material.SmoothPlastic, state)
	piece("Embouchure", Vector3.new(w + 0.06, 0.2, d + 0.06), frame * CFrame.new(0, 0.1, 0), BRASS, Enum.Material.Metal, state)
	for _, at in { 0.28, 0.55 } do
		piece("Bague", Vector3.new(w + 0.05, 0.08, d + 0.05), frame * CFrame.new(0, l * at, 0), BRASS, Enum.Material.Metal, state)
	end
	piece("Bouterolle", Vector3.new(w + 0.06, 0.25, d + 0.06), frame * CFrame.new(0, l - 0.125, 0), BRASS, Enum.Material.Metal, state)
end

function Scabbard.isSheathable(weapon: Model): boolean
	local typeName = weapon:GetAttribute("WeaponType")
	return settings.ENABLED and typeName ~= nil and settings.WEAPONS[typeName] == true
end

-- Équipe le joueur d'un fourreau vide (après une réapparition, par exemple).
function Scabbard.equip(player: Player, root: BasePart)
	if not settings.ENABLED then
		return
	end
	Scabbard.unequip(player)
	local model = Instance.new("Model")
	model.Name = tostring(player.UserId)
	model.Parent = folder
	local state: State = { root = root, model = model, fit = { length = EMPTY_LENGTH, width = 0.4, depth = 0.25 }, weapon = nil }
	states[player] = state
	build(state, state.fit)
end

-- Retire le fourreau. Renvoie l'arme qui y était rangée (déjà détachée), pour que l'appelant
-- la remette au râtelier ou la détruise.
function Scabbard.unequip(player: Player): Model?
	local state = states[player]
	if not state then
		return nil
	end
	states[player] = nil
	local weapon = state.weapon
	if weapon then
		Scabbard.unsheathe(player, weapon)
	end
	state.model:Destroy()
	return weapon
end

function Scabbard.weaponOf(player: Player): Model?
	local state = states[player]
	return state and state.weapon
end

function Scabbard.isEmpty(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.weapon == nil
end

-- Position de l'entrée du fourreau dans le monde, ou nil si le joueur n'en a pas.
function Scabbard.mouthPosition(player: Player): Vector3?
	local state = states[player]
	return state and frameOf(state).Position
end

-- Range l'arme (déjà lâchée par la main) dans le fourreau vide du joueur. Renvoie true si c'est fait.
function Scabbard.sheathe(player: Player, weapon: Model): boolean
	local state = states[player]
	local handle = weapon.PrimaryPart
	if not state or state.weapon or not handle or not Scabbard.isSheathable(weapon) then
		return false
	end
	local fit = measure(weapon)
	if math.abs(fit.length - state.fit.length) > 0.05 or math.abs(fit.width - state.fit.width) > 0.02 then
		build(state, fit)
	end

	Weapons.setHeld(weapon, false)
	for _, item in weapon:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = false
			item.CanTouch = false
			item.Massless = true
		elseif item:IsA("Trail") then
			-- Sinon la lame rangée laisserait une traînée derrière le joueur qui marche.
			item.Enabled = false
		end
	end
	handle.Anchored = false
	handle.AssemblyLinearVelocity = Vector3.zero
	handle.AssemblyAngularVelocity = Vector3.zero
	-- Le haut du manche (là où commence la lame) s'arrête juste devant l'entrée.
	weapon:PivotTo(frameOf(state) * CFrame.new(0, -(handle.Size.Y / 2 + MOUTH_GAP), 0))

	local weld = Instance.new("WeldConstraint")
	weld.Name = "SheathWeld"
	weld.Part0 = state.root
	weld.Part1 = handle
	weld.Parent = handle

	weapon:SetAttribute("Holder", nil)
	weapon:SetAttribute("HolderHand", nil)
	weapon:SetAttribute("DroppedAt", nil)
	weapon:SetAttribute("SheathedBy", player.UserId)
	state.weapon = weapon
	return true
end

-- Sort l'arme du fourreau : elle redevient une arme normale (la saisie la soude ensuite à la main).
function Scabbard.unsheathe(player: Player, weapon: Model)
	local state = states[player]
	if state and state.weapon == weapon then
		state.weapon = nil
	end
	local handle = weapon.PrimaryPart
	local weld = handle and handle:FindFirstChild("SheathWeld")
	if weld then
		weld:Destroy()
	end
	for _, item in weapon:GetDescendants() do
		if item:IsA("BasePart") and not item:GetAttribute("Decor") then
			item.CanTouch = true
			item.Massless = false
		elseif item:IsA("Trail") then
			item.Enabled = true
		end
	end
	weapon:SetAttribute("SheathedBy", nil)
end

return Scabbard

-- Stèle de cultivation : une dalle de pierre dans la cour, sur laquelle chaque technique de l'arbre
-- est une orbe que le joueur touche de la main pour la débloquer.
-- Le serveur construit la stèle ; chaque client colore les orbes selon sa propre progression
-- (voir src/client/Skills.client.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Skills = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Skills"))

local SkillTree = {}

-- Disposition des orbes sur la dalle (studs).
local COLUMN_SPACING = 3
local ROW_SPACING = 1.25
local FIRST_ROW_HEIGHT = 2.3 -- hauteur de la racine : tout l'arbre reste à portée de main
local ORB_SIZE = 0.85
local SLAB_SIZE = Vector3.new(11.5, 8.6, 0.7)

local STONE = Color3.fromRGB(70, 72, 78)
local STONE_DARK = Color3.fromRGB(45, 46, 52)
local GOLD = Color3.fromRGB(215, 175, 85)

local PATH_TITLES = {
	{ Column = -1.5, Text = "炼体\nVoie du Corps" },
	{ Column = -0.5, Text = "剑道\nVoie de la Lame" },
	{ Column = 0.5, Text = "气功\nVoie du Souffle" },
	{ Column = 1.5, Text = "武技\nVoie des Arts" },
}

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Texte gravé sur la face avant d'une pièce.
local function engrave(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.3
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.Antique
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
end

-- Position d'une technique sur la face avant de la dalle, dans le repère de la stèle.
local function orbOffset(skill: Skills.Skill): CFrame
	return CFrame.new(skill.Column * COLUMN_SPACING, FIRST_ROW_HEIGHT + skill.Row * ROW_SPACING, -(SLAB_SIZE.Z / 2 + 0.3))
end

-- `origin` : pied de la stèle ; sa face avant regarde vers -Z de ce repère.
function SkillTree.build(origin: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "CultivationTree"

	block("Socle", Vector3.new(SLAB_SIZE.X + 1.5, 0.8, 2.4), origin * CFrame.new(0, 0.4, 0), STONE_DARK, Enum.Material.Slate, folder)
	block("Dalle", SLAB_SIZE, origin * CFrame.new(0, 0.8 + SLAB_SIZE.Y / 2, 0), STONE, Enum.Material.Slate, folder)
	block("Chapeau", Vector3.new(SLAB_SIZE.X + 1, 0.5, 1.6), origin * CFrame.new(0, 0.8 + SLAB_SIZE.Y + 0.25, 0), STONE_DARK, Enum.Material.Slate, folder)

	-- Titre et nom des trois voies, en haut de la dalle.
	local front = -(SLAB_SIZE.Z / 2 + 0.03)
	local title = block("Titre", Vector3.new(SLAB_SIZE.X - 1, 1, 0.05), origin * CFrame.new(0, 8.6, front), STONE, Enum.Material.Slate, folder)
	title.Transparency = 1
	title.CanCollide = false
	engrave(title, "修炼之道 · Voie de la cultivation", GOLD)
	for _, path in PATH_TITLES do
		local plate = block("Voie", Vector3.new(2.7, 1, 0.05), origin * CFrame.new(path.Column * COLUMN_SPACING, 7.3, front), STONE, Enum.Material.Slate, folder)
		plate.Transparency = 1
		plate.CanCollide = false
		engrave(plate, path.Text, Color3.fromRGB(235, 225, 200))
	end

	-- Méridiens : un trait d'or entre chaque technique et celle qu'elle demande.
	for _, skill in Skills.List do
		local parent = skill.Requires and Skills.ById[skill.Requires]
		if parent then
			local from = (origin * orbOffset(parent)).Position
			local to = (origin * orbOffset(skill)).Position
			local line = block("Meridien", Vector3.new(0.1, 0.1, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to, origin.LookVector), GOLD, Enum.Material.Neon, folder)
			line.CanCollide = false
			line.CanQuery = false
			line.Transparency = 0.4
		end
	end

	-- Une orbe par technique. Sa couleur est gérée par chaque client.
	for _, skill in Skills.List do
		local orb = Instance.new("Part")
		orb.Name = "Orbe" .. skill.Id
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(ORB_SIZE, ORB_SIZE, ORB_SIZE)
		orb.CFrame = origin * orbOffset(skill)
		orb.Color = Color3.fromRGB(90, 90, 100)
		orb.Material = Enum.Material.SmoothPlastic
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanTouch = false
		orb:SetAttribute("SkillId", skill.Id)
		orb.Parent = folder

		local light = Instance.new("PointLight")
		light.Name = "Lueur"
		light.Range = 5
		light.Brightness = 0
		light.Parent = orb

		-- Le caractère chinois de la technique, juste sous l'orbe.
		local tag = Instance.new("BillboardGui")
		tag.Name = "Nom"
		tag.Size = UDim2.fromScale(2.5, 0.42)
		tag.StudsOffset = Vector3.new(0, -0.62, 0)
		tag.LightInfluence = 0
		tag.Parent = orb
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = skill.Name
		label.TextColor3 = Color3.fromRGB(240, 235, 220)
		label.TextStrokeTransparency = 0.2
		label.Parent = tag
	end

	folder.Parent = workspace
	return folder
end

return SkillTree

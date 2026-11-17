-- Arbre de cultivation, en interface : la touche K (clic du joystick gauche en VR) l'ouvre et le
-- ferme. Chaque technique est une case colorée selon la progression du joueur ; un clic (ou le
-- survol) affiche sa fiche, et le bouton « Débloquer » demande son déblocage au serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Skills = require(Shared:WaitForChild("Skills"))

local player = Players.LocalPlayer
local unlockRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UnlockSkill") :: RemoteEvent

local TOGGLE_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.K] = true,
	[Enum.KeyCode.ButtonL3] = true, -- clic du joystick gauche
}

local LOCKED = Color3.fromRGB(70, 70, 80) -- conditions non remplies
local AVAILABLE = Color3.fromRGB(215, 165, 60) -- peut être débloquée maintenant
local OWNED = Color3.fromRGB(60, 170, 120) -- acquise
local GOLD = Color3.fromRGB(235, 200, 120)
local INK = Color3.fromRGB(18, 16, 22)
local TEXT = Color3.fromRGB(235, 232, 225)
local MUTED = Color3.fromRGB(160, 155, 150)
local ERROR = Color3.fromRGB(230, 120, 110)

local PATHS = {
	{ Column = -1.5, Text = "炼体 · Corps" },
	{ Column = -0.5, Text = "剑道 · Lame" },
	{ Column = 0.5, Text = "气功 · Souffle" },
	{ Column = 1.5, Text = "武技 · Arts" },
}
local MAX_ROW = 4

---------------------------------------------------------------------------
-- Construction de l'interface
---------------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function label(parent: Instance, text: string, font: Enum.Font, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Text = text
	item.Font = font
	item.TextColor3 = color
	item.TextScaled = true
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local gui = Instance.new("ScreenGui")
gui.Name = "ArbreCultivation"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panneau"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.7, 0.85)
panel.BackgroundColor3 = INK
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 14)
local ratio = Instance.new("UIAspectRatioConstraint")
ratio.AspectRatio = 1.3
ratio.Parent = panel
local outline = Instance.new("UIStroke")
outline.Color = GOLD
outline.Transparency = 0.5
outline.Thickness = 1.5
outline.Parent = panel

-- Bouton invisible « modal » : tant que le panneau est ouvert, la souris est libérée de la vue
-- à la première personne et peut cliquer.
local modal = Instance.new("TextButton")
modal.Name = "Modal"
modal.Modal = true
modal.BackgroundTransparency = 1
modal.Text = ""
modal.Size = UDim2.fromOffset(0, 0)
modal.Parent = panel

local title = label(panel, "修炼之道 · Voie de la cultivation", Enum.Font.Antique, GOLD)
title.Position = UDim2.fromScale(0.05, 0.02)
title.Size = UDim2.fromScale(0.9, 0.065)

local summary = label(panel, "", Enum.Font.Gotham, MUTED)
summary.Position = UDim2.fromScale(0.05, 0.085)
summary.Size = UDim2.fromScale(0.9, 0.035)

local close = Instance.new("TextButton")
close.Name = "Fermer"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
close.Size = UDim2.fromScale(0.045, 0.058)
close.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
close.Text = "✕"
close.TextScaled = true
close.Font = Enum.Font.GothamBold
close.TextColor3 = TEXT
close.Parent = panel
corner(close, 8)

-- Zone de l'arbre : quatre colonnes (les voies), la racine en bas au centre.
local tree = Instance.new("Frame")
tree.Name = "Arbre"
tree.Position = UDim2.fromScale(0.03, 0.13)
tree.Size = UDim2.fromScale(0.94, 0.6)
tree.BackgroundTransparency = 1
tree.Parent = panel

local NODE_SIZE = Vector2.new(0.21, 0.135)

local function nodeCenter(skill: Skills.Skill): Vector2
	local x = 0.5 + skill.Column * 0.245
	local y = 1 - NODE_SIZE.Y / 2 - skill.Row * (1 - NODE_SIZE.Y - 0.08) / MAX_ROW
	return Vector2.new(x, y)
end

for _, path in PATHS do
	local header = label(tree, path.Text, Enum.Font.GothamBold, GOLD)
	header.AnchorPoint = Vector2.new(0.5, 0)
	header.Position = UDim2.fromScale(0.5 + path.Column * 0.245, -0.02)
	header.Size = UDim2.fromScale(0.22, 0.055)
	header.TextTransparency = 0.2
end

-- Méridiens : un trait entre chaque technique et celle qu'elle demande.
local meridians: { [Skills.Skill]: Frame } = {}
for _, skill in Skills.List do
	if skill.Requires and Skills.ById[skill.Requires] then
		local line = Instance.new("Frame")
		line.Name = "Meridien"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = GOLD
		line.BackgroundTransparency = 0.6
		line.BorderSizePixel = 0
		line.ZIndex = 1
		line.Parent = tree
		meridians[skill] = line
	end
end

-- Les traits sont placés en pixels : on les recalcule quand la taille de l'arbre change.
local function layoutMeridians()
	local size = tree.AbsoluteSize
	for skill, line in meridians do
		local from = nodeCenter(Skills.ById[skill.Requires :: string]) * size
		local to = nodeCenter(skill) * size
		local delta = to - from
		line.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
		line.Size = UDim2.fromOffset(delta.Magnitude, 3)
		line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	end
end
tree:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutMeridians)

-- Fiche de la technique sélectionnée, en bas du panneau.
local card = Instance.new("Frame")
card.Name = "Fiche"
card.Position = UDim2.fromScale(0.03, 0.75)
card.Size = UDim2.fromScale(0.94, 0.22)
card.BackgroundColor3 = Color3.fromRGB(32, 29, 38)
card.BorderSizePixel = 0
card.Parent = panel
corner(card, 10)

local cardTitle = label(card, "", Enum.Font.GothamBold, GOLD)
cardTitle.TextXAlignment = Enum.TextXAlignment.Left
cardTitle.Position = UDim2.fromScale(0.03, 0.06)
cardTitle.Size = UDim2.fromScale(0.7, 0.24)

local cardText = label(card, "", Enum.Font.Gotham, TEXT)
cardText.TextXAlignment = Enum.TextXAlignment.Left
cardText.TextYAlignment = Enum.TextYAlignment.Top
cardText.Position = UDim2.fromScale(0.03, 0.34)
cardText.Size = UDim2.fromScale(0.7, 0.44)

local cardStatus = label(card, "", Enum.Font.GothamBold, MUTED)
cardStatus.TextXAlignment = Enum.TextXAlignment.Left
cardStatus.Position = UDim2.fromScale(0.03, 0.8)
cardStatus.Size = UDim2.fromScale(0.7, 0.16)

local unlockButton = Instance.new("TextButton")
unlockButton.Name = "Debloquer"
unlockButton.AnchorPoint = Vector2.new(1, 0.5)
unlockButton.Position = UDim2.fromScale(0.97, 0.5)
unlockButton.Size = UDim2.fromScale(0.22, 0.42)
unlockButton.BackgroundColor3 = AVAILABLE
unlockButton.Font = Enum.Font.GothamBold
unlockButton.TextScaled = true
unlockButton.TextColor3 = INK
unlockButton.Text = "Débloquer"
unlockButton.Parent = card
corner(unlockButton, 8)

---------------------------------------------------------------------------
-- Cases des techniques et mise à jour
---------------------------------------------------------------------------

local selected: Skills.Skill? = nil
local nodes: { [Skills.Skill]: TextButton } = {}
local refresh: () -> ()

local function progression(): (number, { [string]: boolean }, number)
	local level = player:GetAttribute("Level") or 1
	local owned = Skills.parse(player:GetAttribute("Skills"))
	local points = player:GetAttribute("SkillPoints") or 0
	return level, owned, points
end

local function selectSkill(skill: Skills.Skill)
	selected = skill
	refresh()
end

for _, skill in Skills.List do
	local center = nodeCenter(skill)
	local node = Instance.new("TextButton")
	node.Name = skill.Id
	node.AnchorPoint = Vector2.new(0.5, 0.5)
	node.Position = UDim2.fromScale(center.X, center.Y)
	node.Size = UDim2.fromScale(NODE_SIZE.X, NODE_SIZE.Y)
	node.AutoButtonColor = true
	node.Text = ""
	node.ZIndex = 2
	node.Parent = tree
	corner(node, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Contour"
	stroke.Color = GOLD
	stroke.Thickness = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = node

	local hanzi = label(node, skill.Hanzi, Enum.Font.Antique, TEXT)
	hanzi.Position = UDim2.fromScale(0.05, 0.05)
	hanzi.Size = UDim2.fromScale(0.9, 0.48)
	hanzi.ZIndex = 3
	local name = label(node, skill.Name, Enum.Font.GothamBold, TEXT)
	name.Position = UDim2.fromScale(0.05, 0.55)
	name.Size = UDim2.fromScale(0.9, 0.38)
	name.ZIndex = 3

	node.MouseEnter:Connect(function()
		selectSkill(skill)
	end)
	node.Activated:Connect(function()
		selectSkill(skill)
	end)
	nodes[skill] = node
end

refresh = function()
	local level, owned, points = progression()
	local realm = Skills.realm(level)
	summary.Text = "Niveau " .. level .. " · " .. realm.Hanzi .. " " .. realm.Name .. " · " .. points .. " point" .. (if points > 1 then "s" else "") .. " de Qi à dépenser  —  K pour fermer"

	for skill, node in nodes do
		local color = LOCKED
		if owned[skill.Id] then
			color = OWNED
		elseif Skills.canUnlock(skill, level, owned) then
			color = AVAILABLE
		end
		node.BackgroundColor3 = color
		local stroke = node:FindFirstChild("Contour") :: UIStroke
		stroke.Thickness = if skill == selected then 3 else 0
	end

	local skill = selected
	if not skill then
		cardTitle.Text = "Choisis une technique"
		cardText.Text = "Survole ou clique une case pour lire sa fiche."
		cardStatus.Text = ""
		unlockButton.Visible = false
		return
	end
	cardTitle.Text = skill.Hanzi .. "  " .. skill.Name
	cardText.Text = skill.Description
	local cost = skill.Cost .. " point" .. (if skill.Cost > 1 then "s" else "") .. " · niveau " .. skill.MinLevel
	if owned[skill.Id] then
		cardStatus.Text = "Acquise"
		cardStatus.TextColor3 = OWNED
		unlockButton.Visible = false
	else
		local ok, reason = Skills.canUnlock(skill, level, owned)
		cardStatus.Text = (if ok then "Disponible" else reason or "Indisponible") .. " · " .. cost
		cardStatus.TextColor3 = if ok then AVAILABLE else ERROR
		unlockButton.Visible = ok
	end
end

unlockButton.Activated:Connect(function()
	local skill = selected
	local level, owned = progression()
	if skill and Skills.canUnlock(skill, level, owned) then
		unlockRemote:FireServer(skill.Id) -- le serveur revérifie tout
	end
end)

for _, attribute in { "Level", "Skills", "SkillPoints" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
end

---------------------------------------------------------------------------
-- Ouverture / fermeture
---------------------------------------------------------------------------

local function setOpen(open: boolean)
	gui.Enabled = open
	if open then
		refresh()
		layoutMeridians()
	end
end

close.Activated:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if TOGGLE_KEYS[input.KeyCode] and not (processed and input.KeyCode == Enum.KeyCode.K) then
		setOpen(not gui.Enabled)
	end
end)

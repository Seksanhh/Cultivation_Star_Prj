-- Construit le temple martial : cour pavée, enceinte, grande salle, leitai (estrade de duel),
-- râtelier d'armes, mannequins de bois, lanternes, cerisiers et pics montagneux au loin.
-- Repères : le nord est vers -Z. Le joueur apparaît au sud de la cour, face à la grande salle.

local Lighting = game:GetService("Lighting")

local Collisions = require(script.Parent:WaitForChild("Collisions"))

local Arena = {}

local folder: Folder

---------------------------------------------------------------------------
-- Palette
---------------------------------------------------------------------------

local RED = Color3.fromRGB(150, 38, 32) -- laque rouge des murs et colonnes
local DARK_RED = Color3.fromRGB(105, 25, 25)
local TILE = Color3.fromRGB(45, 68, 72) -- tuiles vernissées gris-vert
local GOLD = Color3.fromRGB(205, 165, 65)
local STONE = Color3.fromRGB(150, 148, 140)
local STONE_DARK = Color3.fromRGB(105, 104, 100)
local WOOD = Color3.fromRGB(70, 45, 30)
local WOOD_LIGHT = Color3.fromRGB(150, 110, 70)
local BLOSSOM = Color3.fromRGB(255, 185, 200)
local LANTERN = Color3.fromRGB(255, 95, 45)

---------------------------------------------------------------------------
-- Briques de base
---------------------------------------------------------------------------

local function block(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Bloc ajouté directement au décor.
local function add(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = block(name, size, cframe, color, material)
	part.Parent = folder
	return part
end

-- Cylindre vertical dont le centre est à `position`.
local function pillar(name: string, diameter: number, height: number, position: Vector3, color: Color3, material: Enum.Material): Part
	local part = block(name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	part.Parent = folder
	return part
end

-- Texte peint sur une face d'une pièce.
local function paint(part: Part, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = text
	label.TextColor3 = color
	label.Parent = gui

	gui.Parent = part
end

---------------------------------------------------------------------------
-- Éléments d'architecture
---------------------------------------------------------------------------

-- Toit chinois à pans concaves et angles relevés. `base` est le centre du bas de l'avant-toit.
-- Renvoie la hauteur du faîte.
local function roof(base: Vector3, width: number, depth: number, levels: number): number
	local layerHeight = 0.9
	local insetWidth = width * 0.35
	local insetDepth = depth - 3
	local topWidth = width

	for i = 0, levels - 1 do
		local t = if levels > 1 then i / (levels - 1) else 0
		-- Pente douce au bord, raide vers le faîte : c'est ce qui donne la courbe.
		local f = 1 - (1 - t) ^ 2
		topWidth = width - insetWidth * f
		local size = Vector3.new(topWidth, layerHeight, depth - insetDepth * f)
		add("Toit", size, CFrame.new(base + Vector3.new(0, (i + 0.5) * layerHeight, 0)), TILE, Enum.Material.Slate)
	end

	local ridgeY = base.Y + levels * layerHeight + 0.4
	add("Faitage", Vector3.new(topWidth + 2, 0.8, 1.2), CFrame.new(base.X, ridgeY, base.Z), GOLD, Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		-- Extrémités du faîtage relevées.
		local tip = CFrame.new(base.X + sx * (topWidth / 2 + 1), ridgeY, base.Z)
			* CFrame.Angles(0, if sx == 1 then 0 else math.pi, 0)
			* CFrame.Angles(0, 0, math.rad(35))
			* CFrame.new(1, 0, 0)
		add("Faitage", Vector3.new(2.5, 0.7, 1), tip, GOLD, Enum.Material.Metal)
	end

	-- Angles de l'avant-toit relevés vers l'extérieur.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = base + Vector3.new(sx * width / 2, 0.45, sz * depth / 2)
			local yaw = math.atan2(-sz, sx)
			local cframe = CFrame.new(corner) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(22)) * CFrame.new(1.5, 0, 0)
			add("Angle", Vector3.new(7, 0.7, 1.4), cframe, TILE, Enum.Material.Slate)
		end
	end

	return ridgeY
end

-- Tronçon de mur d'enceinte aligné sur un axe, coiffé de tuiles.
local function wall(centerX: number, centerZ: number, lengthX: number, lengthZ: number)
	local height = 9
	add("Mur", Vector3.new(lengthX, height, lengthZ), CFrame.new(centerX, height / 2, centerZ), RED, Enum.Material.Concrete)
	add("Soubassement", Vector3.new(lengthX + 0.4, 1.5, lengthZ + 0.4), CFrame.new(centerX, 0.75, centerZ), STONE_DARK, Enum.Material.Slate)
	add("Chaperon", Vector3.new(lengthX + 1.5, 0.8, lengthZ + 1.5), CFrame.new(centerX, height + 0.4, centerZ), TILE, Enum.Material.Slate)
	add("Chaperon", Vector3.new(math.max(lengthX - 0.5, 1), 0.6, math.max(lengthZ - 0.5, 1)), CFrame.new(centerX, height + 1.1, centerZ), TILE, Enum.Material.Slate)
end

-- Lanterne rouge sur potence, avec sa lumière.
local function lantern(position: Vector3, armDirection: number)
	add("Poteau", Vector3.new(0.6, 9, 0.6), CFrame.new(position + Vector3.new(0, 4.5, 0)), WOOD, Enum.Material.Wood)
	add("Potence", Vector3.new(2.6, 0.4, 0.4), CFrame.new(position + Vector3.new(armDirection * 1, 8.6, 0)), WOOD, Enum.Material.Wood)

	local center = position + Vector3.new(armDirection * 2, 7, 0)
	add("Cordon", Vector3.new(0.1, 0.8, 0.1), CFrame.new(center + Vector3.new(0, 1.4, 0)), WOOD, Enum.Material.Fabric)
	local body = add("Lanterne", Vector3.new(1.6, 2, 1.6), CFrame.new(center), LANTERN, Enum.Material.Neon)
	add("Coiffe", Vector3.new(1.8, 0.25, 1.8), CFrame.new(center + Vector3.new(0, 1.1, 0)), GOLD, Enum.Material.Metal)
	add("Coiffe", Vector3.new(1.8, 0.25, 1.8), CFrame.new(center - Vector3.new(0, 1.1, 0)), GOLD, Enum.Material.Metal)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 90)
	light.Range = 22
	light.Brightness = 1.6
	light.Parent = body
end

-- Cerisier en fleurs.
local function cherryTree(position: Vector3, scale: number)
	add("Tronc", Vector3.new(1.6 * scale, 10 * scale, 1.6 * scale), CFrame.new(position + Vector3.new(0, 5 * scale, 0)) * CFrame.Angles(0, 0, math.rad(6)), WOOD, Enum.Material.Wood)
	local crowns = {
		{ Vector3.new(0, 12, 0), 12 },
		{ Vector3.new(4, 10.5, 2), 9 },
		{ Vector3.new(-4, 10, -2), 9 },
		{ Vector3.new(1, 10, -4.5), 8 },
		{ Vector3.new(-1.5, 14, 2.5), 8 },
	}
	for _, crown in crowns do
		local diameter = crown[2] * scale
		local foliage = add("Fleurs", Vector3.new(diameter, diameter, diameter), CFrame.new(position + crown[1] * scale), BLOSSOM, Enum.Material.Grass)
		foliage.Shape = Enum.PartType.Ball
		foliage.CanCollide = false
		foliage.CastShadow = false
	end
end

-- Bannière « 武 » (art martial) pendue à un mât.
local function banner(position: Vector3)
	add("Mat", Vector3.new(0.5, 9, 0.5), CFrame.new(position + Vector3.new(0, 4.5, 0)), DARK_RED, Enum.Material.Wood)
	add("Pommeau", Vector3.new(0.8, 0.4, 0.8), CFrame.new(position + Vector3.new(0, 9.2, 0)), GOLD, Enum.Material.Metal)
	local cloth = add("Banniere", Vector3.new(2.4, 4.5, 0.1), CFrame.new(position + Vector3.new(0, 6.2, 0.35)), RED, Enum.Material.Fabric)
	cloth.CanCollide = false
	paint(cloth, Enum.NormalId.Front, "武", GOLD)
	paint(cloth, Enum.NormalId.Back, "武", GOLD)
end

---------------------------------------------------------------------------
-- Zones du temple
---------------------------------------------------------------------------

local function buildGround()
	-- Cour pavée (120 x 120), dessus à y = 0.
	add("Cour", Vector3.new(124, 1, 124), CFrame.new(0, -0.5, 0), STONE, Enum.Material.Cobblestone)
	-- Allée centrale entre le portail et la grande salle.
	add("Allee", Vector3.new(14, 0.1, 118), CFrame.new(0, 0.05, 0), STONE_DARK, Enum.Material.Slate)

	if not workspace:FindFirstChild("Baseplate") then
		add("Terrain", Vector3.new(900, 1, 900), CFrame.new(0, -0.8, 0), Color3.fromRGB(75, 95, 70), Enum.Material.Grass)
	end

	if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Size = Vector3.new(6, 0.2, 6)
		spawn.CFrame = CFrame.new(0, 0.2, 42)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Parent = folder
	end
end

local function buildWalls()
	wall(0, -61, 124, 2) -- nord
	wall(61, 0, 2, 120) -- est
	wall(-61, 0, 2, 120) -- ouest
	wall(-35, 61, 54, 2) -- sud, de part et d'autre du portail
	wall(35, 61, 54, 2)

	-- Portail d'entrée.
	for _, sx in { -1, 1 } do
		pillar("ColonnePortail", 2, 13, Vector3.new(sx * 7.5, 6.5, 61), RED, Enum.Material.Concrete)
		pillar("BasePortail", 2.8, 1, Vector3.new(sx * 7.5, 0.5, 61), STONE_DARK, Enum.Material.Slate)
	end
	add("Linteau", Vector3.new(19, 1.4, 1.6), CFrame.new(0, 12.3, 61), DARK_RED, Enum.Material.Wood)
	local sign = add("Enseigne", Vector3.new(8, 2.6, 0.4), CFrame.new(0, 10.2, 60.4), Color3.fromRGB(25, 35, 60), Enum.Material.Wood)
	paint(sign, Enum.NormalId.Front, "武道", GOLD)
	roof(Vector3.new(0, 13, 61), 26, 8, 4)
end

local function buildHall()
	-- Terrasse de pierre et escalier.
	add("Terrasse", Vector3.new(66, 3, 30), CFrame.new(0, 1.5, -43), STONE, Enum.Material.Slate)
	add("Marche", Vector3.new(22, 2, 2), CFrame.new(0, 1, -27), STONE_DARK, Enum.Material.Slate)
	add("Marche", Vector3.new(22, 1, 2), CFrame.new(0, 0.5, -25), STONE_DARK, Enum.Material.Slate)

	local floorY = 3
	local columnHeight = 12

	-- Colonnade de façade.
	for x = -24, 24, 8 do
		pillar("Colonne", 1.8, columnHeight, Vector3.new(x, floorY + columnHeight / 2, -32), RED, Enum.Material.Concrete)
		pillar("BaseColonne", 2.6, 0.8, Vector3.new(x, floorY + 0.4, -32), STONE_DARK, Enum.Material.Slate)
	end
	add("Poutre", Vector3.new(54, 1.4, 1.4), CFrame.new(0, floorY + columnHeight - 0.7, -32), Color3.fromRGB(30, 70, 95), Enum.Material.Wood)

	-- Murs du fond et des côtés ; la façade reste ouverte.
	add("MurSalle", Vector3.new(54, columnHeight, 1.2), CFrame.new(0, floorY + columnHeight / 2, -54), RED, Enum.Material.Concrete)
	for _, sx in { -1, 1 } do
		add("MurSalle", Vector3.new(1.2, columnHeight, 18), CFrame.new(sx * 26.4, floorY + columnHeight / 2, -45), RED, Enum.Material.Concrete)
	end
	add("Tapis", Vector3.new(12, 0.1, 20), CFrame.new(0, floorY + 0.05, -43), DARK_RED, Enum.Material.Fabric)

	-- Autel, gong et enseigne.
	add("Autel", Vector3.new(12, 2.2, 3), CFrame.new(0, floorY + 1.1, -51), WOOD, Enum.Material.Wood)
	add("NappeAutel", Vector3.new(12.4, 0.15, 3.4), CFrame.new(0, floorY + 2.28, -51), GOLD, Enum.Material.Fabric)
	local gong = block("Gong", Vector3.new(0.5, 6, 6), CFrame.new(0, floorY + 7.2, -53) * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal)
	gong.Shape = Enum.PartType.Cylinder
	gong.Parent = folder
	local sign = add("Enseigne", Vector3.new(12, 3, 0.4), CFrame.new(0, floorY + columnHeight + 2.2, -30.6), Color3.fromRGB(25, 35, 60), Enum.Material.Wood)
	paint(sign, Enum.NormalId.Back, "武道館", GOLD)

	-- Toit bas, étage, toit haut.
	local lowerRidge = roof(Vector3.new(0, floorY + columnHeight, -43), 68, 34, 7)
	local storeyHeight = 6
	add("Etage", Vector3.new(34, storeyHeight, 12), CFrame.new(0, lowerRidge - 1.5 + storeyHeight / 2, -43), RED, Enum.Material.Concrete)
	roof(Vector3.new(0, lowerRidge - 1.5 + storeyHeight, -43), 44, 20, 6)

	-- Brûle-encens devant l'escalier.
	pillar("PiedBruleEncens", 3, 0.8, Vector3.new(0, 0.4, -18), STONE_DARK, Enum.Material.Slate)
	local burner = pillar("BruleEncens", 4.4, 2.2, Vector3.new(0, 1.9, -18), Color3.fromRGB(110, 85, 50), Enum.Material.Metal)
	pillar("BordBruleEncens", 5, 0.4, Vector3.new(0, 3.2, -18), Color3.fromRGB(110, 85, 50), Enum.Material.Metal)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(220, 215, 205)
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 3
	smoke.Size = 1.5
	smoke.Parent = burner
end

-- Leitai : l'estrade de duel au centre de la cour.
local function buildLeitai()
	add("Leitai", Vector3.new(26, 2, 26), CFrame.new(0, 1, 0), STONE_DARK, Enum.Material.Slate)
	add("BordureLeitai", Vector3.new(26.6, 0.4, 26.6), CFrame.new(0, 1.8, 0), GOLD, Enum.Material.Metal)
	add("TapisLeitai", Vector3.new(22, 0.1, 22), CFrame.new(0, 2.05, 0), RED, Enum.Material.Fabric)

	-- Médaillon central.
	local disc = block("Medaillon", Vector3.new(0.12, 9, 9), CFrame.new(0, 2.06, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Fabric)
	disc.Shape = Enum.PartType.Cylinder
	disc.CanCollide = false
	disc.Parent = folder

	-- Une marche au sud et une au nord.
	for _, sz in { -1, 1 } do
		add("MarcheLeitai", Vector3.new(10, 1, 2), CFrame.new(0, 0.5, sz * 14), STONE, Enum.Material.Slate)
	end

	-- Bannières aux quatre coins, au sol.
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			banner(Vector3.new(sx * 15, 0, sz * 15))
		end
	end
end

local function buildDecor()
	for _, z in { 46, 22, -22 } do
		lantern(Vector3.new(-22, 0, z), 1)
		lantern(Vector3.new(22, 0, z), -1)
	end

	cherryTree(Vector3.new(-46, 0, 46), 1)
	cherryTree(Vector3.new(46, 0, 46), 1.1)
	cherryTree(Vector3.new(-48, 0, -8), 0.9)
	cherryTree(Vector3.new(48, 0, -12), 1)

	-- Pics rocheux dans la brume, tout autour du temple.
	local random = Random.new(7)
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + random:NextNumber(-0.15, 0.15)
		local distance = random:NextNumber(230, 380)
		local height = random:NextNumber(150, 320)
		local diameter = random:NextNumber(45, 85)
		local position = Vector3.new(math.cos(angle) * distance, height / 2 - 10, math.sin(angle) * distance)

		local peak = pillar("Pic", diameter, height, position, Color3.fromRGB(85, 95, 90), Enum.Material.Slate)
		peak.CastShadow = false
		local shoulder = pillar("Pic", diameter * 1.5, height * 0.55, position - Vector3.new(0, height * 0.225, 0), Color3.fromRGB(75, 88, 82), Enum.Material.Slate)
		shoulder.CastShadow = false
		local cap = pillar("Vegetation", diameter * 0.9, 6, position + Vector3.new(0, height / 2 + 2, 0), Color3.fromRGB(60, 95, 65), Enum.Material.Grass)
		cap.CastShadow = false
	end
end

-- Lumière de fin d'après-midi et brume.
local function setAtmosphere()
	Lighting.ClockTime = 17.3
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(95, 78, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 122, 110)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 205, 160)

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.36
		atmosphere.Offset = 0.15
		atmosphere.Color = Color3.fromRGB(235, 200, 170)
		atmosphere.Decay = Color3.fromRGB(160, 120, 110)
		atmosphere.Glare = 0.25
		atmosphere.Haze = 1.8
		atmosphere.Parent = Lighting
	end
end

---------------------------------------------------------------------------
-- Mannequins
---------------------------------------------------------------------------

-- Fait apparaître un mannequin de bois dont les pieds sont à `position`. Il réapparaît après sa mort.
function Arena.spawnDummy(position: Vector3)
	local origin = CFrame.new(position)
	local wood = Enum.Material.Wood

	local model = Instance.new("Model")
	model.Name = "Mannequin"

	local root = block("HumanoidRootPart", Vector3.new(2, 2, 1), origin * CFrame.new(0, 3, 0), WOOD, wood)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.Parent = model

	local pieces = {
		block("Torso", Vector3.new(2, 2, 1), origin * CFrame.new(0, 3, 0), WOOD_LIGHT, wood),
		block("Head", Vector3.new(1.2, 1.2, 1.2), origin * CFrame.new(0, 4.6, 0), WOOD_LIGHT, wood),
		block("Left Arm", Vector3.new(1, 2, 1), origin * CFrame.new(-1.5, 3, 0), WOOD, wood),
		block("Right Arm", Vector3.new(1, 2, 1), origin * CFrame.new(1.5, 3, 0), WOOD, wood),
		block("Left Leg", Vector3.new(1, 2, 1), origin * CFrame.new(-0.5, 1, 0), WOOD, wood),
		block("Right Leg", Vector3.new(1, 2, 1), origin * CFrame.new(0.5, 1, 0), WOOD, wood),
	}
	for _, piece in pieces do
		piece.Parent = model
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Mannequin"
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = model

	model.PrimaryPart = root
	Collisions.assign(model, Collisions.BODIES)
	model.Parent = folder

	local dead = false
	humanoid.HealthChanged:Connect(function(health)
		if health > 0 or dead then
			return
		end
		dead = true
		-- Le mannequin s'effondre, puis un nouveau prend sa place.
		for _, piece in pieces do
			piece.Anchored = false
		end
		task.delay(3, function()
			model:Destroy()
			Arena.spawnDummy(position)
		end)
	end)
end

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------

-- Construit le temple et renvoie les emplacements des armes sur le râtelier.
function Arena.build(weaponCount: number): { CFrame }
	folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace

	setAtmosphere()
	buildGround()
	buildWalls()
	buildHall()
	buildLeitai()
	buildDecor()

	-- Râtelier d'armes, à droite du point d'apparition : les armes flottent au-dessus.
	local spacing = 2.6
	local rackLength = math.max(weaponCount * spacing + 1, 6)
	local rackX, rackZ = 12, 34
	add("Ratelier", Vector3.new(2.5, 2.6, rackLength), CFrame.new(rackX, 1.3, rackZ), WOOD, Enum.Material.Wood)
	add("NappeRatelier", Vector3.new(2.7, 0.1, rackLength + 0.2), CFrame.new(rackX, 2.65, rackZ), RED, Enum.Material.Fabric)

	local homes = {}
	for i = 1, weaponCount do
		local z = rackZ + (i - (weaponCount + 1) / 2) * spacing
		table.insert(homes, CFrame.new(rackX, 4.3, z))
	end

	-- Mannequins : une rangée à gauche du point d'apparition, et un sur le leitai.
	for _, z in { 24, 30, 36, 42 } do
		Arena.spawnDummy(Vector3.new(-13, 0, z))
	end
	Arena.spawnDummy(Vector3.new(0, 2.1, -4))

	return homes
end

return Arena

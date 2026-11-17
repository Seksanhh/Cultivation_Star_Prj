-- Barres de vie et d'expérience, affichées dans le monde pour être lisibles dans le casque :
-- un petit panneau flotte au-dessus de la main gauche (ou devant le regard, selon Config.HUD.ANCHOR)
-- et reste toujours tourné vers les yeux du joueur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local settings = Config.HUD
if not settings.ENABLED then
	return
end

local player = Players.LocalPlayer
local handsFolder = workspace:WaitForChild("VRHands")

local PIXELS_PER_STUD = 400
local GREEN = Color3.fromRGB(90, 200, 90)
local RED = Color3.fromRGB(220, 60, 50)
local BLUE = Color3.fromRGB(90, 170, 255)
local CYAN = Color3.fromRGB(70, 200, 200)

---------------------------------------------------------------------------
-- Construction du panneau
---------------------------------------------------------------------------

local panel = Instance.new("Part")
panel.Name = "HudPanel"
panel.Size = Vector3.new(settings.WIDTH, settings.HEIGHT, 0.02)
panel.Transparency = 1
panel.Anchored = true
panel.CanCollide = false
panel.CanQuery = false
panel.CanTouch = false
panel.CastShadow = false

local gui = Instance.new("SurfaceGui")
gui.Name = "Hud"
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
gui.CanvasSize = Vector2.new(settings.WIDTH * PIXELS_PER_STUD, settings.HEIGHT * PIXELS_PER_STUD)
gui.LightInfluence = 0
gui.AlwaysOnTop = true -- une arme ou un bouclier ne cache pas les barres
gui.ResetOnSpawn = false
gui.Parent = panel

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
background.BackgroundTransparency = 0.35
background.BorderSizePixel = 0
background.Parent = gui

local backgroundCorner = Instance.new("UICorner")
backgroundCorner.CornerRadius = UDim.new(0.15, 0)
backgroundCorner.Parent = background

-- Une barre : un fond sombre, un remplissage coloré et un texte par-dessus.
local function makeBar(top: number, color: Color3): (Frame, TextLabel)
	local track = Instance.new("Frame")
	track.Position = UDim2.fromScale(0.04, top)
	track.Size = UDim2.fromScale(0.92, 0.27)
	track.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = background

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.3, 0)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.ZIndex = 2
	label.Parent = track

	return fill, label
end

local healthFill, healthLabel = makeBar(0.05, GREEN)
local qiFill, qiLabel = makeBar(0.365, CYAN)
local xpFill, xpLabel = makeBar(0.68, BLUE)

panel.Parent = workspace.CurrentCamera -- local à ce client

---------------------------------------------------------------------------
-- Mise à jour
---------------------------------------------------------------------------

local function update()
	local camera = workspace.CurrentCamera
	if panel.Parent ~= camera then
		panel.Parent = camera
	end

	-- Vie.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local health = if humanoid then math.max(humanoid.Health, 0) else 0
	local maxHealth = if humanoid then math.max(humanoid.MaxHealth, 1) else 100
	local healthRatio = math.clamp(health / maxHealth, 0, 1)
	healthFill.Size = UDim2.fromScale(healthRatio, 1)
	healthFill.BackgroundColor3 = RED:Lerp(GREEN, healthRatio) -- vire au rouge quand la vie baisse
	healthLabel.Text = math.ceil(health) .. " / " .. math.round(maxHealth)

	-- Qi : la réserve qui alimente les techniques actives.
	local qi = player:GetAttribute("Qi") or 0
	local qiMax = player:GetAttribute("QiMax") or 100
	qiFill.Size = UDim2.fromScale(math.clamp(qi / math.max(qiMax, 1), 0, 1), 1)
	qiLabel.Text = "Qi " .. qi .. " / " .. qiMax

	-- Expérience (attributs publiés par le serveur, voir Progression.luau).
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local needed = player:GetAttribute("XPNeeded") or 1
	if level >= Config.PlayerLevel.MAX_LEVEL then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpLabel.Text = "Niv. " .. level .. " · MAX"
	else
		xpFill.Size = UDim2.fromScale(math.clamp(xp / math.max(needed, 1), 0, 1), 1)
		xpLabel.Text = "Niv. " .. level .. " · " .. math.floor(xp) .. " / " .. needed .. " XP"
	end
	-- Points de Qi à dépenser dans l'arbre de cultivation (touche K).
	local points = player:GetAttribute("SkillPoints") or 0
	if points > 0 then
		xpLabel.Text ..= " · " .. points .. " pt (K)"
	end

	-- Position : au-dessus de la main gauche, ou devant le regard si la main n'existe pas.
	local eyes = camera:GetRenderCFrame()
	local position = (eyes * CFrame.new(settings.HEAD_OFFSET)).Position
	if settings.ANCHOR == "Hand" then
		local hands = handsFolder:FindFirstChild(tostring(player.UserId))
		local hand = hands and hands:FindFirstChild("Left")
		if hand and hand:IsA("BasePart") then
			position = hand.Position + eyes.UpVector * settings.HAND_HEIGHT
		end
	end

	-- La face avant du panneau regarde toujours les yeux, sans pencher par rapport au regard.
	if (eyes.Position - position).Magnitude > 0.05 then
		panel.CFrame = CFrame.lookAt(position, eyes.Position, eyes.UpVector)
	end
end

-- Après la caméra et le suivi des mains, pour que le panneau ne traîne pas d'une image.
RunService:BindToRenderStep("VRMeleeHud", Enum.RenderPriority.Camera.Value + 2, update)

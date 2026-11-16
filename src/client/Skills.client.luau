-- Arbre de cultivation, côté joueur : colore les orbes de la stèle selon sa progression,
-- affiche la fiche de la technique que la main approche, et demande son déblocage quand
-- le joueur serre la gâchette de préhension (ou appuie sur E / Q sans casque).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Skills = require(Shared:WaitForChild("Skills"))

local player = Players.LocalPlayer
local unlockRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UnlockSkill") :: RemoteEvent
local handsFolder = workspace:WaitForChild("VRHands")
local tree = workspace:WaitForChild("CultivationTree")

local TOUCH_RADIUS = 1.1 -- distance main-orbe pour la sélectionner (studs)

local LOCKED = Color3.fromRGB(85, 85, 95) -- conditions non remplies
local AVAILABLE = Color3.fromRGB(255, 205, 90) -- peut être débloquée maintenant
local OWNED = Color3.fromRGB(90, 230, 170) -- acquise

local orbs: { [string]: BasePart } = {}
local function register(item: Instance)
	local id = item:GetAttribute("SkillId")
	if item:IsA("BasePart") and typeof(id) == "string" then
		orbs[id] = item
	end
end
for _, item in tree:GetChildren() do
	register(item)
end
tree.ChildAdded:Connect(register)

---------------------------------------------------------------------------
-- Fiche de la technique sélectionnée
---------------------------------------------------------------------------

local card = Instance.new("BillboardGui")
card.Name = "FicheTechnique"
card.Size = UDim2.fromScale(5.2, 2.4)
card.StudsOffset = Vector3.new(0, 1.9, 0)
card.AlwaysOnTop = true
card.LightInfluence = 0
card.Enabled = false
card.ResetOnSpawn = false
card.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.fromRGB(18, 16, 22)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = card

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.08, 0)
corner.Parent = frame

local function line(top: number, height: number, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0.04, top)
	label.Size = UDim2.fromScale(0.92, height)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = font
	label.TextColor3 = color
	label.Parent = frame
	return label
end

local titleLabel = line(0.04, 0.24, Enum.Font.GothamBold, Color3.fromRGB(255, 225, 150))
local descriptionLabel = line(0.3, 0.4, Enum.Font.Gotham, Color3.fromRGB(235, 235, 235))
local statusLabel = line(0.73, 0.22, Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255))

---------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------

local selected: string? = nil

local function progression(): (number, { [string]: boolean }, number)
	local level = player:GetAttribute("Level") or 1
	local owned = Skills.parse(player:GetAttribute("Skills"))
	local points = player:GetAttribute("SkillPoints") or 0
	return level, owned, points
end

-- Technique dont l'orbe est la plus proche d'une des deux mains (ou nil).
local function nearestOrb(): string?
	local hands = handsFolder:FindFirstChild(tostring(player.UserId))
	if not hands then
		return nil
	end
	local best: string? = nil
	local bestDistance = TOUCH_RADIUS
	for _, hand in hands:GetChildren() do
		if hand:IsA("BasePart") then
			for id, orb in orbs do
				local distance = (orb.Position - hand.Position).Magnitude
				if distance <= bestDistance then
					best, bestDistance = id, distance
				end
			end
		end
	end
	return best
end

local elapsed = 0
local function update(dt: number)
	-- Dix fois par seconde suffisent : rien ici ne demande la précision d'une image.
	elapsed += dt
	if elapsed < 0.1 then
		return
	end
	elapsed = 0

	local level, owned, points = progression()
	selected = nearestOrb()

	for id, orb in orbs do
		local skill = Skills.ById[id]
		if skill then
			local color = LOCKED
			local glow = 0
			if owned[id] then
				color, glow = OWNED, 1.5
			elseif Skills.canUnlock(skill, level, owned) then
				-- Les techniques disponibles palpitent pour attirer l'œil.
				color, glow = AVAILABLE, 1 + math.sin(os.clock() * 4) * 0.6
			end
			orb.Color = color
			orb.Material = if color == LOCKED then Enum.Material.SmoothPlastic else Enum.Material.Neon
			local size = if id == selected then 1.1 else 0.85
			orb.Size = Vector3.new(size, size, size)
			local light = orb:FindFirstChild("Lueur")
			if light and light:IsA("PointLight") then
				light.Color = color
				light.Brightness = glow
			end
		end
	end

	local skill = selected and Skills.ById[selected]
	local orb = selected and orbs[selected]
	if skill and orb then
		card.Adornee = orb
		card.Enabled = true
		titleLabel.Text = skill.Hanzi .. "  " .. skill.Name
		descriptionLabel.Text = skill.Description
		if owned[skill.Id] then
			statusLabel.Text = "Acquise"
			statusLabel.TextColor3 = OWNED
		else
			local ok, reason = Skills.canUnlock(skill, level, owned)
			local cost = skill.Cost .. " point" .. (if skill.Cost > 1 then "s" else "") .. " de Qi (tu en as " .. points .. ")"
			if ok then
				local action = if VRService.VREnabled then "Serre la gâchette" else "Appuie sur E"
				statusLabel.Text = action .. " · " .. cost
				statusLabel.TextColor3 = AVAILABLE
			else
				statusLabel.Text = (reason or "Indisponible") .. " · " .. cost
				statusLabel.TextColor3 = Color3.fromRGB(230, 120, 110)
			end
		end
	else
		card.Enabled = false
	end
end

RunService.Heartbeat:Connect(update)

---------------------------------------------------------------------------
-- Déblocage
---------------------------------------------------------------------------

local UNLOCK_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.ButtonL1] = true,
	[Enum.KeyCode.ButtonR1] = true,
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.Q] = true,
}

UserInputService.InputBegan:Connect(function(input)
	if not UNLOCK_KEYS[input.KeyCode] or not selected then
		return
	end
	local skill = Skills.ById[selected]
	local level, owned = progression()
	if skill and Skills.canUnlock(skill, level, owned) then
		unlockRemote:FireServer(skill.Id) -- le serveur revérifie tout
	end
end)

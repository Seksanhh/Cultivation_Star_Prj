-- Combos de calligraphie (shared/Calligraphy.luau) : le client reconnaît les traits de lame,
-- le serveur vérifie le combo (arme à lame en main, recharge) puis lance le sort.
--
-- Le caractère tracé EST le sort : il apparaît devant le joueur en encre d'or lumineuse, puis
--   十 Croix du sabre   : part vers la cible (visée automatique dans un cône devant), fend tout sur
--                         son passage et éclate en croix à l'arrivée ;
--   人 Souffle de l'homme : revient se fondre dans la poitrine du joueur, qui reprend vie et Qi ;
--   川 Trois cascades   : file droit devant et fait tomber trois lames de Qi sur son chemin ;
--   大 Grande onde      : monte au-dessus du joueur et s'abat au sol en une onde qui repousse et sonne ;
--   刺 Percée du dragon : part comme une flèche de Qi et transperce tout sur une longue ligne.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Calligraphy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Calligraphy"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Vfx = require(script.Parent:WaitForChild("Vfx"))
local Techniques = require(script.Parent:WaitForChild("Techniques"))

local Combos = {}

local INK = Color3.fromRGB(255, 214, 110) -- encre d'or
local QI = Color3.fromRGB(150, 225, 255)
local AIM_CONE = 35 -- degrés : une cible dans ce cône devant le joueur est visée automatiquement

local weaponsFolder: Instance
local feedbackRemote: RemoteEvent
local readyAt: { [Player]: { [string]: number } } = {}

local function debugPrint(text: string)
	if Calligraphy.DEBUG then
		print("[Calligraphie] " .. text)
	end
end

local function holdsBlade(player: Player): boolean
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:GetAttribute("Holder") == player.UserId then
			for _, part in weapon:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
					return true
				end
			end
		end
	end
	return false
end

local function neon(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = Vfx.folder
	return part
end

---------------------------------------------------------------------------
-- Le caractère-sort
---------------------------------------------------------------------------

-- Le caractère apparaît devant le joueur, lisible des deux côtés, avec un halo et une traînée.
local function castCharacter(root: BasePart, char: string, color: Color3): Part
	local board = neon("Calligraphie", Vector3.new(4, 4, 0.05), color)
	board.Transparency = 1
	local at = root.Position + root.CFrame.LookVector * 4 + Vector3.new(0, 1.5, 0)
	board.CFrame = CFrame.lookAt(at, at - root.CFrame.LookVector)

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 3
		gui.CanvasSize = Vector2.new(400, 400)
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = char
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.TextColor3 = color
		label.TextStrokeColor3 = Color3.fromRGB(90, 30, 10)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
	end

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 3
	light.Parent = board

	-- Traînée lumineuse derrière le caractère quand il vole.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = board
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = board
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Parent = board

	local anchor = Vfx.anchor("CalligraphieHalo", at, nil, 1)
	Vfx.burst(anchor, {
		Texture = Vfx.TEXTURES.Glow,
		Count = 1,
		Color = ColorSequence.new(color),
		Size = Vfx.grow(5, 7),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(0.5),
	})
	Sfx.play("Iai", board, 0.8)
	Debris:AddItem(board, 5) -- filet de sécurité
	return board
end

-- Le caractère s'efface en grandissant.
local function dissolve(board: Part)
	for _, gui in board:GetChildren() do
		local label = gui:IsA("SurfaceGui") and gui:FindFirstChildOfClass("TextLabel")
		if label then
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end
	TweenService:Create(board, TweenInfo.new(0.3), { Size = board.Size * 1.8 }):Play()
	Debris:AddItem(board, 0.35)
end

-- Fait voler le caractère jusqu'à `goal` à `speed` studs/s ; `onStep(position)` à chaque image.
-- Rend la main à l'arrivée.
local function fly(board: Part, goal: Vector3, speed: number, onStep: ((Vector3) -> ())?)
	local start = board.Position
	local distance = (goal - start).Magnitude
	local duration = math.max(distance / speed, 0.05)
	local facing = board.CFrame.Rotation
	local elapsed = 0
	while elapsed < duration and board.Parent do
		elapsed += RunService.Heartbeat:Wait()
		local position = start:Lerp(goal, math.min(elapsed / duration, 1))
		board.CFrame = CFrame.new(position) * facing
		if onStep then
			onStep(position)
		end
	end
end

-- Point visé : la cible la plus proche dans un cône devant le joueur, sinon droit devant à `range`.
local function aimPoint(root: BasePart, range: number): Vector3
	local forward = root.CFrame.LookVector
	local flatForward = (forward * Vector3.new(1, 0, 1)).Unit
	local best, bestDistance = nil, math.huge
	for _, model in Techniques.targetsNear(root.Position + forward * (range / 2), range / 2 + 4) do
		local targetRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if targetRoot and targetRoot:IsA("BasePart") then
			local offset = targetRoot.Position - root.Position
			local flat = offset * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.5 and flat.Magnitude <= range
				and math.deg(math.acos(math.clamp(flat.Unit:Dot(flatForward), -1, 1))) <= AIM_CONE
				and flat.Magnitude < bestDistance then
				best, bestDistance = targetRoot.Position, flat.Magnitude
			end
		end
	end
	return best or (root.Position + forward * range + Vector3.new(0, 1, 0))
end

-- Touche une seule fois chaque cible à moins de `radius` de `position`.
local function hitAround(player: Player, position: Vector3, radius: number, damage: number, already: { [Humanoid]: boolean })
	for humanoid, model in Techniques.targetsNear(position, radius) do
		if not already[humanoid] then
			already[humanoid] = true
			Techniques.strike(player, humanoid, model, damage)
			local part = model:FindFirstChild("HumanoidRootPart")
			if part and part:IsA("BasePart") then
				Sfx.play("Flesh", part, 1)
				local anchor = Vfx.anchor("ImpactSort", part.Position, nil, 1)
				Vfx.burst(anchor, {
					Texture = Vfx.TEXTURES.Burst,
					Count = 1,
					Color = ColorSequence.new(INK),
					Size = Vfx.grow(2, 5),
					Transparency = Vfx.fadeAfter(0.2),
					Lifetime = NumberRange.new(0.2),
				})
			end
		end
	end
end

---------------------------------------------------------------------------
-- Les sorts
---------------------------------------------------------------------------

local EFFECTS: { [string]: (Player, BasePart, Calligraphy.Combo) -> () } = {
	-- 十 : le caractère file vers la cible en fendant tout sur son passage, puis éclate en croix.
	Croix = function(player, root, combo)
		local board = castCharacter(root, combo.Char, INK)
		task.wait(0.25)
		local goal = aimPoint(root, combo.Range :: number)
		local hit: { [Humanoid]: boolean } = {}
		fly(board, goal, 45, function(position)
			hitAround(player, position, (combo.Width :: number) / 2, combo.Damage :: number, hit)
		end)
		-- Éclatement en croix à l'arrivée.
		for _, roll in { math.rad(45), math.rad(-45) } do
			local slash = neon("Croix", Vector3.new(7, 0.3, 0.3), QI)
			slash.Transparency = 0.1
			slash.CFrame = CFrame.lookAt(goal, goal + root.CFrame.LookVector) * CFrame.Angles(0, 0, roll)
			TweenService:Create(slash, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(10, 0.05, 0.05) }):Play()
			Debris:AddItem(slash, 0.4)
		end
		hitAround(player, goal, 5, combo.Damage :: number, hit)
		local anchor = Vfx.anchor("CroixImpact", goal, nil, 1.2)
		Vfx.burst(anchor, {
			Texture = Vfx.TEXTURES.ShockRing,
			Count = 1,
			Color = ColorSequence.new(INK),
			Size = Vfx.grow(2, 12),
			Transparency = Vfx.fadeAfter(0.3),
			Lifetime = NumberRange.new(0.4),
		})
		Vfx.flashLight(anchor, INK, 20, 5, 0.4)
		Sfx.play("PerfectParry", goal, 1.3)
		dissolve(board)
	end,

	-- 人 : le caractère revient se fondre dans la poitrine du joueur.
	Homme = function(player, root, combo)
		local green = Color3.fromRGB(170, 255, 190)
		local board = castCharacter(root, combo.Char, green)
		task.wait(0.35)
		fly(board, root.Position + Vector3.new(0, 1, 0), 12)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * (combo.Heal :: number))
		end
		Techniques.addQi(player, combo.Qi :: number)
		local anchor = Vfx.anchor("SouffleHomme", root.Position, nil, 1.5)
		Vfx.burst(anchor, {
			Texture = Vfx.TEXTURES.Glint,
			Count = 16,
			Color = ColorSequence.new(green, INK),
			Size = Vfx.grow(0.9, 0),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(3, 7),
			Spread = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, 6, 0),
		})
		Vfx.flashLight(anchor, green, 14, 3, 0.8)
		Sfx.play("LevelUp", root, 0.5)
		dissolve(board)
	end,

	-- 川 : le caractère file droit devant et fait tomber trois lames de Qi sur son chemin.
	Riviere = function(player, root, combo)
		local board = castCharacter(root, combo.Char, QI)
		task.wait(0.25)
		local forward = root.CFrame.LookVector
		local origin = root.Position
		local range = combo.Range :: number
		local dropped = 0
		local function cascade(at: Vector3)
			task.spawn(function()
				local blade = neon("Cascade", Vector3.new(0.3, 7, 1.4), QI)
				blade.Transparency = 0.15
				blade.CFrame = CFrame.lookAt(at + Vector3.new(0, 7, 0), at + Vector3.new(0, 7, 0) + forward)
				TweenService:Create(blade, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = CFrame.lookAt(at + Vector3.new(0, 1, 0), at + Vector3.new(0, 1, 0) + forward),
				}):Play()
				task.wait(0.12)
				hitAround(player, at, combo.Width :: number, combo.Damage :: number, {})
				local anchor = Vfx.anchor("CascadeImpact", at, nil, 1)
				Vfx.burst(anchor, {
					Texture = Vfx.TEXTURES.Burst,
					Count = 1,
					Color = ColorSequence.new(QI),
					Size = Vfx.grow(3, 7),
					Transparency = Vfx.fadeAfter(0.2),
					Lifetime = NumberRange.new(0.25),
				})
				Sfx.play("Metal", at, 1)
				TweenService:Create(blade, TweenInfo.new(0.2), { Transparency = 1 }):Play()
				Debris:AddItem(blade, 0.25)
			end)
		end
		fly(board, origin + forward * range + Vector3.new(0, 1.5, 0), 30, function(position)
			local travelled = ((position - origin) * Vector3.new(1, 0, 1)).Magnitude
			while dropped < 3 and travelled >= range * (dropped + 1) / 3 - 0.05 do
				dropped += 1
				cascade(origin + forward * (range * dropped / 3))
			end
		end)
		-- Les trois lames tombent toujours, même si le vol a été écourté.
		while dropped < 3 do
			dropped += 1
			cascade(origin + forward * (range * dropped / 3))
		end
		dissolve(board)
	end,

	-- 大 : le caractère monte au-dessus du joueur puis s'abat en une onde qui repousse et sonne.
	Grand = function(player, root, combo)
		local board = castCharacter(root, combo.Char, INK)
		task.wait(0.2)
		fly(board, root.Position + Vector3.new(0, 7, 0), 25)
		fly(board, root.Position - Vector3.new(0, 2, 0), 60)
		local center = root.Position
		for humanoid, model in Techniques.targetsNear(center, combo.Radius :: number) do
			Techniques.strike(player, humanoid, model, combo.Damage :: number)
			model:SetAttribute("StunnedUntil", os.clock() + (combo.Stun :: number))
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if targetRoot and targetRoot:IsA("BasePart") and not targetRoot.Anchored then
				local away = (targetRoot.Position - center) * Vector3.new(1, 0, 1)
				local push = if away.Magnitude > 0.1 then away.Unit else root.CFrame.LookVector
				targetRoot.AssemblyLinearVelocity = push * 45 + Vector3.new(0, 20, 0)
			end
		end
		local anchor = Vfx.anchor("GrandeOnde", center, nil, 1.5)
		Vfx.burst(anchor, {
			Texture = Vfx.TEXTURES.ShockRing,
			Count = 1,
			Color = ColorSequence.new(INK),
			Size = Vfx.grow(2, (combo.Radius :: number) * 2.2),
			Transparency = Vfx.fadeAfter(0.4),
			Lifetime = NumberRange.new(0.5),
		})
		Vfx.burst(anchor, {
			Texture = Vfx.TEXTURES.Rays,
			Count = 1,
			Color = ColorSequence.new(INK),
			Size = Vfx.grow(3, 18),
			Transparency = Vfx.fadeAfter(0.2),
			Lifetime = NumberRange.new(0.4),
		})
		Vfx.flashLight(anchor, INK, 30, 6, 0.5)
		Sfx.play("Block", center, 1.5)
		dissolve(board)
	end,

	-- 刺 : le caractère part comme une flèche de Qi et transperce tout sur une longue ligne.
	Percee = function(player, root, combo)
		local board = castCharacter(root, combo.Char, QI)
		task.wait(0.2)
		local forward = root.CFrame.LookVector
		local range = combo.Range :: number
		local start = board.Position
		local goal = start + forward * range
		local hit: { [Humanoid]: boolean } = {}
		Sfx.play("PerfectParry", root, 1.2)
		fly(board, goal, 80, function(position)
			hitAround(player, position, (combo.Width :: number) / 2 + 0.5, combo.Damage :: number, hit)
		end)
		-- Le sillage de la percée reste un instant dans l'air.
		local beam = neon("Percee", Vector3.new(0.5, 0.5, range), QI)
		beam.Transparency = 0.2
		local middle = (start + goal) / 2
		beam.CFrame = CFrame.lookAt(middle, goal)
		TweenService:Create(beam, TweenInfo.new(0.4), { Transparency = 1, Size = Vector3.new(0.05, 0.05, range) }):Play()
		Debris:AddItem(beam, 0.45)
		dissolve(board)
	end,
}

local function onCombo(player: Player, comboId: any, side: any)
	local combo = if typeof(comboId) == "string" then Calligraphy.ById[comboId] else nil
	local effect = combo and EFFECTS[combo.Id]
	local root = Techniques.rootOf(player)
	if not combo or not effect then
		debugPrint("combo inconnu : " .. tostring(comboId))
		return
	end
	if not root then
		debugPrint("sort " .. combo.Id .. " refusé : joueur sans corps")
		return
	end
	if not holdsBlade(player) then
		debugPrint("sort " .. combo.Id .. " refusé : aucune arme à lame en main")
		return
	end
	local cooldowns = readyAt[player]
	if not cooldowns then
		cooldowns = {}
		readyAt[player] = cooldowns
	end
	if os.clock() < (cooldowns[combo.Id] or 0) then
		debugPrint("sort " .. combo.Id .. " refusé : en recharge")
		return
	end
	cooldowns[combo.Id] = os.clock() + combo.Cooldown
	player:SetAttribute("Cooldown" .. combo.Id, workspace:GetServerTimeNow() + combo.Cooldown)

	debugPrint("sort " .. combo.Id .. " lancé")
	if side == "Left" or side == "Right" then
		feedbackRemote:FireClient(player, side, 1, 0.25)
	end
	task.spawn(effect, player, root, combo)
end

function Combos.init(weapons: Instance, feedback: RemoteEvent, remote: RemoteEvent)
	weaponsFolder = weapons
	feedbackRemote = feedback
	remote.OnServerEvent:Connect(onCombo)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return Combos

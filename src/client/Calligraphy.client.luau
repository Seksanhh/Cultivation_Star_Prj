-- Client : reconnaît les traits de lame du joueur et les combos de calligraphie (shared/Calligraphy.luau).
-- Un trait est un geste rapide de la pointe ; sa direction est lue dans le repère du regard du joueur
-- (droite, haut, avant), son propre déplacement retiré. Quand les derniers traits forment un caractère,
-- le combo est envoyé au serveur, qui vérifie la recharge et applique l'effet.
--
-- Chaque trait reconnu s'affiche devant les yeux (竖 横 丿 ㇏ 点), en encre d'or ; un combo en
-- recharge s'affiche en gris. Avec Calligraphy.DEBUG, chaque trait s'écrit aussi dans la Sortie.

local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")

local Calligraphy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Calligraphy"))

local comboRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combo") :: RemoteEvent
local weaponsFolder = workspace:WaitForChild("Weapons")
local player = Players.LocalPlayer

local END_SPEED_RATIO = 0.45 -- le trait s'arrête quand la pointe retombe sous cette part du seuil
local END_DELAY = 0.08 -- ... pendant au moins ce temps (s)
-- Un geste qui ralentit un instant puis repart dans le même sens reste un seul trait :
-- deux morceaux séparés de moins de MERGE_TIME et allant dans le même sens sont recollés.
local MERGE_TIME = 0.15
-- Au-delà, la pointe n'a pas été portée par un geste mais déplacée d'un coup (retour de la lame
-- après un coup au clavier, rotation par cran de la vue) : le trait en cours s'arrête là.
local SNAP_SPEED = 120

local INK = Color3.fromRGB(255, 214, 110)
local GREY = Color3.fromRGB(170, 170, 170)

type Stroke = {
	start: Vector3, -- position de la pointe par rapport au corps, au début du trait
	last: Vector3,
	slowSince: number?,
}

type Track = {
	blade: BasePart,
	lastTip: Vector3?,
	stroke: Stroke?,
}

local tracks: { [string]: Track } = {}
local history: { { kind: string, time: number } } = {}
-- Dernier morceau de geste terminé (reconnu ou non), pour recoller un trait coupé en deux.
local lastPiece: { side: string, time: number, displacement: Vector3, added: boolean }? = nil

---------------------------------------------------------------------------
-- Affichage des traits devant les yeux
---------------------------------------------------------------------------

local board = Instance.new("BillboardGui")
board.Name = "TraitsCalligraphie"
board.Size = UDim2.fromScale(3.2, 0.9)
board.StudsOffset = Vector3.new(0, -0.9, -3) -- un peu sous le regard, à 3 studs devant
board.AlwaysOnTop = true
board.LightInfluence = 0
board.Enabled = false
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.TextScaled = true
label.Font = Enum.Font.SourceSansBold
label.TextColor3 = INK
label.TextStrokeColor3 = Color3.fromRGB(60, 20, 5)
label.TextStrokeTransparency = 0.3
label.Parent = board
board.Parent = player:WaitForChild("PlayerGui")

local hideToken = 0
local function show(text: string, color: Color3, duration: number)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	board.Adornee = head
	label.Text = text
	label.TextColor3 = color
	board.Enabled = true
	hideToken += 1
	local token = hideToken
	task.delay(duration, function()
		if hideToken == token then
			board.Enabled = false
		end
	end)
end

local function showHistory()
	local names = {}
	for _, entry in history do
		table.insert(names, Calligraphy.STROKE_NAMES[entry.kind] or entry.kind)
	end
	show(table.concat(names, " · "), INK, Calligraphy.MAX_GAP)
end

---------------------------------------------------------------------------
-- Reconnaissance
---------------------------------------------------------------------------

local function pulse(side: string, strength: number)
	if not VRService.VREnabled then
		return
	end
	local motor = if side == "Left" then Enum.VibrationMotor.LeftHand else Enum.VibrationMotor.RightHand
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, motor, strength)
	end)
	task.delay(0.05, function()
		pcall(function()
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, motor, 0)
		end)
	end)
end

local function heldBlade(side: string): BasePart?
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:GetAttribute("Holder") == player.UserId and weapon:GetAttribute("HolderHand") == side then
			local best: BasePart? = nil
			for _, part in weapon:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("IsBlade") and (not best or part.Size.Y > best.Size.Y) then
					best = part
				end
			end
			return best
		end
	end
	return nil
end

-- Repère du regard, à plat : droite, haut, avant.
local function viewAxes(): (Vector3, Vector3, Vector3)
	local look = workspace.CurrentCamera:GetRenderCFrame().LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = if forward.Magnitude > 0.05 then forward.Unit else Vector3.zAxis
	local right = forward:Cross(Vector3.yAxis).Unit
	return right, Vector3.yAxis, forward
end

local function onCooldown(comboId: string): boolean
	local readyAt = player:GetAttribute("Cooldown" .. comboId)
	return typeof(readyAt) == "number" and readyAt > workspace:GetServerTimeNow()
end

local function finishStroke(side: string, stroke: Stroke)
	local displacement = stroke.last - stroke.start
	local now = os.clock()
	-- Suite d'un trait coupé en deux par un bref ralentissement : on recolle les deux morceaux.
	local previous = lastPiece
	local merged = false
	if previous and previous.side == side and now - previous.time <= MERGE_TIME and displacement:Dot(previous.displacement) > 0 then
		displacement += previous.displacement
		merged = true
		if previous.added and #history > 0 then
			table.remove(history) -- le morceau déjà compté est remplacé par le trait entier
		end
	end
	local right, up, forward = viewAxes()
	local x, y, z = displacement:Dot(right), displacement:Dot(up), displacement:Dot(forward)
	local kind = Calligraphy.classify(x, y, z)
	if Calligraphy.DEBUG then
		print(string.format("[Calligraphie] trait %s%s  (droite %.1f, haut %.1f, avant %.1f, longueur %.1f)",
			kind or "refusé", if merged then " (recollé)" else "", x, y, z, displacement.Magnitude))
	end
	lastPiece = { side = side, time = now, displacement = displacement, added = kind ~= nil }
	if not kind then
		if merged then
			showHistory()
		end
		return
	end
	-- Un trait trop tardif commence un nouveau caractère.
	if #history > 0 and now - history[#history].time > Calligraphy.MAX_GAP then
		table.clear(history)
	end
	table.insert(history, { kind = kind, time = now })
	while #history > 6 do
		table.remove(history, 1)
	end
	pulse(side, 0.2)
	showHistory()

	local kinds = {}
	for _, entry in history do
		table.insert(kinds, entry.kind)
	end
	local combo = Calligraphy.match(kinds)
	if combo then
		table.clear(history)
		if onCooldown(combo.Id) then
			show(combo.Char .. " recharge…", GREY, 0.8)
		else
			show(combo.Char .. " " .. combo.Name, INK, 1.2)
			comboRemote:FireServer(combo.Id, side)
		end
		if Calligraphy.DEBUG then
			print("[Calligraphie] combo " .. combo.Id .. (if onCooldown(combo.Id) then " (en recharge)" else ""))
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	if dt <= 0 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	for _, side in { "Left", "Right" } do
		local blade = heldBlade(side)
		local track = tracks[side]
		if not blade then
			tracks[side] = nil
			continue
		end
		if not track or track.blade ~= blade then
			track = { blade = blade, lastTip = nil, stroke = nil }
			tracks[side] = track
		end

		-- Pointe de la lame par rapport au corps : marcher ne trace pas de trait.
		local tip = blade.CFrame * Vector3.new(0, blade.Size.Y / 2, 0) - root.Position
		local last = track.lastTip
		track.lastTip = tip
		if not last then
			continue
		end
		local speed = (tip - last).Magnitude / dt

		local stroke = track.stroke
		if speed > SNAP_SPEED then
			-- Saut de la lame : le trait en cours se termine juste avant.
			if stroke then
				track.stroke = nil
				finishStroke(side, stroke)
			end
			continue
		end
		if not stroke then
			if speed >= Calligraphy.STROKE_SPEED then
				track.stroke = { start = last, last = tip, slowSince = nil }
			end
		else
			stroke.last = tip
			if speed < Calligraphy.STROKE_SPEED * END_SPEED_RATIO then
				local now = os.clock()
				stroke.slowSince = stroke.slowSince or now
				if now - (stroke.slowSince :: number) >= END_DELAY then
					track.stroke = nil
					finishStroke(side, stroke)
				end
			else
				stroke.slowSince = nil
			end
		end
	end
end)

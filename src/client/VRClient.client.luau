-- Client : pilote les mains avec les manettes VR, saisit les armes et détecte les coups.
-- Sans casque, un mode de test clavier/souris prend le relais :
--   E = saisir/lâcher (main droite), Q = saisir/lâcher (main gauche), clic gauche = frapper.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local HapticService = game:GetService("HapticService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local grabRemote = remotes:WaitForChild("Grab") :: RemoteEvent
local releaseRemote = remotes:WaitForChild("Release") :: RemoteEvent
local hitRemote = remotes:WaitForChild("Hit") :: RemoteEvent

local handsFolder = workspace:WaitForChild("VRHands")
local weaponsFolder = workspace:WaitForChild("Weapons")

local player = Players.LocalPlayer
player.CameraMode = Enum.CameraMode.LockFirstPerson

local SIDES = { "Left", "Right" }
local SWING_TIME = 0.28 -- durée du coup en mode clavier/souris
local MAX_PLAUSIBLE_SPEED = 400 -- au-delà, c'est une téléportation de l'arme, pas un coup

---------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------

local wantHold: { [string]: boolean } = { Left = false, Right = false }
local lastReleaseSent: { [string]: number } = { Left = 0, Right = 0 }

-- Seconde main posée sur une arme à deux mains.
local support: { side: string, weapon: Model, sign: number }? = nil

local swingStart: number? = nil
local lastTips: { [BasePart]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local lastHit: { [Humanoid]: number } = setmetatable({}, { __mode = "k" }) :: any
local peakSpeeds: { [BasePart]: { speed: number, time: number } } = setmetatable({}, { __mode = "k" }) :: any
local PEAK_WINDOW = 0.15 -- durée (s) pendant laquelle la vitesse de pointe d'un geste reste valable

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local highlights: { [string]: Highlight } = {}
for _, side in SIDES do
	local highlight = Instance.new("Highlight")
	highlight.Name = "GrabHint" .. side
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.Enabled = false
	highlight.Parent = workspace.CurrentCamera -- local à ce client, et dans le Workspace pour être affiché
	highlights[side] = highlight
end

---------------------------------------------------------------------------
-- Utilitaires
---------------------------------------------------------------------------

local function otherSide(side: string): string
	return if side == "Left" then "Right" else "Left"
end

local function getHeldWeapon(side: string): Model?
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:GetAttribute("Holder") == player.UserId and weapon:GetAttribute("HolderHand") == side then
			return weapon :: Model
		end
	end
	return nil
end

-- Distance entre un point et le manche d'une arme.
local function distanceToHandle(weapon: Model, position: Vector3): number
	local handle = weapon.PrimaryPart
	if not handle then
		return math.huge
	end
	local localPoint = handle.CFrame:PointToObjectSpace(position)
	local half = handle.Size.Y / 2
	local closest = Vector3.new(0, math.clamp(localPoint.Y, -half, half), 0)
	return (localPoint - closest).Magnitude
end

local function findNearestFreeWeapon(position: Vector3): (Model?, number)
	local nearest: Model? = nil
	local nearestDistance = Config.GRAB_RADIUS
	for _, weapon in weaponsFolder:GetChildren() do
		if weapon:IsA("Model") and not weapon:GetAttribute("Holder") then
			local distance = distanceToHandle(weapon, position)
			if distance <= nearestDistance then
				nearest = weapon
				nearestDistance = distance
			end
		end
	end
	return nearest, nearestDistance
end

-- Position et orientation d'une manette dans le monde.
local function controllerCFrame(side: string): CFrame
	local camera = workspace.CurrentCamera
	if VRService.VREnabled then
		local userCFrame = if side == "Left" then Enum.UserCFrame.LeftHand else Enum.UserCFrame.RightHand
		local tracked = VRService:GetUserCFrame(userCFrame)
		return camera.CFrame * CFrame.new(tracked.Position * camera.HeadScale) * tracked.Rotation
	end

	-- Mode clavier/souris : les mains flottent devant la caméra.
	local x = if side == "Left" then -0.9 else 0.9
	local base = camera.CFrame * CFrame.new(x, -0.9, -1.6)
	if side == "Right" and swingStart then
		local t = (os.clock() - swingStart) / SWING_TIME
		if t >= 1 then
			swingStart = nil
		else
			base *= CFrame.Angles(math.rad(40 - 130 * t), 0, 0)
		end
	end
	return base
end

local function pulse(side: string, strength: number, duration: number?)
	if not VRService.VREnabled then
		return
	end
	local motor = if side == "Left" then Enum.VibrationMotor.LeftHand else Enum.VibrationMotor.RightHand
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, motor, strength)
	end)
	task.delay(duration or 0.08, function()
		pcall(function()
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, motor, 0)
		end)
	end)
end

-- Le serveur fait vibrer la main qui vient de bloquer ou de parer un coup.
local feedbackRemote = remotes:WaitForChild("Feedback") :: RemoteEvent
feedbackRemote.OnClientEvent:Connect(function(side: any, strength: any, duration: any)
	if (side == "Left" or side == "Right") and typeof(strength) == "number" then
		pulse(side, strength, if typeof(duration) == "number" then duration else nil)
	end
end)

local function findHumanoid(part: Instance): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

---------------------------------------------------------------------------
-- Saisir / lâcher
---------------------------------------------------------------------------

local function tryGrab(side: string)
	if getHeldWeapon(side) then
		return
	end
	local handPosition = controllerCFrame(side).Position
	local nearest, nearestDistance = findNearestFreeWeapon(handPosition)

	-- La seconde main peut guider une arme à deux mains déjà tenue.
	local other = otherSide(side)
	local otherWeapon = getHeldWeapon(other)
	if otherWeapon and otherWeapon.PrimaryPart then
		local def = Config.Weapons[otherWeapon:GetAttribute("WeaponType")]
		local distance = distanceToHandle(otherWeapon, handPosition)
		if def and def.TwoHanded and distance <= Config.GRAB_RADIUS and (not nearest or distance <= nearestDistance) then
			local primaryPosition = controllerCFrame(other).Position
			local bladeDirection = otherWeapon.PrimaryPart.CFrame.UpVector
			local sign = if (handPosition - primaryPosition):Dot(bladeDirection) >= 0 then 1 else -1
			support = { side = side, weapon = otherWeapon, sign = sign }
			pulse(side, 0.3)
			return
		end
	end

	if nearest then
		grabRemote:FireServer(nearest, side)
		pulse(side, 0.4)
	end
end

local function letGo(side: string)
	wantHold[side] = false
	if support and support.side == side then
		support = nil
		return
	end
	if getHeldWeapon(side) then
		lastReleaseSent[side] = os.clock()
		releaseRemote:FireServer(side)
	end
end

local function isHolding(side: string): boolean
	return getHeldWeapon(side) ~= nil or (support ~= nil and support.side == side)
end

local function press(side: string, forceToggle: boolean)
	if (Config.GRIP_TOGGLE or forceToggle) and isHolding(side) then
		letGo(side)
		return
	end
	wantHold[side] = true
	tryGrab(side)
end

local GRIP_KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.ButtonL1] = "Left",
	[Enum.KeyCode.ButtonR1] = "Right",
}

UserInputService.InputBegan:Connect(function(input, processed)
	local side = GRIP_KEYS[input.KeyCode]
	if side then
		press(side, false)
		return
	end
	if processed or VRService.VREnabled then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		press("Right", true)
	elseif input.KeyCode == Enum.KeyCode.Q then
		press("Left", true)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		swingStart = os.clock()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local side = GRIP_KEYS[input.KeyCode]
	if side and not Config.GRIP_TOGGLE then
		letGo(side)
	end
end)

---------------------------------------------------------------------------
-- Détection des coups
---------------------------------------------------------------------------

local function checkHits(weapon: Model, side: string, dt: number, rootVelocity: Vector3)
	local def = Config.Weapons[weapon:GetAttribute("WeaponType")]
	if not def then
		return
	end
	for _, part in weapon:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("IsBlade") then
			local tip = part.CFrame * Vector3.new(0, part.Size.Y / 2, 0)
			local last = lastTips[part]
			lastTips[part] = tip
			if last and dt > 0 then
				-- Vitesse de la lame par rapport au joueur : marcher ne compte pas comme un coup.
				local speed = ((tip - last) / dt - rootVelocity).Magnitude

				-- On retient la vitesse de pointe du geste sur un court instant : les dégâts reflètent
				-- l'élan du coup, pas seulement l'image précise où la lame entre dans la cible.
				local now = os.clock()
				local peak = peakSpeeds[part]
				if speed <= MAX_PLAUSIBLE_SPEED and (not peak or speed >= peak.speed or now - peak.time > PEAK_WINDOW) then
					peak = { speed = speed, time = now }
					peakSpeeds[part] = peak
				end
				speed = if peak and now - peak.time <= PEAK_WINDOW then peak.speed else 0

				if speed >= def.MinSpeed then
					for _, hit in workspace:GetPartsInPart(part, overlapParams) do
						local humanoid = findHumanoid(hit)
						if humanoid and humanoid.Health > 0 then
							local now = os.clock()
							local previous = lastHit[humanoid]
							if not previous or now - previous >= Config.HIT_COOLDOWN then
								lastHit[humanoid] = now
								hitRemote:FireServer(weapon, hit, speed)
								pulse(side, math.clamp(speed / Config.REFERENCE_SPEED, 0.3, 1))
							end
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Vibration quand une arme tenue heurte quelque chose de solide
---------------------------------------------------------------------------

local touchConnections: { [Model]: { RBXScriptConnection } } = {}
local lastBump = 0

local function watchCollisions(weapon: Model)
	if touchConnections[weapon] then
		return
	end
	local connections = {}
	touchConnections[weapon] = connections
	for _, item in weapon:GetChildren() do
		if item:IsA("BasePart") then
			local part = item
			table.insert(connections, part.Touched:Connect(function(other)
				local now = os.clock()
				local side = weapon:GetAttribute("HolderHand")
				if now - lastBump < 0.1 or not side then
					return
				end
				if other:IsDescendantOf(weapon) or not other.CanCollide or other.CollisionGroup == "Bodies" then
					return
				end
				local speed = part:GetVelocityAtPosition(part.Position).Magnitude
				if speed < 3 then
					return
				end
				lastBump = now
				pulse(side, math.clamp(speed / Config.REFERENCE_SPEED, 0.2, 1))
			end))
		end
	end
end

-- Coupe l'écoute des armes que ce joueur ne tient plus.
local function unwatchReleased()
	for weapon, connections in touchConnections do
		if weapon:GetAttribute("Holder") ~= player.UserId then
			for _, connection in connections do
				connection:Disconnect()
			end
			touchConnections[weapon] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Boucle principale
---------------------------------------------------------------------------

-- En vue à la première personne, la caméra de Roblox rend le personnage invisible à chaque image.
-- On réaffiche le corps juste après elle ; la tête et les accessoires restent cachés pour ne pas boucher la vue.
local function showAvatar()
	local character = player.Character
	if not character then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "Head" and child.Name ~= "HumanoidRootPart" then
			child.LocalTransparencyModifier = 0
		end
	end
end

local function update(dt: number)
	if Config.SHOW_AVATAR then
		showAvatar()
	end

	local hands = handsFolder:FindFirstChild(tostring(player.UserId))
	if not hands then
		for _, side in SIDES do
			highlights[side].Enabled = false
		end
		return
	end

	local targets: { [string]: CFrame } = {
		Left = controllerCFrame("Left"),
		Right = controllerCFrame("Right"),
	}

	-- Arme à deux mains : la lame s'aligne sur la droite qui relie les deux mains.
	if support then
		local primarySide = otherSide(support.side)
		if getHeldWeapon(primarySide) ~= support.weapon then
			support = nil
		else
			local primaryPosition = targets[primarySide].Position
			local direction = (targets[support.side].Position - primaryPosition) * support.sign
			if direction.Magnitude > 0.2 then
				direction = direction.Unit
				local right = targets[primarySide].RightVector
				right -= direction * right:Dot(direction)
				if right.Magnitude > 0.05 then
					local handleRotation = CFrame.fromMatrix(Vector3.zero, right.Unit, direction)
					targets[primarySide] = CFrame.new(primaryPosition) * handleRotation * Config.GRIP_ROTATION:Inverse()
				end
			end
		end
	end

	-- Envoie les cibles aux contraintes des mains (la physique est simulée par ce client).
	for _, side in SIDES do
		local hand = hands:FindFirstChild(side)
		local alignPosition = hand and hand:FindFirstChild("AlignPosition")
		local alignOrientation = hand and hand:FindFirstChild("AlignOrientation")
		if alignPosition and alignPosition:IsA("AlignPosition") and alignOrientation and alignOrientation:IsA("AlignOrientation") then
			alignPosition.Position = targets[side].Position
			alignOrientation.CFrame = targets[side].Rotation
		end
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local rootVelocity = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.zero

	local ignored: { Instance } = { weaponsFolder, handsFolder }
	if character then
		table.insert(ignored, character)
	end
	overlapParams.FilterDescendantsInstances = ignored
	unwatchReleased()

	for _, side in SIDES do
		local weapon = getHeldWeapon(side)
		local highlight = highlights[side]
		if weapon then
			highlight.Enabled = false
			watchCollisions(weapon)
			if not wantHold[side] and os.clock() - lastReleaseSent[side] > 0.3 then
				-- L'arme est arrivée dans la main après que le joueur a relâché : on la rend.
				lastReleaseSent[side] = os.clock()
				releaseRemote:FireServer(side)
			end
			checkHits(weapon, side, dt, rootVelocity)
		else
			-- Contour blanc sur l'arme que cette main peut saisir.
			local nearest = if support and support.side == side then nil else findNearestFreeWeapon(targets[side].Position)
			highlight.Adornee = nearest
			highlight.Enabled = nearest ~= nil
		end
	end
end

RunService:BindToRenderStep("VRMelee", Enum.RenderPriority.Camera.Value + 1, update)

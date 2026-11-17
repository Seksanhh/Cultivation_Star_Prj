-- Client : qinggong (Config.QINGGONG) — double saut, course sur les murs, vol plané.
-- Le personnage du joueur est simulé par son client : les mouvements sont appliqués ici, sans délai,
-- et le serveur est prévenu pour dépenser le Qi et montrer les effets aux autres joueurs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local settings = Config.QINGGONG

local qinggongRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Qinggong") :: RemoteEvent
local player = Players.LocalPlayer

local airJumpUsed = false
local lastJump = 0
local wall: { normal: Vector3, started: number }? = nil
local wallCooldownUntil = 0
local drain = { WallRun = 0, Glide = 0 }
local lastDrainSent = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function qi(): number
	return player:GetAttribute("Qi") or 0
end

local function jumpHeld(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
end

local function body(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function airborne(humanoid: Humanoid): boolean
	return humanoid.FloorMaterial == Enum.Material.Air
end

-- Mur à gauche ou à droite du corps (surface à peu près verticale), ou nil.
local function findWall(root: BasePart): RaycastResult?
	local ignored: { Instance } = {}
	for _, name in { "Weapons", "VRHands", "Effets", "Enemies", "Projectiles", "Scabbards" } do
		local found = workspace:FindFirstChild(name)
		if found then
			table.insert(ignored, found)
		end
	end
	if player.Character then
		table.insert(ignored, player.Character)
	end
	rayParams.FilterDescendantsInstances = ignored
	for _, direction in { root.CFrame.RightVector, -root.CFrame.RightVector } do
		local result = workspace:Raycast(root.Position, direction * settings.WALL_RUN_DISTANCE, rayParams)
		if result and math.abs(result.Normal.Y) < 0.3 and result.Instance.CanCollide then
			return result
		end
	end
	return nil
end

UserInputService.JumpRequest:Connect(function()
	if not settings.ENABLED then
		return
	end
	local humanoid, root = body()
	if not humanoid or not root or not airborne(humanoid) then
		return
	end
	-- La demande de saut se répète tant que la touche est enfoncée : un seul effet par appui.
	local now = os.clock()
	if now - lastJump < 0.3 then
		return
	end
	lastJump = now
	local velocity = root.AssemblyLinearVelocity

	if wall then
		-- Saut depuis le mur : repoussé du mur, vers le haut, en gardant l'élan le long du mur.
		local along = velocity - wall.normal * velocity:Dot(wall.normal)
		local flat = Vector3.new(along.X, 0, along.Z)
		root.AssemblyLinearVelocity = wall.normal * settings.WALL_KICK + flat + Vector3.new(0, settings.WALL_KICK_UP, 0)
		wall = nil
		wallCooldownUntil = now + 0.35
		airJumpUsed = false -- le mur rend le double saut
		qinggongRemote:FireServer("WallKick", 0)
		return
	end
	if not airJumpUsed and qi() >= settings.DOUBLE_JUMP_QI then
		airJumpUsed = true
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, settings.DOUBLE_JUMP_POWER, velocity.Z)
		qinggongRemote:FireServer("DoubleJump", settings.DOUBLE_JUMP_QI)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not settings.ENABLED then
		return
	end
	local humanoid, root = body()
	if not humanoid or not root then
		wall = nil
		return
	end
	local now = os.clock()
	if not airborne(humanoid) then
		airJumpUsed = false
		wall = nil
	else
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)

		-- Course sur un mur.
		if wall and (now - wall.started > settings.WALL_RUN_MAX_TIME or qi() <= 0) then
			wall = nil
			wallCooldownUntil = now + 0.5
		end
		if not wall and now >= wallCooldownUntil and flat.Magnitude >= settings.WALL_RUN_MIN_SPEED and qi() > 2 then
			local hit = findWall(root)
			if hit then
				wall = { normal = hit.Normal, started = now }
			end
		end
		if wall then
			local hit = findWall(root)
			if not hit then
				wall = nil
			else
				wall.normal = hit.Normal
				-- On court le long du mur, collé à lui, et on monte un peu au début de la course.
				local along = flat - hit.Normal * flat:Dot(hit.Normal)
				local lift = math.max(0, 1 - (now - wall.started) / settings.WALL_RUN_MAX_TIME) * 6
				root.AssemblyLinearVelocity = along - hit.Normal * 2 + Vector3.new(0, math.max(velocity.Y * 0.3, lift), 0)
				drain.WallRun += settings.WALL_RUN_QI_PER_SECOND * dt
			end
		end

		-- Vol plané : saut enfoncé en tombant.
		if not wall and velocity.Y < -settings.GLIDE_FALL_SPEED and jumpHeld() and qi() > 0 then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, -settings.GLIDE_FALL_SPEED, velocity.Z)
			drain.Glide += settings.GLIDE_QI_PER_SECOND * dt
		end
	end

	-- Le Qi dépensé en continu est envoyé au serveur par paquets.
	if now - lastDrainSent >= 0.25 then
		lastDrainSent = now
		for kind, amount in drain do
			if amount > 0 then
				qinggongRemote:FireServer(kind, amount)
				drain[kind] = 0
			end
		end
	end
end)

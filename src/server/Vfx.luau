-- Outils d'effets visuels partagés : textures du Creator Store, points d'ancrage invisibles et
-- gerbes de particules émises d'un coup. Les effets sont créés sur le serveur, donc vus par tous.
--
-- Textures d'effets visuels du Creator Store de Roblox (packs de VFX gratuits, images publiques).
-- Seules les images sont reprises : les émetteurs sont construits ici, sans script venu de la Toolbox.
-- Pour en changer une, colle le numéro d'une autre image (Toolbox → Images, ou propriété Texture
-- d'un ParticleEmitter d'un pack de VFX).

local Debris = game:GetService("Debris")

local Vfx = {}

Vfx.TEXTURES = {
	Streak = "rbxassetid://7216979807", -- trait lumineux fin : étincelle étirée dans le sens de sa course
	Glint = "rbxassetid://8037777212", -- étoile à quatre branches : reflet sur le métal au point de choc
	Burst = "rbxassetid://11536435403", -- éclatement en pointes : impact
	ShockRing = "rbxassetid://14412529554", -- anneau rayonnant : onde de choc
	Rays = "rbxassetid://1084975295", -- rayons partant du centre
	Glow = "rbxassetid://867619398", -- halo doux : éclair de lumière
	Ring = "rbxassetid://1084952073", -- anneau net
}

local folder = Instance.new("Folder")
folder.Name = "Effets"
folder.Parent = workspace
Vfx.folder = folder

-- Point d'ancrage invisible des effets, orienté vers `facing` s'il est donné. Détruit après `life` secondes.
function Vfx.anchor(name: string, position: Vector3, facing: Vector3?, life: number?): Part
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = if facing and facing.Magnitude > 0.1
		then CFrame.lookAt(position, position + facing.Unit)
		else CFrame.new(position)
	anchor.Parent = folder
	if life then
		Debris:AddItem(anchor, life)
	end
	return anchor
end

export type Burst = {
	Texture: string,
	Count: number,
	Color: ColorSequence,
	Size: NumberSequence,
	Transparency: NumberSequence?,
	Lifetime: NumberRange,
	Speed: NumberRange?,
	Spread: Vector2?,
	Orientation: Enum.ParticleOrientation?,
	Rotation: NumberRange?,
	RotSpeed: NumberRange?,
	Drag: number?,
	Acceleration: Vector3?,
	Squash: NumberSequence?,
	ZOffset: number?,
	Direction: Enum.NormalId?,
	LightEmission: number?,
}

-- Émet d'un coup `Count` particules texturées depuis le point d'ancrage.
function Vfx.burst(anchor: BasePart, def: Burst)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Texture = def.Texture
	emitter.Color = def.Color
	emitter.Size = def.Size
	emitter.Transparency = def.Transparency or NumberSequence.new(0, 1)
	emitter.Lifetime = def.Lifetime
	emitter.Speed = def.Speed or NumberRange.new(0)
	emitter.SpreadAngle = def.Spread or Vector2.zero
	emitter.Orientation = def.Orientation or Enum.ParticleOrientation.FacingCamera
	emitter.Rotation = def.Rotation or NumberRange.new(0, 360)
	emitter.RotSpeed = def.RotSpeed or NumberRange.new(0)
	emitter.Drag = def.Drag or 0
	emitter.Acceleration = def.Acceleration or Vector3.zero
	emitter.Squash = def.Squash or NumberSequence.new(0)
	emitter.ZOffset = def.ZOffset or 0
	emitter.EmissionDirection = def.Direction or Enum.NormalId.Top
	emitter.LightEmission = def.LightEmission or 1
	emitter.LightInfluence = 0
	emitter.Brightness = 2
	emitter.Parent = anchor
	emitter:Emit(def.Count)
end

-- Taille qui part de `from` et finit à `to`.
function Vfx.grow(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

-- Transparence : visible tout de suite, puis s'efface à partir de `hold` (fraction de la vie).
function Vfx.fadeAfter(hold: number): NumberSequence
	if hold <= 0 then
		return NumberSequence.new(0, 1)
	end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(hold, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- Lumière ponctuelle qui s'éteint en `time` secondes.
function Vfx.flashLight(anchor: BasePart, color: Color3, range: number, brightness: number, time: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = anchor
	game:GetService("TweenService"):Create(light, TweenInfo.new(time), { Brightness = 0 }):Play()
end

return Vfx

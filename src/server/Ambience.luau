-- Ciel et éclairage : coucher de soleil doré sur le temple, brume chaude, nuages volumétriques,
-- reflets du ciel sur les matériaux et légers effets de post-traitement.
--
-- Le moteur d'éclairage « Future » (ombres douces des lanternes, reflets) ne peut pas être choisi
-- par un script : il est réglé dans default.project.json (Lighting.Technology), que Rojo applique.
--
-- Pour un autre ciel : glisse dans Lighting un objet Sky de la Toolbox (il est conservé tel quel),
-- ou remplace les numéros d'images de SKY ci-dessous.

local Lighting = game:GetService("Lighting")

local Ambience = {}

-- Heure et lumière du soleil.
local LIGHT = {
	ClockTime = 17.6, -- fin d'après-midi : soleil bas, ombres longues et lumière dorée
	GeographicLatitude = 35,
	Brightness = 3,
	ExposureCompensation = 0.1,
	-- Lumière d'ambiance faible : ce sont le soleil et les reflets du ciel qui éclairent,
	-- ce qui donne du relief et des ombres franches.
	Ambient = Color3.fromRGB(40, 32, 36),
	OutdoorAmbient = Color3.fromRGB(120, 100, 95),
	EnvironmentDiffuseScale = 0.9, -- part de la lumière du ciel diffusée sur les surfaces
	EnvironmentSpecularScale = 0.8, -- reflets du ciel sur les métaux et les surfaces lisses
	ShadowSoftness = 0.25,
	ColorShift_Top = Color3.fromRGB(255, 190, 140),
	ColorShift_Bottom = Color3.fromRGB(70, 40, 60),
}

-- Images du ciel (numéros d'images, pas de décalques). Ce sont celles du ciel haute définition de
-- Roblox : nuages réalistes, adaptés à la lumière de fin de journée grâce à la brume ci-dessous.
local SKY = {
	SkyboxBk = 6444884337,
	SkyboxDn = 6444884785,
	SkyboxFt = 6444884337,
	SkyboxLf = 6444884337,
	SkyboxRt = 6444884337,
	SkyboxUp = 6412503613,
	SunTexture = 6196665106,
	MoonTexture = 6444320592,
	SunAngularSize = 14,
	StarCount = 3000,
}

-- Brume : elle teinte l'horizon et noie les lointains dans une lumière chaude.
local ATMOSPHERE = {
	Density = 0.32,
	Offset = 0.2,
	Color = Color3.fromRGB(240, 196, 160),
	Decay = Color3.fromRGB(150, 100, 110),
	Glare = 0.45,
	Haze = 1.6,
}

-- Nuages volumétriques en 3D (ils défilent lentement avec le vent).
local CLOUDS = {
	Cover = 0.55,
	Density = 0.55,
	Color = Color3.fromRGB(255, 222, 200),
}

-- Post-traitement, choisi léger : en VR, un flou ou un effet trop fort fatigue les yeux.
-- (Pas de profondeur de champ : elle ne correspond pas à là où l'œil regarde dans le casque.)
local BLOOM = { Intensity = 0.5, Size = 24, Threshold = 1.4 } -- halo autour des lanternes et du soleil
local SUN_RAYS = { Intensity = 0.06, Spread = 0.7 } -- rayons quand le soleil passe derrière le toit
local COLOR = {
	Brightness = 0.02,
	Contrast = 0.12,
	Saturation = 0.12,
	TintColor = Color3.fromRGB(255, 244, 232),
}

local function assetUrl(id: number): string
	return "rbxassetid://" .. id
end

-- Renvoie l'effet de cette classe déjà présent dans Lighting, ou en crée un.
local function ensure(className: string, parent: Instance): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created
end

local function apply(target: Instance, values: { [string]: any })
	for property, value in values do
		(target :: any)[property] = value
	end
end

function Ambience.apply()
	apply(Lighting, LIGHT)
	Lighting.GlobalShadows = true

	-- Un ciel déjà placé dans Lighting (par exemple depuis la Toolbox) est gardé tel quel.
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SkyboxBk = assetUrl(SKY.SkyboxBk)
		sky.SkyboxDn = assetUrl(SKY.SkyboxDn)
		sky.SkyboxFt = assetUrl(SKY.SkyboxFt)
		sky.SkyboxLf = assetUrl(SKY.SkyboxLf)
		sky.SkyboxRt = assetUrl(SKY.SkyboxRt)
		sky.SkyboxUp = assetUrl(SKY.SkyboxUp)
		sky.SunTextureId = assetUrl(SKY.SunTexture)
		sky.MoonTextureId = assetUrl(SKY.MoonTexture)
		sky.SunAngularSize = SKY.SunAngularSize
		sky.StarCount = SKY.StarCount
		sky.CelestialBodiesShown = true
		sky.Parent = Lighting
	end

	apply(ensure("Atmosphere", Lighting), ATMOSPHERE)
	apply(ensure("Clouds", workspace.Terrain), CLOUDS)
	apply(ensure("BloomEffect", Lighting), BLOOM)
	apply(ensure("SunRaysEffect", Lighting), SUN_RAYS)
	apply(ensure("ColorCorrectionEffect", Lighting), COLOR)
end

return Ambience

-- Fait vaciller doucement les lumières marquées de l'attribut « Flicker » (les lanternes) :
-- leur intensité ondule comme une flamme, chacune à son propre rythme. Calculé sur chaque client,
-- sans rien envoyer sur le réseau.

local RunService = game:GetService("RunService")

local AMPLITUDE = 0.18 -- variation d'intensité (part de l'intensité de départ)

type Flame = { light: Light, base: number, seed: number }

local flames: { [Light]: Flame } = {}
local random = Random.new()

local function watch(item: Instance)
	if item:IsA("Light") and item:GetAttribute("Flicker") and not flames[item] then
		flames[item] = { light = item, base = item.Brightness, seed = random:NextNumber(0, 100) }
	end
end

for _, item in workspace:GetDescendants() do
	watch(item)
end
workspace.DescendantAdded:Connect(watch)
workspace.DescendantRemoving:Connect(function(item)
	flames[item :: any] = nil
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for light, flame in flames do
		-- Bruit lisse : la flamme ondule sans à-coups.
		local wave = math.noise(flame.seed, now * 2.2) * 0.7 + math.noise(flame.seed + 17, now * 6) * 0.3
		light.Brightness = flame.base * (1 + wave * AMPLITUDE * 2)
	end
end)

-- Groupes de collision.
-- Une arme tenue est solide contre le décor et contre les autres armes, mais elle traverse les corps
-- (joueurs, bandits, mannequins) : c'est la détection de coups qui gère les corps, pas la physique.

local PhysicsService = game:GetService("PhysicsService")

local Collisions = {
	BODIES = "Bodies",
	HELD = "HeldWeapons",
	DEFAULT = "Default",
}

PhysicsService:RegisterCollisionGroup(Collisions.BODIES)
PhysicsService:RegisterCollisionGroup(Collisions.HELD)
PhysicsService:CollisionGroupSetCollidable(Collisions.BODIES, Collisions.HELD, false)

-- Place une pièce, ou toutes les pièces d'un modèle, dans un groupe.
function Collisions.assign(root: Instance, group: string)
	if root:IsA("BasePart") then
		root.CollisionGroup = group
	end
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			item.CollisionGroup = group
		end
	end
end

-- Comme `assign`, mais couvre aussi les pièces ajoutées plus tard (accessoires d'un avatar, par exemple).
function Collisions.watch(root: Instance, group: string)
	Collisions.assign(root, group)
	root.DescendantAdded:Connect(function(item)
		if item:IsA("BasePart") then
			item.CollisionGroup = group
		end
	end)
end

return Collisions

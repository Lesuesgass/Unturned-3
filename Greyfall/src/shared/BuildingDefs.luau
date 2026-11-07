-- Base building definitions: material tiers, structure pieces, costs and raid damage rules.
--
-- Tiers from weakest to strongest: pine, birch, maple, brick, metal.
-- Every piece exists in every tier, as an item with the id "<tier>_<piece>" (for example
-- "brick_wall"). Each item is crafted from that tier's material plus a hammer.

local C = Color3.fromRGB
local M = Enum.Material

local BuildingDefs = {}

BuildingDefs.Cell = 8 -- grid size in studs
BuildingDefs.WallHeight = 8

BuildingDefs.TierOrder = { "pine", "birch", "maple", "brick", "metal" }

BuildingDefs.Tiers = {
	pine = {
		name = "Pine",
		material = "pine_planks",
		health = 250,
		color = C(170, 135, 95),
		surface = M.WoodPlanks,
		repairTool = "hammer",
		kitWeight = 1.5,
	},
	birch = {
		name = "Birch",
		material = "birch_planks",
		health = 340,
		color = C(205, 190, 160),
		surface = M.WoodPlanks,
		repairTool = "hammer",
		kitWeight = 1.5,
	},
	maple = {
		name = "Maple",
		material = "maple_planks",
		health = 440,
		color = C(140, 90, 60),
		surface = M.WoodPlanks,
		repairTool = "hammer",
		kitWeight = 1.6,
	},
	brick = {
		name = "Brick",
		material = "bricks",
		health = 900,
		color = C(150, 85, 70),
		surface = M.Brick,
		repairTool = "hammer",
		kitWeight = 3,
	},
	metal = {
		name = "Metal",
		material = "metal_plate",
		health = 1600,
		color = C(110, 115, 118),
		surface = M.DiamondPlate,
		repairTool = "blowtorch",
		kitWeight = 3.5,
	},
}

-- cost: units of the tier material. metalCost replaces cost for the metal tier.
BuildingDefs.Pieces = {
	foundation = { name = "Foundation", healthScale = 1.5, cost = 6, metalCost = 4, order = 1 },
	wall = { name = "Wall", healthScale = 1, cost = 4, metalCost = 3, order = 2 },
	doorway = { name = "Doorway", healthScale = 0.9, cost = 3, metalCost = 2, order = 3 },
	door = { name = "Door", healthScale = 0.7, cost = 4, metalCost = 3, order = 4 },
	floor = { name = "Floor", healthScale = 0.8, cost = 4, metalCost = 3, order = 5 },
	stairs = { name = "Stairs", healthScale = 0.8, cost = 5, metalCost = 4, order = 6 },
}
BuildingDefs.PieceOrder = { "foundation", "wall", "doorway", "door", "floor", "stairs" }

-- Storage containers are placed anywhere outside towns. Only the owner can open them;
-- breaking one spills everything inside.
BuildingDefs.Storage = {
	wooden_crate = { name = "Wooden Crate", tier = "pine", health = 220, slots = 12, size = Vector3.new(4, 3, 3) },
	metal_locker = { name = "Metal Locker", tier = "metal", health = 700, slots = 24, size = Vector3.new(3, 6, 2) },
}

-- How much of each kind of damage a tier actually takes.
-- Wood can be cut down with tools, brick needs a lot of effort, metal only yields to explosives.
BuildingDefs.DamageScale = {
	melee = { pine = 1, birch = 0.8, maple = 0.65, brick = 0.12, metal = 0 },
	bullet = { pine = 1, birch = 0.8, maple = 0.6, brick = 0.08, metal = 0 },
	explosive = { pine = 1, birch = 1, maple = 1, brick = 0.75, metal = 0.5 },
}

-- Fraction of a piece's maximum health restored by one repair, and its material cost.
BuildingDefs.RepairFraction = 0.12
BuildingDefs.RepairCost = 1
BuildingDefs.RepairCooldown = 0.8

-- Fraction of the material cost returned when the owner salvages their own piece.
BuildingDefs.SalvageRefund = 0.5

function BuildingDefs.itemId(tier: string, piece: string): string
	return `{tier}_{piece}`
end

function BuildingDefs.cost(tier: string, piece: string): number
	local pieceDef = BuildingDefs.Pieces[piece]
	return if tier == "metal" then pieceDef.metalCost else pieceDef.cost
end

function BuildingDefs.maxHealth(tier: string, piece: string): number
	local storage = BuildingDefs.Storage[piece]
	if storage then
		return storage.health
	end
	return math.floor(BuildingDefs.Tiers[tier].health * BuildingDefs.Pieces[piece].healthScale)
end

return BuildingDefs

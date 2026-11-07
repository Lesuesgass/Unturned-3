-- Crafting recipes. Inputs are consumed, tools listed in "requires" must be carried but are kept.

local BuildingDefs = require(script.Parent.BuildingDefs)

export type Recipe = {
	id: string,
	category: string,
	output: string,
	count: number,
	inputs: { { id: string, count: number } },
	requires: { string },
}

local Recipes: { Recipe } = {}

local function add(category: string, output: string, count: number, inputs, requires: { string }?)
	local list = {}
	for _, input in inputs do
		table.insert(list, { id = input[1], count = input[2] })
	end
	table.insert(Recipes, {
		id = output,
		category = category,
		output = output,
		count = count,
		inputs = list,
		requires = requires or {},
	})
end

-- Survival
add("Survival", "bandage", 1, { { "cloth", 2 } })
add("Survival", "dressing", 1, { { "cloth", 3 }, { "bandage", 1 } })
add("Survival", "cloth_satchel", 1, { { "cloth", 6 } })

-- Tools and weapons
add("Tools", "hammer", 1, { { "scrap_metal", 1 }, { "pine_planks", 2 } })
add("Tools", "pickaxe", 1, { { "scrap_metal", 3 }, { "birch_planks", 2 } })
add("Tools", "wooden_club", 1, { { "pine_planks", 3 } })
add("Tools", "scrap_knife", 1, { { "scrap_metal", 2 }, { "cloth", 1 } })

-- Materials
add("Materials", "pine_planks", 3, { { "pine_log", 1 } })
add("Materials", "birch_planks", 3, { { "birch_log", 1 } })
add("Materials", "maple_planks", 2, { { "maple_log", 1 } })
add("Materials", "charcoal", 2, { { "pine_log", 1 } }, { "matchbox" })
add("Materials", "bricks", 2, { { "stone", 3 }, { "charcoal", 1 } })
add("Materials", "metal_plate", 1, { { "scrap_metal", 3 } }, { "blowtorch" })
add("Materials", "gunpowder", 2, { { "fertilizer", 2 }, { "charcoal", 1 } })

-- Explosives
add("Explosives", "pipe_charge", 1, { { "scrap_metal", 1 }, { "gunpowder", 3 }, { "cloth", 1 } })
add("Explosives", "demolition_charge", 1, { { "metal_plate", 2 }, { "gunpowder", 10 } })

-- Structures, one recipe per tier and piece
for _, tier in BuildingDefs.TierOrder do
	local material = BuildingDefs.Tiers[tier].material
	for _, piece in BuildingDefs.PieceOrder do
		add(
			"Building",
			BuildingDefs.itemId(tier, piece),
			1,
			{ { material, BuildingDefs.cost(tier, piece) } },
			{ "hammer" }
		)
	end
end
add("Building", "wooden_crate", 1, { { "pine_planks", 8 } }, { "hammer" })
add("Building", "metal_locker", 1, { { "metal_plate", 5 } }, { "hammer", "blowtorch" })

local CATEGORY_ORDER = { "Survival", "Tools", "Materials", "Explosives", "Building" }

local byId: { [string]: Recipe } = {}
for _, recipe in Recipes do
	byId[recipe.id] = recipe
end

return {
	List = Recipes,
	Categories = CATEGORY_ORDER,
	get = function(id: string): Recipe?
		return byId[id]
	end,
}

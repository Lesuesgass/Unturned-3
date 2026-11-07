-- Crafting recipes. Inputs are consumed, the output is added to the inventory.

export type Recipe = {
	id: string,
	output: string,
	count: number,
	inputs: { { id: string, count: number } },
}

local Recipes: { Recipe } = {
	{ id = "bandage", output = "bandage", count = 1, inputs = { { id = "cloth", count = 2 } } },
	{ id = "planks", output = "planks", count = 4, inputs = { { id = "log", count = 1 } } },
	{ id = "wooden_club", output = "wooden_club", count = 1, inputs = { { id = "planks", count = 3 } } },
	{
		id = "scrap_knife",
		output = "scrap_knife",
		count = 1,
		inputs = { { id = "scrap_metal", count = 2 }, { id = "cloth", count = 1 } },
	},
	{ id = "cloth_satchel", output = "cloth_satchel", count = 1, inputs = { { id = "cloth", count = 6 } } },
}

local byId: { [string]: Recipe } = {}
for _, recipe in Recipes do
	byId[recipe.id] = recipe
end

return {
	List = Recipes,
	get = function(id: string): Recipe?
		return byId[id]
	end,
}

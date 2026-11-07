-- Loot tables. Each entry is { itemId, weight, minCount, maxCount }.
-- Higher weight means more common within that table.

local Items = require(game:GetService("ReplicatedStorage").Shared.Items)

local tables = {
	Residential = {
		{ "canned_beans", 10, 1, 1 },
		{ "canned_soup", 8, 1, 1 },
		{ "bread", 6, 1, 1 },
		{ "apple", 6, 1, 2 },
		{ "chocolate_bar", 6, 1, 2 },
		{ "water_bottle", 10, 1, 1 },
		{ "soda_can", 8, 1, 2 },
		{ "bandage", 7, 1, 2 },
		{ "painkillers", 4, 1, 1 },
		{ "dressing", 2, 1, 1 },
		{ "cloth", 8, 1, 3 },
		{ "kitchen_knife", 4, 1, 1 },
		{ "baseball_bat", 3, 1, 1 },
		{ "frying_pan", 3, 1, 1 },
		{ "golf_club", 2, 1, 1 },
		{ "compact_pistol", 2, 1, 1 },
		{ "revolver", 1, 1, 1 },
		{ "double_barrel", 1, 1, 1 },
		{ "revolver_rounds", 2, 4, 10 },
		{ "small_rounds", 2, 8, 20 },
		{ "shotgun_shells", 2, 2, 6 },
		{ "flashlight", 3, 1, 1 },
		{ "matchbox", 3, 1, 1 },
		{ "hammer", 2, 1, 1 },
		{ "daypack", 2, 1, 1 },
		{ "pistol_ammo", 2, 6, 12 },
	},
	Farm = {
		{ "apple", 10, 1, 3 },
		{ "bread", 4, 1, 1 },
		{ "water_bottle", 6, 1, 1 },
		{ "canteen", 3, 1, 1 },
		{ "cloth", 6, 1, 3 },
		{ "pine_log", 4, 1, 2 },
		{ "pine_planks", 8, 3, 6 },
		{ "fertilizer", 7, 1, 3 },
		{ "matchbox", 2, 1, 1 },
		{ "pickaxe", 2, 1, 1 },
		{ "hammer", 2, 1, 1 },
		{ "scrap_metal", 6, 1, 2 },
		{ "fire_axe", 3, 1, 1 },
		{ "machete", 3, 1, 1 },
		{ "varmint_rifle", 2, 1, 1 },
		{ "double_barrel", 2, 1, 1 },
		{ "small_rounds", 4, 10, 25 },
		{ "shovel", 3, 1, 1 },
		{ "hatchet", 3, 1, 1 },
		{ "pipe_wrench", 1, 1, 1 },
		{ "sledgehammer", 1, 1, 1 },
		{ "hunting_rifle", 1, 1, 1 },
		{ "rifle_ammo", 2, 5, 10 },
		{ "pump_shotgun", 1, 1, 1 },
		{ "shotgun_shells", 3, 3, 8 },
	},
	Store = {
		{ "canned_beans", 10, 1, 2 },
		{ "canned_soup", 10, 1, 2 },
		{ "chocolate_bar", 8, 1, 3 },
		{ "bread", 6, 1, 1 },
		{ "mre", 1, 1, 1 },
		{ "water_bottle", 12, 1, 2 },
		{ "soda_can", 12, 1, 3 },
		{ "bandage", 6, 1, 2 },
		{ "painkillers", 4, 1, 1 },
		{ "cloth", 4, 1, 2 },
		{ "flashlight", 4, 1, 1 },
		{ "baseball_bat", 2, 1, 1 },
		{ "golf_club", 1, 1, 1 },
		{ "frying_pan", 2, 1, 1 },
		{ "matchbox", 3, 1, 1 },
		{ "daypack", 3, 1, 1 },
	},
	Medical = {
		{ "bandage", 14, 1, 3 },
		{ "dressing", 8, 1, 2 },
		{ "medkit", 5, 1, 1 },
		{ "painkillers", 10, 1, 2 },
		{ "antibiotics", 7, 1, 1 },
		{ "water_bottle", 4, 1, 1 },
		{ "cloth", 4, 1, 3 },
	},
	Police = {
		{ "service_pistol", 6, 1, 1 },
		{ "pistol_ammo", 12, 8, 18 },
		{ "pump_shotgun", 3, 1, 1 },
		{ "shotgun_shells", 6, 4, 10 },
		{ "flashlight", 6, 1, 1 },
		{ "bandage", 6, 1, 2 },
		{ "crowbar", 3, 1, 1 },
		{ "revolver", 2, 1, 1 },
		{ "revolver_rounds", 4, 6, 12 },
		{ "compact_pistol", 3, 1, 1 },
		{ "daypack", 2, 1, 1 },
	},
	Military = {
		{ "carbine", 3, 1, 1 },
		{ "hunting_rifle", 2, 1, 1 },
		{ "service_pistol", 4, 1, 1 },
		{ "rifle_ammo", 12, 10, 25 },
		{ "pistol_ammo", 8, 8, 18 },
		{ "mre", 8, 1, 1 },
		{ "canteen", 6, 1, 1 },
		{ "medkit", 4, 1, 1 },
		{ "bandage", 6, 1, 2 },
		{ "dressing", 4, 1, 1 },
		{ "antibiotics", 3, 1, 1 },
		{ "field_pack", 3, 1, 1 },
		{ "fire_axe", 2, 1, 1 },
		{ "machete", 3, 1, 1 },
		{ "flashlight", 4, 1, 1 },
		{ "gunpowder", 4, 2, 6 },
		{ "pipe_charge", 2, 1, 1 },
		{ "demolition_charge", 1, 1, 1 },
		{ "blowtorch", 1, 1, 1 },
	},
	Industrial = {
		{ "scrap_metal", 10, 1, 3 },
		{ "pine_planks", 6, 3, 6 },
		{ "birch_planks", 3, 2, 5 },
		{ "crowbar", 5, 1, 1 },
		{ "pipe_wrench", 4, 1, 1 },
		{ "sledgehammer", 2, 1, 1 },
		{ "shovel", 2, 1, 1 },
		{ "hatchet", 2, 1, 1 },
		{ "hammer", 4, 1, 1 },
		{ "blowtorch", 2, 1, 1 },
		{ "pickaxe", 2, 1, 1 },
		{ "metal_plate", 1, 1, 2 },
		{ "fire_axe", 3, 1, 1 },
		{ "cloth", 4, 1, 2 },
		{ "flashlight", 3, 1, 1 },
		{ "water_bottle", 4, 1, 1 },
	},
	Vehicle = {
		{ "water_bottle", 6, 1, 1 },
		{ "soda_can", 6, 1, 2 },
		{ "chocolate_bar", 5, 1, 2 },
		{ "bandage", 5, 1, 1 },
		{ "scrap_metal", 8, 1, 2 },
		{ "crowbar", 3, 1, 1 },
		{ "compact_pistol", 1, 1, 1 },
		{ "pipe_wrench", 2, 1, 1 },
		{ "golf_club", 1, 1, 1 },
		{ "flashlight", 3, 1, 1 },
		{ "blowtorch", 1, 1, 1 },
		{ "pistol_ammo", 2, 4, 10 },
	},
	Zombie = {
		{ "cloth", 10, 1, 2 },
		{ "bandage", 4, 1, 1 },
		{ "canned_beans", 3, 1, 1 },
		{ "soda_can", 3, 1, 1 },
		{ "painkillers", 2, 1, 1 },
		{ "scrap_metal", 3, 1, 1 },
		{ "pistol_ammo", 2, 3, 8 },
	},
}

-- Validate once at startup so a typo shows up immediately in the output window.
for tableName, entries in tables do
	for _, entry in entries do
		if not Items.get(entry[1]) then
			warn(`[LootTables] {tableName} references unknown item "{entry[1]}"`)
		end
	end
end

local LootTables = {}

-- Returns itemId, count for a random roll on a table.
function LootTables.roll(name: string, rng: Random): (string?, number)
	local entries = tables[name]
	if not entries then
		return nil, 0
	end
	local total = 0
	for _, entry in entries do
		total += entry[2]
	end
	local roll = rng:NextNumber() * total
	for _, entry in entries do
		roll -= entry[2]
		if roll <= 0 then
			return entry[1], rng:NextInteger(entry[3], entry[4])
		end
	end
	local last = entries[#entries]
	return last[1], last[3]
end

return LootTables

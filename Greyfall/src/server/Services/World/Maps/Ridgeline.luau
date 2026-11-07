-- Ridgeline: a mainland map. A port city on the western coast, a valley town,
-- farmland, a fenced military base, a forest hamlet and a lodge in the eastern mountains.

return {
	id = "Ridgeline",
	displayName = "Ridgeline",
	size = 2560,
	seed = 9031,
	shape = "coast",
	baseHeight = 10,
	amplitude = 40,
	noiseScale = 340,
	forestScale = 240,
	forestThreshold = 0,
	treeAttempts = 2600,
	mountainHeight = 150,
	snowline = 128,

	towns = {
		{ name = "Port Ashby", kind = "city", x = -700, z = 100, radius = 200, zombies = 22 },
		{ name = "Cedar Falls", kind = "town", x = -50, z = -350, radius = 120, zombies = 10 },
		{ name = "Westfield Farms", kind = "farm", x = -430, z = -660, radius = 110, zombies = 6 },
		{ name = "Fort Hale", kind = "military", x = 200, z = 460, radius = 140, zombies = 14 },
		{ name = "Pine Hollow", kind = "cabins", x = 420, z = -150, radius = 80, zombies = 4 },
		{ name = "Summit Lodge", kind = "cabins", x = 830, z = 300, radius = 60, zombies = 4 },
	},

	roads = {
		{ "Port Ashby", "Cedar Falls" },
		{ "Port Ashby", "Westfield Farms" },
		{ "Port Ashby", "Fort Hale" },
		{ "Cedar Falls", "Westfield Farms" },
		{ "Cedar Falls", "Pine Hollow" },
		{ "Cedar Falls", "Fort Hale" },
		{ "Pine Hollow", "Summit Lodge" },
	},

	spawns = {
		{ x = -860, z = -320 },
		{ x = -860, z = 520 },
		{ x = -100, z = 900 },
		{ x = -100, z = -1000 },
		{ x = 560, z = -700 },
		{ x = -250, z = 120 },
		{ x = 300, z = 1000 },
	},
}

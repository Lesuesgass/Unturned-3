-- Ridgeline: a large mainland. A port city on the western coast, a valley town, a river
-- village, farmland, a fenced military base, a forest hamlet, a mountain pass town and a
-- lodge high in the eastern mountains.

return {
	id = "Ridgeline",
	displayName = "Ridgeline",
	size = 3584,
	seed = 9031,
	shape = "coast",
	baseHeight = 10,
	amplitude = 42,
	noiseScale = 420,
	forestScale = 280,
	forestThreshold = 0,
	treeAttempts = 5200,
	mountainHeight = 150,
	snowline = 128,

	towns = {
		{ name = "Port Ashby", kind = "city", x = -980, z = 140, radius = 210, zombies = 24 },
		{ name = "Cedar Falls", kind = "town", x = -70, z = -490, radius = 130, zombies = 12 },
		{ name = "Riverside", kind = "village", x = -560, z = 760, radius = 90, zombies = 6 },
		{ name = "Westfield Farms", kind = "farm", x = -600, z = -920, radius = 115, zombies = 6 },
		{ name = "Fort Hale", kind = "military", x = 280, z = 640, radius = 145, zombies = 16 },
		{ name = "Pine Hollow", kind = "cabins", x = 590, z = -210, radius = 85, zombies = 4 },
		{ name = "Granite Pass", kind = "village", x = 980, z = -700, radius = 90, zombies = 7 },
		{ name = "Summit Lodge", kind = "cabins", x = 1160, z = 420, radius = 65, zombies = 5 },
	},

	roads = {
		{ "Port Ashby", "Cedar Falls" },
		{ "Port Ashby", "Westfield Farms" },
		{ "Port Ashby", "Riverside" },
		{ "Riverside", "Fort Hale" },
		{ "Cedar Falls", "Westfield Farms" },
		{ "Cedar Falls", "Pine Hollow" },
		{ "Cedar Falls", "Fort Hale" },
		{ "Pine Hollow", "Summit Lodge" },
		{ "Pine Hollow", "Granite Pass" },
	},

	spawns = {
		{ x = -1200, z = -450 },
		{ x = -1200, z = 730 },
		{ x = -140, z = 1260 },
		{ x = -140, z = -1400 },
		{ x = 780, z = -980 },
		{ x = -350, z = 170 },
		{ x = 420, z = 1400 },
	},
}

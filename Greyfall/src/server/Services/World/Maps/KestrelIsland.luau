-- Kestrel Island: a small rural island with a fishing village, a central town,
-- farmland, a lighthouse, a hilltop radar station and a few forest cabins.

return {
	id = "KestrelIsland",
	displayName = "Kestrel Island",
	size = 1536,
	seed = 4127,
	shape = "island",
	baseHeight = 8,
	amplitude = 46,
	noiseScale = 260,
	forestScale = 180,
	forestThreshold = 0.05,
	treeAttempts = 1100,
	snowline = math.huge,

	towns = {
		{ name = "Kestrel", kind = "town", x = 40, z = -40, radius = 120, zombies = 12 },
		{ name = "Harbor Point", kind = "village", x = -340, z = 170, radius = 85, zombies = 6 },
		{ name = "Millbrook Farms", kind = "farm", x = 270, z = 250, radius = 105, zombies = 5 },
		{ name = "North Light", kind = "lighthouse", x = 60, z = -420, radius = 45, zombies = 2 },
		{ name = "Radar Station", kind = "military", x = 330, z = -220, radius = 75, zombies = 7, small = true },
		{ name = "Cove Cabins", kind = "cabins", x = -260, z = -250, radius = 60, zombies = 3 },
	},

	roads = {
		{ "Kestrel", "Harbor Point" },
		{ "Kestrel", "Millbrook Farms" },
		{ "Kestrel", "North Light" },
		{ "Kestrel", "Radar Station" },
		{ "Harbor Point", "Cove Cabins" },
	},

	spawns = {
		{ x = -440, z = -40 },
		{ x = 430, z = 40 },
		{ x = -80, z = 420 },
		{ x = 150, z = 410 },
		{ x = -420, z = -330 },
		{ x = 450, z = -380 },
	},
}

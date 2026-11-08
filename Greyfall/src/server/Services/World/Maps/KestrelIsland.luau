-- Kestrel Island: a rural island with a central town, two fishing villages, farmland,
-- a lighthouse, a hilltop radar station and forest cabins.

return {
	id = "KestrelIsland",
	displayName = "Kestrel Island",
	size = 2304,
	seed = 4127,
	shape = "island",
	baseHeight = 8,
	amplitude = 52,
	noiseScale = 340,
	forestScale = 220,
	forestThreshold = 0.05,
	treeAttempts = 1700,
	snowline = math.huge,

	towns = {
		{ name = "Kestrel", kind = "town", x = 60, z = -60, radius = 130, zombies = 12 },
		{ name = "Harbor Point", kind = "village", x = -510, z = 255, radius = 90, zombies = 6 },
		{ name = "Saltmarsh", kind = "village", x = 420, z = 520, radius = 85, zombies = 6 },
		{ name = "Millbrook Farms", kind = "farm", x = 400, z = 150, radius = 110, zombies = 5 },
		{ name = "Westbrook Farms", kind = "farm", x = -330, z = -120, radius = 100, zombies = 5 },
		{ name = "North Light", kind = "lighthouse", x = 90, z = -640, radius = 45, zombies = 2 },
		{ name = "Radar Station", kind = "military", x = 500, z = -330, radius = 80, zombies = 8, small = true },
		{ name = "Cove Cabins", kind = "cabins", x = -390, z = -480, radius = 60, zombies = 3 },
	},

	roads = {
		{ "Kestrel", "Harbor Point" },
		{ "Kestrel", "Millbrook Farms" },
		{ "Kestrel", "North Light" },
		{ "Kestrel", "Radar Station" },
		{ "Kestrel", "Westbrook Farms" },
		{ "Millbrook Farms", "Saltmarsh" },
		{ "Westbrook Farms", "Harbor Point" },
		{ "Westbrook Farms", "Cove Cabins" },
	},

	spawns = {
		{ x = -660, z = -60 },
		{ x = 640, z = 60 },
		{ x = -120, z = 630 },
		{ x = 225, z = 615 },
		{ x = -630, z = -500 },
		{ x = 675, z = -570 },
		{ x = -150, z = -700 },
	},
}

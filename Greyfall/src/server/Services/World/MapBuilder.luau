-- Builds a whole map: terrain, towns, roads with wrecks, trees, rocks and the map boundary.
-- Returns everything other services need (loot points, doors, trees, spawns, zombie zones).

local Terrain = require(script.Parent.Terrain)
local Structures = require(script.Parent.Structures)
local Maps = script.Parent.Maps

local MapBuilder = {}

local V = Vector3.new

-- Buildings each kind of town receives, placed from the centre outwards.
local PLANS = {
	village = { { "store", 1 }, { "house", 6 }, { "shed", 2 } },
	town = { { "police", 1 }, { "clinic", 1 }, { "store", 2 }, { "house", 8 }, { "shed", 1 } },
	city = { { "apartment", 8 }, { "warehouse", 2 }, { "store", 5 }, { "clinic", 2 }, { "police", 1 }, { "house", 6 } },
	farm = { { "barn", 2 }, { "house", 2 }, { "silo", 2 }, { "shed", 2 } },
	military = { { "warehouse", 3 }, { "barracks", 3 }, { "watchtower", 2 } },
	militarySmall = { { "warehouse", 1 }, { "barracks", 1 }, { "watchtower", 2 } },
	cabins = { { "cabin", 4 } },
	lighthouse = { { "lighthouse", 1 }, { "cabin", 1 } },
}

local function planFor(town)
	if town.kind == "military" and town.small then
		return PLANS.militarySmall
	end
	return PLANS[town.kind] or PLANS.village
end

local function layoutTown(ctx, field, town, parent: Instance)
	local rng = ctx.rng
	local folder = Instance.new("Folder")
	folder.Name = town.name
	folder.Parent = parent

	local spacing = if town.kind == "city" or town.kind == "military" then 54 else 44
	local candidates = {}
	for gx = -town.radius, town.radius, spacing do
		for gz = -town.radius, town.radius, spacing do
			local x = town.x + gx + rng:NextNumber(-4, 4)
			local z = town.z + gz + rng:NextNumber(-4, 4)
			local d = math.sqrt((x - town.x) ^ 2 + (z - town.z) ^ 2)
			table.insert(candidates, { x = x, z = z, d = d + rng:NextNumber(0, 20) })
		end
	end
	table.sort(candidates, function(a, b)
		return a.d < b.d
	end)

	local placed = {}
	local military = town.kind == "military"
	for _, entry in planFor(town) do
		local typeName, count = entry[1], entry[2]
		local buildingType = Structures.Types[typeName]
		for _ = 1, count do
			for index, spot in candidates do
				local fp = buildingType.footprint
				local centreDist = math.sqrt((spot.x - town.x) ^ 2 + (spot.z - town.z) ^ 2)
				local roadDist = field:roadDistance(spot.x, spot.z)
				local fits = centreDist + fp <= town.radius - 4 and roadDist > fp * 0.75 + Terrain.RoadHalfWidth + 4
				if fits then
					for _, other in placed do
						if math.sqrt((spot.x - other.x) ^ 2 + (spot.z - other.z) ^ 2) < fp + other.fp + 4 then
							fits = false
							break
						end
					end
				end
				if fits then
					table.remove(candidates, index)
					table.insert(placed, { x = spot.x, z = spot.z, fp = fp })

					-- Face the nearest road, or the town centre when no road is close.
					local position = V(spot.x, town.baseY, spot.z)
					local _, road, u = field:roadDistance(spot.x, spot.z)
					local target = V(town.x, town.baseY, town.z)
					if road then
						local rx = road.ax + (road.bx - road.ax) * u
						local rz = road.az + (road.bz - road.az) * u
						if math.sqrt((rx - spot.x) ^ 2 + (rz - spot.z) ^ 2) < 120 then
							target = V(rx, town.baseY, rz)
						end
					end
					if (target - position).Magnitude < 1 then
						target = position + V(0, 0, -1)
					end

					local model = Instance.new("Model")
					model.Name = typeName
					buildingType.build(ctx, model, CFrame.lookAt(position, target), { military = military })
					model.Parent = folder
					break
				end
			end
		end
	end

	if military then
		local ring = town.radius - 6
		local segments = 32
		for i = 0, segments - 1 do
			local a0 = i / segments * math.pi * 2
			local a1 = (i + 1) / segments * math.pi * 2
			local p0 = V(town.x + math.cos(a0) * ring, town.baseY, town.z + math.sin(a0) * ring)
			local p1 = V(town.x + math.cos(a1) * ring, town.baseY, town.z + math.sin(a1) * ring)
			local mid = (p0 + p1) / 2
			if field:roadDistance(mid.X, mid.Z) > 16 then
				Structures.fence(folder, p0, p1)
			end
		end
	end
end

local function placeWrecks(ctx, field, parent: Instance)
	local rng = ctx.rng
	for _, road in field.roads do
		local dx, dz = (road.bx - road.ax) / road.length, (road.bz - road.az) / road.length
		local s = 60
		while s < road.length - 60 do
			if rng:NextNumber() < 0.35 then
				local side = if rng:NextNumber() < 0.5 then -3 else 3
				local x = road.ax + dx * s - dz * side
				local z = road.az + dz * s + dx * side
				local y = field:height(x, z)
				local yaw = math.atan2(-dx, -dz) + math.rad(rng:NextNumber(-25, 25))
				Structures.carWreck(ctx, parent, CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0))
			end
			s += 90
		end
	end
end

local function placeNature(ctx, field, def, parent: Instance)
	local rng = ctx.rng
	local half = field.half
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = parent

	for _ = 1, def.treeAttempts do
		local x = rng:NextNumber(-half + 20, half - 20)
		local z = rng:NextNumber(-half + 20, half - 20)
		local h = field:height(x, z)
		local forest = field:forest(x, z)
		local dense = forest > def.forestThreshold
		if
			h > 3
			and h < def.snowline - 4
			and (dense or rng:NextNumber() < 0.08)
			and not field:townAt(x, z, 12)
			and field:roadDistance(x, z) > 14
		then
			local slope = math.abs(field:height(x + 4, z) - h) + math.abs(field:height(x, z + 4) - h)
			if slope < 5 then
				local kind
				if h > 45 or forest > def.forestThreshold + 0.12 then
					kind = "pine"
				elseif math.noise(x / 150, z / 150, 7.7) > 0 then
					kind = "birch"
				else
					kind = "maple"
				end
				Structures.tree(ctx, trees, V(x, h, z), kind)
			end
		end
	end

	local rocks = Instance.new("Folder")
	rocks.Name = "Rocks"
	rocks.Parent = parent
	for _ = 1, math.floor(def.treeAttempts / 6) do
		local x = rng:NextNumber(-half + 20, half - 20)
		local z = rng:NextNumber(-half + 20, half - 20)
		local h = field:height(x, z)
		if h > 2 and not field:townAt(x, z, 10) and field:roadDistance(x, z) > 14 then
			Structures.rock(ctx, rocks, V(x, h + 0.5, z))
		end
	end
end

local function placeBoundary(field, parent: Instance)
	local size = field.def.size
	local half = field.half
	for _, side in { { 0, -half, size, 4 }, { 0, half, size, 4 }, { -half, 0, 4, size }, { half, 0, 4, size } } do
		Structures.newPart("Part", parent, {
			Name = "Boundary",
			Size = V(side[3], 800, side[4]),
			CFrame = CFrame.new(side[1], 300, side[2]),
			Transparency = 1,
			CanQuery = false,
			CanTouch = false,
		})
	end
end

local function resolveSpawns(field, def)
	local spawns = {}
	for _, spot in def.spawns do
		local x, z = spot.x, spot.z
		-- Walk toward the centre of the map until the ground is dry land.
		for _ = 1, 60 do
			local h = field:height(x, z)
			if h > 3 and not field:townAt(x, z, 20) then
				table.insert(spawns, CFrame.new(x, h + 4, z))
				break
			end
			local len = math.sqrt(x * x + z * z)
			if len < 1 then
				break
			end
			x -= x / len * 20
			z -= z / len * 20
		end
	end
	if #spawns == 0 then
		local town = field.towns[1]
		table.insert(spawns, CFrame.new(town.x, town.baseY + 4, town.z))
	end
	return spawns
end

function MapBuilder.build(mapId: string)
	local module = Maps:FindFirstChild(mapId)
	if not module then
		warn(`[MapBuilder] unknown map "{mapId}", falling back to KestrelIsland`)
		module = Maps:FindFirstChild("KestrelIsland")
	end
	local def = require(module :: ModuleScript)

	local started = os.clock()
	local field = Terrain.newField(def)
	Terrain.generate(field)

	local root = workspace:FindFirstChild("World")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = workspace

	local ctx = { rng = Random.new(def.seed), loot = {}, doors = {}, resources = {} }

	local towns = Instance.new("Folder")
	towns.Name = "Towns"
	towns.Parent = root
	for _, town in field.towns do
		layoutTown(ctx, field, town, towns)
		task.wait()
	end

	local wrecks = Instance.new("Folder")
	wrecks.Name = "Wrecks"
	wrecks.Parent = root
	placeWrecks(ctx, field, wrecks)
	placeNature(ctx, field, def, root)
	placeBoundary(field, root)

	local zones = {}
	for _, town in field.towns do
		table.insert(zones, {
			name = town.name,
			center = V(town.x, town.baseY, town.z),
			radius = town.radius,
			count = town.zombies or 0,
		})
	end

	print(
		`[MapBuilder] {def.displayName}: {#ctx.loot} loot points, {#ctx.doors} doors, {#ctx.resources} resources, built in {string.format(
			"%.1f",
			os.clock() - started
		)} s`
	)

	return {
		def = def,
		field = field,
		folder = root,
		lootPoints = ctx.loot,
		doors = ctx.doors,
		resources = ctx.resources,
		spawns = resolveSpawns(field, def),
		zones = zones,
	}
end

return MapBuilder

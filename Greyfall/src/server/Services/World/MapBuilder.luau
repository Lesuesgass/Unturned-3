-- Builds a whole map: terrain, towns, roads with wrecks, trees, rocks and the map boundary.
-- Returns everything other services need (loot points, doors, trees, spawns, zombie zones).

local Terrain = require(script.Parent.Terrain)
local Structures = require(script.Parent.Structures)
local Decor = require(script.Parent.Decor)
local Maps = script.Parent.Maps

local MapBuilder = {}

local V = Vector3.new

local decorateTown -- defined below, used by layoutTown
local optimise -- defined below

-- Buildings each kind of town receives, placed from the centre outwards.
local PLANS = {
	village = { { "store", 1 }, { "large_house", 2 }, { "house", 5 }, { "shed", 2 } },
	town = { { "police", 1 }, { "clinic", 1 }, { "store", 2 }, { "large_house", 3 }, { "house", 7 }, { "shed", 1 } },
	city = {
		{ "apartment", 8 },
		{ "warehouse", 2 },
		{ "store", 5 },
		{ "clinic", 2 },
		{ "police", 1 },
		{ "large_house", 3 },
		{ "house", 5 },
	},
	farm = { { "barn", 2 }, { "large_house", 1 }, { "house", 1 }, { "silo", 2 }, { "shed", 2 } },
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

-- Building footprints that get a fenced yard and a mailbox.
local YARDS = {
	house = { w = 26, d = 20 },
	large_house = { w = 34, d = 26 },
	cabin = { w = 18, d = 14 },
}
local MAILBOX_COLORS = { Color3.fromRGB(60, 70, 80), Color3.fromRGB(120, 50, 45), Color3.fromRGB(70, 80, 60) }

local function addYard(ctx, field, parent: Instance, base: CFrame, yard)
	local rng = ctx.rng
	local hw, hd = yard.w / 2 + 3, yard.d / 2 + 4
	local corners = {
		base * CFrame.new(-hw, 0, -hd + 6),
		base * CFrame.new(-hw, 0, hd),
		base * CFrame.new(hw, 0, hd),
		base * CFrame.new(hw, 0, -hd + 6),
	}
	-- Side and back fences; the front stays open toward the road.
	for i = 1, 3 do
		local a, b = corners[i].Position, corners[i + 1].Position
		local mid = (a + b) / 2
		if field:roadDistance(mid.X, mid.Z) > Terrain.RoadHalfWidth + 3 and rng:NextNumber() < 0.8 then
			Decor.fence(parent, a, b)
		end
	end
	local mailbox = base * CFrame.new(hw - 2, 0, -hd - 1)
	local spot = mailbox.Position
	if field:roadDistance(spot.X, spot.Z) > Terrain.RoadHalfWidth + 1 then
		Decor.mailbox(parent, mailbox, MAILBOX_COLORS[rng:NextInteger(1, #MAILBOX_COLORS)])
	end
end

local function clearOf(placed, x: number, z: number, radius: number): boolean
	for _, other in placed do
		if math.sqrt((x - other.x) ^ 2 + (z - other.z) ^ 2) < other.fp + radius then
			return false
		end
	end
	return true
end

-- Street furniture, parked cars, fields, piers and military clutter for one town.
function decorateTown(ctx, field, town, folder: Instance, placed)
	local rng = ctx.rng
	local urban = town.kind == "town" or town.kind == "city" or town.kind == "village"

	-- Walk every road that passes through the town.
	for _, road in field.roads do
		local dx, dz = (road.bx - road.ax) / road.length, (road.bz - road.az) / road.length
		local side = 1
		for s = 0, road.length, 18 do
			local cx, cz = road.ax + dx * s, road.az + dz * s
			if math.sqrt((cx - town.x) ^ 2 + (cz - town.z) ^ 2) < town.radius - 10 then
				local step = math.floor(s / 18)
				side = -side
				local nx, nz = -dz * side, dx * side -- unit vector across the road
				local function spot(offset: number): (number, number)
					return cx + nx * offset, cz + nz * offset
				end
				if urban and step % 2 == 0 then
					local lx, lz = spot(Terrain.RoadHalfWidth + 2)
					if clearOf(placed, lx, lz, 2) then
						local ground = V(lx, field:height(lx, lz), lz)
						Decor.streetLamp(folder, CFrame.lookAt(ground, ground - V(nx, 0, nz)))
					end
				end
				if urban and rng:NextNumber() < 0.3 then
					local px, pz = spot(Terrain.RoadHalfWidth - 2.5)
					local yaw = math.atan2(-dx, -dz) + (if rng:NextNumber() < 0.5 then 0 else math.pi)
					Structures.carWreck(
						ctx,
						folder,
						CFrame.new(px, field:height(px, pz), pz) * CFrame.Angles(0, yaw, 0)
					)
				elseif urban and rng:NextNumber() < 0.25 then
					local bx, bz = spot(Terrain.RoadHalfWidth + 4)
					if clearOf(placed, bx, bz, 3) then
						local ground = V(bx, field:height(bx, bz), bz)
						if rng:NextNumber() < 0.6 then
							Decor.bench(folder, CFrame.lookAt(ground, ground - V(nx, 0, nz)))
						else
							Decor.trashBin(folder, ground)
						end
					end
				end
			end
		end
	end

	if town.kind == "farm" then
		for _ = 1, 6 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(10, town.radius - 10)
			local hx, hz = town.x + math.cos(angle) * distance, town.z + math.sin(angle) * distance
			if clearOf(placed, hx, hz, 3) and field:roadDistance(hx, hz) > Terrain.RoadHalfWidth + 3 then
				Decor.hayBale(folder, V(hx, field:height(hx, hz), hz), rng:NextNumber(0, math.pi))
			end
		end
		-- Crop fields just outside the farm, on flat ground away from roads.
		local fields = 0
		for _ = 1, 24 do
			if fields >= 4 then
				break
			end
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = town.radius + rng:NextNumber(30, 80)
			local fx, fz = town.x + math.cos(angle) * distance, town.z + math.sin(angle) * distance
			local h = field:height(fx, fz)
			local flat = math.abs(field:height(fx + 20, fz) - h)
				+ math.abs(field:height(fx, fz + 15) - h)
				+ math.abs(field:height(fx - 20, fz) - h)
				+ math.abs(field:height(fx, fz - 15) - h)
			if h > 3 and flat < 6 and field:roadDistance(fx, fz) > 32 and not field:townAt(fx, fz, 25) then
				local yaw = rng:NextNumber(0, math.pi)
				Decor.cropField(folder, CFrame.new(fx, h, fz) * CFrame.Angles(0, yaw, 0), 40, 28, rng)
				fields += 1
			end
		end
	end

	if town.kind == "village" then
		-- Find the nearest water and run a pier out from the shore.
		for i = 0, 23 do
			local angle = i / 24 * math.pi * 2
			local dirX, dirZ = math.cos(angle), math.sin(angle)
			local shore
			for r = town.radius * 0.6, town.radius + 160, 6 do
				local x, z = town.x + dirX * r, town.z + dirZ * r
				if field:height(x, z) < 0.5 then
					shore = r
					break
				end
			end
			if shore then
				local startR = shore - 8
				local sx, sz = town.x + dirX * startR, town.z + dirZ * startR
				Decor.pier(folder, V(sx, field:height(sx, sz), sz), V(dirX, 0, dirZ), 44, rng)
				break
			end
		end
	end

	if town.kind == "military" then
		for _ = 1, (if town.small then 2 else 4) do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(15, town.radius - 20)
			local x, z = town.x + math.cos(angle) * distance, town.z + math.sin(angle) * distance
			if clearOf(placed, x, z, 6) and field:roadDistance(x, z) > Terrain.RoadHalfWidth + 4 then
				local base = CFrame.new(x, town.baseY, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
				if rng:NextNumber() < 0.5 then
					Decor.tent(folder, base)
				else
					Decor.sandbags(folder, base, 10)
				end
			end
		end
	end
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
					local base = CFrame.lookAt(position, target)
					buildingType.build(ctx, model, base, { military = military })
					model.Parent = folder
					local yard = YARDS[typeName]
					if yard then
						addYard(ctx, field, folder, base, yard)
					end
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

	decorateTown(ctx, field, town, folder, placed)
end

local function flatEnough(field, x: number, z: number, radius: number, tolerance: number): boolean
	local h = field:height(x, z)
	for _, offset in { { radius, 0 }, { -radius, 0 }, { 0, radius }, { 0, -radius } } do
		if math.abs(field:height(x + offset[1], z + offset[2]) - h) > tolerance then
			return false
		end
	end
	return true
end

-- Gas stations halfway along long roads and name boards where roads enter towns.
local function placeRoadside(ctx, field, parent: Instance)
	local byName = {}
	for _, town in field.towns do
		byName[town.x .. "," .. town.z] = town
	end
	for _, road in field.roads do
		local dx, dz = (road.bx - road.ax) / road.length, (road.bz - road.az) / road.length
		-- Town signs at both ends.
		for _, endpoint in { { road.ax, road.az, 1 }, { road.bx, road.bz, -1 } } do
			local town = byName[endpoint[1] .. "," .. endpoint[2]]
			if town then
				local along = town.radius + 18
				local sx = endpoint[1] + dx * along * endpoint[3] - dz * (Terrain.RoadHalfWidth + 4)
				local sz = endpoint[2] + dz * along * endpoint[3] + dx * (Terrain.RoadHalfWidth + 4)
				local ground = V(sx, field:height(sx, sz), sz)
				local facing = V(dx * endpoint[3], 0, dz * endpoint[3])
				Decor.signpost(parent, CFrame.lookAt(ground, ground + facing), town.name)
			end
		end
		if road.length > 450 then
			for _, side in { 1, -1 } do
				local s = road.length * 0.5
				local cx, cz = road.ax + dx * s, road.az + dz * s
				local nx, nz = -dz * side, dx * side
				local shopX, shopZ = cx + nx * 34, cz + nz * 34
				local padX, padZ = cx + nx * 17, cz + nz * 17
				if
					not field:townAt(shopX, shopZ, 30)
					and flatEnough(field, shopX, shopZ, 12, 3)
					and field:height(shopX, shopZ) > 2
				then
					local shopGround = V(shopX, field:height(shopX, shopZ), shopZ)
					local toRoad = V(-nx, 0, -nz)
					local model = Instance.new("Model")
					model.Name = "GasStation"
					Structures.Types.kiosk.build(ctx, model, CFrame.lookAt(shopGround, shopGround + toRoad), {})
					local padGround = V(padX, field:height(padX, padZ), padZ)
					Decor.gasCanopy(model, CFrame.lookAt(padGround, padGround + toRoad))
					Structures.carWreck(
						ctx,
						model,
						CFrame.new(padX + dx * 6, padGround.Y, padZ + dz * 6)
							* CFrame.Angles(0, math.atan2(-dx, -dz), 0)
					)
					model.Parent = parent
					break
				end
			end
		end
	end
end

-- Campsites and hunting stands hidden in the forests.
local function placeWilderness(ctx, field, def, parent: Instance)
	local rng = ctx.rng
	local half = field.half
	local wanted = math.floor(def.size / 400)
	local camps, stands = 0, 0
	for _ = 1, 400 do
		if camps >= wanted and stands >= wanted then
			break
		end
		local x = rng:NextNumber(-half + 60, half - 60)
		local z = rng:NextNumber(-half + 60, half - 60)
		local h = field:height(x, z)
		if
			h > 4
			and h < def.snowline - 10
			and field:forest(x, z) > def.forestThreshold
			and not field:townAt(x, z, 60)
			and field:roadDistance(x, z) > 30
			and flatEnough(field, x, z, 7, 2)
		then
			local base = CFrame.new(x, h, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			if camps < wanted and (stands >= wanted or rng:NextNumber() < 0.5) then
				camps += 1
				table.insert(ctx.loot, { position = Decor.campsite(parent, base, rng), table = "Residential" })
			else
				stands += 1
				table.insert(ctx.loot, { position = Decor.huntingStand(parent, base), table = "Farm" })
			end
		end
	end
end

-- Power poles along roads between towns.
local function placePoles(field, parent: Instance)
	for _, road in field.roads do
		local dx, dz = (road.bx - road.ax) / road.length, (road.bz - road.az) / road.length
		for s = 30, road.length - 30, 55 do
			local x = road.ax + dx * s - dz * (Terrain.RoadHalfWidth + 5)
			local z = road.az + dz * s + dx * (Terrain.RoadHalfWidth + 5)
			if not field:townAt(x, z, 5) then
				local y = field:height(x, z)
				if y > 1 then
					Decor.powerPole(
						parent,
						CFrame.new(x, y, z) * CFrame.Angles(0, math.atan2(-dx, -dz) + math.pi / 2, 0)
					)
				end
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

	local bushes = Instance.new("Folder")
	bushes.Name = "Bushes"
	bushes.Parent = parent
	for _ = 1, math.floor(def.treeAttempts * 0.6) do
		local x = rng:NextNumber(-half + 20, half - 20)
		local z = rng:NextNumber(-half + 20, half - 20)
		local h = field:height(x, z)
		if h > 2.5 and h < def.snowline - 4 and field:roadDistance(x, z) > 10 and not field:townAt(x, z, 6) then
			Decor.bush(bushes, V(x, h, z), rng)
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

-- Lets distant buildings and trees draw as simplified meshes. Needs Workspace streaming,
-- and is skipped quietly where the property cannot be set from a script.
function optimise(root: Instance)
	for _, model in root:GetDescendants() do
		if model:IsA("Model") then
			pcall(function()
				model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
			end)
		end
	end
end

function MapBuilder.build(mapId: string, onProgress: ((string) -> ())?)
	local module = Maps:FindFirstChild(mapId)
	if not module then
		warn(`[MapBuilder] unknown map "{mapId}", falling back to KestrelIsland`)
		module = Maps:FindFirstChild("KestrelIsland")
	end
	local def = require(module :: ModuleScript)

	local started = os.clock()
	local function progress(stage: string)
		if onProgress then
			onProgress(stage)
		end
	end
	progress("Shaping the terrain")
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

	progress("Building towns")
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
	placePoles(field, wrecks)
	placeRoadside(ctx, field, wrecks)
	progress("Growing forests")
	placeNature(ctx, field, def, root)
	placeWilderness(ctx, field, def, root)
	optimise(root)
	placeBoundary(field, root)

	local zones = {}
	for _, town in field.towns do
		table.insert(zones, {
			name = town.name,
			center = V(town.x, town.baseY, town.z),
			radius = town.radius,
			count = town.zombies or 0,
			kind = town.kind,
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

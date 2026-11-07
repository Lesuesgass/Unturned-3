-- Procedural terrain. A height field is built from layered noise, shaped into an island or a
-- coastline, then flattened under towns and roads. The result is written into Roblox terrain
-- with WriteVoxels, one chunk at a time so the server never stalls.

local Terrain = {}

local RES = 4 -- terrain voxel size in studs
local CHUNK = 32 -- voxel columns per chunk side
local MIN_Y = -40
local SHELL_DEPTH = 16 -- solid terrain kept below the lowest surface point of a chunk
local SEA_LEVEL = 0
local OCEAN_FLOOR = -22
local ROAD_HALF_WIDTH = 7
local ROAD_BLEND = 26
local TOWN_BLEND = 45

Terrain.SeaLevel = SEA_LEVEL
Terrain.RoadHalfWidth = ROAD_HALF_WIDTH

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function fbm(x: number, z: number, seed: number, octaves: number): number
	local total, amplitude, frequency, norm = 0, 1, 1, 0
	for _ = 1, octaves do
		total += math.noise(x * frequency, z * frequency, seed) * amplitude
		norm += amplitude
		amplitude *= 0.5
		frequency *= 2
	end
	return total / norm
end

-- Distance from point (x, z) to a road segment, and the 0..1 position along it.
local function segmentDistance(x: number, z: number, road): (number, number)
	local dx, dz = road.bx - road.ax, road.bz - road.az
	local lengthSq = dx * dx + dz * dz
	local u = 0
	if lengthSq > 0 then
		u = math.clamp(((x - road.ax) * dx + (z - road.az) * dz) / lengthSq, 0, 1)
	end
	local px, pz = road.ax + dx * u, road.az + dz * u
	return math.sqrt((x - px) ^ 2 + (z - pz) ^ 2), u
end

export type Field = {
	def: any,
	half: number,
	towns: { any },
	roads: { any },
	height: (self: Field, x: number, z: number) -> number,
	rawHeight: (self: Field, x: number, z: number) -> number,
	roadDistance: (self: Field, x: number, z: number) -> (number, any?, number),
	forest: (self: Field, x: number, z: number) -> number,
	townAt: (self: Field, x: number, z: number, margin: number?) -> any?,
}

local Field = {}
Field.__index = Field

function Field:rawHeight(x: number, z: number): number
	local def = self.def
	local s = self.seeds
	local n = fbm(x / def.noiseScale, z / def.noiseScale, s[1], 4)
	local u = math.clamp(n * 1.25 + 0.5, 0, 1)
	local land = def.baseHeight + u ^ 1.5 * def.amplitude + fbm(x / 60, z / 60, s[2], 2) * 3

	local mask
	if def.shape == "island" then
		local d = math.sqrt(x * x + z * z) / self.half
		local warp = fbm(x / 300, z / 300, s[3], 2) * 0.25
		mask = 1 - smoothstep(0.62, 0.92, d + warp)
	else
		local xn = x / self.half
		local warp = fbm(z / 300, x / 500, s[3], 2) * 0.12
		mask = smoothstep(-0.8, -0.68, xn + warp)
		local ridge = math.clamp(1 - math.abs(fbm(x / 420, z / 420, s[4], 3)) * 2.2, 0, 1)
		land += smoothstep(0.05, 0.75, xn) * (def.mountainHeight or 0) * ridge * ridge
	end

	return lerp(OCEAN_FLOOR, land, mask)
end

-- Height plus the nearest road distance and the town (if any) at a point, in one pass.
-- Roads and towns are skipped with a cheap bounding-box test when they are far away.
function Field:sample(x: number, z: number): (number, number, any?)
	local h = self:rawHeight(x, z)
	local roadDist = math.huge
	for _, road in self.roads do
		if x >= road.minX and x <= road.maxX and z >= road.minZ and z <= road.maxZ then
			local d, u = segmentDistance(x, z, road)
			if d < roadDist then
				roadDist = d
			end
			if d < ROAD_BLEND then
				local roadY = lerp(road.ay, road.by, u)
				h = lerp(h, roadY, 1 - smoothstep(ROAD_HALF_WIDTH, ROAD_BLEND, d))
			end
		end
	end
	local inTown = nil
	for _, town in self.towns do
		local dx, dz = x - town.x, z - town.z
		local reach = town.radius + TOWN_BLEND
		if dx * dx + dz * dz < reach * reach then
			local d = math.sqrt(dx * dx + dz * dz)
			h = lerp(h, town.baseY, 1 - smoothstep(town.radius, reach, d))
			if d < town.radius then
				inTown = town
			end
		end
	end
	return h, roadDist, inTown
end

function Field:height(x: number, z: number): number
	return (self:sample(x, z))
end

-- Returns the distance to the nearest road, that road, and the position along it.
function Field:roadDistance(x: number, z: number): (number, any?, number)
	local best, bestRoad, bestU = math.huge, nil, 0
	for _, road in self.roads do
		local d, u = segmentDistance(x, z, road)
		if d < best then
			best, bestRoad, bestU = d, road, u
		end
	end
	return best, bestRoad, bestU
end

function Field:forest(x: number, z: number): number
	return fbm(x / self.def.forestScale, z / self.def.forestScale, self.seeds[5], 3)
end

function Field:townAt(x: number, z: number, margin: number?)
	for _, town in self.towns do
		if math.sqrt((x - town.x) ^ 2 + (z - town.z) ^ 2) < town.radius + (margin or 0) then
			return town
		end
	end
	return nil
end

function Terrain.newField(def): Field
	local self = setmetatable({}, Field) :: any
	self.def = def
	self.half = def.size / 2
	self.seeds = {}
	for i = 1, 5 do
		self.seeds[i] = (def.seed % 997) * 0.7131 + i * 13.37 + 0.5
	end

	self.roads = {}
	self.towns = {}
	local byName = {}
	for _, source in def.towns do
		local town = table.clone(source)
		town.baseY = math.max(self:rawHeight(town.x, town.z), 5)
		table.insert(self.towns, town)
		byName[town.name] = town
	end
	for _, pair in def.roads do
		local a, b = byName[pair[1]], byName[pair[2]]
		if a and b then
			table.insert(self.roads, {
				ax = a.x,
				az = a.z,
				ay = a.baseY,
				bx = b.x,
				bz = b.z,
				by = b.baseY,
				length = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2),
				minX = math.min(a.x, b.x) - ROAD_BLEND,
				maxX = math.max(a.x, b.x) + ROAD_BLEND,
				minZ = math.min(a.z, b.z) - ROAD_BLEND,
				maxZ = math.max(a.z, b.z) + ROAD_BLEND,
			})
		else
			warn(`[Terrain] road references unknown town: {pair[1]} / {pair[2]}`)
		end
	end
	return self
end

local M = Enum.Material

local function surfaceMaterial(
	field,
	x: number,
	z: number,
	h: number,
	slope: number,
	roadDist: number,
	town
): Enum.Material
	local def = field.def
	if roadDist < ROAD_HALF_WIDTH then
		return M.Asphalt
	end
	if town then
		if town.kind == "city" then
			return M.Pavement
		elseif town.kind == "military" then
			return M.Ground
		elseif town.kind == "farm" then
			return if math.noise(x / 40, z / 40, 3.3) > 0 then M.Ground else M.Grass
		end
		return M.Grass
	end
	if h < SEA_LEVEL + 2.5 then
		return M.Sand
	end
	if slope > 0.95 then
		return M.Rock
	end
	if h > def.snowline then
		return M.Snow
	end
	if h > def.snowline - 22 then
		return M.Slate
	end
	if field:forest(x, z) > def.forestThreshold then
		return M.LeafyGrass
	end
	return M.Grass
end

function Terrain.generate(field: Field)
	local terrain = workspace.Terrain
	terrain:Clear()

	local half = field.half
	local cells = math.floor(field.def.size / RES)

	for cz0 = 0, cells - 1, CHUNK do
		for cx0 = 0, cells - 1, CHUNK do
			local nx = math.min(CHUNK, cells - cx0)
			local nz = math.min(CHUNK, cells - cz0)

			-- Heights with a one-cell border so slopes can be measured at the edges.
			-- Road distance and town are kept per column so materials need no second lookup.
			local heights, roads, towns = {}, {}, {}
			local maxH, minH = SEA_LEVEL, math.huge
			for i = 0, nx + 1 do
				local column, roadColumn, townColumn = {}, {}, {}
				heights[i], roads[i], towns[i] = column, roadColumn, townColumn
				local x = -half + (cx0 + i - 1 + 0.5) * RES
				for j = 0, nz + 1 do
					local z = -half + (cz0 + j - 1 + 0.5) * RES
					local h, roadDist, town = field:sample(x, z)
					column[j], roadColumn[j], townColumn[j] = h, roadDist, town or false
					if i >= 1 and i <= nx and j >= 1 and j <= nz then
						maxH = math.max(maxH, h)
						minH = math.min(minH, h)
					end
				end
			end

			-- Only fill a shell below the surface: nothing deeper is ever seen, and skipping
			-- it cuts the voxel count to a fraction.
			local baseY = math.max(MIN_Y, math.floor((math.min(minH, SEA_LEVEL) - SHELL_DEPTH) / RES) * RES)
			local ny = math.ceil((maxH + RES * 2 - baseY) / RES)
			local materials, occupancies = {}, {}
			for i = 1, nx do
				local matX, occX = {}, {}
				materials[i], occupancies[i] = matX, occX
				local x = -half + (cx0 + i - 1 + 0.5) * RES
				for y = 1, ny do
					matX[y], occX[y] = {}, {}
				end
				for j = 1, nz do
					local z = -half + (cz0 + j - 1 + 0.5) * RES
					local h = heights[i][j]
					local slope = math.max(
						math.abs(heights[i + 1][j] - heights[i - 1][j]),
						math.abs(heights[i][j + 1] - heights[i][j - 1])
					) / (2 * RES)
					local town = towns[i][j]
					local surface = surfaceMaterial(field, x, z, h, slope, roads[i][j], if town then town else nil)
					local under = if surface == M.Sand then M.Sand else M.Ground
					for y = 1, ny do
						local y0 = baseY + (y - 1) * RES
						local occupancy = math.clamp((h - y0) / RES, 0, 1)
						local material
						if occupancy > 0 then
							local depth = h - (y0 + RES / 2)
							if depth < 3 then
								material = surface
							elseif depth < 12 then
								material = under
							else
								material = M.Rock
							end
						elseif y0 + RES <= SEA_LEVEL then
							material, occupancy = M.Water, 1
						else
							material = M.Air
						end
						matX[y][j] = material
						occX[y][j] = occupancy
					end
				end
			end

			local minCorner = Vector3.new(-half + cx0 * RES, baseY, -half + cz0 * RES)
			local region = Region3.new(minCorner, minCorner + Vector3.new(nx * RES, ny * RES, nz * RES))
			terrain:WriteVoxels(region:ExpandToGrid(RES), RES, materials, occupancies)
			task.wait()
		end
	end
end

return Terrain

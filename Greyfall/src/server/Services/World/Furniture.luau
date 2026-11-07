-- Furniture for building interiors, built from a few plain parts each.
--
-- A layout is a list of { kind, x, z, yaw, options } in the building's local space:
-- x runs across the width, z from the front wall (negative) to the back wall (positive),
-- yaw in degrees turns the piece; each piece faces its own -Z (toward the room).
-- Pieces with a usable surface add a loot point there, using the building's loot table.

local Furniture = {}

local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material

local WOOD = C(120, 92, 66)
local DARK_WOOD = C(78, 60, 44)
local METAL = C(120, 124, 126)
local FABRICS = { C(110, 70, 60), C(70, 85, 100), C(95, 105, 75), C(140, 120, 90), C(90, 80, 100) }

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Parent = parent
	return p
end

local function loot(ctx, frame: CFrame, offset: Vector3, chance: number?)
	if ctx.lootTable and ctx.rng:NextNumber() < (chance or 0.6) then
		table.insert(ctx.loot, { position = (frame * CFrame.new(offset)).Position, table = ctx.lootTable })
	end
end

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- Builders: (ctx, parent, frame, options). frame sits on the floor at the piece's centre.
local B = {}

function B.bed(ctx, parent, f)
	part(parent, V(4, 1.2, 7), f * CFrame.new(0, 0.6, 0), DARK_WOOD, M.Wood)
	part(parent, V(3.8, 0.7, 6.6), f * CFrame.new(0, 1.55, 0), C(214, 210, 198), M.Fabric)
	part(parent, V(3.9, 0.3, 4.2), f * CFrame.new(0, 1.95, -1.1), pick(ctx.rng, FABRICS), M.Fabric)
	part(parent, V(2.6, 0.5, 1.2), f * CFrame.new(0, 2.1, 2.6), C(230, 228, 220), M.Fabric)
	part(parent, V(4, 3, 0.4), f * CFrame.new(0, 1.5, 3.4), DARK_WOOD, M.Wood)
	loot(ctx, f, V(0, 2.1, 0), 0.35)
end

function B.bunk(ctx, parent, f)
	for level = 0, 1 do
		local y = level * 3.4
		part(parent, V(3.6, 0.5, 6.6), f * CFrame.new(0, 1 + y, 0), METAL, M.Metal)
		part(parent, V(3.4, 0.5, 6.4), f * CFrame.new(0, 1.5 + y, 0), C(95, 100, 75), M.Fabric)
	end
	part(parent, V(0.3, 6.5, 0.3), f * CFrame.new(-1.7, 3.25, -3.2), METAL, M.Metal)
	part(parent, V(0.3, 6.5, 0.3), f * CFrame.new(1.7, 3.25, 3.2), METAL, M.Metal)
	loot(ctx, f, V(0, 1.8, 0), 0.4)
end

function B.table(ctx, parent, f)
	part(parent, V(5, 0.35, 3.2), f * CFrame.new(0, 2.6, 0), WOOD, M.Wood)
	part(parent, V(0.4, 2.45, 2.6), f * CFrame.new(-2.1, 1.22, 0), DARK_WOOD, M.Wood)
	part(parent, V(0.4, 2.45, 2.6), f * CFrame.new(2.1, 1.22, 0), DARK_WOOD, M.Wood)
	loot(ctx, f, V(ctx.rng:NextNumber(-1.5, 1.5), 2.78, 0), 0.5)
end

function B.chair(_ctx, parent, f)
	part(parent, V(1.6, 0.3, 1.6), f * CFrame.new(0, 1.5, 0), WOOD, M.Wood)
	part(parent, V(1.6, 2, 0.3), f * CFrame.new(0, 2.6, 0.65), WOOD, M.Wood)
	part(parent, V(1.3, 1.35, 1.3), f * CFrame.new(0, 0.68, 0), DARK_WOOD, M.Wood)
end

function B.counter(ctx, parent, f, options)
	local length = options and options.length or 8
	part(parent, V(length, 3, 2.4), f * CFrame.new(0, 1.5, 0), C(170, 165, 150), M.SmoothPlastic)
	part(parent, V(length + 0.2, 0.3, 2.6), f * CFrame.new(0, 3.15, 0), C(80, 78, 74), M.Slate)
	loot(ctx, f, V(ctx.rng:NextNumber(-length / 2 + 1, length / 2 - 1), 3.32, 0), 0.7)
end

function B.fridge(ctx, parent, f)
	part(parent, V(2.6, 6, 2.4), f * CFrame.new(0, 3, 0), C(205, 205, 198), M.SmoothPlastic)
	part(parent, V(0.2, 1.8, 0.2), f * CFrame.new(0.9, 3.8, -1.3), METAL, M.Metal)
	loot(ctx, f, V(0, 6.05, 0), 0.25)
end

function B.shelf(ctx, parent, f, options)
	local width = options and options.width or 4
	part(parent, V(width, 6, 0.3), f * CFrame.new(0, 3, 0.55), DARK_WOOD, M.Wood)
	for i = 0, 2 do
		part(parent, V(width, 0.25, 1.4), f * CFrame.new(0, 0.6 + i * 2, 0), WOOD, M.Wood)
	end
	loot(ctx, f, V(ctx.rng:NextNumber(-width / 2 + 0.6, width / 2 - 0.6), 0.75 + ctx.rng:NextInteger(0, 2) * 2, 0), 0.7)
end

-- A long free-standing store shelf, loot on both sides.
function B.aisle(ctx, parent, f, options)
	local length = options and options.length or 14
	part(parent, V(1.2, 5.5, length), f * CFrame.new(0, 2.75, 0), C(150, 150, 145), M.Metal)
	for i = 0, 2 do
		part(parent, V(3, 0.2, length), f * CFrame.new(0, 0.5 + i * 1.8, 0), C(185, 185, 180), M.Metal)
	end
	for _ = 1, 2 do
		local side = if ctx.rng:NextNumber() < 0.5 then -1 else 1
		loot(
			ctx,
			f,
			V(side * 0.95, 0.62 + ctx.rng:NextInteger(0, 2) * 1.8, ctx.rng:NextNumber(-length / 2 + 1, length / 2 - 1)),
			0.75
		)
	end
end

function B.sofa(ctx, parent, f)
	local fabric = pick(ctx.rng, FABRICS)
	part(parent, V(6, 1.5, 2.6), f * CFrame.new(0, 0.75, 0), fabric, M.Fabric)
	part(parent, V(6, 2.2, 0.7), f * CFrame.new(0, 1.9, 1), fabric, M.Fabric)
	part(parent, V(0.6, 2, 2.6), f * CFrame.new(-2.7, 1.3, 0), fabric, M.Fabric)
	part(parent, V(0.6, 2, 2.6), f * CFrame.new(2.7, 1.3, 0), fabric, M.Fabric)
	loot(ctx, f, V(ctx.rng:NextNumber(-1.5, 1.5), 1.55, -0.3), 0.3)
end

function B.wardrobe(ctx, parent, f)
	part(parent, V(4, 7, 2), f * CFrame.new(0, 3.5, 0), DARK_WOOD, M.Wood)
	part(parent, V(0.1, 6.6, 0.1), f * CFrame.new(0, 3.5, -1.02), C(40, 32, 26), M.Wood)
	loot(ctx, f, V(0, 7.05, 0), 0.3)
end

function B.desk(ctx, parent, f)
	part(parent, V(4.5, 0.3, 2.2), f * CFrame.new(0, 2.6, 0), WOOD, M.Wood)
	part(parent, V(1.6, 2.45, 2), f * CFrame.new(-1.4, 1.22, 0), DARK_WOOD, M.Wood)
	part(parent, V(0.3, 2.45, 2), f * CFrame.new(2.05, 1.22, 0), DARK_WOOD, M.Wood)
	loot(ctx, f, V(ctx.rng:NextNumber(-1.5, 1.5), 2.76, 0), 0.6)
end

function B.locker(ctx, parent, f)
	part(parent, V(2.2, 6.5, 2), f * CFrame.new(0, 3.25, 0), C(95, 105, 110), M.Metal)
	part(parent, V(0.08, 6, 0.1), f * CFrame.new(0, 3.25, -1.02), C(60, 65, 70), M.Metal)
	loot(ctx, f, V(0, 6.55, 0), 0.4)
end

function B.hospitalBed(ctx, parent, f)
	part(parent, V(3.4, 0.4, 7), f * CFrame.new(0, 2, 0), METAL, M.Metal)
	part(parent, V(3.2, 0.5, 6.8), f * CFrame.new(0, 2.45, 0), C(225, 228, 228), M.Fabric)
	part(parent, V(3.2, 1.9, 0.3), f * CFrame.new(0, 1, 3.2), METAL, M.Metal)
	part(parent, V(3.2, 1.9, 0.3), f * CFrame.new(0, 1, -3.2), METAL, M.Metal)
	loot(ctx, f, V(0, 2.75, 0), 0.4)
end

function B.crate(ctx, parent, f, options)
	local size = options and options.size or 3
	part(
		parent,
		V(size, size, size),
		f * CFrame.new(0, size / 2, 0) * CFrame.Angles(0, math.rad(ctx.rng:NextNumber(-15, 15)), 0),
		C(140, 110, 70),
		M.WoodPlanks
	)
	loot(ctx, f, V(0, size + 0.05, 0), 0.45)
end

function B.barrel(ctx, parent, f)
	local p = part(
		parent,
		V(3.2, 2.2, 2.2),
		f * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
		pick(ctx.rng, { C(70, 85, 70), C(120, 60, 45), C(70, 80, 100) }),
		M.Metal
	)
	p.Shape = Enum.PartType.Cylinder
end

function B.rack(ctx, parent, f, options)
	local length = options and options.length or 10
	for _, x in { -length / 2 + 0.2, length / 2 - 0.2 } do
		part(parent, V(0.4, 8, 3), f * CFrame.new(x, 4, 0), C(150, 90, 50), M.Metal)
	end
	for i = 0, 2 do
		part(parent, V(length, 0.3, 3), f * CFrame.new(0, 0.6 + i * 3.2, 0), C(130, 120, 100), M.WoodPlanks)
	end
	loot(
		ctx,
		f,
		V(ctx.rng:NextNumber(-length / 2 + 1, length / 2 - 1), 0.77 + ctx.rng:NextInteger(0, 2) * 3.2, 0),
		0.75
	)
end

function B.workbench(ctx, parent, f)
	part(parent, V(6, 0.4, 2.6), f * CFrame.new(0, 3, 0), C(110, 85, 60), M.WoodPlanks)
	part(parent, V(5.6, 2.8, 2.2), f * CFrame.new(0, 1.4, 0.1), C(90, 70, 50), M.Wood)
	loot(ctx, f, V(ctx.rng:NextNumber(-2, 2), 3.22, 0), 0.6)
end

function B.hay(ctx, parent, f)
	local p = part(
		parent,
		V(3, 3.4, 3.4),
		f * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2),
		C(196, 170, 100),
		M.Grass
	)
	p.Shape = Enum.PartType.Cylinder
	local _ = ctx
end

function B.rug(ctx, parent, f, options)
	local size = options and options.size or V(7, 0.08, 5)
	part(parent, size, f * CFrame.new(0, 0.04, 0), pick(ctx.rng, FABRICS), M.Fabric, false)
end

-- Room layouts for each building type. Coordinates assume the building's own size.
local LAYOUTS = {
	house = function(w, d)
		return {
			{ "rug", 0, -1 },
			{ "bed", -w / 2 + 3.2, d / 2 - 4.6, 180 },
			{ "wardrobe", -w / 2 + 8, d / 2 - 1.6, 180 },
			{ "table", 6, 0 },
			{ "chair", 6, -2.6, 0 },
			{ "chair", 6, 2.6, 180 },
			{ "counter", w / 2 - 6.5, d / 2 - 1.8, 180, { length = 7 } },
			{ "fridge", w / 2 - 1.9, d / 2 - 1.8, 180 },
			{ "sofa", -w / 2 + 2, -1.5, 90 },
			{ "shelf", w / 2 - 1.3, -4, -90 },
		}
	end,
	cabin = function(w, d)
		return {
			{ "bed", -w / 2 + 3.2, d / 2 - 4.4, 180 },
			{ "table", 3.5, 1 },
			{ "chair", 3.5, -1.6, 0 },
			{ "shelf", w / 2 - 1.3, -2.5, -90 },
			{ "crate", w / 2 - 2.5, d / 2 - 2.5, 0, { size = 2.4 } },
		}
	end,
	large_ground = function(w, d)
		return {
			{ "rug", 4, -2, 0, { size = V(9, 0.08, 6) } },
			{ "sofa", 4, -6.5, 180 },
			{ "table", 4, 3 },
			{ "chair", 4, 0.5, 0 },
			{ "chair", 4, 5.5, 180 },
			{ "counter", w / 2 - 1.8, 4, -90, { length = 9 } },
			{ "fridge", w / 2 - 1.8, -2.5, -90 },
			{ "shelf", -w / 2 + 1.3, -5, 90 },
			{ "desk", -w / 2 + 9.5, d / 2 - 1.7, 180 },
		}
	end,
	large_upper = function(w, d)
		return {
			{ "bed", w / 2 - 3.2, d / 2 - 4.6, 180 },
			{ "bed", w / 2 - 3.2, -d / 2 + 4.6, 0 },
			{ "wardrobe", 2, d / 2 - 1.6, 180 },
			{ "desk", 2, -d / 2 + 1.7, 0 },
			{ "chair", 2, -d / 2 + 3.6, 180 },
			{ "rug", 6, 0, 90, { size = V(8, 0.08, 5) } },
			{ "shelf", -w / 2 + 8.5, -3, 90 },
		}
	end,
	store = function(w, d)
		return {
			{ "aisle", -12, 3, 0, { length = 14 } },
			{ "aisle", -6, 3, 0, { length = 14 } },
			{ "aisle", 6, 3, 0, { length = 14 } },
			{ "aisle", 12, 3, 0, { length = 14 } },
			{ "counter", 10, -d / 2 + 5, 0, { length = 6 } },
			{ "shelf", -w / 2 + 1.3, -d / 2 + 6, 90, { width = 5 } },
			-- The back door sits on the left as seen from inside, so the fridges go right.
			{ "fridge", w / 2 - 1.9, d / 2 - 2, -90 },
			{ "fridge", w / 2 - 4.6, d / 2 - 2, 180 },
		}
	end,
	clinic = function(w, d)
		return {
			{ "hospitalBed", -9, d / 2 - 4.5, 180 },
			{ "hospitalBed", -3, d / 2 - 4.5, 180 },
			{ "hospitalBed", 3, d / 2 - 4.5, 180 },
			{ "shelf", w / 2 - 1.3, 0, -90, { width = 5 } },
			{ "shelf", w / 2 - 1.3, 6, -90, { width = 5 } },
			{ "desk", -w / 2 + 4, -d / 2 + 5, 0 },
			{ "chair", -w / 2 + 4, -d / 2 + 7, 180 },
		}
	end,
	police = function(w, d)
		return {
			{ "desk", -8, -2, 0 },
			{ "chair", -8, 0, 180 },
			{ "desk", 6, -2, 0 },
			{ "chair", 6, 0, 180 },
			{ "locker", -2, d / 2 - 1.5, 180 },
			{ "locker", -4.6, d / 2 - 1.5, 180 },
			{ "locker", 2.6, d / 2 - 1.5, 180 },
			{ "shelf", w / 2 - 1.3, 4, -90 },
		}
	end,
	warehouse = function(w, d)
		return {
			{ "rack", -12, d / 2 - 2.5, 180, { length = 12 } },
			{ "rack", 4, d / 2 - 2.5, 180, { length = 12 } },
			{ "crate", -16, 0 },
			{ "crate", -16, 3.4 },
			{ "crate", 12, 0, 0, { size = 3.6 } },
			{ "barrel", 16, -4 },
			{ "barrel", 18.6, -4 },
			{ "workbench", w / 2 - 2, 6, -90 },
		}
	end,
	barracks = function(_w, d)
		return {
			{ "bunk", -14, d / 2 - 4.2, 180 },
			{ "bunk", -8, d / 2 - 4.2, 180 },
			{ "bunk", 8, d / 2 - 4.2, 180 },
			{ "bunk", 14, d / 2 - 4.2, 180 },
			{ "locker", 2, d / 2 - 1.5, 180 },
			{ "table", 0, -3 },
			{ "crate", 16, -5, 0, { size = 2.6 } },
		}
	end,
	barn = function(w, _d)
		return {
			{ "hay", -12, 8 },
			{ "hay", -12, 4.2 },
			{ "hay", -8.5, 8 },
			{ "workbench", w / 2 - 2, 4, -90 },
			{ "crate", 12, -7 },
			{ "barrel", 9, 9 },
		}
	end,
	shed = function(w, d)
		return {
			{ "workbench", 0, d / 2 - 2, 180 },
			{ "barrel", -w / 2 + 2, -1 },
		}
	end,
}

-- Furnishes a building. floorFrame sits at floor level in the building's centre.
function Furniture.furnish(
	ctx,
	parent: Instance,
	floorFrame: CFrame,
	layoutName: string,
	w: number,
	d: number,
	lootTable: string?
)
	local layout = LAYOUTS[layoutName]
	if not layout then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "Furniture"
	local furnishCtx = { rng = ctx.rng, loot = ctx.loot, lootTable = lootTable }
	for _, entry in layout(w, d) do
		local builder = B[entry[1]]
		if builder then
			local frame = floorFrame * CFrame.new(entry[2], 0, entry[3]) * CFrame.Angles(0, math.rad(entry[4] or 0), 0)
			builder(furnishCtx, folder, frame, entry[5])
		end
	end
	folder.Parent = parent
end

Furniture.Builders = B

return Furniture

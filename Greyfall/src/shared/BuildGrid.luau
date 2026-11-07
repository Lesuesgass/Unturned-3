-- Snapping rules for base building, shared so the client preview and the server agree.
--
-- The world is divided into 8 x 8 stud cells aligned to the world axes.
--   Foundations fill a cell and rest on the ground (or line up with the foundation you aim at).
--   Walls and doorways stand on the edge of a foundation or floor cell, on the side you aim at.
--   Floors sit on top of walls, or above a foundation, or next to another floor.
--   Stairs fill a foundation or floor cell, rising away from you.
--   Doors go into doorways. Storage goes on any flat surface.
--
-- Every structure part carries attributes describing where it sits:
--   StructureId, Piece, Tier, CellX, CellZ, Base (floor level of the piece),
--   Axis and Sign (walls), Frame (CFrame of the wall's bottom centre).

local BuildingDefs = require(script.Parent.BuildingDefs)

local CELL = BuildingDefs.Cell
local WALL_H = BuildingDefs.WallHeight

local BuildGrid = {}

export type Input = {
	position: Vector3,
	normal: Vector3,
	part: BasePart?,
	look: Vector3,
}

export type Placement = {
	piece: string,
	cframe: CFrame,
	size: Vector3,
	shape: string, -- "block", "wedge" or "doorway"
	cellX: number,
	cellZ: number,
	base: number,
	axis: string?,
	sign: number?,
	frame: CFrame?,
	doorwayId: number?,
}

local function cellCenter(i: number): number
	return (i + 0.5) * CELL
end

local function cellIndex(v: number): number
	return math.floor(v / CELL)
end

local function signOf(v: number): number
	return if v >= 0 then 1 else -1
end

-- Unit vector along the dominant horizontal axis of v.
local function snapAxis(v: Vector3): Vector3
	if math.abs(v.X) > math.abs(v.Z) then
		return Vector3.new(signOf(v.X), 0, 0)
	end
	return Vector3.new(0, 0, signOf(v.Z))
end

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include

local function groundY(x: number, z: number, nearY: number): number?
	terrainParams.FilterDescendantsInstances = { workspace.Terrain }
	local result = workspace:Raycast(Vector3.new(x, nearY + 24, z), Vector3.new(0, -60, 0), terrainParams)
	if result and result.Material ~= Enum.Material.Water then
		return result.Position.Y
	end
	return nil
end

local function attr(part: Instance?, name: string): any
	return if part then part:GetAttribute(name) else nil
end

local function supportCell(part: BasePart?): (number?, number?, number?)
	local piece = attr(part, "Piece")
	if piece == "foundation" or piece == "floor" then
		return attr(part, "CellX"), attr(part, "CellZ"), attr(part, "Base")
	end
	return nil, nil, nil
end

local function foundation(input: Input): (Placement?, string?)
	local ci, cz, top
	if attr(input.part, "Piece") == "foundation" and math.abs(input.normal.Y) < 0.5 then
		local step = snapAxis(input.normal)
		ci = attr(input.part, "CellX") + step.X
		cz = attr(input.part, "CellZ") + step.Z
		top = attr(input.part, "Base")
	else
		local p = input.position + input.normal * 0.1
		ci, cz = cellIndex(p.X), cellIndex(p.Z)
		local center = groundY(cellCenter(ci), cellCenter(cz), input.position.Y)
		if not center then
			return nil, "Needs solid ground"
		end
		top = center + 1
	end

	local x, z = cellCenter(ci), cellCenter(cz)
	local lowest, highest = math.huge, -math.huge
	for _, offset in { { -3.5, -3.5 }, { 3.5, -3.5 }, { -3.5, 3.5 }, { 3.5, 3.5 }, { 0, 0 } } do
		local g = groundY(x + offset[1], z + offset[2], top)
		if not g then
			return nil, "Needs solid ground"
		end
		lowest = math.min(lowest, g)
		highest = math.max(highest, g)
	end
	if highest > top + 1.5 then
		return nil, "Ground is too uneven"
	end
	if top - lowest > 8 then
		return nil, "Ground is too steep"
	end
	local height = math.max(2, top - lowest + 1)
	return {
		piece = "foundation",
		cframe = CFrame.new(x, top - height / 2, z),
		size = Vector3.new(CELL, height, CELL),
		shape = "block",
		cellX = ci,
		cellZ = cz,
		base = top,
	}
end

local function wall(piece: string, input: Input): (Placement?, string?)
	local ci, cz, top = supportCell(input.part)
	if not ci then
		return nil, "Aim at a foundation or floor"
	end
	local x, z = cellCenter(ci), cellCenter(cz :: number)
	local offset = input.position - Vector3.new(x, 0, z)
	local axis, sign, frame
	if math.abs(offset.X) > math.abs(offset.Z) then
		axis, sign = "x", signOf(offset.X)
		frame = CFrame.new(x + sign * CELL / 2, top, z) * CFrame.Angles(0, math.pi / 2, 0)
	else
		axis, sign = "z", signOf(offset.Z)
		frame = CFrame.new(x, top, z + sign * CELL / 2)
	end
	return {
		piece = piece,
		cframe = frame * CFrame.new(0, WALL_H / 2, 0),
		size = Vector3.new(CELL, WALL_H, 1),
		shape = if piece == "doorway" then "doorway" else "block",
		cellX = ci,
		cellZ = cz :: number,
		base = top,
		axis = axis,
		sign = sign,
		frame = frame,
	}
end

local function floor(input: Input): (Placement?, string?)
	local part = input.part
	local piece = attr(part, "Piece")
	local ci, cz, top
	if piece == "wall" or piece == "doorway" then
		ci, cz = attr(part, "CellX"), attr(part, "CellZ")
		top = attr(part, "Base") + WALL_H
		local outward = if attr(part, "Axis") == "x"
			then Vector3.new(attr(part, "Sign"), 0, 0)
			else Vector3.new(0, 0, attr(part, "Sign"))
		if input.look:Dot(outward) > 0 then
			ci += outward.X
			cz += outward.Z
		end
	elseif piece == "floor" then
		local step = snapAxis(if math.abs(input.normal.Y) < 0.5 then input.normal else input.look)
		ci = attr(part, "CellX") + step.X
		cz = attr(part, "CellZ") + step.Z
		top = attr(part, "Base") - 1
	elseif piece == "foundation" then
		ci, cz = attr(part, "CellX"), attr(part, "CellZ")
		top = attr(part, "Base") + WALL_H
	else
		return nil, "Aim at a wall, floor or foundation"
	end
	return {
		piece = "floor",
		cframe = CFrame.new(cellCenter(ci), top + 0.5, cellCenter(cz)),
		size = Vector3.new(CELL, 1, CELL),
		shape = "block",
		cellX = ci,
		cellZ = cz,
		base = top + 1,
	}
end

local function stairs(input: Input): (Placement?, string?)
	local ci, cz, top = supportCell(input.part)
	if not ci then
		return nil, "Aim at a foundation or floor"
	end
	local direction = snapAxis(input.look)
	local center = Vector3.new(cellCenter(ci), top + WALL_H / 2, cellCenter(cz :: number))
	-- A wedge rises toward its back, so its front (low end) faces the player.
	return {
		piece = "stairs",
		cframe = CFrame.lookAt(center, center - direction),
		size = Vector3.new(CELL, WALL_H, CELL),
		shape = "wedge",
		cellX = ci,
		cellZ = cz :: number,
		base = top,
	}
end

local function door(input: Input): (Placement?, string?)
	local part = input.part
	if attr(part, "Piece") ~= "doorway" then
		return nil, "Aim at a doorway"
	end
	local frame: CFrame = attr(part, "Frame")
	return {
		piece = "door",
		cframe = frame * CFrame.new(0, 3.5, 0),
		size = Vector3.new(3.8, 6.9, 0.3),
		shape = "block",
		cellX = attr(part, "CellX"),
		cellZ = attr(part, "CellZ"),
		base = attr(part, "Base"),
		frame = frame,
		doorwayId = attr(part, "StructureId"),
	}
end

local function storage(piece: string, input: Input): (Placement?, string?)
	if input.normal.Y < 0.7 then
		return nil, "Needs a flat surface"
	end
	local size = BuildingDefs.Storage[piece].size
	local p = input.position
	local position = Vector3.new(math.round(p.X * 2) / 2, p.Y + size.Y / 2 + 0.05, math.round(p.Z * 2) / 2)
	local facing = snapAxis(-input.look)
	return {
		piece = piece,
		cframe = CFrame.lookAt(position, position + facing),
		size = size,
		shape = "block",
		cellX = cellIndex(p.X),
		cellZ = cellIndex(p.Z),
		base = p.Y,
	}
end

function BuildGrid.solve(piece: string, input: Input): (Placement?, string?)
	if piece == "foundation" then
		return foundation(input)
	elseif piece == "wall" or piece == "doorway" then
		return wall(piece, input)
	elseif piece == "floor" then
		return floor(input)
	elseif piece == "stairs" then
		return stairs(input)
	elseif piece == "door" then
		return door(input)
	elseif BuildingDefs.Storage[piece] then
		return storage(piece, input)
	end
	return nil, "Unknown piece"
end

-- Box used to check that a new piece does not overlap anything. It is shrunk a little so
-- pieces that merely touch (a wall on a foundation, two walls at a corner) are allowed.
function BuildGrid.clearanceSize(placement: Placement): Vector3
	local s = placement.size
	return Vector3.new(math.max(0.2, s.X - 1.2), math.max(0.2, s.Y - 1.2), math.max(0.2, s.Z - 1.2))
end

return BuildGrid

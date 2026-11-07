-- Building blocks for the world: walls with doors and windows, simple buildings,
-- towers, vehicles wrecks, fences, trees and rocks. Everything is made of plain parts.
--
-- Every builder receives a context table that collects:
--   ctx.loot  = { { position: Vector3, table: string } }
--   ctx.doors = { { part, closed: CFrame, open: CFrame } }
--   ctx.resources = { { part, parts, resource, yield } }  trees, rocks and wrecks that can be harvested

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)

local Structures = {}

local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material

local function newPart(className: string, parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanTouch = false -- nothing in the world uses Touched, so skip the physics work
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end
Structures.newPart = newPart

local function pick(rng: Random, list: { any }): any
	return list[rng:NextInteger(1, #list)]
end

local function addLoot(ctx, position: Vector3, lootTable: string)
	table.insert(ctx.loot, { position = position, table = lootTable })
end

-- Opening helpers. x is the opening centre along the wall.
local function Door(x: number)
	return { x = x, w = 5, y0 = 0, y1 = 8, kind = "door" }
end
local function Gap(x: number, w: number, h: number)
	return { x = x, w = w, y0 = 0, y1 = h, kind = "gap" }
end
local function Window(x: number, w: number?, y0: number?, y1: number?)
	return { x = x, w = w or 5, y0 = y0 or 3.5, y1 = y1 or 7.5, kind = "window" }
end
Structures.Door, Structures.Gap, Structures.Window = Door, Gap, Window

local function door(ctx, parent: Instance, frame: CFrame, o, thickness: number)
	local width = o.w - 0.2
	local hinge = frame * CFrame.new(o.x - o.w / 2 + 0.1, (o.y0 + o.y1) / 2, 0)
	local closed = hinge * CFrame.new(width / 2, 0, 0)
	local open = hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(width / 2, 0, 0)
	local part = newPart("Part", parent, {
		Name = "Door",
		Size = V(width, o.y1 - o.y0 - 0.1, math.min(thickness, 0.4)),
		CFrame = closed,
		Color = C(105, 80, 60),
		Material = M.Wood,
	})
	part:SetAttribute("Door", true)
	part:SetAttribute("Open", false)
	table.insert(ctx.doors, { part = part, closed = closed, open = open })
end

-- A straight wall. frame sits at the bottom centre of the wall, X runs along it.
function Structures.wall(
	ctx,
	parent: Instance,
	frame: CFrame,
	length: number,
	height: number,
	thickness: number,
	openings,
	style
)
	local sorted = table.clone(openings or {})
	table.sort(sorted, function(a, b)
		return a.x < b.x
	end)

	local function segment(x0: number, x1: number, y0: number, y1: number)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		newPart("Part", parent, {
			Size = V(x1 - x0, y1 - y0, thickness),
			CFrame = frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0),
			Color = style.color,
			Material = style.material,
		})
	end

	local cursor = -length / 2
	for _, o in sorted do
		local ox0, ox1 = o.x - o.w / 2, o.x + o.w / 2
		segment(cursor, ox0, 0, height)
		segment(ox0, ox1, 0, o.y0)
		segment(ox0, ox1, o.y1, height)
		if o.kind == "window" then
			newPart("Part", parent, {
				Size = V(o.w, o.y1 - o.y0, 0.2),
				CFrame = frame * CFrame.new(o.x, (o.y0 + o.y1) / 2, 0),
				Color = C(150, 165, 170),
				Material = M.Glass,
				Transparency = 0.55,
			})
		elseif o.kind == "door" then
			door(ctx, parent, frame, o, thickness)
		end
		cursor = ox1
	end
	segment(cursor, length / 2, 0, height)
end

local function sign(parent: Instance, frame: CFrame, text: string, width: number)
	local board = newPart("Part", parent, {
		Name = "Sign",
		Size = V(width, 2.6, 0.3),
		CFrame = frame,
		Color = C(200, 196, 182),
		Material = M.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.FontFace = Theme.FontBold
	label.TextScaled = true
	label.TextColor3 = C(48, 48, 44)
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.Parent = label
end

-- A rectangular building. base sits at ground level in the middle of the footprint,
-- the front wall faces base.LookVector.
function Structures.box(ctx, model: Instance, base: CFrame, spec)
	local w, d, h, t = spec.w, spec.d, spec.h, 1
	local floorTop = 0.4
	local style = { color = spec.wallColor, material = spec.wallMaterial or M.SmoothPlastic }

	newPart("Part", model, {
		Name = "Floor",
		Size = V(w, 5, d),
		CFrame = base * CFrame.new(0, floorTop - 2.5, 0),
		Color = spec.floorColor or C(110, 105, 95),
		Material = spec.floorMaterial or M.Concrete,
	})

	local y = floorTop
	Structures.wall(ctx, model, base * CFrame.new(0, y, -d / 2 + t / 2), w, h, t, spec.front, style)
	Structures.wall(
		ctx,
		model,
		base * CFrame.new(0, y, d / 2 - t / 2) * CFrame.Angles(0, math.pi, 0),
		w,
		h,
		t,
		spec.back,
		style
	)
	Structures.wall(
		ctx,
		model,
		base * CFrame.new(-w / 2 + t / 2, y, 0) * CFrame.Angles(0, math.pi / 2, 0),
		d - 2 * t,
		h,
		t,
		spec.left,
		style
	)
	Structures.wall(
		ctx,
		model,
		base * CFrame.new(w / 2 - t / 2, y, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		d - 2 * t,
		h,
		t,
		spec.right,
		style
	)

	local roofColor = spec.roofColor or C(70, 68, 66)
	newPart("Part", model, {
		Name = "Ceiling",
		Size = V(w, 1, d),
		CFrame = base * CFrame.new(0, y + h + 0.5, 0),
		Color = if spec.roof == "gable" then C(150, 145, 135) else roofColor,
		Material = M.Concrete,
	})

	if spec.roof == "gable" then
		local roofH = spec.roofH or 6
		local halfDepth = d / 2 + 1
		local cy = y + h + 1 + roofH / 2
		-- A wedge's slope rises from its front (-Z) edge to its back (+Z) edge.
		newPart("WedgePart", model, {
			Name = "Roof",
			Size = V(w + 2, roofH, halfDepth),
			CFrame = base * CFrame.new(0, cy, -halfDepth / 2),
			Color = roofColor,
			Material = spec.roofMaterial or M.Slate,
		})
		newPart("WedgePart", model, {
			Name = "Roof",
			Size = V(w + 2, roofH, halfDepth),
			CFrame = base * CFrame.new(0, cy, halfDepth / 2) * CFrame.Angles(0, math.pi, 0),
			Color = roofColor,
			Material = spec.roofMaterial or M.Slate,
		})
	else
		local top = y + h + 1
		for _, edge in { { 0, -d / 2, w, 0.6 }, { 0, d / 2, w, 0.6 }, { -w / 2, 0, 0.6, d }, { w / 2, 0, 0.6, d } } do
			newPart("Part", model, {
				Name = "Parapet",
				Size = V(edge[3], 1.4, edge[4]),
				CFrame = base * CFrame.new(edge[1], top + 0.7, edge[2]),
				Color = style.color,
				Material = style.material,
			})
		end
	end

	if spec.sign then
		local width = math.min(w - 4, #spec.sign * 1.6 + 4)
		sign(model, base * CFrame.new(0, y + h - 1.6, -d / 2 - 0.2), spec.sign, width)
	end

	local rng = ctx.rng
	for _ = 1, spec.loot or 0 do
		local lx = rng:NextNumber(-w / 2 + 3, w / 2 - 3)
		local lz = rng:NextNumber(-d / 2 + 3, d / 2 - 3)
		addLoot(ctx, (base * CFrame.new(lx, floorTop + 0.05, lz)).Position, spec.lootTable)
	end
end

local function verticalCylinder(
	parent: Instance,
	position: Vector3,
	diameter: number,
	height: number,
	color: Color3,
	material: Enum.Material
)
	return newPart("Part", parent, {
		Shape = Enum.PartType.Cylinder,
		Size = V(height, diameter, diameter),
		CFrame = CFrame.new(position + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
	})
end

local function railing(parent: Instance, center: CFrame, size: number, color: Color3)
	for _, side in
		{
			{ 0, -size / 2, size, 0.3 },
			{ 0, size / 2, size, 0.3 },
			{ -size / 2, 0, 0.3, size },
			{ size / 2, 0, 0.3, size },
		}
	do
		newPart("Part", parent, {
			Size = V(side[3], 3, side[4]),
			CFrame = center * CFrame.new(side[1], 1.5, side[2]),
			Color = color,
			Material = M.Metal,
			Transparency = 0.2,
		})
	end
end

local WALL_COLORS = {
	C(200, 195, 180),
	C(190, 180, 150),
	C(150, 160, 165),
	C(160, 110, 95),
	C(175, 170, 160),
	C(140, 150, 130),
}

-- Building types. footprint is the radius used to keep buildings apart.
Structures.Types = {
	house = {
		footprint = 17,
		build = function(ctx, model, base, info)
			Structures.box(ctx, model, base, {
				w = 26,
				d = 20,
				h = 10,
				wallColor = pick(ctx.rng, WALL_COLORS),
				wallMaterial = M.WoodPlanks,
				floorColor = C(120, 100, 80),
				floorMaterial = M.WoodPlanks,
				front = { Door(-5), Window(6) },
				back = { Window(-6), Window(6) },
				left = { Window(0) },
				right = { Window(0) },
				roof = "gable",
				roofH = 6,
				loot = 4,
				lootTable = info.lootTable or "Residential",
			})
		end,
	},
	-- Two-storey house with an inside staircase and loot on both floors.
	large_house = {
		footprint = 22,
		build = function(ctx, model, base, info)
			local rng = ctx.rng
			local w, d = 34, 26
			local groundH, upperH = 10, 9
			local floorTop = 0.4
			local style = { color = pick(rng, WALL_COLORS), material = M.WoodPlanks }
			local floorColor, floorMaterial = C(120, 100, 80), M.WoodPlanks
			local lootTable = info.lootTable or "Residential"

			newPart("Part", model, {
				Name = "Floor",
				Size = V(w, 5, d),
				CFrame = base * CFrame.new(0, floorTop - 2.5, 0),
				Color = floorColor,
				Material = floorMaterial,
			})

			local function storey(y: number, h: number, openings)
				Structures.wall(ctx, model, base * CFrame.new(0, y, -d / 2 + 0.5), w, h, 1, openings.front, style)
				Structures.wall(
					ctx,
					model,
					base * CFrame.new(0, y, d / 2 - 0.5) * CFrame.Angles(0, math.pi, 0),
					w,
					h,
					1,
					openings.back,
					style
				)
				Structures.wall(
					ctx,
					model,
					base * CFrame.new(-w / 2 + 0.5, y, 0) * CFrame.Angles(0, math.pi / 2, 0),
					d - 2,
					h,
					1,
					openings.left,
					style
				)
				Structures.wall(
					ctx,
					model,
					base * CFrame.new(w / 2 - 0.5, y, 0) * CFrame.Angles(0, -math.pi / 2, 0),
					d - 2,
					h,
					1,
					openings.right,
					style
				)
			end

			storey(floorTop, groundH, {
				front = { Door(-6), Window(5), Window(12) },
				back = { Window(-8), Window(8) },
				left = { Window(-5) },
				right = { Window(-5), Window(5) },
			})

			-- Upper floor with a stairwell gap in the back-left corner.
			local slabY = floorTop + groundH + 0.5
			local stairWidth, stairLength = 5.5, 12
			local gapX = -w / 2 + 7
			newPart("Part", model, {
				Name = "UpperFloor",
				Size = V(w - 7, 1, d),
				CFrame = base * CFrame.new((gapX + w / 2) / 2, slabY, 0),
				Color = floorColor,
				Material = floorMaterial,
			})
			newPart("Part", model, {
				Name = "UpperFloor",
				Size = V(7, 1, d - stairLength - 1),
				CFrame = base * CFrame.new((-w / 2 + gapX) / 2, slabY, -(stairLength + 1) / 2),
				Color = floorColor,
				Material = floorMaterial,
			})
			-- A wedge rises toward its back (+Z), so the stairs climb toward the back wall.
			newPart("WedgePart", model, {
				Name = "Stairs",
				Size = V(stairWidth, groundH + 0.5, stairLength),
				CFrame = base * CFrame.new(
					-w / 2 + 1 + stairWidth / 2,
					floorTop + (groundH + 0.5) / 2,
					d / 2 - 1 - stairLength / 2
				),
				Color = C(105, 85, 65),
				Material = M.WoodPlanks,
			})

			local upperY = slabY + 0.5
			storey(upperY, upperH, {
				front = { Window(-9), Window(0), Window(9) },
				back = { Window(-8), Window(8) },
				left = { Window(-5) },
				right = { Window(-5), Window(5) },
			})

			local top = upperY + upperH
			newPart("Part", model, {
				Name = "Ceiling",
				Size = V(w, 1, d),
				CFrame = base * CFrame.new(0, top + 0.5, 0),
				Color = C(150, 145, 135),
				Material = M.Concrete,
			})
			local roofH, halfDepth = 7, d / 2 + 1
			local roofColor = C(70, 68, 66)
			newPart("WedgePart", model, {
				Name = "Roof",
				Size = V(w + 2, roofH, halfDepth),
				CFrame = base * CFrame.new(0, top + 1 + roofH / 2, -halfDepth / 2),
				Color = roofColor,
				Material = M.Slate,
			})
			newPart("WedgePart", model, {
				Name = "Roof",
				Size = V(w + 2, roofH, halfDepth),
				CFrame = base * CFrame.new(0, top + 1 + roofH / 2, halfDepth / 2) * CFrame.Angles(0, math.pi, 0),
				Color = roofColor,
				Material = M.Slate,
			})

			for _ = 1, 4 do
				local lx = rng:NextNumber(-w / 2 + 9, w / 2 - 3)
				local lz = rng:NextNumber(-d / 2 + 3, d / 2 - 3)
				addLoot(ctx, (base * CFrame.new(lx, floorTop + 0.05, lz)).Position, lootTable)
			end
			for _ = 1, 4 do
				local lx = rng:NextNumber(gapX + 2, w / 2 - 3)
				local lz = rng:NextNumber(-d / 2 + 3, d / 2 - 3)
				addLoot(ctx, (base * CFrame.new(lx, upperY + 0.05, lz)).Position, lootTable)
			end
		end,
	},
	cabin = {
		footprint = 12,
		build = function(ctx, model, base, info)
			Structures.box(ctx, model, base, {
				w = 18,
				d = 14,
				h = 9,
				wallColor = C(115, 85, 60),
				wallMaterial = M.Wood,
				floorColor = C(100, 80, 60),
				floorMaterial = M.WoodPlanks,
				front = { Door(-3), Window(4.5, 4) },
				left = { Window(0, 4) },
				right = { Window(0, 4) },
				roof = "gable",
				roofH = 5,
				roofColor = C(60, 55, 50),
				loot = 2,
				lootTable = info.lootTable or "Residential",
			})
		end,
	},
	shed = {
		footprint = 8,
		build = function(ctx, model, base, info)
			Structures.box(ctx, model, base, {
				w = 12,
				d = 10,
				h = 8,
				wallColor = C(125, 120, 110),
				wallMaterial = M.CorrodedMetal,
				front = { Gap(0, 6, 6.5) },
				roof = "flat",
				roofColor = C(90, 88, 84),
				loot = 1,
				lootTable = info.lootTable or "Farm",
			})
		end,
	},
	barn = {
		footprint = 23,
		build = function(ctx, model, base)
			Structures.box(ctx, model, base, {
				w = 34,
				d = 26,
				h = 16,
				wallColor = C(130, 60, 50),
				wallMaterial = M.WoodPlanks,
				floorColor = C(110, 95, 70),
				floorMaterial = M.Ground,
				front = { Gap(0, 12, 13) },
				left = { Window(0, 4, 9, 12) },
				right = { Window(0, 4, 9, 12) },
				roof = "gable",
				roofH = 9,
				roofColor = C(80, 75, 70),
				roofMaterial = M.CorrodedMetal,
				loot = 3,
				lootTable = "Farm",
			})
		end,
	},
	store = {
		footprint = 23,
		build = function(ctx, model, base)
			Structures.box(ctx, model, base, {
				w = 36,
				d = 28,
				h = 12,
				wallColor = C(165, 160, 150),
				wallMaterial = M.Brick,
				front = { Window(-11, 9, 2, 9), Door(0), Window(11, 9, 2, 9) },
				back = { Door(12) },
				roof = "flat",
				sign = "GENERAL STORE",
				loot = 5,
				lootTable = "Store",
			})
		end,
	},
	clinic = {
		footprint = 20,
		build = function(ctx, model, base)
			Structures.box(ctx, model, base, {
				w = 30,
				d = 24,
				h = 11,
				wallColor = C(205, 205, 198),
				wallMaterial = M.Concrete,
				front = { Window(-8), Door(0), Window(8) },
				left = { Window(-4), Window(5) },
				right = { Window(-4), Window(5) },
				roof = "flat",
				sign = "CLINIC",
				loot = 4,
				lootTable = "Medical",
			})
		end,
	},
	police = {
		footprint = 21,
		build = function(ctx, model, base)
			Structures.box(ctx, model, base, {
				w = 32,
				d = 26,
				h = 12,
				wallColor = C(120, 130, 140),
				wallMaterial = M.Concrete,
				front = { Window(-9), Door(0), Window(9) },
				back = { Door(-8) },
				left = { Window(0) },
				right = { Window(0) },
				roof = "flat",
				sign = "POLICE",
				loot = 4,
				lootTable = "Police",
			})
		end,
	},
	warehouse = {
		footprint = 28,
		build = function(ctx, model, base, info)
			Structures.box(ctx, model, base, {
				w = 46,
				d = 30,
				h = 16,
				wallColor = info.military and C(95, 100, 75) or C(130, 125, 115),
				wallMaterial = M.CorrodedMetal,
				front = { Gap(-8, 14, 12), Door(12) },
				left = { Window(0, 8, 10, 13) },
				right = { Window(0, 8, 10, 13) },
				roof = "flat",
				roofColor = C(85, 85, 80),
				loot = 5,
				lootTable = info.military and "Military" or "Industrial",
			})
		end,
	},
	barracks = {
		footprint = 21,
		build = function(ctx, model, base)
			Structures.box(ctx, model, base, {
				w = 38,
				d = 18,
				h = 10,
				wallColor = C(100, 105, 80),
				wallMaterial = M.Concrete,
				front = { Window(-13), Door(-4), Window(5), Window(13) },
				back = { Window(-10), Window(0), Window(10) },
				roof = "flat",
				roofColor = C(80, 82, 70),
				loot = 4,
				lootTable = "Military",
			})
		end,
	},
	apartment = {
		footprint = 22,
		build = function(ctx, model, base)
			local rng = ctx.rng
			local height = rng:NextInteger(5, 10) * 9
			local color = pick(rng, { C(150, 145, 135), C(120, 115, 110), C(165, 155, 140), C(105, 110, 115) })
			newPart("Part", model, {
				Name = "Tower",
				Size = V(30, height, 30),
				CFrame = base * CFrame.new(0, height / 2 - 2, 0),
				Color = color,
				Material = M.Concrete,
			})
			-- Window bands on all four faces.
			for floor = 1, math.floor(height / 9) - 1 do
				local y = floor * 9 + 1
				for _, face in
					{ { 0, -15.1, 26, 0.2 }, { 0, 15.1, 26, 0.2 }, { -15.1, 0, 0.2, 26 }, { 15.1, 0, 0.2, 26 } }
				do
					newPart("Part", model, {
						Size = V(face[3], 3.2, face[4]),
						CFrame = base * CFrame.new(face[1], y, face[2]),
						Color = C(55, 62, 66),
						Material = M.Glass,
						Transparency = 0.15,
						CanCollide = false,
					})
				end
			end
		end,
	},
	silo = {
		footprint = 8,
		build = function(_ctx, model, base)
			local pos = base.Position
			verticalCylinder(model, pos - V(0, 1, 0), 12, 30, C(150, 150, 145), M.CorrodedMetal)
			newPart("Part", model, {
				Shape = Enum.PartType.Ball,
				Size = V(12, 12, 12),
				CFrame = CFrame.new(pos + V(0, 29, 0)),
				Color = C(140, 140, 135),
				Material = M.Metal,
			})
		end,
	},
	watchtower = {
		footprint = 8,
		build = function(ctx, model, base)
			local legH = 24
			local wood = C(100, 85, 65)
			for _, corner in { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
				newPart("Part", model, {
					Size = V(1, legH + 8, 1),
					CFrame = base * CFrame.new(corner[1], (legH + 8) / 2 - 1, corner[2]),
					Color = wood,
					Material = M.Wood,
				})
			end
			local platform = base * CFrame.new(0, legH, 0)
			newPart("Part", model, { Size = V(12, 1, 12), CFrame = platform, Color = wood, Material = M.WoodPlanks })
			railing(model, platform * CFrame.new(0, 0.5, 0), 12, C(90, 80, 65))
			newPart("Part", model, {
				Size = V(13, 0.6, 13),
				CFrame = base * CFrame.new(0, legH + 7.5, 0),
				Color = C(70, 72, 60),
				Material = M.CorrodedMetal,
			})
			newPart("TrussPart", model, {
				Size = V(2, legH + 2, 2),
				CFrame = base * CFrame.new(0, (legH + 2) / 2, -7),
				Color = C(80, 80, 78),
				Material = M.Metal,
			})
			addLoot(ctx, (platform * CFrame.new(2, 0.55, 2)).Position, "Military")
		end,
	},
	lighthouse = {
		footprint = 10,
		build = function(ctx, model, base)
			local pos = base.Position
			local height = 46
			for band = 0, 3 do
				local bandH = height / 4
				verticalCylinder(
					model,
					pos + V(0, band * bandH - 1, 0),
					14,
					bandH,
					if band % 2 == 0 then C(210, 208, 200) else C(150, 60, 55),
					M.Concrete
				)
			end
			local top = CFrame.new(pos + V(0, height - 1, 0)) * base.Rotation
			newPart("Part", model, { Size = V(18, 1, 18), CFrame = top, Color = C(70, 70, 70), Material = M.Metal })
			railing(model, top * CFrame.new(0, 0.5, 0), 18, C(60, 60, 60))
			newPart("Part", model, {
				Size = V(7, 6, 7),
				CFrame = top * CFrame.new(0, 3.5, 0),
				Color = C(200, 200, 180),
				Material = M.Glass,
				Transparency = 0.4,
			})
			local lamp = newPart("Part", model, {
				Shape = Enum.PartType.Ball,
				Size = V(3, 3, 3),
				CFrame = top * CFrame.new(0, 3.5, 0),
				Color = C(240, 230, 190),
				Material = M.Neon,
				CanCollide = false,
			})
			local light = Instance.new("PointLight")
			light.Range = 40
			light.Brightness = 2
			light.Color = C(255, 240, 200)
			light.Parent = lamp
			newPart("TrussPart", model, {
				Size = V(2, height, 2),
				CFrame = base * CFrame.new(0, height / 2 - 0.5, -8),
				Color = C(80, 80, 78),
				Material = M.Metal,
			})
			addLoot(ctx, (top * CFrame.new(5, 0.55, 5)).Position, "Residential")
		end,
	},
}

local CAR_COLORS = { C(110, 50, 45), C(70, 85, 100), C(150, 145, 130), C(60, 65, 60), C(120, 110, 80) }

function Structures.carWreck(ctx, parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Wreck"
	local color = pick(ctx.rng, CAR_COLORS)
	local tilt = base * CFrame.Angles(math.rad(ctx.rng:NextNumber(-3, 3)), 0, math.rad(ctx.rng:NextNumber(-4, 4)))
	local body = newPart(
		"Part",
		model,
		{ Size = V(6, 2.4, 13), CFrame = tilt * CFrame.new(0, 2.2, 0), Color = color, Material = M.CorrodedMetal }
	)
	newPart(
		"Part",
		model,
		{ Size = V(5.6, 2, 6.5), CFrame = tilt * CFrame.new(0, 4.4, 0.8), Color = color, Material = M.CorrodedMetal }
	)
	newPart("Part", model, {
		Size = V(5.4, 1.6, 0.2),
		CFrame = tilt * CFrame.new(0, 4.4, -2.5),
		Color = C(60, 65, 68),
		Material = M.Glass,
		Transparency = 0.3,
	})
	for _, wheel in { { -3, -4 }, { 3, -4 }, { -3, 4 }, { 3, 4 } } do
		newPart("Part", model, {
			Shape = Enum.PartType.Cylinder,
			Size = V(1, 2.4, 2.4),
			CFrame = tilt * CFrame.new(wheel[1], 1.1, wheel[2]),
			Color = C(35, 35, 35),
			Material = M.Rubber,
		})
	end
	model.Parent = parent
	addLoot(ctx, (base * CFrame.new(4.5, 0.1, 0)).Position, "Vehicle")
	local parts = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child:SetAttribute("Resource", "scrap")
			table.insert(parts, child)
		end
	end
	table.insert(ctx.resources, { part = body, parts = parts, resource = "scrap", yield = "scrap_metal" })
end

function Structures.fence(parent: Instance, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	local frame = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	newPart("Part", parent, {
		Name = "Fence",
		Size = V(length, 8, 0.3),
		CFrame = frame * CFrame.new(0, 4, 0),
		Color = C(120, 125, 120),
		Material = M.DiamondPlate,
		Transparency = 0.35,
	})
	newPart("Part", parent, {
		Name = "Post",
		Size = V(0.6, 9, 0.6),
		CFrame = CFrame.new(a + V(0, 4.5, 0)),
		Color = C(90, 90, 88),
		Material = M.Metal,
	})
end

local TREE_KINDS = {
	pine = { trunk = C(85, 65, 48), leavesA = C(55, 75, 50), leavesB = C(70, 85, 60), yield = "pine_log" },
	birch = { trunk = C(215, 210, 198), leavesA = C(120, 140, 70), leavesB = C(150, 160, 85), yield = "birch_log" },
	maple = { trunk = C(95, 70, 55), leavesA = C(150, 85, 50), leavesB = C(120, 110, 55), yield = "maple_log" },
}

-- kind is "pine", "birch" or "maple"; each drops its own kind of log.
function Structures.tree(ctx, parent: Instance, position: Vector3, kind: string)
	local rng = ctx.rng
	local style = TREE_KINDS[kind] or TREE_KINDS.pine
	local model = Instance.new("Model")
	model.Name = "Tree"
	local scale = rng:NextNumber(0.8, 1.3)
	local trunkH = (if kind == "pine" then 14 else 11) * scale
	local girth = (if kind == "birch" then 1.2 else 1.6) * scale
	local trunk = newPart("Part", model, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = V(trunkH, girth, girth),
		CFrame = CFrame.new(position + V(0, trunkH / 2 - 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = style.trunk,
		Material = M.Wood,
	})
	trunk:SetAttribute("Resource", "log")

	local parts = { trunk }
	local green = style.leavesA:Lerp(style.leavesB, rng:NextNumber())
	if kind == "pine" then
		for layer = 0, 2 do
			local size = (11 - layer * 3) * scale
			local leaves = newPart("Part", model, {
				Size = V(size, 4 * scale, size),
				CFrame = CFrame.new(position + V(0, (6 + layer * 4.2) * scale, 0))
					* CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0),
				Color = green,
				Material = M.Grass,
				CanCollide = false,
			})
			table.insert(parts, leaves)
		end
	else
		for _ = 1, 2 do
			local size = rng:NextNumber(7, 10) * scale
			local offset = V(rng:NextNumber(-1.5, 1.5), trunkH + rng:NextNumber(-1, 1.5), rng:NextNumber(-1.5, 1.5))
			local leaves = newPart("Part", model, {
				Shape = Enum.PartType.Ball,
				Size = V(size, size * (if kind == "birch" then 1.3 else 1), size),
				CFrame = CFrame.new(position + offset),
				Color = green,
				Material = M.Grass,
				CanCollide = false,
			})
			table.insert(parts, leaves)
		end
	end
	model.Parent = parent
	table.insert(ctx.resources, { part = trunk, parts = parts, resource = "log", yield = style.yield })
end

function Structures.rock(ctx, parent: Instance, position: Vector3)
	local rng = ctx.rng
	local size = rng:NextNumber(5, 13)
	local rock = newPart("Part", parent, {
		Name = "Rock",
		Size = V(size * rng:NextNumber(0.9, 1.4), size * rng:NextNumber(0.6, 0.9), size),
		CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)),
		Color = C(115, 112, 105),
		Material = M.Rock,
	})
	rock:SetAttribute("Resource", "stone")
	table.insert(ctx.resources, { part = rock, parts = { rock }, resource = "stone", yield = "stone" })
end

return Structures

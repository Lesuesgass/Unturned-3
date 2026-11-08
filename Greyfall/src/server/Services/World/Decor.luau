-- Small outdoor details that make the world feel lived in: street lamps, power poles,
-- fences, mailboxes, benches, bins, crop fields, hay bales, piers, boats, sandbags,
-- tents and bushes. Everything is a handful of anchored parts.

local Decor = {}

local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: { [string]: any }?
)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	-- Small props skip shadows; tall ones opt back in where it matters.
	p.CastShadow = size.Magnitude > 9
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- A lamp post. base sits on the ground, the arm reaches toward base.LookVector.
-- lit is false for every other lamp: the light pools overlap anyway and each light costs
-- rendering time.
function Decor.streetLamp(parent: Instance, base: CFrame, lit: boolean?)
	local metal = C(58, 60, 58)
	part(parent, V(0.5, 13, 0.5), base * CFrame.new(0, 6.5, 0), metal, M.Metal)
	part(parent, V(0.35, 0.35, 3), base * CFrame.new(0, 12.8, -1.4), metal, M.Metal)
	local head = part(
		parent,
		V(1.2, 0.5, 1.6),
		base * CFrame.new(0, 12.6, -2.8),
		C(235, 225, 190),
		M.Neon,
		{ CanCollide = false }
	)
	if lit == false then
		return
	end
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 26
	light.Angle = 110
	light.Brightness = 1.4
	light.Color = C(255, 228, 180)
	light.Shadows = false
	light.Parent = head
end

function Decor.powerPole(parent: Instance, base: CFrame)
	local wood = C(92, 72, 54)
	part(parent, V(0.8, 18, 0.8), base * CFrame.new(0, 8.5, 0), wood, M.Wood)
	part(parent, V(6, 0.4, 0.4), base * CFrame.new(0, 16.2, 0), wood, M.Wood)
	for _, x in { -2.6, 0, 2.6 } do
		part(parent, V(0.3, 0.5, 0.3), base * CFrame.new(x, 16.65, 0), C(90, 110, 100), M.Glass, { CanCollide = false })
	end
end

-- Picket fence from a to b, both on the ground.
function Decor.fence(parent: Instance, a: Vector3, b: Vector3, color: Color3?)
	local length = (b - a).Magnitude
	if length < 1 then
		return
	end
	local wood = color or C(200, 196, 182)
	local frame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
	part(parent, V(length, 0.3, 0.2), frame * CFrame.new(0, 1.2, 0), wood, M.WoodPlanks)
	part(parent, V(length, 0.3, 0.2), frame * CFrame.new(0, 2.6, 0), wood, M.WoodPlanks)
	local posts = math.max(2, math.floor(length / 4) + 1)
	for i = 0, posts - 1 do
		local x = -length / 2 + i * (length / (posts - 1))
		part(parent, V(0.35, 3.4, 0.35), frame * CFrame.new(x, 1.7, 0), wood, M.WoodPlanks)
	end
end

function Decor.mailbox(parent: Instance, base: CFrame, color: Color3)
	part(parent, V(0.3, 3.4, 0.3), base * CFrame.new(0, 1.7, 0), C(90, 70, 52), M.Wood)
	part(parent, V(0.9, 0.9, 1.6), base * CFrame.new(0, 3.8, 0), color, M.Metal)
end

function Decor.bench(parent: Instance, base: CFrame)
	local wood = C(120, 90, 62)
	part(parent, V(5, 0.3, 1.6), base * CFrame.new(0, 1.6, 0), wood, M.WoodPlanks)
	part(parent, V(5, 1.4, 0.25), base * CFrame.new(0, 2.6, 0.75), wood, M.WoodPlanks)
	for _, x in { -2.1, 2.1 } do
		part(parent, V(0.3, 1.5, 1.4), base * CFrame.new(x, 0.75, 0), C(55, 57, 55), M.Metal)
	end
end

function Decor.trashBin(parent: Instance, position: Vector3)
	local bin = part(
		parent,
		V(3, 2, 2),
		CFrame.new(position + V(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		C(70, 82, 70),
		M.Metal
	)
	bin.Shape = Enum.PartType.Cylinder
end

function Decor.hayBale(parent: Instance, position: Vector3, yaw: number)
	local bale = part(
		parent,
		V(3, 3.4, 3.4),
		CFrame.new(position + V(0, 1.7, 0)) * CFrame.Angles(0, yaw, math.pi / 2),
		C(196, 170, 100),
		M.Grass
	)
	bale.Shape = Enum.PartType.Cylinder
end

-- Rows of crops on a flat patch. base sits at ground level in the field's centre.
function Decor.cropField(parent: Instance, base: CFrame, width: number, depth: number, rng: Random)
	local crops = { C(120, 150, 70), C(190, 165, 80), C(95, 130, 60) }
	local color = crops[rng:NextInteger(1, #crops)]
	local rows = math.floor(width / 3)
	for i = 0, rows - 1 do
		local x = -width / 2 + 1.5 + i * 3
		part(
			parent,
			V(1.4, 1.6, depth),
			base * CFrame.new(x, 0.6, 0),
			color,
			M.Grass,
			{ CanCollide = false, CastShadow = false }
		)
	end
	local corners = {
		(base * CFrame.new(-width / 2 - 1, 0, -depth / 2 - 1)).Position,
		(base * CFrame.new(width / 2 + 1, 0, -depth / 2 - 1)).Position,
		(base * CFrame.new(width / 2 + 1, 0, depth / 2 + 1)).Position,
		(base * CFrame.new(-width / 2 - 1, 0, depth / 2 + 1)).Position,
	}
	for i = 1, 4 do
		if i ~= 1 then -- leave the front edge open
			Decor.fence(parent, corners[i], corners[i % 4 + 1], C(140, 115, 85))
		end
	end
end

-- A wooden pier from the shore out over the water, with boats moored alongside.
function Decor.pier(parent: Instance, start: Vector3, direction: Vector3, length: number, rng: Random)
	local deckY = math.max(start.Y, 0) + 2
	local mid = Vector3.new(start.X, deckY, start.Z) + direction * (length / 2)
	local frame = CFrame.lookAt(mid, mid + direction)
	part(parent, V(6, 0.6, length), frame, C(120, 95, 70), M.WoodPlanks)
	for z = -length / 2 + 2, length / 2, 6 do
		for _, x in { -2.6, 2.6 } do
			part(parent, V(0.6, 10, 0.6), frame * CFrame.new(x, -5, z), C(85, 66, 48), M.Wood)
		end
	end
	for i = 1, 2 do
		local side = if i == 1 then -1 else 1
		local boatFrame = frame
			* CFrame.new(side * 7, -1.4, -length / 2 + 8 + i * 9)
			* CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0)
		local hull = { C(170, 168, 160), C(90, 110, 130), C(140, 70, 55) }
		local color = hull[rng:NextInteger(1, #hull)]
		part(parent, V(5, 2, 11), boatFrame, color, M.Wood)
		local bow =
			part(parent, V(5, 2, 3), boatFrame * CFrame.new(0, 0, -7) * CFrame.Angles(0, math.pi, 0), color, M.Wood)
		local wedge = Instance.new("WedgePart")
		wedge.Anchored = true
		wedge.CanTouch = false
		wedge.Size = bow.Size
		wedge.CFrame = bow.CFrame
		wedge.Color = color
		wedge.Material = M.Wood
		wedge.Parent = parent
		bow:Destroy()
		part(parent, V(3, 2, 3.5), boatFrame * CFrame.new(0, 2, 2), C(200, 198, 190), M.SmoothPlastic)
	end
end

function Decor.sandbags(parent: Instance, base: CFrame, length: number)
	local color = C(150, 138, 105)
	for row = 0, 2 do
		local count = math.floor(length / 2)
		for i = 0, count - 1 do
			local offset = if row % 2 == 1 then 1 else 0
			local x = -length / 2 + 1 + i * 2 + offset
			if x < length / 2 then
				part(parent, V(2, 0.9, 1.2), base * CFrame.new(x, 0.45 + row * 0.9, 0), color, M.Fabric)
			end
		end
	end
end

function Decor.tent(parent: Instance, base: CFrame)
	local canvas = C(105, 110, 80)
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Anchored = true
		wedge.CanTouch = false
		wedge.Size = V(10, 5, 4)
		wedge.CFrame = base * CFrame.new(0, 2.5, side * 2) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
		wedge.Color = canvas
		wedge.Material = M.Fabric
		wedge.Parent = parent
	end
end

-- A bush of two or three overlapping clumps; some carry berries or flowers.
function Decor.bush(parent: Instance, position: Vector3, rng: Random)
	local greens = { C(78, 100, 58), C(95, 110, 62), C(70, 88, 55), C(105, 112, 66) }
	local base = rng:NextNumber(2.5, 4.5)
	local clumps = rng:NextInteger(2, 3)
	local top = 0
	for i = 1, clumps do
		local size = base * (if i == 1 then 1 else rng:NextNumber(0.6, 0.85))
		local offset = if i == 1
			then V(0, size * 0.3, 0)
			else V(rng:NextNumber(-1.2, 1.2), size * 0.35, rng:NextNumber(-1.2, 1.2)) * base / 3
		top = math.max(top, offset.Y + size / 2)
		part(parent, V(size, size, size), CFrame.new(position + offset), greens[rng:NextInteger(1, #greens)], M.Grass, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			CastShadow = false,
			CanQuery = false,
		})
	end
	if rng:NextNumber() < 0.3 then
		local dots = { C(150, 40, 45), C(210, 200, 120), C(180, 120, 170), C(235, 235, 230) }
		local color = dots[rng:NextInteger(1, #dots)]
		for _ = 1, 3 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local spot = position
				+ V(math.cos(angle) * base * 0.45, top * rng:NextNumber(0.5, 0.9), math.sin(angle) * base * 0.45)
			part(parent, V(0.5, 0.5, 0.5), CFrame.new(spot), color, M.SmoothPlastic, {
				Shape = Enum.PartType.Ball,
				CanCollide = false,
				CastShadow = false,
				CanQuery = false,
			})
		end
	end
end

-- Gas station forecourt: a roof on four pillars over two pumps. base faces the road.
function Decor.gasCanopy(parent: Instance, base: CFrame)
	local white = C(200, 198, 190)
	for _, corner in { { -9, -5 }, { 9, -5 }, { -9, 5 }, { 9, 5 } } do
		part(parent, V(0.8, 12, 0.8), base * CFrame.new(corner[1], 6, corner[2]), white, M.Concrete)
	end
	part(parent, V(22, 1.2, 14), base * CFrame.new(0, 12.6, 0), C(150, 55, 45), M.SmoothPlastic)
	for _, x in { -4, 4 } do
		part(parent, V(1.6, 0.4, 3.4), base * CFrame.new(x, 0.2, 0), C(120, 120, 115), M.Concrete)
		part(parent, V(1.2, 4.2, 1.8), base * CFrame.new(x, 2.5, 0), C(185, 70, 55), M.SmoothPlastic)
		part(parent, V(1.25, 1, 1.85), base * CFrame.new(x, 3.6, 0), C(40, 40, 40), M.Glass)
	end
end

-- Abandoned campsite: a tent, logs round a cold fire pit and a supply crate.
function Decor.campsite(parent: Instance, base: CFrame, rng: Random): Vector3
	Decor.tent(parent, base * CFrame.new(0, 0, 6) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		part(
			parent,
			V(0.9, 0.7, 0.9),
			base * CFrame.new(math.cos(a) * 1.6, 0.35, math.sin(a) * 1.6),
			C(105, 102, 96),
			M.Rock,
			{ CastShadow = false }
		)
	end
	part(
		parent,
		V(1.6, 0.3, 1.6),
		base * CFrame.new(0, 0.15, 0),
		C(30, 28, 26),
		M.Slate,
		{ CanCollide = false, CastShadow = false }
	)
	for _, a in { 0.4, 2.3, 4.2 } do
		local log = part(
			parent,
			V(4, 1.1, 1.1),
			base * CFrame.new(math.cos(a) * 4.2, 0.55, math.sin(a) * 4.2) * CFrame.Angles(0, -a + math.pi / 2, 0),
			C(100, 76, 54),
			M.Wood
		)
		log.Shape = Enum.PartType.Cylinder
	end
	local crate = base * CFrame.new(5.5, 0, -1)
	part(parent, V(2.4, 2.4, 2.4), crate * CFrame.new(0, 1.2, 0), C(130, 100, 64), M.WoodPlanks)
	return (crate * CFrame.new(0, 2.45, 0)).Position
end

-- Wooden hunting stand with a ladder. Returns the loot spot on its platform.
function Decor.huntingStand(parent: Instance, base: CFrame): Vector3
	local wood = C(105, 85, 62)
	local h = 14
	for _, corner in { { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } } do
		part(parent, V(0.6, h + 5, 0.6), base * CFrame.new(corner[1], (h + 5) / 2, corner[2]), wood, M.Wood)
	end
	part(parent, V(6.4, 0.5, 6.4), base * CFrame.new(0, h, 0), wood, M.WoodPlanks)
	for _, side in { { 0, 3.1, 6.4, 0.25 }, { -3.1, 0, 0.25, 6.4 }, { 3.1, 0, 0.25, 6.4 } } do
		part(parent, V(side[3], 2.2, side[4]), base * CFrame.new(side[1], h + 1.35, side[2]), wood, M.WoodPlanks)
	end
	part(parent, V(7, 0.4, 7), base * CFrame.new(0, h + 5.2, 0), C(70, 80, 55), M.Fabric)
	local ladder = Instance.new("TrussPart")
	ladder.Anchored = true
	ladder.CanTouch = false
	ladder.Size = V(2, h, 2)
	ladder.CFrame = base * CFrame.new(0, h / 2, -4.2)
	ladder.Color = wood
	ladder.Material = M.Wood
	ladder.Parent = parent
	return (base * CFrame.new(1.2, h + 0.3, 1.2)).Position
end

-- Town name board where a road enters a town.
function Decor.signpost(parent: Instance, base: CFrame, text: string)
	part(parent, V(0.4, 7, 0.4), base * CFrame.new(-3.2, 3.5, 0), C(80, 80, 78), M.Metal)
	part(parent, V(0.4, 7, 0.4), base * CFrame.new(3.2, 3.5, 0), C(80, 80, 78), M.Metal)
	local board = part(parent, V(7.4, 2.2, 0.25), base * CFrame.new(0, 6, 0), C(55, 85, 60), M.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = string.upper(text)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.TextColor3 = C(235, 235, 225)
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.18, 0)
		pad.PaddingBottom = UDim.new(0.18, 0)
		pad.PaddingLeft = UDim.new(0.05, 0)
		pad.PaddingRight = UDim.new(0.05, 0)
		pad.Parent = label
	end
end

return Decor

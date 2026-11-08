-- Survivor appearance options. Every player has the same blocky body and clothes; only the
-- head is customised. These tables match the approved avatar preview.
--
-- Face grids are 8 x 8, top row first. Letters: k dark, w white, r red, d dark red,
-- b bag shadow, h hair colour, . nothing (skin shows through).
-- Hair blocks are in head units: the head spans 0..8 on every axis; x runs left to right
-- as seen from the front, y bottom to top, z from the face (0) to the back (8).

local C = Color3.fromRGB

local Avatar = {}

Avatar.HeadSize = 1.4

Avatar.Skin = {
	{ name = "Porcelain", color = C(243, 220, 198) },
	{ name = "Fair", color = C(230, 194, 160) },
	{ name = "Light", color = C(210, 164, 124) },
	{ name = "Olive", color = C(180, 136, 94) },
	{ name = "Tan", color = C(152, 108, 69) },
	{ name = "Brown", color = C(122, 82, 51) },
	{ name = "Dark", color = C(92, 59, 36) },
	{ name = "Deep", color = C(67, 42, 25) },
}

Avatar.HairColours = {
	{ name = "Black", color = C(37, 33, 29) },
	{ name = "Dark brown", color = C(74, 48, 33) },
	{ name = "Brown", color = C(110, 74, 46) },
	{ name = "Auburn", color = C(132, 58, 36) },
	{ name = "Ginger", color = C(181, 100, 47) },
	{ name = "Blonde", color = C(207, 174, 104) },
	{ name = "Grey", color = C(140, 137, 131) },
	{ name = "White", color = C(216, 213, 205) },
}

Avatar.Ink = {
	k = C(29, 26, 23),
	w = C(233, 230, 220),
	r = C(179, 36, 31),
	d = C(90, 23, 20),
	b = C(107, 90, 102),
}

Avatar.Eyes = {
	{
		name = "Plain",
		grid = { "........", "........", "........", ".kk..kk.", ".kk..kk.", "........", "........", "........" },
	},
	{
		name = "Dots",
		grid = { "........", "........", "........", "..k..k..", "........", "........", "........", "........" },
	},
	{
		name = "Wide",
		grid = { "........", "........", "........", ".wk..kw.", ".ww..ww.", "........", "........", "........" },
	},
	{
		name = "Tired",
		grid = { "........", "........", "........", ".bb..bb.", ".kk..kk.", "........", "........", "........" },
	},
	{
		name = "Angry",
		grid = { "........", ".k....k.", "..k..k..", ".kk..kk.", ".kk..kk.", "........", "........", "........" },
	},
	{
		name = "Red eyes",
		grid = { "........", "........", "........", ".rr..rr.", ".rr..rr.", "........", "........", "........" },
	},
	{
		name = "Bloodshot",
		grid = { "........", "........", "........", ".wr..rw.", ".rk..kr.", "........", "........", "........" },
	},
	{
		name = "Closed",
		grid = { "........", "........", "........", "........", ".kk..kk.", "........", "........", "........" },
	},
}

Avatar.Mouths = {
	{
		name = "Neutral",
		grid = { "........", "........", "........", "........", "........", "........", "..kkkk..", "........" },
	},
	{
		name = "Grin",
		grid = { "........", "........", "........", "........", "........", "k......k", "kwwwwwwk", ".kkkkkk." },
	},
	{
		name = "Smile",
		grid = { "........", "........", "........", "........", "........", ".k....k.", "..kkkk..", "........" },
	},
	{
		name = "Frown",
		grid = { "........", "........", "........", "........", "........", "........", "..kkkk..", ".k....k." },
	},
	{
		name = "Gritted",
		grid = { "........", "........", "........", "........", "........", ".kkkkkk.", ".kwkwkk.", ".kkkkkk." },
	},
	{
		name = "Smirk",
		grid = { "........", "........", "........", "........", "........", ".....k..", "..kkk...", "........" },
	},
	{
		name = "Shocked",
		grid = { "........", "........", "........", "........", "........", "...kk...", "..kddk..", "...kk..." },
	},
}

-- side grids: column 1 is the edge nearest the face.
Avatar.FacialHair = {
	{ name = "None" },
	{
		name = "Stubble",
		front = { "........", "........", "........", "........", "........", "h......h", "h.h..h.h", ".h.hh.h." },
	},
	{
		name = "Moustache",
		front = { "........", "........", "........", "........", "........", ".hhhhhh.", "........", "........" },
	},
	{
		name = "Goatee",
		front = { "........", "........", "........", "........", "........", "........", "...hh...", "..hhhh.." },
	},
	{
		name = "Chin strap",
		front = { "........", "........", "........", "........", "h......h", "h......h", "h......h", ".hhhhhh." },
		side = { "........", "........", "........", "........", "hh......", "hh......", "hhh.....", "hhh....." },
	},
	{
		name = "Full beard",
		front = { "........", "........", "........", "........", "h......h", "hhhhhhhh", "hh....hh", "hhhhhhhh" },
		side = { "........", "........", "........", "hh......", "hhh.....", "hhhh....", "hhhh....", "hhhhh..." },
	},
}

Avatar.Hair = {
	{ name = "Bald", boxes = {} },
	{ name = "Buzz", boxes = { { -0.15, 7.4, -0.15, 8.15, 8.3, 8.15 }, { -0.15, 5.2, 6.6, 8.15, 7.4, 8.15 } } },
	{
		name = "Short",
		boxes = {
			{ -0.3, 7.2, -0.3, 8.3, 8.7, 8.3 },
			{ -0.3, 6.6, -0.3, 8.3, 7.2, 0.25 },
			{ -0.3, 4.2, 6.4, 8.3, 7.2, 8.3 },
			{ -0.3, 5.6, 3, 0.2, 7.2, 6.4 },
			{ 7.8, 5.6, 3, 8.3, 7.2, 6.4 },
		},
	},
	{
		name = "Side part",
		boxes = {
			{ -0.3, 7.2, -0.3, 8.3, 9.0, 8.3 },
			{ -0.3, 5.8, -0.3, 4.5, 7.2, 0.25 },
			{ -0.3, 4.2, 6.4, 8.3, 7.2, 8.3 },
			{ -0.3, 5.0, 2.5, 0.2, 7.2, 6.4 },
			{ 7.8, 5.6, 3, 8.3, 7.2, 6.4 },
		},
	},
	{ name = "Mohawk", boxes = { { 2.9, 7.8, -0.2, 5.1, 10.4, 8.3 }, { 3.1, 5.5, 7.8, 4.9, 7.8, 8.4 } } },
	{
		name = "Long",
		boxes = {
			{ -0.3, 7.2, -0.3, 8.3, 8.8, 8.3 },
			{ -0.3, 6.6, -0.3, 8.3, 7.2, 0.25 },
			{ -0.4, 0.8, 6.5, 8.4, 7.2, 8.5 },
			{ -0.45, 2.0, 2.6, 0.2, 7.2, 6.5 },
			{ 7.8, 2.0, 2.6, 8.45, 7.2, 6.5 },
		},
	},
	{
		name = "Bun",
		boxes = {
			{ -0.2, 7.3, -0.2, 8.2, 8.6, 8.2 },
			{ -0.2, 4.6, 6.6, 8.2, 7.3, 8.2 },
			{ 2.8, 7.4, 6.2, 5.2, 9.8, 8.6 },
		},
	},
}

-- The same clothes for everyone.
Avatar.Clothes = {
	shirt = C(93, 104, 107),
	sleeve = C(75, 85, 88),
	belt = C(47, 42, 36),
	pants = C(74, 65, 52),
	boots = C(45, 41, 37),
}

export type Choice = { skin: number, hairColour: number, hair: number, eyes: number, mouth: number, facial: number }

Avatar.Default = { skin = 3, hairColour = 2, hair = 3, eyes = 1, mouth = 1, facial = 1 } :: Choice

local LIMITS = {
	skin = Avatar.Skin,
	hairColour = Avatar.HairColours,
	hair = Avatar.Hair,
	eyes = Avatar.Eyes,
	mouth = Avatar.Mouths,
	facial = Avatar.FacialHair,
}

-- Turns anything (saved data, a client request) into a valid choice.
function Avatar.sanitize(raw: any): Choice
	local choice = table.clone(Avatar.Default)
	if typeof(raw) ~= "table" then
		return choice
	end
	for key, list in LIMITS do
		local value = raw[key]
		if typeof(value) == "number" and value == value and value % 1 == 0 and value >= 1 and value <= #list then
			choice[key] = value
		end
	end
	return choice
end

-- The face as an 8 x 8 grid of colours (nil where the skin shows through).
function Avatar.faceGrid(choice: Choice): { { Color3? } }
	local hairColour = Avatar.HairColours[choice.hairColour].color
	local grid = {}
	for y = 1, 8 do
		grid[y] = {}
	end
	local layers =
		{ Avatar.FacialHair[choice.facial].front, Avatar.Eyes[choice.eyes].grid, Avatar.Mouths[choice.mouth].grid }
	for _, layer in layers do
		if layer then
			for y, row in layer do
				for x = 1, 8 do
					local ch = string.sub(row, x, x)
					if ch == "h" then
						grid[y][x] = hairColour
					elseif ch ~= "." then
						grid[y][x] = Avatar.Ink[ch]
					end
				end
			end
		end
	end
	return grid
end

return Avatar

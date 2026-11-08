-- Gives every player the same blocky survivor body and builds their chosen head: a cube
-- with a pixel face, hair blocks and facial hair. Roblox avatars are not used.
-- Choices are saved per player in a DataStore when one is available (published games, or
-- Studio with API access turned on) and kept for the session either way.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Avatar = require(ReplicatedStorage.Shared.Avatar)
local Net = require(ReplicatedStorage.Shared.Net)

local AvatarService = {}

local choices: { [Player]: Avatar.Choice } = {}
local lastSave: { [Player]: number } = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("GreyfallAvatar")
end)

local function choiceOf(player: Player): Avatar.Choice
	return choices[player] or Avatar.Default
end

local function publish(player: Player)
	-- Clients read this to show the current look in the Customization screen.
	player:SetAttribute("Avatar", HttpService:JSONEncode(choiceOf(player)))
end

local function save(player: Player)
	if not store then
		return
	end
	local now = os.clock()
	if now - (lastSave[player] or -math.huge) < 6 then
		return -- DataStores limit how often a key can be written
	end
	lastSave[player] = now
	local data = choiceOf(player)
	task.spawn(function()
		pcall(function()
			store:SetAsync(tostring(player.UserId), data)
		end)
	end)
end

local function weldTo(part: BasePart, to: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = to
	weld.Part1 = part
	weld.Parent = part
end

local function pixelGui(parent: BasePart, face: Enum.NormalId, grid, mirror: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Avatar" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(80, 80)
	gui.LightInfluence = 1
	for y = 1, 8 do
		for x = 1, 8 do
			local color = grid[y][x]
			if color then
				local column = if mirror then 9 - x else x
				local pixel = Instance.new("Frame")
				pixel.BorderSizePixel = 0
				pixel.BackgroundColor3 = color
				pixel.Position = UDim2.fromOffset((column - 1) * 10, (y - 1) * 10)
				pixel.Size = UDim2.fromOffset(10, 10)
				pixel.Parent = gui
			end
		end
	end
	gui.Parent = parent
end

local function sideGrid(choice: Avatar.Choice)
	local side = Avatar.FacialHair[choice.facial].side
	if not side then
		return nil
	end
	local color = Avatar.HairColours[choice.hairColour].color
	local grid = {}
	for y, row in side do
		grid[y] = {}
		for x = 1, 8 do
			if string.sub(row, x, x) == "h" then
				grid[y][x] = color
			end
		end
	end
	return grid
end

local BODY_COLORS = {
	UpperTorso = "shirt",
	LowerTorso = "belt",
	LeftUpperArm = "sleeve",
	RightUpperArm = "sleeve",
	LeftUpperLeg = "pants",
	RightUpperLeg = "pants",
	LeftLowerLeg = "pants",
	RightLowerLeg = "pants",
	LeftFoot = "boots",
	RightFoot = "boots",
}

-- Colours the body and (re)builds the head on a character.
function AvatarService.dress(character: Model, choice: Avatar.Choice)
	local skin = Avatar.Skin[choice.skin].color
	local hairColour = Avatar.HairColours[choice.hairColour].color

	for _, child in character:GetChildren() do
		if
			child:IsA("Accessory")
			or child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic")
			or child:IsA("BodyColors")
		then
			child:Destroy()
		end
	end
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local clothing = BODY_COLORS[part.Name]
			part.Color = if clothing then Avatar.Clothes[clothing] else skin
		end
	end

	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	head.Transparency = 1
	for _, child in head:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	local old = character:FindFirstChild("AvatarHead")
	if old then
		old:Destroy()
	end

	local size = Avatar.HeadSize
	local cube = Instance.new("Part")
	cube.Name = "AvatarHead"
	cube.Size = Vector3.new(size, size, size)
	cube.CFrame = head.CFrame * CFrame.new(0, 0.1, 0)
	cube.Color = skin
	cube.Material = Enum.Material.SmoothPlastic
	cube.CanCollide = false
	cube.CanQuery = false
	cube.CanTouch = false
	cube.Massless = true
	cube.TopSurface = Enum.SurfaceType.Smooth
	cube.BottomSurface = Enum.SurfaceType.Smooth
	weldTo(cube, head)

	pixelGui(cube, Enum.NormalId.Front, Avatar.faceGrid(choice), false)
	local side = sideGrid(choice)
	if side then
		-- Seen from outside, the face edge is on the left of the left side and on the right
		-- of the right side.
		pixelGui(cube, Enum.NormalId.Left, side, false)
		pixelGui(cube, Enum.NormalId.Right, side, true)
	end

	local unit = size / 8
	for _, box in Avatar.Hair[choice.hair].boxes do
		local hair = Instance.new("Part")
		hair.Name = "Hair"
		hair.Size = Vector3.new((box[4] - box[1]) * unit, (box[5] - box[2]) * unit, (box[6] - box[3]) * unit)
		-- Head units to studs: x is mirrored (left as seen from the front is +X), z = 0 is the face.
		local cx = size / 2 - (box[1] + box[4]) / 2 * unit
		local cy = -size / 2 + (box[2] + box[5]) / 2 * unit
		local cz = -size / 2 + (box[3] + box[6]) / 2 * unit
		hair.CFrame = cube.CFrame * CFrame.new(cx, cy, cz)
		hair.Color = hairColour
		hair.Material = Enum.Material.SmoothPlastic
		hair.CanCollide = false
		hair.CanQuery = false
		hair.CanTouch = false
		hair.Massless = true
		hair.CastShadow = false
		hair.TopSurface = Enum.SurfaceType.Smooth
		hair.BottomSurface = Enum.SurfaceType.Smooth
		weldTo(hair, cube)
		hair.Parent = cube
	end
	cube.Parent = character
end

-- Spawns the player with the shared blocky body (no Roblox avatar).
function AvatarService.spawn(player: Player)
	local description = Instance.new("HumanoidDescription")
	local skin = Avatar.Skin[choiceOf(player).skin].color
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = Avatar.Clothes.shirt
	description.LeftLegColor = Avatar.Clothes.pants
	description.RightLegColor = Avatar.Clothes.pants
	local ok, err = pcall(function()
		player:LoadCharacterWithHumanoidDescription(description)
	end)
	if not ok then
		warn("[Greyfall] could not spawn with the survivor body:", err)
		player:LoadCharacter()
	end
end

function AvatarService.init()
	local function onPlayer(player: Player)
		local function dressCharacter(character: Model)
			character:WaitForChild("Head", 10)
			AvatarService.dress(character, choiceOf(player))
		end
		player.CharacterAdded:Connect(function(character)
			task.defer(dressCharacter, character)
		end)
		-- Roblox can add body parts a moment later; dressing again is harmless.
		player.CharacterAppearanceLoaded:Connect(dressCharacter)

		local loaded = nil
		if store then
			pcall(function()
				loaded = store:GetAsync(tostring(player.UserId))
			end)
		end
		if not choices[player] then
			choices[player] = Avatar.sanitize(loaded)
		end
		publish(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		choices[player] = nil
		lastSave[player] = nil
	end)

	Net.get("Avatar").OnServerEvent:Connect(function(player, raw)
		choices[player] = Avatar.sanitize(raw)
		publish(player)
		save(player)
		-- Applies straight away to the current character.
		if player.Character then
			AvatarService.dress(player.Character, choiceOf(player))
		end
	end)
end

return AvatarService

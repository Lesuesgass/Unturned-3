-- Main menu (work in progress) and loading screen.
--
-- The host picks singleplayer or multiplayer, a map and a difficulty, then starts the game.
-- Everyone else sees a waiting screen until the world is ready.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)
local Net = require(Shared.Net)
local Ui = require(script.Parent.Ui)

local Menu = {}

local player = Players.LocalPlayer

local gui: ScreenGui
local menuFrame: Frame
local waitFrame: Frame
local waitTitle: TextLabel
local waitDetail: TextLabel

local choice = {
	mode = Config.DefaultMode,
	map = Config.DefaultMap,
	difficulty = Config.DefaultDifficulty,
}

local MODES = {
	{ id = "Singleplayer", name = "Singleplayer", description = "A private world just for you." },
	{
		id = "Multiplayer",
		name = "Multiplayer",
		description = "Other players can join this server while you play.",
	},
}

local function sectionTitle(parent: Instance, order: number, text: string)
	Ui.label({
		Text = text,
		FontFace = Theme.FontBold,
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, 0, 0, 24),
		TextYAlignment = Enum.TextYAlignment.Bottom,
		LayoutOrder = order,
		Parent = parent,
	})
end

-- A row of mutually exclusive options with a description line underneath.
local function optionRow(parent: Instance, order: number, options, key: string)
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		Parent = parent,
	})
	Ui.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local description = Ui.label({
		TextColor3 = Theme.TextDim,
		TextSize = Theme.SmallTextSize + 1,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = order + 1,
		Parent = parent,
	})

	local buttons = {}
	local function refresh()
		for id, button in buttons do
			local selected = choice[key] == id
			local stroke = button:FindFirstChildOfClass("UIStroke")
			button.TextColor3 = if selected then Theme.Text else Theme.TextDim
			button.BackgroundColor3 = if selected then Theme.PanelHover else Theme.PanelLight
			if stroke then
				stroke.Color = if selected then Theme.Accent else Theme.Line
				stroke.Transparency = if selected then 0 else 0.5
			end
		end
		for _, option in options do
			if option.id == choice[key] then
				description.Text = option.description
			end
		end
	end

	for index, option in options do
		buttons[option.id] = Ui.button({
			Text = option.name,
			TextSize = Theme.TextSize,
			Size = UDim2.new(1 / #options, -6, 1, 0),
			LayoutOrder = index,
			Parent = row,
		}, function()
			choice[key] = option.id
			refresh()
		end)
	end
	refresh()
end

local function buildMenu()
	menuFrame = Ui.new("Frame", {
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	-- Keeps the mouse free on the menu.
	Ui.new(
		"TextButton",
		{ Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromOffset(0, 0), Parent = menuFrame }
	)

	local column = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 72, 0.5, 0),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = menuFrame,
	})
	Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = column })
	local scale = Ui.new("UIScale", { Parent = column })
	local function rescale()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (viewport.Y - 40) / 600, (viewport.X - 100) / 460)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	Ui.label({
		Text = "GREYFALL",
		FontFace = Theme.FontBold,
		TextSize = 44,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 1,
		Parent = column,
	})
	Ui.label({
		Text = "WORK IN PROGRESS BUILD",
		FontFace = Theme.FontMedium,
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 2,
		Parent = column,
	})

	sectionTitle(column, 10, "MODE")
	optionRow(column, 11, MODES, "mode")

	sectionTitle(column, 20, "MAP")
	optionRow(column, 21, Config.Maps, "map")

	sectionTitle(column, 30, "DIFFICULTY")
	local difficulties = {}
	for _, id in Config.DifficultyOrder do
		table.insert(difficulties, { id = id, name = id, description = Config.Difficulty[id].summary })
	end
	optionRow(column, 31, difficulties, "difficulty")

	Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10), LayoutOrder = 40, Parent = column })
	local start = Ui.button({
		Text = "START",
		FontFace = Theme.FontBold,
		TextSize = Theme.TitleTextSize,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 41,
		Parent = column,
	}, function()
		Net.get("Setup"):FireServer(choice.mode, choice.map, choice.difficulty)
	end)
	local stroke = start:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Accent
		stroke.Transparency = 0
	end
end

local function buildWaiting()
	waitFrame = Ui.new("Frame", {
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	waitTitle = Ui.label({
		Text = "GREYFALL",
		FontFace = Theme.FontBold,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(500, 36),
		Parent = waitFrame,
	})
	waitDetail = Ui.label({
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.51),
		Size = UDim2.fromOffset(500, 20),
		Parent = waitFrame,
	})
end

local function mapName(id: string?): string
	for _, entry in Config.Maps do
		if entry.id == id then
			return entry.name
		end
	end
	return id or ""
end

local function refresh()
	local state = workspace:GetAttribute("GameState")
	local isHost = workspace:GetAttribute("HostUserId") == player.UserId

	if state == "Ready" then
		menuFrame.Visible = false
		waitFrame.Visible = false
		return
	end
	if state == "Menu" and isHost then
		menuFrame.Visible = true
		waitFrame.Visible = false
		return
	end

	menuFrame.Visible = false
	waitFrame.Visible = true
	if state == "Menu" then
		waitTitle.Text = "GREYFALL"
		waitDetail.Text = "Waiting for the host to choose the game settings"
	else
		local map = workspace:GetAttribute("MapName") or mapName(choice.map)
		local difficulty = workspace:GetAttribute("Difficulty") or choice.difficulty
		waitTitle.Text = string.upper(map) .. "   " .. string.upper(difficulty)
		waitDetail.Text = workspace:GetAttribute("LoadingStage") or "Preparing the world"
	end
end

function Menu.init()
	gui = Ui.new("ScreenGui", {
		Name = "Menu",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildMenu()
	buildWaiting()
	for _, name in { "GameState", "HostUserId", "LoadingStage", "MapName", "Difficulty" } do
		workspace:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return Menu

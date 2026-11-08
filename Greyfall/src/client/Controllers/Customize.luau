-- Customization screen: skin tone, hair, hair colour, eyes, mouth and facial hair.
-- Opened from the main menu, or with K during play. Saving applies the look straight away.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Avatar = require(Shared.Avatar)
local Net = require(Shared.Net)
local Theme = require(Shared.Theme)
local Ui = require(script.Parent.Ui)

local Customize = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local root: Frame
local facePixels: { { Frame } } = {}
local headFrame: Frame
local hairBand: Frame
local summary: TextLabel
local refreshers: { () -> () } = {}
local choice: Avatar.Choice = table.clone(Avatar.Default)

local function readCurrent()
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Avatar") or "")
	end)
	choice = Avatar.sanitize(if ok then decoded else nil)
end

local function updatePreview()
	local skin = Avatar.Skin[choice.skin].color
	headFrame.BackgroundColor3 = skin
	local grid = Avatar.faceGrid(choice)
	for y = 1, 8 do
		for x = 1, 8 do
			local color = grid[y][x]
			local pixel = facePixels[y][x]
			pixel.BackgroundColor3 = color or skin
		end
	end
	local hair = Avatar.Hair[choice.hair]
	hairBand.Visible = #hair.boxes > 0
	hairBand.BackgroundColor3 = Avatar.HairColours[choice.hairColour].color
	summary.Text = string.format(
		"%s skin, %s hair (%s)\n%s eyes, %s mouth, %s",
		Avatar.Skin[choice.skin].name,
		hair.name,
		string.lower(Avatar.HairColours[choice.hairColour].name),
		Avatar.Eyes[choice.eyes].name,
		string.lower(Avatar.Mouths[choice.mouth].name),
		string.lower(Avatar.FacialHair[choice.facial].name) .. " facial hair"
	)
	for _, refresh in refreshers do
		refresh()
	end
end

local function section(parent: Instance, order: number, title: string)
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	Ui.label({
		Text = title,
		FontFace = Theme.FontBold,
		TextSize = Theme.CaptionTextSize,
		TextColor3 = Theme.TextDim,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		Parent = holder,
	})
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = holder,
	})
	Ui.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Wraps = true,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	return row
end

local function markSelected(button: GuiButton, selected: boolean)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Accent
		stroke.Thickness = 2
		stroke.Transparency = if selected then 0 else 1
	end
end

local function names(parent: Instance, order: number, title: string, list, key: string)
	local row = section(parent, order, title)
	local buttons = {}
	for index, entry in list do
		buttons[index] = Ui.button({
			Text = entry.name,
			TextSize = Theme.SmallTextSize,
			Size = UDim2.fromOffset(0, Theme.ControlHeight),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			Parent = row,
		}, function()
			choice[key] = index
			updatePreview()
		end)
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = buttons[index] })
	end
	table.insert(refreshers, function()
		for index, button in buttons do
			markSelected(button, choice[key] == index)
		end
	end)
end

local function swatches(parent: Instance, order: number, title: string, list, key: string)
	local row = section(parent, order, title)
	local buttons = {}
	for index, entry in list do
		buttons[index] = Ui.button({
			Size = UDim2.fromOffset(Theme.ControlHeight, Theme.ControlHeight),
			BackgroundColor3 = entry.color,
			LayoutOrder = index,
			Parent = row,
		}, function()
			choice[key] = index
			updatePreview()
		end)
	end
	table.insert(refreshers, function()
		for index, button in buttons do
			markSelected(button, choice[key] == index)
		end
	end)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "Customize",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 60,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(820, 560),
		BackgroundTransparency = 0,
		Parent = gui,
	})
	Ui.new(
		"TextButton",
		{ Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromOffset(0, 0), Parent = root }
	)
	local scale = Ui.new("UIScale", { Parent = root })
	local function rescale()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (viewport.X - 32) / 820, (viewport.Y - 32) / 560)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	Ui.label({
		Text = "CUSTOMIZATION",
		FontFace = Theme.FontBold,
		TextSize = Theme.TitleTextSize,
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.fromOffset(400, 26),
		Parent = root,
	})

	-- Preview: the head with its pixel face and a band showing the hair colour.
	local preview = Ui.new("Frame", {
		BackgroundColor3 = Theme.PanelLight,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(24, 60),
		Size = UDim2.fromOffset(240, 410),
		Parent = root,
	})
	headFrame = Ui.new("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(176, 176),
		Parent = preview,
	})
	hairBand = Ui.new("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(184, 26),
		Parent = preview,
	})
	for y = 1, 8 do
		facePixels[y] = {}
		for x = 1, 8 do
			facePixels[y][x] = Ui.new("Frame", {
				BorderSizePixel = 0,
				Position = UDim2.fromOffset((x - 1) * 22, (y - 1) * 22),
				Size = UDim2.fromOffset(22, 22),
				Parent = headFrame,
			})
		end
	end
	summary = Ui.label({
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.TextDim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(16, 256),
		Size = UDim2.new(1, -32, 0, 80),
		Parent = preview,
	})
	Ui.label({
		Text = "Everyone wears the same clothes. Your head is what makes you recognisable.",
		TextSize = Theme.CaptionTextSize,
		TextColor3 = Theme.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 16, 1, -64),
		Size = UDim2.new(1, -32, 0, 48),
		Parent = preview,
	})

	local options = Ui.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(284, 60),
		Size = UDim2.new(1, -308, 0, 410),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Line,
		Parent = root,
	})
	Ui.new("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder, Parent = options })
	swatches(options, 1, "SKIN TONE", Avatar.Skin, "skin")
	names(options, 2, "HAIR", Avatar.Hair, "hair")
	swatches(options, 3, "HAIR COLOUR", Avatar.HairColours, "hairColour")
	names(options, 4, "EYES", Avatar.Eyes, "eyes")
	names(options, 5, "MOUTH", Avatar.Mouths, "mouth")
	names(options, 6, "FACIAL HAIR", Avatar.FacialHair, "facial")

	local save = Ui.button({
		Text = "SAVE LOOK",
		FontFace = Theme.FontBold,
		TextSize = Theme.TextSize,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -20),
		Size = UDim2.fromOffset(180, Theme.ControlHeight),
		Parent = root,
	}, function()
		Net.get("Avatar"):FireServer(choice)
		Customize.close()
	end)
	Ui.makePrimary(save)
	Ui.button({
		Text = "CANCEL",
		FontFace = Theme.FontBold,
		TextSize = Theme.TextSize,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -216, 1, -20),
		Size = UDim2.fromOffset(140, Theme.ControlHeight),
		Parent = root,
	}, function()
		Customize.close()
	end)
end

function Customize.open()
	readCurrent()
	updatePreview()
	gui.Enabled = true
end

function Customize.close()
	gui.Enabled = false
end

function Customize.isOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function Customize.init()
	build()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.K then
			if gui.Enabled then
				Customize.close()
			else
				Customize.open()
			end
		elseif input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
			Customize.close()
		end
	end)
end

return Customize

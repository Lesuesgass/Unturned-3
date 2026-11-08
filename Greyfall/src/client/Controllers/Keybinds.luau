-- Controls overlay. H shows or hides the list of keys; a small hint in the corner reminds
-- new players it exists.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Ui = require(script.Parent.Ui)
local Hud = require(script.Parent.Hud)

local Keybinds = {}

local player = Players.LocalPlayer

-- Grouped so related controls sit together. Edit this list if you change a key binding.
local SECTIONS = {
	{
		title = "MOVEMENT",
		keys = {
			{ "W A S D", "Move" },
			{ "Space", "Jump" },
			{ "Left Shift", "Sprint (uses stamina)" },
			{ "V", "First or third person" },
		},
	},
	{
		title = "COMBAT",
		keys = {
			{ "Left click", "Attack or shoot" },
			{ "Left click", "Punch with empty hands" },
			{ "Hold left click", "Automatic fire" },
			{ "R", "Reload" },
			{ "1 to 5", "Equip hotbar slot, again to put away" },
			{ "Left click", "Use the equipped bandage, food or drink" },
		},
	},
	{
		title = "ITEMS",
		keys = {
			{ "F", "Pick up, open doors and storage" },
			{ "Tab or I", "Inventory" },
			{ "C", "Crafting" },
			{ "Escape", "Close the panel" },
		},
	},
	{
		title = "BUILDING AND RAIDING",
		keys = {
			{ "Left click", "Place the equipped piece" },
			{ "Left click", "Plant the equipped charge" },
			{ "Left click", "Repair (hammer or blowtorch)" },
			{ "X", "Salvage your own piece (hammer)" },
		},
	},
	{
		title = "INTERFACE",
		keys = {
			{ "H", "Show or hide this list" },
			{ "K", "Customize your look" },
		},
	},
}

local overlay: Frame

local function build(gui: ScreenGui)
	overlay = Ui.panel({
		Name = "Keybinds",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = gui,
	})
	Ui.padding(16).Parent = overlay
	Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = overlay })

	local scale = Ui.new("UIScale", { Parent = overlay })
	local function rescale()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (viewport.X - 32) / 560, (viewport.Y - 32) / 620)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	Ui.label({
		Text = "CONTROLS",
		FontFace = Theme.FontBold,
		TextSize = Theme.TitleTextSize,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = nextOrder(),
		Parent = overlay,
	})

	for _, section in SECTIONS do
		Ui.label({
			Text = section.title,
			FontFace = Theme.FontBold,
			TextSize = Theme.SmallTextSize,
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(1, 0, 0, 22),
			TextYAlignment = Enum.TextYAlignment.Bottom,
			LayoutOrder = nextOrder(),
			Parent = overlay,
		})
		for _, entry in section.keys do
			local row = Ui.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 22),
				LayoutOrder = nextOrder(),
				Parent = overlay,
			})
			local key = Ui.new("Frame", {
				BackgroundColor3 = Theme.PanelLight,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(150, 20),
				Parent = row,
			})
			Ui.label({
				Text = entry[1],
				FontFace = Theme.FontMedium,
				TextSize = Theme.SmallTextSize,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = key,
			})
			Ui.label({
				Text = entry[2],
				TextSize = Theme.SmallTextSize,
				Position = UDim2.fromOffset(164, 0),
				Size = UDim2.new(1, -164, 1, 0),
				Parent = row,
			})
		end
	end

	-- Corner hint, under the clock.
	Ui.label({
		Text = "H   Controls",
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.TextDim,
		Position = UDim2.fromOffset(16, 30),
		Size = UDim2.fromOffset(200, 16),
		Parent = gui,
	})
end

function Keybinds.toggle()
	overlay.Visible = not overlay.Visible
end

function Keybinds.init()
	local gui = Ui.new("ScreenGui", {
		Name = "Keybinds",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
	})
	build(gui)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			Keybinds.toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
			overlay.Visible = false
		end
	end)

	task.delay(4, function()
		Hud.notify("Press H to see the controls")
	end)
end

return Keybinds

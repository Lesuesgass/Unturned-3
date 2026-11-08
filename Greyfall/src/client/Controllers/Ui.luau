-- Small helpers for building interface elements in the game's style.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)

local Ui = {}

-- The one filled, accent-coloured button on a screen: the main action.
function Ui.makePrimary(button: TextButton)
	button.BackgroundColor3 = Theme.Accent
	button.TextColor3 = Theme.Panel
	button:SetAttribute("Primary", true)
end

function Ui.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

-- Panels and buttons are set apart by their fill alone. The stroke exists so a selected or
-- active element can light it up in the accent colour; it is invisible otherwise.
function Ui.stroke(transparency: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = Theme.Line,
		Thickness = 1,
		Transparency = transparency or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Ui.new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

function Ui.panel(props: { [string]: any }): Frame
	local frame = Ui.new("Frame", {
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		BorderSizePixel = 0,
	})
	for key, value in props do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	Ui.stroke().Parent = frame
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

function Ui.label(props: { [string]: any }): TextLabel
	local label = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextColor3 = Theme.Text,
		TextSize = Theme.TextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

function Ui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local button = Ui.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PanelLight,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
		FontFace = Theme.FontMedium,
		TextColor3 = Theme.Text,
		TextSize = Theme.SmallTextSize,
		Text = "",
	})
	for key, value in props do
		if key ~= "Parent" then
			(button :: any)[key] = value
		end
	end
	Ui.stroke().Parent = button
	button.MouseEnter:Connect(function()
		if button.Active and not button:GetAttribute("Primary") then
			button.BackgroundColor3 = Theme.PanelHover
		end
	end)
	button.MouseLeave:Connect(function()
		if not button:GetAttribute("Primary") then
			button.BackgroundColor3 = props.BackgroundColor3 or Theme.PanelLight
		end
	end)
	button.Activated:Connect(function()
		if button.Active then
			onClick()
		end
	end)
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
end

return Ui

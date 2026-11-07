-- Inventory, crafting and storage panel.
--   I opens the inventory, C opens crafting, Escape or the same key closes it.
--   Opening a storage container shows its contents in a third column.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Theme)
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Net = require(Shared.Net)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Panel = {}

local player = Players.LocalPlayer
local action = Net.get("Action")

local gui: ScreenGui
local root: Frame
local tabButtons = {}
local weightLabel: TextLabel
local listFrame: ScrollingFrame
local storageColumn: Frame
local storageTitle: TextLabel
local storageList: ScrollingFrame
local details: Frame

local tab = "inventory"
local selection: { source: string, uid: string }? = nil
local selectedRecipe: string? = nil
local craftCategory = "Survival"

local function scrolling(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local frame = Ui.new("ScrollingFrame", {
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Line,
		Parent = parent,
	})
	Ui.stroke(0.5).Parent = frame
	Ui.padding(4).Parent = frame
	Ui.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	return frame
end

local function row(
	parent: Instance,
	order: number,
	left: string,
	right: string,
	selected: boolean,
	onClick: () -> ()
): TextButton
	local button = Ui.button({
		Size = UDim2.new(1, -4, 0, 26),
		LayoutOrder = order,
		BackgroundColor3 = if selected then Theme.PanelHover else Theme.PanelLight,
		Parent = parent,
	}, onClick)
	if selected then
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.Accent
			stroke.Transparency = 0
		end
	end
	Ui.label({
		Text = left,
		TextSize = Theme.SmallTextSize + 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -90, 1, 0),
		Parent = button,
	})
	Ui.label({
		Text = right,
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -88, 0, 0),
		Size = UDim2.new(0, 80, 1, 0),
		Parent = button,
	})
	return button
end

local function header(parent: Instance, order: number, text: string)
	Ui.label({
		Text = text,
		FontFace = Theme.FontBold,
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.Accent,
		Size = UDim2.new(1, -4, 0, 20),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function detailButton(text: string, order: number, onClick: () -> ()): TextButton
	return Ui.button({ Text = text, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = details }, onClick)
end

local function stackLabel(stack): (string, string)
	local def = Items.get(stack.id)
	local name = if def then def.name else stack.id
	local right
	if def and def.category == "Gun" then
		right = `{stack.mag} rds`
	else
		right = `x{stack.count}`
	end
	if def then
		right ..= string.format("  %.1f", def.weight * stack.count)
	end
	return name, right
end

local function findStored(uid: string)
	if not State.storage then
		return nil
	end
	for _, stack in State.storage.items do
		if stack.uid == uid then
			return stack
		end
	end
	return nil
end

local refresh: () -> ()

local function inventoryDetails()
	Ui.clear(details)
	local stack = if selection and selection.source == "inv" then State.find(selection.uid) else nil
	local stored = if selection and selection.source == "store" then findStored(selection.uid) else nil
	local current = stack or stored
	local def = current and Items.get(current.id)

	if not def then
		Ui.label({
			Text = "Select an item",
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = details,
		})
		if State.pack ~= "" then
			local packDef = Items.get(State.pack)
			Ui.label({
				Text = `Wearing: {packDef and packDef.name or State.pack}`,
				TextSize = Theme.SmallTextSize,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 2,
				Parent = details,
			})
			detailButton("Take off pack", 3, function()
				action:FireServer("RemovePack")
			end)
		end
		return
	end

	Ui.label({
		Text = def.name,
		FontFace = Theme.FontBold,
		TextSize = Theme.TitleTextSize - 2,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1,
		Parent = details,
	})
	Ui.label({
		Text = def.description,
		TextColor3 = Theme.TextDim,
		TextSize = Theme.SmallTextSize,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 2,
		Parent = details,
	})
	Ui.label({
		Text = Items.summary(def),
		TextSize = Theme.SmallTextSize,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 3,
		Parent = details,
	})

	if stored then
		detailButton("Take 1", 10, function()
			action:FireServer("StoreTake", stored.uid, 1)
		end)
		detailButton("Take all", 11, function()
			action:FireServer("StoreTake", stored.uid, stored.count)
		end)
		return
	end

	local uid = stack.uid
	if Items.isConsumable(def) then
		detailButton(
			if def.category == "Water" then "Drink" else if def.category == "Food" then "Eat" else "Use",
			10,
			function()
				action:FireServer("Use", uid)
			end
		)
	elseif def.category == "Backpack" then
		detailButton("Wear", 10, function()
			action:FireServer("Use", uid)
		end)
	elseif Items.isEquippable(def) then
		detailButton("Equip", 10, function()
			action:FireServer("Use", uid)
		end)
		local slotRow = Ui.new(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 11, Parent = details }
		)
		Ui.new(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = slotRow }
		)
		for slot = 1, 5 do
			Ui.button(
				{ Text = tostring(slot), Size = UDim2.new(0.2, -4, 1, 0), LayoutOrder = slot, Parent = slotRow },
				function()
					action:FireServer("Assign", uid, slot)
				end
			)
		end
	end
	if State.storage then
		detailButton("Store 1", 12, function()
			action:FireServer("StorePut", uid, 1)
		end)
		detailButton("Store all", 13, function()
			action:FireServer("StorePut", uid, stack.count)
		end)
	end
	detailButton("Drop 1", 14, function()
		action:FireServer("Drop", uid, 1)
	end)
	if stack.count > 1 then
		detailButton("Drop all", 15, function()
			action:FireServer("Drop", uid, stack.count)
		end)
	end
end

local function craftDetails()
	Ui.clear(details)
	local recipe = selectedRecipe and Recipes.get(selectedRecipe)
	local output = recipe and Items.get(recipe.output)
	if not recipe or not output then
		Ui.label({
			Text = "Select a recipe",
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = details,
		})
		return
	end
	local title = output.name .. (if recipe.count > 1 then ` x{recipe.count}` else "")
	Ui.label({
		Text = title,
		FontFace = Theme.FontBold,
		TextSize = Theme.TitleTextSize - 2,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1,
		Parent = details,
	})
	Ui.label({
		Text = output.description,
		TextColor3 = Theme.TextDim,
		TextSize = Theme.SmallTextSize,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 2,
		Parent = details,
	})
	local ready = true
	local order = 3
	header(details, order, "NEEDS")
	for _, input in recipe.inputs do
		order += 1
		local have = State.count(input.id)
		local def = Items.get(input.id)
		ready = ready and have >= input.count
		Ui.label({
			Text = `{def and def.name or input.id}   {have} / {input.count}`,
			TextSize = Theme.SmallTextSize + 1,
			TextColor3 = if have >= input.count then Theme.Text else Theme.Danger,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = order,
			Parent = details,
		})
	end
	if #recipe.requires > 0 then
		order += 1
		header(details, order, "TOOLS")
		for _, tool in recipe.requires do
			order += 1
			local have = State.count(tool) > 0
			local def = Items.get(tool)
			ready = ready and have
			Ui.label({
				Text = def and def.name or tool,
				TextSize = Theme.SmallTextSize + 1,
				TextColor3 = if have then Theme.Text else Theme.Danger,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = order,
				Parent = details,
			})
		end
	end
	local button = detailButton("Craft", 100, function()
		action:FireServer("Craft", recipe.id)
	end)
	button.Active = ready
	button.TextColor3 = if ready then Theme.Text else Theme.TextDim
end

local function fillInventory()
	Ui.clear(listFrame)
	local sorted = table.clone(State.inventory)
	table.sort(sorted, function(a, b)
		local da, db = Items.get(a.id), Items.get(b.id)
		local ca, cb = da and da.category or "", db and db.category or ""
		if ca ~= cb then
			return ca < cb
		end
		return (da and da.name or a.id) < (db and db.name or b.id)
	end)
	local lastCategory = nil
	local order = 0
	for _, stack in sorted do
		local def = Items.get(stack.id)
		local category = def and def.category or "Other"
		if category ~= lastCategory then
			order += 1
			header(listFrame, order, string.upper(category))
			lastCategory = category
		end
		order += 1
		local name, right = stackLabel(stack)
		local selected = selection ~= nil and selection.source == "inv" and selection.uid == stack.uid
		row(listFrame, order, name, right, selected, function()
			selection = { source = "inv", uid = stack.uid }
			refresh()
		end)
	end
	if #sorted == 0 then
		Ui.label({
			Text = "Nothing carried",
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = listFrame,
		})
	end
end

local function fillStorage()
	storageColumn.Visible = State.storage ~= false and tab == "inventory"
	if not State.storage then
		return
	end
	storageTitle.Text = `{State.storage.name}   {#State.storage.items} / {State.storage.slots}`
	Ui.clear(storageList)
	for index, stack in State.storage.items do
		local name, right = stackLabel(stack)
		local selected = selection ~= nil and selection.source == "store" and selection.uid == stack.uid
		row(storageList, index, name, right, selected, function()
			selection = { source = "store", uid = stack.uid }
			refresh()
		end)
	end
end

local function fillCrafting()
	Ui.clear(listFrame)
	local order = 0
	-- Category switcher across the top of the list.
	local bar = Ui.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 26), LayoutOrder = 0, Parent = listFrame }
	)
	Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), Parent = bar })
	for index, category in Recipes.Categories do
		local active = category == craftCategory
		local button = Ui.button({
			Text = category,
			TextSize = Theme.SmallTextSize - 1,
			Size = UDim2.new(1 / #Recipes.Categories, -3, 1, 0),
			LayoutOrder = index,
			BackgroundColor3 = if active then Theme.PanelHover else Theme.PanelLight,
			Parent = bar,
		}, function()
			craftCategory = category
			selectedRecipe = nil
			refresh()
		end)
		button.TextColor3 = if active then Theme.Accent else Theme.Text
	end
	for _, recipe in Recipes.List do
		if recipe.category == craftCategory then
			order += 1
			local output = Items.get(recipe.output)
			local craftable = true
			for _, input in recipe.inputs do
				craftable = craftable and State.count(input.id) >= input.count
			end
			for _, tool in recipe.requires do
				craftable = craftable and State.count(tool) > 0
			end
			local name = (output and output.name or recipe.output)
				.. (if recipe.count > 1 then ` x{recipe.count}` else "")
			local button = row(
				listFrame,
				order,
				name,
				if craftable then "ready" else "",
				selectedRecipe == recipe.id,
				function()
					selectedRecipe = recipe.id
					refresh()
				end
			)
			if not craftable then
				local label = button:FindFirstChildOfClass("TextLabel")
				if label then
					label.TextColor3 = Theme.TextDim
				end
			end
		end
	end
end

function refresh()
	if not root.Visible then
		return
	end
	weightLabel.Text = string.format("%.1f / %.1f kg", State.weight, State.capacity)
	for name, button in tabButtons do
		button.TextColor3 = if name == tab then Theme.Accent else Theme.TextDim
	end
	if tab == "inventory" then
		fillInventory()
		fillStorage()
		inventoryDetails()
	else
		storageColumn.Visible = false
		fillCrafting()
		craftDetails()
	end
end

function Panel.isOpen(): boolean
	return root.Visible
end

function Panel.open(which: string)
	tab = which
	root.Visible = true
	State.panelOpen = true
	refresh()
end

function Panel.close()
	root.Visible = false
	State.panelOpen = false
	selection = nil
	if State.storage then
		action:FireServer("StoreClose")
	end
end

function Panel.toggle(which: string)
	if root.Visible and tab == which then
		Panel.close()
	else
		Panel.open(which)
	end
end

function Panel.init()
	gui = Ui.new("ScreenGui", {
		Name = "Panel",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(800, 470),
		Visible = false,
		Parent = gui,
	})
	Ui.new("UISizeConstraint", { MaxSize = Vector2.new(800, 470) }).Parent = root
	-- Shrink on small screens.
	local scale = Ui.new("UIScale", { Parent = root })
	local function rescale()
		local viewport = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1, (viewport.X - 32) / 800, (viewport.Y - 32) / 470)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- A modal button keeps the mouse free while the panel is open, even in first person.
	Ui.new(
		"TextButton",
		{ Modal = true, BackgroundTransparency = 1, Text = "", Size = UDim2.fromOffset(0, 0), Parent = root }
	)

	for index, entry in { { "inventory", "INVENTORY  [I]" }, { "crafting", "CRAFTING  [C]" } } do
		tabButtons[entry[1]] = Ui.button({
			Text = entry[2],
			FontFace = Theme.FontBold,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12 + (index - 1) * 150, 8),
			Size = UDim2.fromOffset(140, 26),
			Parent = root,
		}, function()
			tab = entry[1]
			selection = nil
			refresh()
		end)
	end
	weightLabel = Ui.label({
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.TextDim,
		Position = UDim2.new(1, -212, 0, 10),
		Size = UDim2.fromOffset(200, 22),
		Parent = root,
	})

	listFrame = scrolling(root, UDim2.fromOffset(12, 42), UDim2.new(0, 300, 1, -54))
	details = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(324, 42),
		Size = UDim2.new(0, 220, 1, -54),
		Parent = root,
	})
	Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = details })

	storageColumn = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(556, 42),
		Size = UDim2.new(0, 232, 1, -54),
		Visible = false,
		Parent = root,
	})
	storageTitle = Ui.label({ FontFace = Theme.FontMedium, Size = UDim2.new(1, 0, 0, 20), Parent = storageColumn })
	storageList = scrolling(storageColumn, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 1, -24))

	local hadStorage = false
	State.Changed:Connect(function()
		local hasStorage = State.storage ~= false
		if hasStorage and not hadStorage then
			Panel.open("inventory")
		end
		hadStorage = hasStorage
		refresh()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			Panel.toggle("inventory")
		elseif input.KeyCode == Enum.KeyCode.C then
			Panel.toggle("crafting")
		elseif input.KeyCode == Enum.KeyCode.Escape and root.Visible then
			Panel.close()
		end
	end)
	player.CharacterAdded:Connect(function()
		if root.Visible then
			Panel.close()
		end
	end)
end

return Panel

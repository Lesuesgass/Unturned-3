-- Heads-up display: survival bars, hotbar, equipped item, crosshair, prompts,
-- notifications, clock, loading screen, death screen and damage flash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Theme)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)

local Hud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local bars = {}
local slots = {}
local promptLabel: TextLabel
local targetLabel: TextLabel
local equippedName: TextLabel
local equippedAmmo: TextLabel
local clockLabel: TextLabel
local statusLabel: TextLabel
local notifyList: Frame
local loading: Frame
local death: Frame
local deathDetail: TextLabel
local flash: Frame

local STATS = {
	{ key = "Health", label = "HEALTH", color = Theme.Health },
	{ key = "Food", label = "FOOD", color = Theme.Food },
	{ key = "Water", label = "WATER", color = Theme.Water },
	{ key = "Stamina", label = "STAMINA", color = Theme.Stamina },
	{ key = "Infection", label = "INFECTION", color = Theme.Infection },
}

local function buildStats()
	local holder = Ui.panel({
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(240, 5 * 24 + 16),
		Parent = gui,
	})
	Ui.padding(8).Parent = holder
	Ui.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	for index, stat in STATS do
		local row = Ui.new(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = index, Parent = holder }
		)
		Ui.label({
			Text = stat.label,
			TextSize = Theme.SmallTextSize,
			TextColor3 = Theme.TextDim,
			Size = UDim2.new(0, 70, 0, 12),
			Parent = row,
		})
		local value = Ui.label({
			Text = "100",
			TextSize = Theme.SmallTextSize,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(1, -40, 0, 0),
			Size = UDim2.new(0, 40, 0, 12),
			Parent = row,
		})
		local track = Ui.new("Frame", {
			BackgroundColor3 = Theme.PanelLight,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 14),
			Size = UDim2.new(1, 0, 0, 5),
			Parent = row,
		})
		local fill = Ui.new(
			"Frame",
			{ BackgroundColor3 = stat.color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = track }
		)
		bars[stat.key] = { fill = fill, value = value }
	end
	statusLabel = Ui.label({
		Text = "",
		TextColor3 = Theme.Danger,
		FontFace = Theme.FontBold,
		TextSize = Theme.SmallTextSize,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 0, -6),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = holder,
	})
end

local function buildHotbar()
	local holder = Ui.new("Frame", {
		Name = "Hotbar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(5 * 112 + 4 * 6, 48),
		Parent = gui,
	})
	Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = holder })
	for i = 1, 5 do
		local slot = Ui.panel({ Size = UDim2.fromOffset(112, 48), LayoutOrder = i, Parent = holder })
		Ui.label({
			Text = tostring(i),
			TextSize = Theme.SmallTextSize - 1,
			TextColor3 = Theme.TextDim,
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.fromOffset(12, 12),
			Parent = slot,
		})
		local name = Ui.label({
			Text = "",
			TextSize = Theme.SmallTextSize,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Position = UDim2.fromOffset(6, 12),
			Size = UDim2.new(1, -12, 0, 22),
			Parent = slot,
		})
		local detail = Ui.label({
			Text = "",
			TextSize = Theme.SmallTextSize - 2,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0, 6, 1, -15),
			Size = UDim2.new(1, -12, 0, 12),
			Parent = slot,
		})
		slots[i] = { frame = slot, name = name, detail = detail, stroke = slot:FindFirstChildOfClass("UIStroke") }
	end
end

local function buildEquipped()
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -18),
		Size = UDim2.fromOffset(260, 44),
		Parent = gui,
	})
	equippedName = Ui.label({
		TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = Theme.FontMedium,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = holder,
	})
	equippedAmmo = Ui.label({
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = Theme.TitleTextSize,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 22),
		Parent = holder,
	})
end

local function buildCentre()
	Ui.new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.Text,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = gui,
	})
	promptLabel = Ui.label({
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.FontMedium,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 26),
		Size = UDim2.fromOffset(420, 20),
		Parent = gui,
	})
	targetLabel = Ui.label({
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.TextDim,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 48),
		Size = UDim2.fromOffset(420, 16),
		Parent = gui,
	})
end

local function buildCorner()
	clockLabel = Ui.label({
		TextSize = Theme.SmallTextSize,
		TextColor3 = Theme.TextDim,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(300, 16),
		Parent = gui,
	})
	notifyList = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -176),
		Size = UDim2.fromOffset(360, 200),
		Parent = gui,
	})
	Ui.new("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = notifyList,
	})
end

local function buildOverlays()
	flash = Ui.new("Frame", {
		BackgroundColor3 = Theme.Health,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = gui,
	})

	death = Ui.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	Ui.label({
		Text = "YOU DIED",
		FontFace = Theme.FontBold,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(400, 40),
		ZIndex = 11,
		Parent = death,
	})
	deathDetail = Ui.label({
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(400, 20),
		ZIndex = 11,
		Parent = death,
	})

	loading = Ui.new("Frame", {
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = gui,
	})
	Ui.label({
		Text = "GREYFALL",
		FontFace = Theme.FontBold,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(400, 36),
		ZIndex = 21,
		Parent = loading,
	})
	Ui.label({
		Text = "Generating the world",
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.51),
		Size = UDim2.fromOffset(400, 20),
		ZIndex = 21,
		Parent = loading,
	})
end

function Hud.setPrompt(text: string)
	promptLabel.Text = text
end

function Hud.setTarget(text: string)
	targetLabel.Text = text
end

function Hud.notify(text: string)
	local label = Ui.label({
		Text = text,
		TextSize = Theme.SmallTextSize + 1,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = notifyList,
	})
	local children = notifyList:GetChildren()
	if #children > 9 then
		for _, child in children do
			if child:IsA("TextLabel") and child ~= label then
				child:Destroy()
				break
			end
		end
	end
	task.delay(3.5, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

local function refreshHotbar()
	for i, slot in slots do
		local uid = State.hotbar[i]
		local stack = uid ~= "" and State.find(uid) or nil
		local def = stack and Items.get(stack.id)
		slot.name.Text = if def then def.name else ""
		if def and def.category == "Gun" then
			slot.detail.Text = tostring(stack.mag)
		elseif stack and stack.count > 1 then
			slot.detail.Text = `x{stack.count}`
		else
			slot.detail.Text = ""
		end
		local active = State.equipped == i
		slot.stroke.Color = if active then Theme.Accent else Theme.Line
		slot.stroke.Transparency = if active then 0 else 0.3
		slot.stroke.Thickness = if active then 2 else 1
	end
end

local function refreshEquipped()
	local stack = State.equippedStack()
	local def = stack and Items.get(stack.id)
	equippedName.Text = if def then def.name else ""
	if def and def.category == "Gun" then
		local reserve = State.count(def.ammo)
		equippedAmmo.Text = if player:GetAttribute("Reloading") then "Reloading" else `{stack.mag} / {reserve}`
	elseif stack and stack.count > 1 then
		equippedAmmo.Text = `x{stack.count}`
	else
		equippedAmmo.Text = ""
	end
end

local function formatClock(): string
	local t = Lighting.ClockTime
	local hours = math.floor(t)
	local minutes = math.floor((t - hours) * 60)
	local day = Lighting:GetAttribute("Day") or 1
	local map = workspace:GetAttribute("MapName") or ""
	return string.format("%s    Day %d    %02d:%02d", map, day, hours, minutes)
end

local lastHealth = 100

local function watchCharacter(character: Model)
	death.Visible = false
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth - 0.5 then
			flash.BackgroundTransparency = 0.75
			TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		task.wait(0.2)
		local seconds = player:GetAttribute("LastLife") or 0
		deathDetail.Text = string.format("Survived %d min %02d s", seconds // 60, seconds % 60)
		death.Visible = true
	end)
end

function Hud.init()
	gui = Ui.new("ScreenGui", {
		Name = "Hud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildStats()
	buildHotbar()
	buildEquipped()
	buildCentre()
	buildCorner()
	buildOverlays()

	State.Changed:Connect(function()
		refreshHotbar()
		refreshEquipped()
	end)
	player:GetAttributeChangedSignal("Reloading"):Connect(refreshEquipped)
	Net.get("Notify").OnClientEvent:Connect(Hud.notify)

	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		loading.Visible = workspace:GetAttribute("WorldReady") ~= true

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local values = {
			Health = if humanoid then humanoid.Health / humanoid.MaxHealth * 100 else 0,
			Food = player:GetAttribute("Food") or 0,
			Water = player:GetAttribute("Water") or 0,
			Stamina = player:GetAttribute("Stamina") or 0,
			Infection = player:GetAttribute("Infection") or 0,
		}
		for key, bar in bars do
			local v = math.clamp(values[key], 0, 100)
			bar.fill.Size = UDim2.fromScale(v / 100, 1)
			bar.value.Text = tostring(math.floor(v + 0.5))
		end
		local status = {}
		if player:GetAttribute("Bleeding") then
			table.insert(status, "BLEEDING")
		end
		if values.Food <= 0 then
			table.insert(status, "STARVING")
		end
		if values.Water <= 0 then
			table.insert(status, "DEHYDRATED")
		end
		statusLabel.Text = table.concat(status, "   ")
		clockLabel.Text = formatClock()
	end)
end

return Hud

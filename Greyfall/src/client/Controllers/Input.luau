-- Player controls.
--   Left click   attack, shoot, place a structure, plant a charge, or repair; punch with empty hands
--   R            reload
--   1 to 5       equip a hotbar slot (press again to put it away)
--   Left Shift   sprint
--   V            switch between first and third person
--   X            salvage your own structure (hammer equipped)
-- The in-game list of keys lives in Keybinds.luau; keep both in step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Config = require(Shared.Config)
local Aim = require(script.Parent.Aim)
local State = require(script.Parent.State)
local Build = require(script.Parent.Build)
local Interaction = require(script.Parent.Interaction)

local InputController = {}

local player = Players.LocalPlayer
local action = Net.get("Action")
local attack = Net.get("Attack")

local mouseDown = false
local lastShot = 0
local firstPerson = false

local HOTBAR_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

local function head(): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("Head")
	return if part and part:IsA("BasePart") then part else nil
end

local function aimDirection(): Vector3?
	local h = head()
	if not h then
		return nil
	end
	local target = Aim.point(1000, { workspace:FindFirstChild("Drops") :: Instance })
	local offset = target - h.Position
	if offset.Magnitude < 0.1 then
		return nil
	end
	return offset.Unit
end

local function primary()
	local stack = State.equippedStack()
	local def = if stack then Items.get(stack.id) else Items.Fists
	if not def then
		return
	end
	local now = os.clock()
	if def.category == "Melee" then
		if now - lastShot >= def.cooldown then
			local direction = aimDirection()
			if direction then
				lastShot = now
				attack:FireServer("Melee", direction)
			end
		end
	elseif def.category == "Gun" then
		if now - lastShot >= def.fireRate then
			local direction = aimDirection()
			if direction then
				lastShot = now
				attack:FireServer("Fire", direction)
			end
		end
	elseif def.category == "Structure" then
		local input = Build.input
		if input and stack then
			action:FireServer("Place", stack.uid, input)
		end
	elseif def.category == "Explosive" then
		local result = Aim.cast(10, { workspace:FindFirstChild("Drops") :: Instance })
		if result and stack then
			action:FireServer("Plant", stack.uid, result.Position, result.Normal)
		end
	elseif def.repairs then
		local part = Interaction.structurePart
		if part then
			action:FireServer("Repair", part)
		end
	end
end

local function setFirstPerson(on: boolean)
	firstPerson = on
	if on then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = Config.Player.MaxCameraZoom
	end
end

function InputController.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or State.panelOpen then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseDown = true
			primary()
			return
		end
		local slot = HOTBAR_KEYS[input.KeyCode]
		if slot then
			action:FireServer("Equip", slot)
		elseif input.KeyCode == Enum.KeyCode.R then
			action:FireServer("Reload")
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			action:FireServer("Sprint", true)
		elseif input.KeyCode == Enum.KeyCode.V then
			setFirstPerson(not firstPerson)
		elseif input.KeyCode == Enum.KeyCode.X then
			local part = Interaction.structurePart
			if part then
				action:FireServer("Salvage", part)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseDown = false
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			action:FireServer("Sprint", false)
		end
	end)

	-- Automatic weapons keep firing while the button is held.
	RunService.Heartbeat:Connect(function()
		if not mouseDown or State.panelOpen then
			return
		end
		local stack = State.equippedStack()
		local def = stack and Items.get(stack.id)
		if def and def.category == "Gun" and def.automatic then
			primary()
		end
	end)
end

return InputController

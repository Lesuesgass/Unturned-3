-- Shows what the player is looking at and handles the interact key (F).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Net = require(Shared.Net)
local Aim = require(script.Parent.Aim)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)

local Interaction = {}

local player = Players.LocalPlayer
local action = Net.get("Action")

local focus: BasePart? = nil
local focusKind: string? = nil
Interaction.structurePart = nil :: BasePart?

local function structureModel(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("StructureId") then
		return model
	end
	return nil
end

local function update()
	focus, focusKind = nil, nil
	Interaction.structurePart = nil
	local prompt, target = "", ""
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or State.panelOpen then
		Hud.setPrompt("")
		Hud.setTarget("")
		return
	end

	local result = Aim.cast(40)
	local part = result and result.Instance
	if part and part:IsA("BasePart") then
		local distance = (result.Position - (root :: BasePart).Position).Magnitude
		local near = distance <= Config.Combat.MaxInteractDistance

		local drops = workspace:FindFirstChild("Drops")
		if near and drops and part.Parent == drops and part:GetAttribute("ItemId") then
			local def = Items.get(part:GetAttribute("ItemId"))
			local count = part:GetAttribute("Count") or 1
			focus, focusKind = part, "Pickup"
			prompt = `[F]  Pick up {def and def.name or "item"}` .. (if count > 1 then `  x{count}` else "")
		elseif near and part:GetAttribute("Door") then
			local owner = part:GetAttribute("Owner")
			focus, focusKind = part, "Interact"
			if owner and owner ~= player.UserId then
				prompt = "Locked door"
			else
				prompt = if part:GetAttribute("Open") then "[F]  Close door" else "[F]  Open door"
			end
		elseif near and part:GetAttribute("Storage") then
			local owner = part:GetAttribute("Owner")
			focus, focusKind = part, "Interact"
			local model = structureModel(part)
			prompt = if owner == player.UserId then `[F]  Open {model and model.Name or "storage"}` else "Locked"
		end

		local model = structureModel(part)
		if model and distance < 30 then
			Interaction.structurePart = part
			local health = model:GetAttribute("Health") or 0
			local maxHealth = model:GetAttribute("MaxHealth") or 0
			target = `{model.Name}   {health} / {maxHealth}`
			local stack = State.equippedStack()
			local def = stack and Items.get(stack.id)
			if def and def.repairs then
				target ..= "   Click to repair"
				if def.id == "hammer" and model:GetAttribute("Owner") == player.UserId then
					target ..= "   X to salvage"
				end
			end
		end
	end
	Hud.setPrompt(prompt)
	local stack = State.equippedStack()
	local def = stack and Items.get(stack.id)
	if not def or def.category ~= "Structure" then
		-- While building, the placement preview owns this line instead.
		Hud.setTarget(target)
	end
end

function Interaction.init()
	RunService.RenderStepped:Connect(update)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or State.panelOpen then
			return
		end
		if input.KeyCode == Enum.KeyCode.F and focus and focusKind then
			action:FireServer(focusKind, focus)
		end
	end)
end

return Interaction

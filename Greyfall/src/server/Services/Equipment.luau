-- Puts the equipped hotbar item into the character's hand as a Tool, so the default
-- character animations raise the arm. The worn backpack is shown on the character's back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Items)
local PlayerState = require(script.Parent.PlayerState)

local Equipment = {}

local function clearHeld(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("Held") then
			child:Destroy()
		end
	end
end

local function makeTool(def): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.RequiresHandle = true
	tool:SetAttribute("Held", true)
	tool:SetAttribute("ItemId", def.id)

	local size = def.model.size
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = def.model.color
	handle.Material = def.model.material or Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- Hold the item near its back end, pointing forward.
	tool.Grip = CFrame.new(0, 0, size.Z / 2 - 0.4)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0, -size.Z / 2)
	muzzle.Parent = handle

	if def.light then
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = def.light.range
		light.Brightness = def.light.brightness
		light.Angle = def.light.angle
		light.Color = Color3.fromRGB(255, 244, 220)
		light.Shadows = true
		light.Parent = handle
	end
	return tool
end

function Equipment.refresh(player: Player)
	local character = player.Character
	local state = PlayerState.get(player)
	if not character or not state then
		return
	end
	clearHeld(character)
	local stack = PlayerState.equippedStack(state)
	if not stack then
		return
	end
	local def = Items.get(stack.id)
	if def and Items.isEquippable(def) then
		local tool = makeTool(def)
		tool.Parent = character
	end
end

function Equipment.refreshPack(player: Player)
	local character = player.Character
	local state = PlayerState.get(player)
	if not character or not state then
		return
	end
	local old = character:FindFirstChild("WornPack")
	if old then
		old:Destroy()
	end
	local def = Items.get(state.pack)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not def or not torso or not torso:IsA("BasePart") then
		return
	end
	local part = Instance.new("Part")
	part.Name = "WornPack"
	part.Size = def.model.size
	part.Color = def.model.color
	part.Material = def.model.material or Enum.Material.Fabric
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2 + def.model.size.Z / 2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
end

function Equipment.init()
	PlayerState.onEquipmentChanged = Equipment.refresh
end

return Equipment

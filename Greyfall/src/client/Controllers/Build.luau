-- Placement preview for structures. While a building piece is equipped, a see-through copy
-- follows the aim and snaps to the grid; it turns red where the piece cannot go.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Items)
local BuildGrid = require(Shared.BuildGrid)
local Aim = require(script.Parent.Aim)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)

local Build = {}

local player = Players.LocalPlayer
local ghost: BasePart? = nil
local ghostShape = ""

local VALID = Color3.fromRGB(150, 175, 130)
local INVALID = Color3.fromRGB(170, 80, 70)

-- The last aim used for the preview, sent to the server when the player clicks.
Build.input = nil :: any

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
		ghostShape = ""
	end
end

local function ensureGhost(shape: string): BasePart
	if ghost and ghostShape == shape then
		return ghost
	end
	clearGhost()
	local part = Instance.new(if shape == "wedge" then "WedgePart" else "Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 0.55
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = workspace.CurrentCamera
	ghost = part
	ghostShape = shape
	return part
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function update()
	local stack = State.equippedStack()
	local def = stack and Items.get(stack.id)
	if not def or def.category ~= "Structure" or State.panelOpen then
		clearGhost()
		Build.input = nil
		return
	end

	local ignore = { workspace:FindFirstChild("Drops") }
	if ghost then
		table.insert(ignore, ghost)
	end
	local result = Aim.cast(24, ignore)
	if not result then
		clearGhost()
		Build.input = nil
		return
	end
	local hit = result.Instance
	local input = {
		position = result.Position,
		normal = result.Normal,
		part = if hit:GetAttribute("StructureId") then hit else nil,
		look = workspace.CurrentCamera.CFrame.LookVector,
	}
	Build.input = input

	local placement, reason = BuildGrid.solve(def.piece, input)
	if not placement then
		clearGhost()
		Hud.setTarget(reason or "")
		return
	end
	local part = ensureGhost(placement.shape)
	part.Size = placement.size
	part.CFrame = placement.cframe

	local ignoreList = { part }
	local drops = workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignoreList, drops)
	end
	if player.Character then
		-- The server also refuses to build on players, but the local character should not
		-- turn the preview red while standing beside the spot.
		table.insert(ignoreList, player.Character)
	end
	overlapParams.FilterDescendantsInstances = ignoreList
	local blocked = #workspace:GetPartBoundsInBox(
			placement.cframe,
			BuildGrid.clearanceSize(placement),
			overlapParams
		) > 0
	part.Color = if blocked then INVALID else VALID
	Hud.setTarget(if blocked then "Something is in the way" else "Click to place")
end

function Build.init()
	RunService.RenderStepped:Connect(update)
end

return Build

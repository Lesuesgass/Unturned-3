-- Items lying in the world. Each drop is a single anchored part in workspace.Drops with
-- the attributes ItemId, Count and Mag (loaded rounds for guns, -1 otherwise).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Items = require(ReplicatedStorage.Shared.Items)

local Drops = {}

local folder: Folder

function Drops.init()
	folder = Instance.new("Folder")
	folder.Name = "Drops"
	folder.Parent = workspace
end

function Drops.folder(): Folder
	return folder
end

-- position is the point on the ground the item rests on.
function Drops.spawn(id: string, count: number, position: Vector3, mag: number?, lifetime: number?): BasePart?
	local def = Items.get(id)
	if not def or count <= 0 then
		return nil
	end
	local size = def.model.size
	local part = Instance.new("Part")
	part.Name = def.name
	part.Size = size
	part.Color = def.model.color
	part.Material = def.model.material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local rotation = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	part.CFrame = CFrame.new(position + Vector3.new(0, size.Y / 2, 0)) * rotation
	part:SetAttribute("ItemId", id)
	part:SetAttribute("Count", count)
	part:SetAttribute("Mag", mag or -1)
	part.Parent = folder
	if lifetime then
		Debris:AddItem(part, lifetime)
	end
	return part
end

-- Finds a resting spot on whatever is under a point (terrain, floors, roofs).
function Drops.groundBelow(position: Vector3, ignore: { Instance }?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { folder }
	if ignore then
		for _, item in ignore do
			table.insert(list, item)
		end
	end
	params.FilterDescendantsInstances = list
	local result = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	if result then
		return result.Position
	end
	return position
end

function Drops.isDrop(instance: Instance?): boolean
	return instance ~= nil and instance.Parent == folder and instance:GetAttribute("ItemId") ~= nil
end

return Drops

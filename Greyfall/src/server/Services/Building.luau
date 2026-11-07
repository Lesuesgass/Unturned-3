-- Player-built structures: placement, health, raid damage, repairs, salvage and storage.
--
-- Raiding rules (numbers live in shared/BuildingDefs):
--   * Every piece has health that depends on its tier and piece type.
--   * Melee hits and bullets scale down sharply on stronger tiers and do nothing to metal.
--   * Explosive charges are the main way through brick and metal.
--   * Doors and storage only open for their owner, so raiders have to break them.
--   * Destroying a doorway takes its door with it; destroying storage spills its contents.
--   * Owners repair pieces with a hammer (wood, brick) or a blowtorch (metal), paying material.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local BuildingDefs = require(Shared.BuildingDefs)
local BuildGrid = require(Shared.BuildGrid)

local PlayerState = require(script.Parent.PlayerState)
local Drops = require(script.Parent.Drops)
local Doors = require(script.Parent.Doors)
local Effects = require(script.Parent.Effects)

local Building = {}

local folder: Folder
local field
local structures: { [number]: any } = {}
local nextId = 1
local openStorage: { [Player]: number } = {}
local lastRepair: { [Player]: number } = {}
local countByOwner: { [number]: number } = {}

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function recordOf(part: Instance?)
	if not part then
		return nil
	end
	local id = part:GetAttribute("StructureId")
	return if typeof(id) == "number" then structures[id] else nil
end

function Building.isStructure(part: Instance?): boolean
	return recordOf(part) ~= nil
end

function Building.folder(): Folder
	return folder
end

local function newPart(className: string, model: Model, props): BasePart
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = model
	return part
end

local function tagParts(record, placement)
	for _, part in record.model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("StructureId", record.id)
			part:SetAttribute("Piece", record.piece)
			part:SetAttribute("Tier", record.tier)
			part:SetAttribute("CellX", placement.cellX)
			part:SetAttribute("CellZ", placement.cellZ)
			part:SetAttribute("Base", placement.base)
			part:SetAttribute("Axis", placement.axis)
			part:SetAttribute("Sign", placement.sign)
			part:SetAttribute("Frame", placement.frame)
		end
	end
end

local function construct(record, placement, def)
	local tierDef = BuildingDefs.Tiers[record.tier]
	local model = Instance.new("Model")
	model.Name = def.name
	model:SetAttribute("StructureId", record.id)
	model:SetAttribute("Owner", record.owner)
	model:SetAttribute("Health", record.health)
	model:SetAttribute("MaxHealth", record.maxHealth)
	record.model = model

	local look = { Color = tierDef.color, Material = tierDef.surface }
	if placement.shape == "wedge" then
		newPart(
			"WedgePart",
			model,
			{ Size = placement.size, CFrame = placement.cframe, Color = look.Color, Material = look.Material }
		)
	elseif placement.shape == "doorway" then
		local frame: CFrame = placement.frame
		local h = BuildingDefs.WallHeight
		newPart("Part", model, {
			Size = Vector3.new(2, h, 1),
			CFrame = frame * CFrame.new(-3, h / 2, 0),
			Color = look.Color,
			Material = look.Material,
		})
		newPart("Part", model, {
			Size = Vector3.new(2, h, 1),
			CFrame = frame * CFrame.new(3, h / 2, 0),
			Color = look.Color,
			Material = look.Material,
		})
		newPart("Part", model, {
			Size = Vector3.new(4, h - 7, 1),
			CFrame = frame * CFrame.new(0, 7 + (h - 7) / 2, 0),
			Color = look.Color,
			Material = look.Material,
		})
	elseif record.piece == "door" then
		local frame: CFrame = placement.frame
		local hinge = frame * CFrame.new(-1.9, 3.5, 0)
		local closed = hinge * CFrame.new(1.9, 0, 0)
		local open = hinge * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(1.9, 0, 0)
		local part = newPart("Part", model, {
			Name = "Door",
			Size = placement.size,
			CFrame = closed,
			Color = look.Color:Lerp(Color3.new(0, 0, 0), 0.15),
			Material = look.Material,
		})
		Doors.register(part, closed, open, record.owner)
		record.doorwayId = placement.doorwayId
	else
		local part = newPart(
			"Part",
			model,
			{ Size = placement.size, CFrame = placement.cframe, Color = look.Color, Material = look.Material }
		)
		if record.storage then
			part.Name = "Storage"
			part:SetAttribute("Storage", true)
			part:SetAttribute("Owner", record.owner)
		end
	end

	tagParts(record, placement)
	model.Parent = folder
end

local function spill(record)
	local position = record.model:GetPivot().Position
	for _, stack in record.storage.items do
		local offset = Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2)
		Drops.spawn(
			stack.id,
			stack.count,
			Drops.groundBelow(position + offset, { folder }),
			stack.mag,
			Config.Loot.DroppedItemLifetime
		)
	end
	record.storage.items = {}
end

local function destroy(record, broken: boolean)
	if not structures[record.id] then
		return
	end
	structures[record.id] = nil
	countByOwner[record.owner] = math.max(0, (countByOwner[record.owner] or 1) - 1)
	if record.storage then
		spill(record)
		for player, id in openStorage do
			if id == record.id then
				openStorage[player] = nil
				PlayerState.sync(player)
			end
		end
	end
	if record.piece == "doorway" then
		for _, other in structures do
			if other.doorwayId == record.id then
				destroy(other, broken)
			end
		end
	end
	if broken then
		Effects.impact(record.model:GetPivot().Position, false)
		Effects.sound("StructureBreak", record.model:GetPivot().Position)
	end
	record.model:Destroy()
end

-- Applies damage of a kind ("melee", "bullet" or "explosive") to the structure owning part.
-- Returns the damage actually dealt, or nil if part is not a structure.
function Building.damage(part: Instance, amount: number, kind: string, attacker: Player?): number?
	local record = recordOf(part)
	if not record then
		return nil
	end
	return Building.damageRecord(record, amount, kind, attacker)
end

function Building.damageRecord(record, amount: number, kind: string, attacker: Player?): number
	local scale = BuildingDefs.DamageScale[kind] and BuildingDefs.DamageScale[kind][record.tier] or 1
	local dealt = amount * scale
	if dealt <= 0 then
		if attacker and kind == "melee" then
			PlayerState.notify(attacker, `{BuildingDefs.Tiers[record.tier].name} needs explosives`)
		end
		return 0
	end
	record.health -= dealt
	record.model:SetAttribute("Health", math.max(0, math.floor(record.health)))
	if record.health <= 0 then
		destroy(record, true)
	end
	return dealt
end

-- Every structure within radius of position, once each, with its distance.
function Building.inRadius(position: Vector3, radius: number)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local found = {}
	for _, part in workspace:GetPartBoundsInRadius(position, radius, params) do
		local record = recordOf(part)
		if record then
			local distance = (part.Position - position).Magnitude
			if not found[record] or distance < found[record] then
				found[record] = distance
			end
		end
	end
	return found
end

function Building.place(player: Player, uid: string, input)
	local state = PlayerState.get(player)
	local root = characterRoot(player)
	if not state or not root then
		return
	end
	local stack = PlayerState.findStack(state, uid)
	local def = stack and Items.get(stack.id)
	if not stack or not def or def.category ~= "Structure" then
		return
	end
	if (input.position - root.Position).Magnitude > 24 then
		return
	end
	if input.part and not input.part:IsDescendantOf(folder) and BuildingDefs.Storage[def.piece] == nil then
		input.part = nil
	end

	local placement, reason = BuildGrid.solve(def.piece, input)
	if not placement then
		PlayerState.notify(player, reason or "Cannot place that here")
		return
	end
	local position = placement.cframe.Position
	if (position - root.Position).Magnitude > 26 then
		PlayerState.notify(player, "Too far away")
		return
	end
	if field:townAt(position.X, position.Z, Config.Building.TownMargin) then
		PlayerState.notify(player, "You cannot build inside a town")
		return
	end
	if (countByOwner[player.UserId] or 0) >= Config.Building.MaxPiecesPerPlayer then
		PlayerState.notify(player, "You have reached the building limit")
		return
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Drops.folder() }
	local blocking = workspace:GetPartBoundsInBox(placement.cframe, BuildGrid.clearanceSize(placement), params)
	if #blocking > 0 then
		PlayerState.notify(player, "Something is in the way")
		return
	end

	if PlayerState.takeFromStack(player, uid, 1) < 1 then
		return
	end

	local storageDef = BuildingDefs.Storage[def.piece]
	local record = {
		id = nextId,
		owner = player.UserId,
		itemId = def.id,
		tier = def.tier,
		piece = def.piece,
		maxHealth = BuildingDefs.maxHealth(def.tier, def.piece),
		health = 0,
		storage = if storageDef then { slots = storageDef.slots, items = {}, nextUid = 1 } else nil,
	}
	record.health = record.maxHealth
	nextId += 1
	structures[record.id] = record
	countByOwner[player.UserId] = (countByOwner[player.UserId] or 0) + 1
	construct(record, placement, def)
	Effects.sound("Build", position)
end

function Building.repair(player: Player, part: Instance, toolDef)
	local record = recordOf(part)
	local root = characterRoot(player)
	if not record or not root or not toolDef.repairs then
		return
	end
	if (record.model:GetPivot().Position - root.Position).Magnitude > 14 then
		return
	end
	local now = os.clock()
	if now - (lastRepair[player] or 0) < BuildingDefs.RepairCooldown then
		return
	end
	lastRepair[player] = now

	local tierDef = BuildingDefs.Tiers[record.tier]
	if tierDef.repairTool ~= toolDef.id then
		local needed = Items.get(tierDef.repairTool)
		PlayerState.notify(player, `{tierDef.name} is repaired with a {needed and needed.name or tierDef.repairTool}`)
		return
	end
	if record.health >= record.maxHealth then
		PlayerState.notify(player, "Already at full health")
		return
	end
	if not PlayerState.remove(player, tierDef.material, BuildingDefs.RepairCost) then
		local material = Items.get(tierDef.material)
		PlayerState.notify(
			player,
			`Repairing needs {BuildingDefs.RepairCost} {material and material.name or tierDef.material}`
		)
		return
	end
	record.health = math.min(record.maxHealth, record.health + record.maxHealth * BuildingDefs.RepairFraction)
	record.model:SetAttribute("Health", math.floor(record.health))
	Effects.sound("Repair", record.model:GetPivot().Position)
end

function Building.salvage(player: Player, part: Instance)
	local record = recordOf(part)
	local root = characterRoot(player)
	if not record or not root then
		return
	end
	if record.owner ~= player.UserId then
		PlayerState.notify(player, "You can only salvage your own structures")
		return
	end
	if (record.model:GetPivot().Position - root.Position).Magnitude > 14 then
		return
	end
	local recipe = Recipes.get(record.itemId)
	destroy(record, false)
	if recipe then
		for _, input in recipe.inputs do
			local refund = math.floor(input.count * BuildingDefs.SalvageRefund)
			if refund > 0 then
				local added = PlayerState.add(player, input.id, refund)
				if added < refund then
					Drops.spawn(
						input.id,
						refund - added,
						Drops.groundBelow(root.Position),
						nil,
						Config.Loot.DroppedItemLifetime
					)
				end
			end
		end
	end
	PlayerState.notify(player, "Salvaged")
end

-- Storage ------------------------------------------------------------------------------

local function openRecord(player: Player)
	local id = openStorage[player]
	local record = id and structures[id]
	local root = characterRoot(player)
	if not record or not root or (record.model:GetPivot().Position - root.Position).Magnitude > 14 then
		openStorage[player] = nil
		return nil
	end
	return record
end

function Building.isStorage(part: Instance): boolean
	local record = recordOf(part)
	return record ~= nil and record.storage ~= nil
end

function Building.openStorage(player: Player, part: Instance)
	local record = recordOf(part)
	local root = characterRoot(player)
	if not record or not record.storage or not root then
		return
	end
	if record.owner ~= player.UserId then
		PlayerState.notify(player, "Locked")
		return
	end
	if (record.model:GetPivot().Position - root.Position).Magnitude > 12 then
		return
	end
	openStorage[player] = record.id
	PlayerState.sync(player)
end

function Building.closeStorage(player: Player)
	if openStorage[player] then
		openStorage[player] = nil
		PlayerState.sync(player)
	end
end

function Building.storagePut(player: Player, uid: string, count: number)
	local record = openRecord(player)
	local state = PlayerState.get(player)
	if not record or not state then
		return
	end
	local stack = PlayerState.findStack(state, uid)
	local def = stack and Items.get(stack.id)
	if not stack or not def then
		return
	end
	count = math.clamp(math.floor(count), 1, stack.count)
	local items = record.storage.items
	local moved = 0

	if def.maxStack > 1 then
		for _, stored in items do
			if stored.id == stack.id and stored.count < def.maxStack and moved < count then
				local take = math.min(count - moved, def.maxStack - stored.count)
				stored.count += take
				moved += take
			end
		end
	end
	while moved < count and #items < record.storage.slots do
		local take = math.min(count - moved, def.maxStack)
		table.insert(items, { uid = tostring(record.storage.nextUid), id = stack.id, count = take, mag = stack.mag })
		record.storage.nextUid += 1
		moved += take
	end
	if moved == 0 then
		PlayerState.notify(player, "Storage is full")
		return
	end
	PlayerState.takeFromStack(player, uid, moved)
end

function Building.storageTake(player: Player, uid: string, count: number)
	local record = openRecord(player)
	if not record then
		return
	end
	local items = record.storage.items
	for index, stored in items do
		if stored.uid == uid then
			count = math.clamp(math.floor(count), 1, stored.count)
			local added = PlayerState.add(player, stored.id, count, stored.mag)
			if added == 0 then
				PlayerState.notify(player, "Too heavy")
				return
			end
			stored.count -= added
			if stored.count <= 0 then
				table.remove(items, index)
			end
			PlayerState.sync(player)
			return
		end
	end
end

local function storageSnapshot(player: Player)
	local record = openRecord(player)
	if not record then
		return false
	end
	local items = {}
	for i, stored in record.storage.items do
		items[i] = { uid = stored.uid, id = stored.id, count = stored.count, mag = stored.mag or -1 }
	end
	return { name = record.model.Name, slots = record.storage.slots, items = items }
end

function Building.init(world)
	field = world.field
	folder = Instance.new("Folder")
	folder.Name = "Structures"
	folder.Parent = workspace

	PlayerState.snapshotExtras = function(player: Player)
		return { storage = storageSnapshot(player) }
	end
	Players.PlayerRemoving:Connect(function(player)
		openStorage[player] = nil
		lastRepair[player] = nil
	end)
end

return Building

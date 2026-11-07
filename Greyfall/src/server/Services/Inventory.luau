-- Handles every request a client sends through the Action remote.
-- All arguments are checked here before anything changes.
--
--   Use uid             eat, drink, heal, wear a pack, or equip
--   Drop uid count      drop items on the ground
--   Assign uid slot     put an item into a hotbar slot (1-5)
--   Equip slot          equip a hotbar slot, 0 or the same slot to unequip
--   Craft recipeId
--   Reload
--   Pickup part         pick up a dropped item
--   Interact part       open a door or a storage container
--   Sprint bool
--   RemovePack
--   Place uid input     place a structure (input = { position, normal, part, look })
--   Plant uid position normal
--   Repair part         with a hammer or blowtorch equipped
--   Salvage part        with a hammer equipped, own structures only
--   StorePut uid count / StoreTake uid count / StoreClose

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Recipes = require(Shared.Recipes)
local Net = require(Shared.Net)

local PlayerState = require(script.Parent.PlayerState)
local Survival = require(script.Parent.Survival)
local Equipment = require(script.Parent.Equipment)
local Drops = require(script.Parent.Drops)
local Doors = require(script.Parent.Doors)
local Building = require(script.Parent.Building)
local Combat = require(script.Parent.Combat)
local Effects = require(script.Parent.Effects)

local Inventory = {}

local MAX_ACTIONS_PER_SECOND = 30
local budget: { [Player]: { count: number, window: number } } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	local entry = budget[player]
	if not entry or now - entry.window > 1 then
		entry = { count = 0, window = now }
		budget[player] = entry
	end
	entry.count += 1
	return entry.count <= MAX_ACTIONS_PER_SECOND
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isString(v: any): boolean
	return typeof(v) == "string" and #v < 64
end

local function isCount(v: any): boolean
	return typeof(v) == "number" and v == v and v >= 1 and v < 10000
end

local function isVector(v: any): boolean
	return typeof(v) == "Vector3" and v.Magnitude == v.Magnitude and v.Magnitude < 100000
end

local function withinReach(player: Player, part: any, distance: number): boolean
	local root = rootOf(player)
	return root ~= nil
		and typeof(part) == "Instance"
		and part:IsA("BasePart")
		and part:IsDescendantOf(workspace)
		and (part.Position - root.Position).Magnitude <= distance
end

local function equippedDef(state)
	local stack = PlayerState.equippedStack(state)
	return stack and Items.get(stack.id), stack
end

local function equip(player: Player, state, slot: number)
	if state.equipped == slot then
		slot = 0
	end
	state.equipped = slot
	state.reloading = false
	player:SetAttribute("Reloading", false)
	PlayerState.sync(player)
	-- The held tool is rebuilt during the sync, once the change is final.
end

local function use(player: Player, state, uid: string)
	local stack = PlayerState.findStack(state, uid)
	local def = stack and Items.get(stack.id)
	if not stack or not def then
		return
	end
	if Items.isConsumable(def) then
		if Survival.applyConsumable(player, def) then
			PlayerState.takeFromStack(player, uid, 1)
		end
	elseif def.category == "Backpack" then
		local old = state.pack
		PlayerState.takeFromStack(player, uid, 1)
		state.pack = def.id
		if old ~= "" and PlayerState.add(player, old, 1) < 1 then
			local root = rootOf(player)
			if root then
				Drops.spawn(old, 1, Drops.groundBelow(root.Position), nil, Config.Loot.DroppedItemLifetime)
			end
		end
		Equipment.refreshPack(player)
		PlayerState.sync(player)
	elseif Items.isEquippable(def) then
		local slot = table.find(state.hotbar, uid)
		if not slot then
			slot = table.find(state.hotbar, "")
			if not slot then
				PlayerState.notify(player, "Hotbar is full")
				return
			end
			state.hotbar[slot] = uid
		end
		equip(player, state, slot)
	end
end

local function drop(player: Player, state, uid: string, count: number)
	local root = rootOf(player)
	local stack = PlayerState.findStack(state, uid)
	if not root or not stack then
		return
	end
	local mag = stack.mag
	local id = stack.id
	local taken = PlayerState.takeFromStack(player, uid, math.floor(count))
	if taken > 0 then
		local spot = root.Position + root.CFrame.LookVector * 3
		Drops.spawn(
			id,
			taken,
			Drops.groundBelow(spot, { player.Character :: Instance }),
			mag,
			Config.Loot.DroppedItemLifetime
		)
	end
end

local function craft(player: Player, state, recipeId: string)
	local recipe = Recipes.get(recipeId)
	if not recipe then
		return
	end
	for _, tool in recipe.requires do
		if PlayerState.count(state, tool) < 1 then
			local def = Items.get(tool)
			PlayerState.notify(player, `Requires a {def and def.name or tool}`)
			return
		end
	end
	for _, input in recipe.inputs do
		if PlayerState.count(state, input.id) < input.count then
			PlayerState.notify(player, "Missing materials")
			return
		end
	end
	local output = Items.get(recipe.output)
	if not output then
		return
	end
	-- Make sure the result fits once the inputs are gone.
	local inputWeight = 0
	for _, input in recipe.inputs do
		local def = Items.get(input.id)
		inputWeight += (if def then def.weight else 0) * input.count
	end
	local free = PlayerState.capacity(state) - PlayerState.weight(state) + inputWeight
	if output.weight * recipe.count > free + 1e-6 then
		PlayerState.notify(player, "Too heavy to craft that")
		return
	end
	for _, input in recipe.inputs do
		PlayerState.remove(player, input.id, input.count)
	end
	PlayerState.add(player, recipe.output, recipe.count)
	PlayerState.notify(player, `Crafted {output.name}` .. (if recipe.count > 1 then ` x{recipe.count}` else ""))
end

local function pickup(player: Player, part: BasePart)
	if not Drops.isDrop(part) then
		return
	end
	local id = part:GetAttribute("ItemId") :: string
	local count = part:GetAttribute("Count") :: number
	local mag = part:GetAttribute("Mag") :: number
	local added = PlayerState.add(player, id, count, if mag >= 0 then mag else nil)
	if added <= 0 then
		PlayerState.notify(player, "Too heavy")
		return
	end
	Effects.sound("Pickup", part.Position)
	if added >= count then
		part:Destroy()
	else
		part:SetAttribute("Count", count - added)
		PlayerState.notify(player, "Too heavy to carry it all")
	end
end

local function readBuildInput(raw: any)
	if typeof(raw) ~= "table" then
		return nil
	end
	local position, normal, look, part = raw.position, raw.normal, raw.look, raw.part
	if not isVector(position) or not isVector(normal) or not isVector(look) then
		return nil
	end
	if normal.Magnitude < 0.5 or look.Magnitude < 0.5 then
		return nil
	end
	if part ~= nil and not (typeof(part) == "Instance" and part:IsA("BasePart") and part:IsDescendantOf(workspace)) then
		return nil
	end
	return { position = position, normal = normal.Unit, look = look.Unit, part = part }
end

local handlers = {}

function handlers.Use(player, state, uid)
	if isString(uid) then
		use(player, state, uid)
	end
end

function handlers.Drop(player, state, uid, count)
	if isString(uid) and isCount(count) then
		drop(player, state, uid, count)
	end
end

function handlers.Assign(player, state, uid, slot)
	if not isString(uid) or typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > PlayerState.HotbarSize then
		return
	end
	local stack = PlayerState.findStack(state, uid)
	if not stack then
		return
	end
	local existing = table.find(state.hotbar, uid)
	if existing then
		state.hotbar[existing] = ""
	end
	state.hotbar[slot] = uid
	PlayerState.sync(player)
end

function handlers.Equip(player, state, slot)
	if typeof(slot) == "number" and slot % 1 == 0 and slot >= 0 and slot <= PlayerState.HotbarSize then
		equip(player, state, slot)
	end
end

function handlers.Craft(player, state, recipeId)
	if isString(recipeId) then
		craft(player, state, recipeId)
	end
end

function handlers.Reload(player)
	Combat.reload(player)
end

function handlers.Pickup(player, _state, part)
	if withinReach(player, part, Config.Combat.MaxInteractDistance) then
		pickup(player, part)
	end
end

function handlers.Interact(player, _state, part)
	if not withinReach(player, part, Config.Combat.MaxInteractDistance) then
		return
	end
	if Doors.isDoor(part) then
		Doors.toggle(player, part)
	elseif Building.isStorage(part) then
		Building.openStorage(player, part)
	end
end

function handlers.Sprint(_player, state, on)
	if typeof(on) == "boolean" then
		state.wantSprint = on
	end
end

function handlers.RemovePack(player, state)
	if state.pack == "" then
		return
	end
	local packDef = Items.get(state.pack)
	local base = Config.Player.BaseCarryKg
	if PlayerState.weight(state) + (packDef and packDef.weight or 0) > base then
		PlayerState.notify(player, "Too much weight to take the pack off")
		return
	end
	local old = state.pack
	state.pack = ""
	PlayerState.add(player, old, 1)
	Equipment.refreshPack(player)
	PlayerState.sync(player)
end

function handlers.Place(player, _state, uid, rawInput)
	local input = readBuildInput(rawInput)
	if isString(uid) and input then
		Building.place(player, uid, input)
	end
end

function handlers.Plant(player, _state, uid, position, normal)
	if isString(uid) and isVector(position) and isVector(normal) and normal.Magnitude > 0.5 then
		Combat.plant(player, uid, position, normal.Unit)
	end
end

function handlers.Repair(player, state, part)
	local def = equippedDef(state)
	if def and def.repairs and withinReach(player, part, 14) then
		Building.repair(player, part, def)
	end
end

function handlers.Salvage(player, state, part)
	local def = equippedDef(state)
	if def and def.id == "hammer" and withinReach(player, part, 14) then
		Building.salvage(player, part)
	end
end

function handlers.StorePut(player, _state, uid, count)
	if isString(uid) and isCount(count) then
		Building.storagePut(player, uid, count)
	end
end

function handlers.StoreTake(player, _state, uid, count)
	if isString(uid) and isCount(count) then
		Building.storageTake(player, uid, count)
	end
end

function handlers.StoreClose(player)
	Building.closeStorage(player)
end

function Inventory.init()
	Net.get("Action").OnServerEvent:Connect(function(player, kind, ...)
		if typeof(kind) ~= "string" or not allowed(player) then
			return
		end
		local handler = handlers[kind]
		local state = PlayerState.get(player)
		if handler and state then
			handler(player, state, ...)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		budget[player] = nil
	end)
end

return Inventory

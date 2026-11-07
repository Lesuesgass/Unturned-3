-- Per-player inventory state and the helpers that change it.
-- Survival stats live as attributes on the Player (Food, Water, Stamina, Immunity, Oxygen, Bleeding)
-- so they replicate to the client automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Net = require(Shared.Net)

export type Stack = { uid: string, id: string, count: number, mag: number? }

export type State = {
	inventory: { Stack },
	hotbar: { string },
	equipped: number,
	heldUid: string,
	pack: string,
	nextUid: number,
	wantSprint: boolean,
	lastStaminaUse: number,
	lastAttack: number,
	reloading: boolean,
	lifeStarted: number,
	syncQueued: boolean,
}

local HOTBAR_SIZE = 5

local PlayerState = {}
PlayerState.HotbarSize = HOTBAR_SIZE

-- Set by the Equipment service: called after a sync when the equipped stack changed.
PlayerState.onEquipmentChanged = nil :: ((Player) -> ())?

-- Set by the Building service: extra fields (open storage) added to every snapshot.
PlayerState.snapshotExtras = nil :: ((Player) -> { [string]: any })?

local states: { [Player]: State } = {}

local syncRemote: RemoteEvent
local notifyRemote: RemoteEvent

function PlayerState.init()
	syncRemote = Net.get("Sync")
	notifyRemote = Net.get("Notify")
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

local function newState(): State
	local hotbar = {}
	for i = 1, HOTBAR_SIZE do
		hotbar[i] = ""
	end
	return {
		inventory = {},
		hotbar = hotbar,
		equipped = 0,
		heldUid = "",
		pack = "",
		nextUid = 1,
		wantSprint = false,
		lastStaminaUse = 0,
		lastAttack = 0,
		reloading = false,
		lifeStarted = os.clock(),
		syncQueued = false,
	}
end

function PlayerState.get(player: Player): State?
	return states[player]
end

-- Fresh inventory and stats, used at the start of every life.
function PlayerState.reset(player: Player): State
	local state = newState()
	states[player] = state
	player:SetAttribute("Food", 100)
	player:SetAttribute("Water", 100)
	player:SetAttribute("Stamina", Config.Survival.StaminaMax)
	player:SetAttribute("Immunity", 100)
	player:SetAttribute("Oxygen", Config.Survival.OxygenMax)
	player:SetAttribute("Bleeding", false)
	player:SetAttribute("Sprinting", false)
	player:SetAttribute("Reloading", false)
	return state
end

function PlayerState.notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

function PlayerState.capacity(state: State): number
	local pack = Items.get(state.pack)
	return Config.Player.BaseCarryKg + (if pack then pack.capacity or 0 else 0)
end

function PlayerState.weight(state: State): number
	local total = 0
	for _, stack in state.inventory do
		local def = Items.get(stack.id)
		if def then
			total += def.weight * stack.count
		end
	end
	return total
end

function PlayerState.findStack(state: State, uid: string): (Stack?, number?)
	for index, stack in state.inventory do
		if stack.uid == uid then
			return stack, index
		end
	end
	return nil, nil
end

function PlayerState.count(state: State, id: string): number
	local total = 0
	for _, stack in state.inventory do
		if stack.id == id then
			total += stack.count
		end
	end
	return total
end

-- How many units of an item still fit by weight.
function PlayerState.room(state: State, id: string): number
	local def = Items.get(id)
	if not def then
		return 0
	end
	if def.weight <= 0 then
		return math.huge
	end
	local free = PlayerState.capacity(state) - PlayerState.weight(state)
	return math.max(0, math.floor(free / def.weight + 1e-6))
end

local function newUid(state: State): string
	local uid = tostring(state.nextUid)
	state.nextUid += 1
	return uid
end

-- Adds up to count units. Returns how many were actually added.
function PlayerState.add(player: Player, id: string, count: number, mag: number?): number
	local state = states[player]
	local def = Items.get(id)
	if not state or not def or count <= 0 then
		return 0
	end
	local remaining = math.min(count, PlayerState.room(state, id))
	local added = 0

	-- Top up existing stacks first.
	if def.maxStack > 1 then
		for _, stack in state.inventory do
			if remaining <= 0 then
				break
			end
			if stack.id == id and stack.count < def.maxStack then
				local take = math.min(remaining, def.maxStack - stack.count)
				stack.count += take
				remaining -= take
				added += take
			end
		end
	end

	while remaining > 0 do
		local take = math.min(remaining, def.maxStack)
		local stack: Stack = { uid = newUid(state), id = id, count = take }
		if def.category == "Gun" then
			stack.mag = mag or 0
		end
		table.insert(state.inventory, stack)
		remaining -= take
		added += take

		-- Weapons and tools go straight into a free hotbar slot.
		if Items.isEquippable(def) then
			for slot = 1, HOTBAR_SIZE do
				if state.hotbar[slot] == "" then
					state.hotbar[slot] = stack.uid
					break
				end
			end
		end
	end

	if added > 0 then
		PlayerState.sync(player)
	end
	return added
end

-- Removes count units from a specific stack. Returns how many were removed.
function PlayerState.takeFromStack(player: Player, uid: string, count: number): number
	local state = states[player]
	if not state then
		return 0
	end
	local stack, index = PlayerState.findStack(state, uid)
	if not stack or not index then
		return 0
	end
	local take = math.min(count, stack.count)
	stack.count -= take
	if stack.count <= 0 then
		table.remove(state.inventory, index)
	end
	PlayerState.sync(player)
	return take
end

-- Removes count units of an item across all stacks. Returns false (and changes nothing)
-- when there are not enough.
function PlayerState.remove(player: Player, id: string, count: number): boolean
	local state = states[player]
	if not state or PlayerState.count(state, id) < count then
		return false
	end
	local remaining = count
	for index = #state.inventory, 1, -1 do
		local stack = state.inventory[index]
		if stack.id == id then
			local take = math.min(remaining, stack.count)
			stack.count -= take
			remaining -= take
			if stack.count <= 0 then
				table.remove(state.inventory, index)
			end
			if remaining <= 0 then
				break
			end
		end
	end
	PlayerState.sync(player)
	return true
end

function PlayerState.equippedStack(state: State): Stack?
	if state.equipped == 0 then
		return nil
	end
	local uid = state.hotbar[state.equipped]
	if uid == "" then
		return nil
	end
	return (PlayerState.findStack(state, uid))
end

local function flush(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.syncQueued = false

	-- Drop hotbar references to stacks that no longer exist.
	for slot = 1, HOTBAR_SIZE do
		local uid = state.hotbar[slot]
		if uid ~= "" and not PlayerState.findStack(state, uid) then
			state.hotbar[slot] = ""
		end
	end
	local equippedStack = PlayerState.equippedStack(state)
	if not equippedStack then
		state.equipped = 0
	end
	local heldUid = if equippedStack then equippedStack.uid else ""
	if heldUid ~= state.heldUid then
		state.heldUid = heldUid
		if PlayerState.onEquipmentChanged then
			PlayerState.onEquipmentChanged(player)
		end
	end

	local inventory = {}
	for i, stack in state.inventory do
		inventory[i] = { uid = stack.uid, id = stack.id, count = stack.count, mag = stack.mag or -1 }
	end
	local snapshot = {
		inventory = inventory,
		hotbar = table.clone(state.hotbar),
		equipped = state.equipped,
		pack = state.pack,
		weight = PlayerState.weight(state),
		capacity = PlayerState.capacity(state),
	}
	if PlayerState.snapshotExtras then
		for key, value in PlayerState.snapshotExtras(player) do
			snapshot[key] = value
		end
	end
	syncRemote:FireClient(player, snapshot)
end

-- Queues an inventory snapshot for the client. Several changes in one frame send one snapshot.
function PlayerState.sync(player: Player)
	local state = states[player]
	if not state or state.syncQueued then
		return
	end
	state.syncQueued = true
	task.defer(flush, player)
end

return PlayerState

-- Client copy of the inventory, updated whenever the server sends a snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

export type Stack = { uid: string, id: string, count: number, mag: number }

local State = {
	inventory = {} :: { Stack },
	hotbar = { "", "", "", "", "" },
	equipped = 0,
	pack = "",
	weight = 0,
	capacity = 12,
	storage = false :: any,
	panelOpen = false,
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event

function State.init()
	Net.get("Sync").OnClientEvent:Connect(function(snapshot)
		State.inventory = snapshot.inventory or {}
		State.hotbar = snapshot.hotbar or State.hotbar
		State.equipped = snapshot.equipped or 0
		State.pack = snapshot.pack or ""
		State.weight = snapshot.weight or 0
		State.capacity = snapshot.capacity or 12
		State.storage = snapshot.storage or false
		changed:Fire()
	end)
end

function State.find(uid: string): Stack?
	for _, stack in State.inventory do
		if stack.uid == uid then
			return stack
		end
	end
	return nil
end

function State.count(id: string): number
	local total = 0
	for _, stack in State.inventory do
		if stack.id == id then
			total += stack.count
		end
	end
	return total
end

function State.equippedStack(): Stack?
	if State.equipped == 0 then
		return nil
	end
	local uid = State.hotbar[State.equipped]
	return if uid and uid ~= "" then State.find(uid) else nil
end

return State

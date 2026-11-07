-- Fills loot points with items and refills empty points over time, but never while a
-- player is close enough to see the item appear.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Drops = require(script.Parent.Drops)
local LootTables = require(script.Parent.LootTables)

local Loot = {}

local rng = Random.new()
local points = {}

local function fill(point)
	local id, count = LootTables.roll(point.table, rng)
	if not id then
		return
	end
	local def = Items.get(id)
	local mag = nil
	if def and def.category == "Gun" then
		mag = rng:NextInteger(0, def.magSize)
	end
	local part = Drops.spawn(id, count, point.position, mag)
	if not part then
		return
	end
	point.drop = part
	part.Destroying:Connect(function()
		if point.drop == part then
			point.drop = nil
			point.emptiedAt = os.clock()
		end
	end)
end

local function playerNear(position: Vector3, radius: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude < radius then
			return true
		end
	end
	return false
end

-- Rolls an item from a table and drops it at a position (used for zombie loot).
function Loot.dropFromTable(name: string, position: Vector3)
	local id, count = LootTables.roll(name, rng)
	if id then
		Drops.spawn(id, count, Drops.groundBelow(position), nil, Config.Loot.DroppedItemLifetime)
	end
end

function Loot.init(world)
	for _, source in world.lootPoints do
		local point = { position = source.position, table = source.table, drop = nil, emptiedAt = -math.huge }
		table.insert(points, point)
		if rng:NextNumber() < Config.Loot.InitialFill then
			fill(point)
		else
			point.emptiedAt = os.clock()
		end
	end

	task.spawn(function()
		while true do
			task.wait(Config.Loot.CheckInterval)
			local now = os.clock()
			for _, point in points do
				if
					not point.drop
					and now - point.emptiedAt > Config.Loot.RespawnSeconds
					and not playerNear(point.position, Config.Loot.PlayerBlockRadius)
				then
					if rng:NextNumber() < Config.Loot.RespawnChance then
						fill(point)
					else
						point.emptiedAt = now
					end
				end
			end
		end
	end)
end

return Loot

-- Harvestable world objects: trees give logs, rocks give stone, wrecks give scrap metal.
-- Hitting one with a melee item deals that item's "gather" damage for the resource type.
-- Every chunk of damage yields one unit; a depleted object disappears and regrows later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(script.Parent.PlayerState)
local Drops = require(script.Parent.Drops)
local Items = require(ReplicatedStorage.Shared.Items)
local Config = require(ReplicatedStorage.Shared.Config)

local Resources = {}

local RULES = {
	log = { health = 100, perUnit = 25, regrow = 600 },
	stone = { health = 150, perUnit = 30, regrow = 600 },
	scrap = { health = 160, perUnit = 40, regrow = 900 },
}

local byPart: { [BasePart]: any } = {}

function Resources.init(world)
	for _, entry in world.resources do
		local rule = RULES[entry.resource]
		if rule then
			local record = {
				part = entry.part,
				parts = entry.parts,
				resource = entry.resource,
				yield = entry.yield,
				health = rule.health,
				progress = 0,
				depleted = false,
				saved = {},
			}
			for _, part in entry.parts do
				byPart[part] = record
			end
		end
	end
end

local function setVisible(record, visible: boolean)
	for _, part in record.parts do
		if visible then
			local saved = record.saved[part]
			if saved then
				part.Transparency = saved.transparency
				part.CanCollide = saved.collide
				part.CanQuery = saved.query
			end
		else
			record.saved[part] = { transparency = part.Transparency, collide = part.CanCollide, query = part.CanQuery }
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
		end
	end
end

-- Returns true if the part belongs to a harvestable resource.
function Resources.isResource(part: Instance): boolean
	return part:IsA("BasePart") and byPart[part] ~= nil
end

function Resources.harvest(player: Player, part: BasePart, def): boolean
	local record = byPart[part]
	if not record or record.depleted then
		return false
	end
	local damage = def.gather and def.gather[record.resource] or 0
	if damage <= 0 then
		PlayerState.notify(player, "This tool cannot harvest that")
		return true
	end
	local rule = RULES[record.resource]
	record.health -= damage
	record.progress += damage

	local units = math.floor(record.progress / rule.perUnit)
	record.progress -= units * rule.perUnit
	if record.health <= 0 then
		units += 1
	end
	if units > 0 then
		local state = PlayerState.get(player)
		local added = PlayerState.add(player, record.yield, units)
		if added > 0 then
			local yieldDef = Items.get(record.yield)
			PlayerState.notify(player, `+{added} {yieldDef and yieldDef.name or record.yield}`)
		end
		if added < units and state then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				Drops.spawn(
					record.yield,
					units - added,
					Drops.groundBelow(root.Position),
					nil,
					Config.Loot.DroppedItemLifetime
				)
				PlayerState.notify(player, "Too heavy, dropped on the ground")
			end
		end
	end

	if record.health <= 0 then
		record.depleted = true
		setVisible(record, false)
		task.delay(rule.regrow, function()
			record.depleted = false
			record.health = rule.health
			record.progress = 0
			setVisible(record, true)
		end)
	end
	return true
end

return Resources

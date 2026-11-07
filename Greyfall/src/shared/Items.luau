-- Item definitions shared by server and client.
--
-- Fields
--   name, category, weight (kg per unit), maxStack, description
--   model = { size, color, material? }   placeholder block used in the world and in hands
--   Consumables: food, water, health, infection (negative cures), stamina, stopsBleeding
--   Melee: damage, range, cooldown, structureDamage,
--          gather = { log?, stone?, scrap? }  damage dealt to trees, rocks and wrecks
--   Gun: damage, pellets?, fireRate (seconds between shots), automatic, magSize, ammo,
--        range, spread (degrees), reloadTime, noise (zombie alert radius), sound (Config.Sounds key),
--        structureDamage (per bullet or pellet)
--   Explosive: structureDamage, playerDamage, radius, fuse (seconds)
--   Structure: generated from BuildingDefs, carries tier and piece
--   Backpack: capacity (extra kg)
--   Tool: light = { range, brightness, angle }, repairs (true for hammer and blowtorch)

export type ItemDef = {
	id: string,
	name: string,
	category: string,
	weight: number,
	maxStack: number,
	description: string,
	model: { size: Vector3, color: Color3, material: Enum.Material? },
	[string]: any,
}

local BuildingDefs = require(script.Parent.BuildingDefs)

local C = Color3.fromRGB
local V = Vector3.new

local defs: { [string]: any } = {
	-- Food
	canned_beans = {
		name = "Canned Beans",
		category = "Food",
		weight = 0.4,
		maxStack = 4,
		food = 30,
		description = "Cold, but filling.",
		model = { size = V(0.8, 1, 0.8), color = C(150, 120, 90), material = Enum.Material.Metal },
	},
	canned_soup = {
		name = "Canned Soup",
		category = "Food",
		weight = 0.4,
		maxStack = 4,
		food = 25,
		water = 10,
		description = "Restores a little water as well.",
		model = { size = V(0.8, 1, 0.8), color = C(140, 70, 60), material = Enum.Material.Metal },
	},
	apple = {
		name = "Apple",
		category = "Food",
		weight = 0.2,
		maxStack = 6,
		food = 10,
		water = 5,
		description = "Found in orchards and kitchens.",
		model = { size = V(0.6, 0.6, 0.6), color = C(150, 50, 45) },
	},
	bread = {
		name = "Bread",
		category = "Food",
		weight = 0.3,
		maxStack = 4,
		food = 20,
		description = "Slightly stale.",
		model = { size = V(1.4, 0.6, 0.7), color = C(170, 130, 80) },
	},
	chocolate_bar = {
		name = "Chocolate Bar",
		category = "Food",
		weight = 0.1,
		maxStack = 8,
		food = 12,
		stamina = 25,
		description = "Small boost of food and stamina.",
		model = { size = V(1, 0.2, 0.5), color = C(90, 60, 45) },
	},
	mre = {
		name = "Field Ration",
		category = "Food",
		weight = 0.6,
		maxStack = 3,
		food = 60,
		water = 10,
		description = "Military ration pack.",
		model = { size = V(1.2, 0.4, 0.8), color = C(110, 105, 75) },
	},

	-- Water
	water_bottle = {
		name = "Water Bottle",
		category = "Water",
		weight = 0.5,
		maxStack = 4,
		water = 40,
		description = "Clean drinking water.",
		model = { size = V(0.5, 1.2, 0.5), color = C(150, 175, 185), material = Enum.Material.Glass },
	},
	soda_can = {
		name = "Soda Can",
		category = "Water",
		weight = 0.35,
		maxStack = 6,
		water = 20,
		stamina = 15,
		description = "Flat, warm and sugary.",
		model = { size = V(0.5, 0.8, 0.5), color = C(120, 130, 140), material = Enum.Material.Metal },
	},
	canteen = {
		name = "Canteen",
		category = "Water",
		weight = 0.8,
		maxStack = 2,
		water = 60,
		description = "A full military canteen.",
		model = { size = V(0.9, 1.1, 0.5), color = C(95, 100, 70), material = Enum.Material.Metal },
	},

	-- Medical
	bandage = {
		name = "Bandage",
		category = "Medical",
		weight = 0.1,
		maxStack = 6,
		health = 15,
		stopsBleeding = true,
		description = "Stops bleeding and restores some health.",
		model = { size = V(0.6, 0.4, 0.6), color = C(215, 210, 195), material = Enum.Material.Fabric },
	},
	medkit = {
		name = "Medkit",
		category = "Medical",
		weight = 0.8,
		maxStack = 2,
		health = 60,
		infection = -10,
		stopsBleeding = true,
		description = "Restores a large amount of health.",
		model = { size = V(1.2, 0.5, 0.9), color = C(170, 165, 155) },
	},
	painkillers = {
		name = "Painkillers",
		category = "Medical",
		weight = 0.1,
		maxStack = 4,
		health = 25,
		description = "Restores some health.",
		model = { size = V(0.4, 0.6, 0.4), color = C(190, 185, 170) },
	},
	antibiotics = {
		name = "Antibiotics",
		category = "Medical",
		weight = 0.1,
		maxStack = 4,
		infection = -50,
		description = "Reduces infection by half of the bar.",
		model = { size = V(0.4, 0.6, 0.4), color = C(120, 150, 120) },
	},

	-- Melee
	kitchen_knife = {
		name = "Kitchen Knife",
		category = "Melee",
		weight = 0.3,
		maxStack = 1,
		damage = 20,
		range = 5,
		cooldown = 0.45,
		gather = { log = 4, scrap = 3 },
		structureDamage = 3,
		description = "Fast but weak.",
		model = { size = V(0.2, 0.3, 1.8), color = C(160, 160, 160), material = Enum.Material.Metal },
	},
	scrap_knife = {
		name = "Scrap Knife",
		category = "Melee",
		weight = 0.4,
		maxStack = 1,
		damage = 18,
		range = 5,
		cooldown = 0.45,
		gather = { log = 4, scrap = 3 },
		structureDamage = 3,
		description = "A sharpened piece of scrap.",
		model = { size = V(0.25, 0.3, 1.8), color = C(120, 110, 100), material = Enum.Material.CorrodedMetal },
	},
	wooden_club = {
		name = "Wooden Club",
		category = "Melee",
		weight = 1.2,
		maxStack = 1,
		damage = 25,
		range = 6,
		cooldown = 0.8,
		gather = { log = 6 },
		structureDamage = 6,
		description = "Crude, heavy, reliable.",
		model = { size = V(0.5, 0.5, 3.2), color = C(110, 80, 55), material = Enum.Material.Wood },
	},
	crowbar = {
		name = "Crowbar",
		category = "Melee",
		weight = 1.5,
		maxStack = 1,
		damage = 35,
		range = 6,
		cooldown = 0.85,
		gather = { log = 6, stone = 5, scrap = 30 },
		structureDamage = 10,
		description = "Solid steel.",
		model = { size = V(0.25, 0.25, 3), color = C(70, 70, 75), material = Enum.Material.Metal },
	},
	machete = {
		name = "Machete",
		category = "Melee",
		weight = 1,
		maxStack = 1,
		damage = 40,
		range = 6,
		cooldown = 0.75,
		gather = { log = 15, scrap = 4 },
		structureDamage = 6,
		description = "Long blade, good reach.",
		model = { size = V(0.15, 0.5, 3), color = C(150, 150, 145), material = Enum.Material.Metal },
	},
	fire_axe = {
		name = "Fire Axe",
		category = "Melee",
		weight = 2.5,
		maxStack = 1,
		damage = 50,
		range = 6.5,
		cooldown = 1.2,
		gather = { log = 35, stone = 5, scrap = 10 },
		structureDamage = 14,
		description = "Heavy hits. Fells trees quickly.",
		model = { size = V(0.4, 1, 3.4), color = C(140, 55, 45) },
	},
	pickaxe = {
		name = "Pickaxe",
		category = "Melee",
		weight = 2.8,
		maxStack = 1,
		damage = 32,
		range = 6,
		cooldown = 1.1,
		gather = { log = 8, stone = 30, scrap = 12 },
		structureDamage = 12,
		description = "Breaks rocks into stone.",
		model = { size = V(1.6, 0.3, 3.2), color = C(95, 90, 85), material = Enum.Material.Metal },
	},

	-- Guns
	service_pistol = {
		name = "Service Pistol",
		category = "Gun",
		weight = 0.9,
		maxStack = 1,
		structureDamage = 3,
		damage = 28,
		fireRate = 0.22,
		automatic = false,
		magSize = 12,
		ammo = "pistol_ammo",
		range = 250,
		spread = 1.2,
		reloadTime = 1.6,
		noise = 120,
		sound = "PistolShot",
		description = "Semi-automatic sidearm. Uses pistol rounds.",
		model = { size = V(0.3, 0.6, 1.4), color = C(45, 45, 48), material = Enum.Material.Metal },
	},
	pump_shotgun = {
		name = "Pump Shotgun",
		category = "Gun",
		weight = 3,
		maxStack = 1,
		structureDamage = 2,
		damage = 12,
		pellets = 8,
		fireRate = 0.9,
		automatic = false,
		magSize = 6,
		ammo = "shotgun_shells",
		range = 80,
		spread = 6,
		reloadTime = 2.8,
		noise = 160,
		sound = "ShotgunShot",
		description = "Devastating up close. Uses shotgun shells.",
		model = { size = V(0.35, 0.6, 3.4), color = C(70, 55, 45), material = Enum.Material.Wood },
	},
	hunting_rifle = {
		name = "Hunting Rifle",
		category = "Gun",
		weight = 3.5,
		maxStack = 1,
		structureDamage = 8,
		damage = 70,
		fireRate = 1.1,
		automatic = false,
		magSize = 5,
		ammo = "rifle_ammo",
		range = 600,
		spread = 0.3,
		reloadTime = 2.5,
		noise = 200,
		sound = "RifleShot",
		description = "Accurate bolt action. Uses rifle rounds.",
		model = { size = V(0.3, 0.6, 4), color = C(85, 65, 50), material = Enum.Material.Wood },
	},
	carbine = {
		name = "Carbine",
		category = "Gun",
		weight = 3.2,
		maxStack = 1,
		structureDamage = 4,
		damage = 30,
		fireRate = 0.11,
		automatic = true,
		magSize = 30,
		ammo = "rifle_ammo",
		range = 350,
		spread = 1.6,
		reloadTime = 2.2,
		noise = 200,
		sound = "RifleShot",
		description = "Fully automatic. Uses rifle rounds.",
		model = { size = V(0.35, 0.7, 3), color = C(55, 58, 50), material = Enum.Material.Metal },
	},

	-- Ammo
	pistol_ammo = {
		name = "Pistol Rounds",
		category = "Ammo",
		weight = 0.012,
		maxStack = 48,
		description = "For the Service Pistol.",
		model = { size = V(0.6, 0.4, 0.4), color = C(150, 125, 70), material = Enum.Material.Metal },
	},
	shotgun_shells = {
		name = "Shotgun Shells",
		category = "Ammo",
		weight = 0.04,
		maxStack = 24,
		description = "For the Pump Shotgun.",
		model = { size = V(0.6, 0.4, 0.4), color = C(140, 50, 45) },
	},
	rifle_ammo = {
		name = "Rifle Rounds",
		category = "Ammo",
		weight = 0.02,
		maxStack = 60,
		description = "For the Hunting Rifle and Carbine.",
		model = { size = V(0.6, 0.4, 0.4), color = C(160, 140, 80), material = Enum.Material.Metal },
	},

	-- Materials
	cloth = {
		name = "Cloth",
		category = "Material",
		weight = 0.1,
		maxStack = 10,
		description = "Used to craft bandages and packs.",
		model = { size = V(0.8, 0.2, 0.8), color = C(150, 145, 130), material = Enum.Material.Fabric },
	},
	scrap_metal = {
		name = "Scrap Metal",
		category = "Material",
		weight = 0.5,
		maxStack = 10,
		description = "Bent and rusted.",
		model = { size = V(1, 0.3, 0.8), color = C(115, 100, 85), material = Enum.Material.CorrodedMetal },
	},

	-- Building and raiding materials
	pine_log = {
		name = "Pine Log",
		category = "Material",
		weight = 2,
		maxStack = 4,
		description = "Cut it into pine planks.",
		model = { size = V(0.9, 0.9, 3), color = C(105, 80, 55), material = Enum.Material.Wood },
	},
	birch_log = {
		name = "Birch Log",
		category = "Material",
		weight = 2,
		maxStack = 4,
		description = "Cut it into birch planks.",
		model = { size = V(0.9, 0.9, 3), color = C(215, 210, 195), material = Enum.Material.Wood },
	},
	maple_log = {
		name = "Maple Log",
		category = "Material",
		weight = 2.2,
		maxStack = 4,
		description = "Cut it into maple planks.",
		model = { size = V(0.9, 0.9, 3), color = C(120, 80, 55), material = Enum.Material.Wood },
	},
	pine_planks = {
		name = "Pine Planks",
		category = "Material",
		weight = 0.4,
		maxStack = 15,
		description = "The cheapest building material.",
		model = { size = V(2.5, 0.25, 0.8), color = C(170, 135, 95), material = Enum.Material.WoodPlanks },
	},
	birch_planks = {
		name = "Birch Planks",
		category = "Material",
		weight = 0.4,
		maxStack = 15,
		description = "Sturdier than pine.",
		model = { size = V(2.5, 0.25, 0.8), color = C(205, 190, 160), material = Enum.Material.WoodPlanks },
	},
	maple_planks = {
		name = "Maple Planks",
		category = "Material",
		weight = 0.45,
		maxStack = 15,
		description = "The strongest wood.",
		model = { size = V(2.5, 0.25, 0.8), color = C(140, 90, 60), material = Enum.Material.WoodPlanks },
	},
	stone = {
		name = "Stone",
		category = "Material",
		weight = 0.6,
		maxStack = 12,
		description = "Broken from rocks with a pickaxe.",
		model = { size = V(0.9, 0.7, 0.9), color = C(120, 118, 112), material = Enum.Material.Rock },
	},
	charcoal = {
		name = "Charcoal",
		category = "Material",
		weight = 0.2,
		maxStack = 12,
		description = "Burned pine. Fuel for bricks and gunpowder.",
		model = { size = V(0.7, 0.4, 0.5), color = C(40, 38, 36), material = Enum.Material.Slate },
	},
	bricks = {
		name = "Bricks",
		category = "Material",
		weight = 0.8,
		maxStack = 12,
		description = "Fired from stone and charcoal.",
		model = { size = V(1.2, 0.5, 0.6), color = C(150, 85, 70), material = Enum.Material.Brick },
	},
	metal_plate = {
		name = "Metal Plate",
		category = "Material",
		weight = 1,
		maxStack = 10,
		description = "Welded from scrap with a blowtorch.",
		model = { size = V(1.6, 0.2, 1.2), color = C(110, 115, 118), material = Enum.Material.DiamondPlate },
	},
	fertilizer = {
		name = "Fertilizer",
		category = "Material",
		weight = 0.5,
		maxStack = 8,
		description = "Found on farms. Used for gunpowder.",
		model = { size = V(0.8, 1, 0.5), color = C(120, 130, 90), material = Enum.Material.Fabric },
	},
	gunpowder = {
		name = "Gunpowder",
		category = "Material",
		weight = 0.1,
		maxStack = 20,
		description = "Used to craft explosives.",
		model = { size = V(0.5, 0.4, 0.5), color = C(55, 55, 55) },
	},
	matchbox = {
		name = "Matchbox",
		category = "Material",
		weight = 0.05,
		maxStack = 1,
		description = "Needed to burn logs into charcoal. Not used up.",
		model = { size = V(0.5, 0.2, 0.3), color = C(160, 60, 50) },
	},

	-- Explosives
	pipe_charge = {
		name = "Pipe Charge",
		category = "Explosive",
		weight = 1,
		maxStack = 4,
		structureDamage = 240,
		playerDamage = 70,
		radius = 8,
		fuse = 6,
		description = "Plant it on a structure. Breaks wood quickly, dents brick.",
		model = { size = V(0.5, 0.5, 1.4), color = C(90, 85, 75), material = Enum.Material.Metal },
	},
	demolition_charge = {
		name = "Demolition Charge",
		category = "Explosive",
		weight = 2.5,
		maxStack = 2,
		structureDamage = 760,
		playerDamage = 120,
		radius = 11,
		fuse = 8,
		description = "Plant it on a structure. The only reliable way through metal.",
		model = { size = V(1.4, 0.7, 1), color = C(95, 100, 70), material = Enum.Material.Metal },
	},

	-- Backpacks
	cloth_satchel = {
		name = "Cloth Satchel",
		category = "Backpack",
		weight = 0.5,
		maxStack = 1,
		capacity = 6,
		description = "Wear it to carry 6 kg more.",
		model = { size = V(1.4, 1.4, 0.6), color = C(130, 120, 100), material = Enum.Material.Fabric },
	},
	daypack = {
		name = "Daypack",
		category = "Backpack",
		weight = 0.8,
		maxStack = 1,
		capacity = 10,
		description = "Wear it to carry 10 kg more.",
		model = { size = V(1.6, 1.8, 0.8), color = C(70, 80, 90), material = Enum.Material.Fabric },
	},
	field_pack = {
		name = "Field Pack",
		category = "Backpack",
		weight = 1.4,
		maxStack = 1,
		capacity = 20,
		description = "Military pack. Wear it to carry 20 kg more.",
		model = { size = V(1.8, 2.2, 1), color = C(90, 95, 65), material = Enum.Material.Fabric },
	},

	-- Tools
	hammer = {
		name = "Hammer",
		category = "Tool",
		weight = 0.8,
		maxStack = 1,
		repairs = true,
		description = "Needed to craft structures. Equip it and click a wood or brick piece to repair it, press X to salvage your own.",
		model = { size = V(0.3, 1, 1.6), color = C(110, 90, 70), material = Enum.Material.Wood },
	},
	blowtorch = {
		name = "Blowtorch",
		category = "Tool",
		weight = 1.2,
		maxStack = 1,
		repairs = true,
		description = "Welds scrap metal into plates. Equip it and click a metal piece to repair it.",
		model = { size = V(0.5, 0.8, 1.6), color = C(160, 120, 50), material = Enum.Material.Metal },
	},
	flashlight = {
		name = "Flashlight",
		category = "Tool",
		weight = 0.3,
		maxStack = 1,
		light = { range = 60, brightness = 3, angle = 50 },
		description = "Equip it to light the way at night.",
		model = { size = V(0.35, 0.35, 1.3), color = C(40, 40, 40), material = Enum.Material.Metal },
	},
}

-- Structure kits, one per tier and piece, plus storage containers.
for _, tier in BuildingDefs.TierOrder do
	local tierDef = BuildingDefs.Tiers[tier]
	for _, piece in BuildingDefs.PieceOrder do
		local pieceDef = BuildingDefs.Pieces[piece]
		defs[BuildingDefs.itemId(tier, piece)] = {
			name = `{tierDef.name} {pieceDef.name}`,
			category = "Structure",
			weight = tierDef.kitWeight,
			maxStack = 4,
			tier = tier,
			piece = piece,
			description = `Equip it and click to place. {BuildingDefs.maxHealth(tier, piece)} health.`,
			model = { size = V(1.6, 1.2, 1.6), color = tierDef.color, material = tierDef.surface },
		}
	end
end
for id, storage in BuildingDefs.Storage do
	local tierDef = BuildingDefs.Tiers[storage.tier]
	defs[id] = {
		name = storage.name,
		category = "Structure",
		weight = tierDef.kitWeight,
		maxStack = 2,
		tier = storage.tier,
		piece = id,
		description = `Storage for {storage.slots} stacks. Only you can open it. {storage.health} health.`,
		model = { size = V(1.6, 1.2, 1.2), color = tierDef.color, material = tierDef.surface },
	}
end

local Items = {}

Items.Defs = defs :: { [string]: ItemDef }

for id, def in defs do
	def.id = id
end

function Items.get(id: string): ItemDef?
	return defs[id]
end

function Items.isEquippable(def: ItemDef): boolean
	return def.category == "Melee"
		or def.category == "Gun"
		or def.category == "Tool"
		or def.category == "Structure"
		or def.category == "Explosive"
end

function Items.isConsumable(def: ItemDef): boolean
	return def.category == "Food" or def.category == "Water" or def.category == "Medical"
end

-- One short line describing what an item does, for the inventory panel.
function Items.summary(def: ItemDef): string
	local parts = {}
	if def.food then
		table.insert(parts, `Food +{def.food}`)
	end
	if def.water then
		table.insert(parts, `Water +{def.water}`)
	end
	if def.health then
		table.insert(parts, `Health +{def.health}`)
	end
	if def.infection then
		table.insert(parts, `Infection {def.infection}`)
	end
	if def.stamina then
		table.insert(parts, `Stamina +{def.stamina}`)
	end
	if def.stopsBleeding then
		table.insert(parts, "Stops bleeding")
	end
	if def.category == "Melee" then
		table.insert(parts, `Damage {def.damage}`)
		table.insert(parts, `Speed {string.format("%.2f", def.cooldown)} s`)
	elseif def.category == "Gun" then
		local dmg = if def.pellets then `{def.damage} x {def.pellets}` else tostring(def.damage)
		table.insert(parts, `Damage {dmg}`)
		table.insert(parts, `Magazine {def.magSize}`)
		local ammoDef = defs[def.ammo]
		if ammoDef then
			table.insert(parts, ammoDef.name)
		end
	elseif def.category == "Explosive" then
		table.insert(parts, `Structure damage {def.structureDamage}`)
		table.insert(parts, `Radius {def.radius}`)
	elseif def.category == "Backpack" then
		table.insert(parts, `Capacity +{def.capacity} kg`)
	end
	table.insert(parts, `{string.format("%.2f", def.weight)} kg`)
	return table.concat(parts, "   ")
end

return Items

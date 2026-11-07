-- Central tuning values. Every gameplay number that is worth tweaking lives here.
-- Distances are in studs (1 stud is roughly 0.28 m), weights in kilograms, times in seconds.

local Config = {}

Config.GameName = "Greyfall"

-- Choices pre-selected in the main menu.
Config.DefaultMap = "KestrelIsland"
Config.DefaultDifficulty = "Medium"
Config.DefaultMode = "Singleplayer"

-- Maps listed in the main menu, in order. Ids match src/server/Services/World/Maps.
Config.Maps = {
	{
		id = "KestrelIsland",
		name = "Kestrel Island",
		description = "A rural island. Farms, a fishing village, a lighthouse and a radar station.",
	},
	{
		id = "Ridgeline",
		name = "Ridgeline",
		description = "A large mainland. A port city, a military base and snowy mountains.",
	},
}

-- Difficulty rules. Loot scales by half per step, so it gets exponentially scarcer.
Config.DifficultyOrder = { "Easy", "Medium", "Hard" }
Config.Difficulty = {
	Easy = {
		summary = "No bleeding. Plenty of loot. Weaker zombies, slower hunger.",
		bleeding = false,
		zombieBleedChance = 0,
		weaponBleedScale = 0,
		lootScale = 1,
		zombieDamageScale = 0.75,
		immunityLossScale = 0.6,
		zombieCountScale = 0.75,
		hungerScale = 0.8,
	},
	Medium = {
		summary = "Zombie hits cause bleeding 5% of the time; weapons have their own chance. Half the loot.",
		bleeding = true,
		zombieBleedChance = 0.05,
		weaponBleedScale = 1,
		lootScale = 0.5,
		zombieDamageScale = 1,
		immunityLossScale = 1,
		zombieCountScale = 1,
		hungerScale = 1,
	},
	Hard = {
		summary = "Zombie hits cause bleeding 15% of the time, weapons more often. A quarter of the loot. More, stronger zombies.",
		bleeding = true,
		zombieBleedChance = 0.15,
		weaponBleedScale = 1.5,
		lootScale = 0.25,
		zombieDamageScale = 1.3,
		immunityLossScale = 1.4,
		zombieCountScale = 1.3,
		hungerScale = 1.2,
	},
}

Config.Player = {
	WalkSpeed = 14,
	SprintSpeed = 22,
	MaxCameraZoom = 18,
	BaseCarryKg = 12,
	RespawnDelay = 6,
	-- Items every new life starts with: { itemId, count }
	StarterItems = {
		{ "apple", 1 },
		{ "water_bottle", 1 },
		{ "bandage", 1 },
	},
}

Config.Survival = {
	FoodDrainPerSecond = 100 / (45 * 60), -- full to empty in 45 minutes
	WaterDrainPerSecond = 100 / (30 * 60), -- full to empty in 30 minutes
	SprintWaterMultiplier = 2,
	StarveDamagePerSecond = 0.6, -- when food or water is empty
	RegenThreshold = 60, -- food and water above this let health regenerate
	RegenPerSecond = 0.35,
	ImmunityDamageBelow = 50, -- immunity under this drains health
	ImmunityDamagePerSecond = 0.8, -- at 0 immunity, scaled down linearly to the threshold
	RegenImmunity = 75, -- immunity needed for health to regenerate
	BleedDamagePerSecond = 0.8,

	StaminaMax = 100,
	StaminaDrainPerSecond = 14,
	StaminaRegenPerSecond = 10,
	StaminaRegenDelay = 1.2,
	MeleeStaminaCost = 6,

	OxygenMax = 100,
	OxygenUnderwaterDrain = 4, -- per second with the head under water (25 s of air)
	OxygenAltitude = 240, -- studs above sea level where the air gets thin
	OxygenAltitudeDrain = 2,
	OxygenRegen = 20,
	SuffocateDamagePerSecond = 5,

	FallDamageMinSpeed = 58, -- downward speed (studs/s) before landing hurts
	FallDamagePerSpeed = 1.2,
}

Config.Zombies = {
	MaxTotal = 70,
	Health = 100,
	WalkSpeed = 3,
	ChaseSpeed = 10, -- players walk at 14, so a steady walk outpaces them
	SightRange = 70,
	HearRange = 14,
	SprintHearRange = 32,
	LoseRange = 110,
	AttackRange = 4.5,
	AttackDamage = 11,
	AttackCooldown = 1.3,
	ImmunityLossPerHit = 7,
	ZoneActivateRange = 320, -- a zone fills with zombies when a player is this close
	ZoneDespawnDelay = 60, -- seconds without nearby players before a zone empties
	RespawnDelay = 90,
	ThinkInterval = 0.25,
	IdleThinkInterval = 1, -- zombies with no player nearby think less often
	IdleDistance = 150,
	CorpseTime = 6,
	LootDropChance = 0.25,
	SpawnMinPlayerDistance = 45,
}

Config.Loot = {
	-- Base values for Easy. Medium and Hard multiply fill and refill chances by their
	-- lootScale and divide the refill time by it.
	InitialFill = 0.8, -- chance each loot point starts filled
	RespawnSeconds = 480, -- an emptied point may refill after this long
	RespawnChance = 0.7,
	CheckInterval = 20,
	PlayerBlockRadius = 70, -- points never refill while a player is this close
	DroppedItemLifetime = 900,
}

Config.Combat = {
	PvP = true,
	HeadshotMultiplier = 2,
	MaxInteractDistance = 10,
}

Config.Building = {
	TownMargin = 25, -- no building inside a town radius plus this many studs
	MaxPiecesPerPlayer = 400,
}

-- Zombie voices are played by each client, quietly and only up close.
Config.ZombieVoice = {
	Volume = 0.35,
	MaxDistance = 60,
	MinInterval = 10,
	MaxInterval = 25,
	MaxPlaying = 2,
}

Config.DayNight = {
	DayLengthMinutes = 32,
	StartClockTime = 8,
}

-- Sound ids. Leave a value empty to play nothing. A list picks one at random each time.
-- Upload or pick your own sounds in the Creator Store and paste their ids here as
-- "rbxassetid://123456". The zombie sounds are community uploads from the Creator Store;
-- listen to them in Studio and replace any you do not like.
Config.Sounds = {
	MeleeSwing = "rbxasset://sounds/swordslash.wav",
	MeleeHit = "rbxasset://sounds/swordlunge.wav",
	PistolShot = "",
	ShotgunShot = "",
	RifleShot = "",
	Reload = "",
	DryFire = "",
	Pickup = "",
	ZombieGroan = {
		"rbxassetid://99659350948942",
		"rbxassetid://96529107293726",
		"rbxassetid://134766104012323",
		"rbxassetid://74103327872448",
	},
	ZombieAttack = {
		"rbxassetid://18942682166",
		"rbxassetid://18942691946",
		"rbxassetid://18942711304",
	},
	DoorOpen = "",
	Build = "",
	Repair = "",
	StructureBreak = "",
	ChargeBeep = "",
	Explosion = "",
}

return Config

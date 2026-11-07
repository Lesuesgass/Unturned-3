-- Central tuning values. Every gameplay number that is worth tweaking lives here.
-- Distances are in studs (1 stud is roughly 0.28 m), weights in kilograms, times in seconds.

local Config = {}

Config.GameName = "Greyfall"

-- Map this server builds. To pick another map in Studio, add a string attribute
-- named "Map" to Workspace with one of the ids in src/server/Services/World/Maps.
Config.DefaultMap = "KestrelIsland"

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
	InfectionDamageStart = 50, -- infection above this drains health
	InfectionDamagePerSecond = 0.8, -- at 100 infection, scaled down linearly to the start value
	BleedDamagePerSecond = 0.8,

	StaminaMax = 100,
	StaminaDrainPerSecond = 14,
	StaminaRegenPerSecond = 10,
	StaminaRegenDelay = 1.2,
	MeleeStaminaCost = 6,

	FallDamageMinSpeed = 58, -- downward speed (studs/s) before landing hurts
	FallDamagePerSpeed = 1.2,
}

Config.Zombies = {
	MaxTotal = 70,
	Health = 100,
	WalkSpeed = 5,
	ChaseSpeed = 15,
	SightRange = 70,
	HearRange = 14,
	SprintHearRange = 32,
	LoseRange = 110,
	AttackRange = 4.5,
	AttackDamage = 11,
	AttackCooldown = 1.3,
	InfectionPerHit = 7,
	BleedChance = 0.2,
	ZoneActivateRange = 320, -- a zone fills with zombies when a player is this close
	ZoneDespawnDelay = 60, -- seconds without nearby players before a zone empties
	RespawnDelay = 90,
	ThinkInterval = 0.25,
	CorpseTime = 6,
	LootDropChance = 0.25,
	SpawnMinPlayerDistance = 45,
}

Config.Loot = {
	InitialFill = 0.65, -- chance each loot point starts filled
	RespawnSeconds = 480, -- an emptied point may refill after this long
	RespawnChance = 0.6,
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

Config.DayNight = {
	DayLengthMinutes = 32,
	StartClockTime = 8,
}

-- Sound ids. Leave a value empty to play nothing. Upload or pick your own sounds
-- in the Creator Store and paste their ids here as "rbxassetid://123456".
Config.Sounds = {
	MeleeSwing = "rbxasset://sounds/swordslash.wav",
	MeleeHit = "rbxasset://sounds/swordlunge.wav",
	PistolShot = "",
	ShotgunShot = "",
	RifleShot = "",
	Reload = "",
	DryFire = "",
	Pickup = "",
	ZombieGroan = "",
	ZombieAttack = "",
	DoorOpen = "",
	Build = "",
	Repair = "",
	StructureBreak = "",
	ChargeBeep = "",
	Explosion = "",
}

return Config

-- Server entry point. Builds the world, starts every service, then lets players spawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)

Net.setup()
Players.CharacterAutoLoads = false

local Services = script.Parent.Services
local MapBuilder = require(Services.World.MapBuilder)
local PlayerState = require(Services.PlayerState)
local Equipment = require(Services.Equipment)
local Drops = require(Services.Drops)
local Effects = require(Services.Effects)
local Survival = require(Services.Survival)
local Loot = require(Services.Loot)
local Resources = require(Services.Resources)
local Doors = require(Services.Doors)
local Building = require(Services.Building)
local Zombies = require(Services.Zombies)
local Combat = require(Services.Combat)
local Inventory = require(Services.Inventory)
local Environment = require(Services.Environment)

local mapId = workspace:GetAttribute("Map")
if typeof(mapId) ~= "string" or mapId == "" then
	mapId = Config.DefaultMap
end

Environment.init()
local world = MapBuilder.build(mapId)
workspace:SetAttribute("MapName", world.def.displayName)

PlayerState.init()
Equipment.init()
Drops.init()
Effects.init()
Survival.init()
Loot.init(world)
Resources.init(world)
Doors.init(world)
Building.init(world)
Zombies.init(world)
Combat.init()
Inventory.init()

local spawnRandom = Random.new()

local function onCharacterAdded(player: Player, character: Model)
	local state = PlayerState.reset(player)
	for _, entry in Config.Player.StarterItems do
		PlayerState.add(player, entry[1], entry[2])
	end
	PlayerState.sync(player)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.MaxHealth = 100
	humanoid.Health = 100

	local spawn = world.spawns[spawnRandom:NextInteger(1, #world.spawns)]
	task.defer(function()
		if character.Parent then
			character:PivotTo(spawn)
		end
	end)

	humanoid.Died:Connect(function()
		-- Everything carried, including a worn pack, falls where the player died.
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and PlayerState.get(player) == state then
			local position = root.Position
			local function scatter(id: string, count: number, mag: number?)
				local offset = Vector3.new(spawnRandom:NextNumber(-3, 3), 0, spawnRandom:NextNumber(-3, 3))
				Drops.spawn(
					id,
					count,
					Drops.groundBelow(position + offset, { character }),
					mag,
					Config.Loot.DroppedItemLifetime
				)
			end
			for _, stack in state.inventory do
				scatter(stack.id, stack.count, stack.mag)
			end
			if state.pack ~= "" then
				scatter(state.pack, 1)
			end
			state.inventory = {}
			state.pack = ""
		end
		Building.closeStorage(player)
		player:SetAttribute("LastLife", os.clock() - state.lifeStarted)
		task.delay(Config.Player.RespawnDelay, function()
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
end

local function onPlayerAdded(player: Player)
	player.CameraMaxZoomDistance = Config.Player.MaxCameraZoom
	player.DevEnableMouseLock = false
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:LoadCharacter()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

workspace:SetAttribute("WorldReady", true)

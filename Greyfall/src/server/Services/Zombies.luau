-- Zombie spawning and behaviour.
-- Each town is a zone. A zone fills with zombies while a player is nearby and empties again
-- some time after everyone has left, which keeps the server light on large maps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Survival = require(script.Parent.Survival)
local Loot = require(script.Parent.Loot)
local Settings = require(script.Parent.Settings)

local Zombies = {}

local Z = Config.Zombies

local folder: Folder
local templates: { Model } = {}
local zombies = {}
local zones = {}
local total = 0
local rng = Random.new()

local function buildTemplate(shirt: Color3, pants: Color3): Model?
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(118, 128, 104):Lerp(Color3.fromRGB(140, 140, 120), rng:NextNumber())
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Zombies] could not build a zombie rig:", model)
		return nil
	end

	-- The limping walk is drawn by each client (ZombieAnimator), so the rig needs no
	-- animation scripts or Animator, which also saves server work.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local head = model:FindFirstChild("Head")
	local face = head and head:FindFirstChildOfClass("Decal")
	if face then
		face:Destroy()
	end

	model.Name = "Zombie"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = Z.Health
	humanoid.Health = Z.Health
	humanoid.WalkSpeed = Z.WalkSpeed
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	model:SetAttribute("Zombie", true)
	return model
end

local function groundAt(x: number, z: number): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local result = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -800, 0), params)
	if result and result.Material ~= Enum.Material.Water then
		return result.Position
	end
	return nil
end

local function nearestPlayerDistance(position: Vector3): number
	local best = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			best = math.min(best, (root.Position - position).Magnitude)
		end
	end
	return best
end

local function onDied(zombie)
	if zombie.dead then
		return
	end
	zombie.dead = true
	zombies[zombie.model] = nil
	total -= 1
	local zone = zombie.zone
	zone.alive -= 1
	table.insert(zone.cooldowns, os.clock() + Z.RespawnDelay)
	if rng:NextNumber() < Z.LootDropChance then
		Loot.dropFromTable("Zombie", zombie.root.Position)
	end
	Debris:AddItem(zombie.model, Z.CorpseTime)
end

local function spawnZombie(zone): boolean
	if #templates == 0 then
		return false
	end
	local position
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(0, zone.radius)
		local ground = groundAt(zone.center.X + math.cos(angle) * radius, zone.center.Z + math.sin(angle) * radius)
		if ground and nearestPlayerDistance(ground) > Z.SpawnMinPlayerDistance then
			position = ground
			break
		end
	end
	if not position then
		return false
	end

	local model = templates[rng:NextInteger(1, #templates)]:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = folder
	root:SetNetworkOwner(nil)

	local zombie = {
		model = model,
		humanoid = humanoid,
		root = root,
		zone = zone,
		home = position,
		target = nil :: Player?,
		alertPosition = nil :: Vector3?,
		alertUntil = 0,
		lastAttack = 0,
		nextWander = 0,
		speedScale = rng:NextNumber(0.85, 1.15),
		nextThink = 0,
		lastPosition = root.Position,
		stuckFor = 0,
		dead = false,
	}
	zombies[model] = zombie
	total += 1
	zone.alive += 1

	humanoid.Died:Connect(function()
		onDied(zombie)
	end)
	return true
end

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function canSee(zombie, character: Model, targetRoot: BasePart): boolean
	local eye = zombie.root.Position + Vector3.new(0, 2, 0)
	local offset = targetRoot.Position - eye
	sightParams.FilterDescendantsInstances = { folder, workspace:FindFirstChild("Drops") :: Instance }
	local result = workspace:Raycast(eye, offset, sightParams)
	return result == nil or result.Instance:IsDescendantOf(character)
end

local function targetRootOf(player: Player?): (BasePart?, Humanoid?)
	local character = player and player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

local function findTarget(zombie): Player?
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = targetRootOf(player)
		if root then
			local distance = (root.Position - zombie.root.Position).Magnitude
			if distance < bestDistance then
				local sprinting = player:GetAttribute("Sprinting") == true
				local noticed = distance < Z.HearRange
					or (sprinting and distance < Z.SprintHearRange)
					or (distance < Z.SightRange and canSee(zombie, player.Character :: Model, root))
				if noticed then
					best, bestDistance = player, distance
				end
			end
		end
	end
	return best
end

local function think(zombie, now: number, dt: number)
	local humanoid: Humanoid = zombie.humanoid
	local root: BasePart = zombie.root
	if humanoid.Health <= 0 then
		return
	end

	local targetRoot = targetRootOf(zombie.target)
	if targetRoot and (targetRoot.Position - root.Position).Magnitude > Z.LoseRange then
		targetRoot = nil
	end
	if not targetRoot then
		zombie.target = findTarget(zombie)
		targetRoot = targetRootOf(zombie.target)
	end

	local chasing = false
	if targetRoot then
		chasing = true
		humanoid.WalkSpeed = Z.ChaseSpeed * zombie.speedScale
		humanoid:MoveTo(targetRoot.Position)
		local offset = targetRoot.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if flat < Z.AttackRange and math.abs(offset.Y) < 5 and now - zombie.lastAttack > Z.AttackCooldown then
			zombie.lastAttack = now
			Survival.zombieHit(zombie.target :: Player, Z.AttackDamage)
			-- Clients see this attribute change, play the lunge and the attack sound.
			zombie.model:SetAttribute("AttackAt", workspace:GetServerTimeNow())
		end
	elseif zombie.alertPosition and now < zombie.alertUntil then
		chasing = true
		humanoid.WalkSpeed = Z.ChaseSpeed * zombie.speedScale
		humanoid:MoveTo(zombie.alertPosition)
		if (zombie.alertPosition - root.Position).Magnitude < 8 then
			zombie.alertPosition = nil
		end
	else
		zombie.alertPosition = nil
		if now > zombie.nextWander then
			zombie.nextWander = now + rng:NextNumber(4, 10)
			humanoid.WalkSpeed = Z.WalkSpeed * zombie.speedScale
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = rng:NextNumber(4, 30)
			humanoid:MoveTo(zombie.home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		end
	end

	-- Jump when blocked while chasing.
	if chasing then
		if (root.Position - zombie.lastPosition).Magnitude < 0.4 then
			zombie.stuckFor += dt
			if zombie.stuckFor > 0.75 then
				humanoid.Jump = true
				zombie.stuckFor = 0
			end
		else
			zombie.stuckFor = 0
		end
	end
	zombie.lastPosition = root.Position
end

local function updateZones(now: number)
	for _, zone in zones do
		for i = #zone.cooldowns, 1, -1 do
			if zone.cooldowns[i] <= now then
				table.remove(zone.cooldowns, i)
			end
		end

		local near = nearestPlayerDistance(zone.center) < Z.ZoneActivateRange
		if near then
			zone.lastNear = now
			if zone.alive + #zone.cooldowns < zone.count and total < Z.MaxTotal and now >= zone.nextSpawn then
				zone.nextSpawn = now + 0.5
				spawnZombie(zone)
			end
		elseif zone.alive > 0 and now - zone.lastNear > Z.ZoneDespawnDelay then
			for model, zombie in zombies do
				if zombie.zone == zone and not zombie.target then
					zombies[model] = nil
					zombie.dead = true
					total -= 1
					zone.alive -= 1
					model:Destroy()
				end
			end
		end
	end
end

function Zombies.isZombie(model: Instance?): boolean
	return model ~= nil and zombies[model] ~= nil
end

-- Called by Combat whenever a player hurts a zombie.
function Zombies.onDamaged(model: Instance, attacker: Player?)
	local zombie = zombies[model]
	if zombie and attacker then
		zombie.target = attacker
	end
end

-- Loud noises (gunshots) pull idle zombies toward the source.
function Zombies.alert(position: Vector3, radius: number)
	local now = os.clock()
	for _, zombie in zombies do
		if not zombie.target and (zombie.root.Position - position).Magnitude < radius then
			zombie.alertPosition = position
			zombie.alertUntil = now + 15
		end
	end
end

function Zombies.init(world)
	folder = Instance.new("Folder")
	folder.Name = "Zombies"
	folder.Parent = workspace

	local outfits = {
		{ Color3.fromRGB(70, 80, 95), Color3.fromRGB(55, 55, 60) },
		{ Color3.fromRGB(110, 95, 75), Color3.fromRGB(60, 60, 70) },
		{ Color3.fromRGB(130, 125, 115), Color3.fromRGB(80, 70, 60) },
		{ Color3.fromRGB(90, 100, 70), Color3.fromRGB(70, 75, 55) },
	}
	for _, outfit in outfits do
		local template = buildTemplate(outfit[1], outfit[2])
		if template then
			table.insert(templates, template)
		end
	end

	for _, source in world.zones do
		if source.count > 0 then
			table.insert(zones, {
				name = source.name,
				center = source.center,
				radius = source.radius,
				count = math.max(1, math.round(source.count * Settings.rules().zombieCountScale)),
				alive = 0,
				cooldowns = {},
				lastNear = -math.huge,
				nextSpawn = 0,
			})
		end
	end

	task.spawn(function()
		local last = os.clock()
		local zoneTimer = 0
		while true do
			task.wait(Z.ThinkInterval)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, zombie in zombies do
				if now >= zombie.nextThink then
					-- Zombies far from every player think once a second instead of four times.
					local far = not zombie.target and nearestPlayerDistance(zombie.root.Position) > Z.IdleDistance
					zombie.nextThink = now + (if far then Z.IdleThinkInterval else 0)
					think(zombie, now, if far then Z.IdleThinkInterval else dt)
				end
			end
			zoneTimer += dt
			if zoneTimer >= 1 then
				zoneTimer = 0
				updateZones(now)
			end
		end
	end)
end

return Zombies

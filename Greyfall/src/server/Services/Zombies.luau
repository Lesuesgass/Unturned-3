-- Zombie spawning and behaviour.
-- Each town is a zone. A zone fills with zombies while a player is nearby and empties again
-- some time after everyone has left, which keeps the server light on large maps.
--
-- Types (stats in Config.ZombieTypes, looks in ZombieLooks):
--   Walker      the common shambler
--   Smoulderer  burning; its hits set players alight
--   Livewire    electrified; its hits slow and drain stamina, and it zaps players from range
--   Behemoth    boss of military bases; ground slam that throws players and cracks bases,
--               short charges at players who keep their distance, rich loot

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Survival = require(script.Parent.Survival)
local Loot = require(script.Parent.Loot)
local Settings = require(script.Parent.Settings)
local ZombieLooks = require(script.Parent.ZombieLooks)
local Effects = require(script.Parent.Effects)
local Building = require(script.Parent.Building)

local Zombies = {}

local Z = Config.Zombies

local folder: Folder
local templates: { [string]: { Model } } = {}
local TYPES = Config.ZombieTypes
local zombies = {}
local zones = {}
local total = 0
local rng = Random.new()

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
	if zombie.isBoss then
		zone.bossAlive = false
		zone.bossReadyAt = os.clock() + TYPES.Behemoth.respawnSeconds
		for _ = 1, 3 do
			Loot.dropFromTable(
				"Military",
				zombie.root.Position + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			)
		end
	else
		zone.alive -= 1
		table.insert(zone.cooldowns, os.clock() + Z.RespawnDelay)
		if rng:NextNumber() < Z.LootDropChance then
			Loot.dropFromTable("Zombie", zombie.root.Position)
		end
	end
	Debris:AddItem(zombie.model, Z.CorpseTime)
end

local function pickType(): string
	local totalWeight = 0
	for _, def in TYPES do
		totalWeight += def.weight
	end
	local roll = rng:NextNumber() * totalWeight
	for name, def in TYPES do
		roll -= def.weight
		if def.weight > 0 and roll <= 0 then
			return name
		end
	end
	return "Walker"
end

local function spawnZombie(zone, typeName: string?): boolean
	typeName = typeName or pickType()
	local pool = templates[typeName :: string]
	if not pool or #pool == 0 then
		return false
	end
	local def = TYPES[typeName :: string]
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

	local model = pool[rng:NextInteger(1, #pool)]:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local lift = 3.5 * (def.scale or 1)
	model:PivotTo(CFrame.new(position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
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
		speedScale = rng:NextNumber(0.85, 1.15) * def.speedScale,
		typeName = typeName,
		def = def,
		isBoss = def.boss == true,
		lastArc = 0,
		lastSlam = 0,
		lastCharge = 0,
		chargeUntil = 0,
		nextThink = 0,
		lastPosition = root.Position,
		stuckFor = 0,
		dead = false,
	}
	zombies[model] = zombie
	if zombie.isBoss then
		zone.bossAlive = true
	else
		total += 1
		zone.alive += 1
	end

	humanoid.Died:Connect(function()
		onDied(zombie)
	end)
	return true
end

local useAbilities -- defined below

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

-- Livewire zaps from range; Behemoth slams the ground and charges.
function useAbilities(zombie, now: number, targetRoot: BasePart, distance: number)
	local def = zombie.def
	local root: BasePart = zombie.root
	if
		def.arcRange
		and distance < def.arcRange
		and distance > Z.AttackRange
		and now - zombie.lastArc > def.arcCooldown
	then
		zombie.lastArc = now
		local target = zombie.target :: Player
		Effects.arc(root.Position + Vector3.new(0, 1, 0), targetRoot.Position)
		Effects.sound("Zap", root.Position)
		Survival.zombieHit(target, def.arcDamage, "Livewire", true)
	end
	if def.slamRange and distance < def.slamRange and now - zombie.lastSlam > def.slamCooldown then
		zombie.lastSlam = now
		zombie.lastAttack = now + 1 -- no normal swing during the slam
		zombie.model:SetAttribute("SlamAt", workspace:GetServerTimeNow())
		task.delay(0.7, function()
			if zombie.dead or zombie.humanoid.Health <= 0 then
				return
			end
			local center = root.Position - Vector3.new(0, 2.5 * (def.scale or 1), 0)
			Effects.shockwave(center, def.slamRange)
			Effects.sound("BossSlam", center)
			for _, player in Players:GetPlayers() do
				local playerRoot = targetRootOf(player)
				if playerRoot then
					local away = playerRoot.Position - center
					local d = Vector3.new(away.X, 0, away.Z).Magnitude
					if d < def.slamRange and math.abs(away.Y) < 8 then
						local falloff = 1 - 0.5 * d / def.slamRange
						Survival.zombieHit(player, def.slamDamage * falloff, "Behemoth", true)
						local direction = if d > 0.1 then Vector3.new(away.X, 0, away.Z).Unit else Vector3.zAxis
						Effects.knockback(player, direction * 55 + Vector3.new(0, 38, 0))
					end
				end
			end
			-- The slam also cracks player bases.
			for record, d in Building.inRadius(center, def.slamRange) do
				Building.damageRecord(record, 140 * (1 - 0.5 * d / def.slamRange), "explosive", nil)
			end
		end)
	end
	if def.chargeSpeed and distance > 18 and distance < 60 and now - zombie.lastCharge > def.chargeCooldown then
		zombie.lastCharge = now
		zombie.chargeUntil = now + def.chargeTime
		zombie.model:SetAttribute("ChargeUntil", workspace:GetServerTimeNow() + def.chargeTime)
	end
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
		if targetRoot then
			-- Clients play a roar (bosses) or a groan when a zombie spots someone.
			zombie.model:SetAttribute("NoticeAt", workspace:GetServerTimeNow())
		end
	end

	local chasing = false
	if targetRoot then
		chasing = true
		local def = zombie.def
		local charging = now < zombie.chargeUntil
		humanoid.WalkSpeed = if charging then def.chargeSpeed else Z.ChaseSpeed * zombie.speedScale
		humanoid:MoveTo(targetRoot.Position)
		local offset = targetRoot.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		useAbilities(zombie, now, targetRoot, flat)
		local reach = def.attackRange or Z.AttackRange
		if
			flat < reach
			and math.abs(offset.Y) < 5 * (def.scale or 1)
			and now - zombie.lastAttack > Z.AttackCooldown
		then
			zombie.lastAttack = now
			Survival.zombieHit(zombie.target :: Player, def.damage, zombie.typeName)
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
			if zone.bossLair and not zone.bossAlive and now >= zone.bossReadyAt then
				zone.bossReadyAt = now + 5 -- retry later if no spot was free
				spawnZombie(zone, "Behemoth")
			end
			if zone.alive + #zone.cooldowns < zone.count and total < Z.MaxTotal and now >= zone.nextSpawn then
				zone.nextSpawn = now + 0.5
				spawnZombie(zone)
			end
		elseif (zone.alive > 0 or zone.bossAlive) and now - zone.lastNear > Z.ZoneDespawnDelay then
			for model, zombie in zombies do
				if zombie.zone == zone and not zombie.target then
					zombies[model] = nil
					zombie.dead = true
					if zombie.isBoss then
						zone.bossAlive = false
					else
						total -= 1
						zone.alive -= 1
					end
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

	-- A few variations of every type, built once and cloned for each spawn.
	for typeName, def in TYPES do
		templates[typeName] = {}
		for _ = 1, (if def.boss then 1 elseif typeName == "Walker" then 4 else 2) do
			local template = ZombieLooks.build(typeName, rng)
			if template then
				table.insert(templates[typeName], template)
			end
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
				bossLair = source.kind == "military",
				bossAlive = false,
				bossReadyAt = 0,
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

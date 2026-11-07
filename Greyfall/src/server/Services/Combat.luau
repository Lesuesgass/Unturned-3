-- Melee swings, gunshots, reloading and planted explosive charges.
-- The client only sends an aim direction; every hit is worked out on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Items = require(Shared.Items)
local Net = require(Shared.Net)

local PlayerState = require(script.Parent.PlayerState)
local Survival = require(script.Parent.Survival)
local Zombies = require(script.Parent.Zombies)
local Resources = require(script.Parent.Resources)
local Building = require(script.Parent.Building)
local Drops = require(script.Parent.Drops)
local Effects = require(script.Parent.Effects)

local Combat = {}

local function aliveCharacter(player: Player): (Model?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if character and humanoid and humanoid.Health > 0 and head and head:IsA("BasePart") then
		return character, head
	end
	return nil, nil
end

local function humanoidOf(part: Instance): Humanoid?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function validDirection(direction: any): Vector3?
	if typeof(direction) ~= "Vector3" then
		return nil
	end
	local magnitude = direction.Magnitude
	if not (magnitude > 0.5 and magnitude < 2) then
		return nil
	end
	return direction.Unit
end

-- Damages a player or zombie. Returns true if damage was applied.
-- bleedChance is the weapon's chance to make a player bleed (scaled by difficulty).
function Combat.damageHumanoid(
	attacker: Player?,
	humanoid: Humanoid,
	amount: number,
	allowSelf: boolean?,
	bleedChance: number?
): boolean
	if humanoid.Health <= 0 then
		return false
	end
	local model = humanoid.Parent
	if Zombies.isZombie(model) then
		humanoid:TakeDamage(amount)
		Zombies.onDamaged(model :: Instance, attacker)
		return true
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		if victim == attacker and not allowSelf then
			return false
		end
		if attacker and victim ~= attacker and not Config.Combat.PvP then
			return false
		end
		humanoid:TakeDamage(amount)
		if humanoid.Health > 0 then
			Survival.weaponHit(victim, bleedChance)
		end
		return true
	end
	return false
end

local function hitParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, Drops.folder() }
	return params
end

local function melee(player: Player, state, def, direction: Vector3)
	local character, head = aliveCharacter(player)
	if not character or not head then
		return
	end
	local now = os.clock()
	if now - state.lastAttack < def.cooldown * 0.9 then
		return
	end
	if not Survival.useStamina(player, Config.Survival.MeleeStaminaCost) then
		PlayerState.notify(player, "Too tired")
		return
	end
	state.lastAttack = now

	local origin = head.Position
	Effects.sound("MeleeSwing", origin)
	local result = workspace:Spherecast(origin, 1.2, direction * def.range, hitParams(character))
	if not result then
		return
	end
	local hit = result.Instance
	local humanoid = humanoidOf(hit)
	if humanoid then
		local amount = if def.damageMin then math.random(def.damageMin, def.damageMax) else def.damage
		if hit.Name == "Head" and not def.noHeadshot then
			amount *= 1.5
		end
		if Combat.damageHumanoid(player, humanoid, amount, false, def.bleedChance) then
			Effects.impact(result.Position, true)
			Effects.sound("MeleeHit", result.Position)
		end
	elseif Resources.isResource(hit) then
		Resources.harvest(player, hit :: BasePart, def)
		Effects.impact(result.Position, false)
	elseif Building.isStructure(hit) then
		Building.damage(hit, def.structureDamage or 0, "melee", player)
		Effects.impact(result.Position, false)
	else
		Effects.impact(result.Position, false)
	end
end

local function spread(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local frame = CFrame.lookAt(Vector3.zero, direction)
	local roll = math.random() * math.pi * 2
	local tilt = math.rad(math.random() * degrees)
	return (frame * CFrame.Angles(0, 0, roll) * CFrame.Angles(tilt, 0, 0)).LookVector
end

local function fire(player: Player, state, def, stack, direction: Vector3)
	local character, head = aliveCharacter(player)
	if not character or not head or state.reloading then
		return
	end
	local now = os.clock()
	if now - state.lastAttack < def.fireRate * 0.85 then
		return
	end
	if (stack.mag or 0) <= 0 then
		Effects.sound("DryFire", head.Position)
		PlayerState.notify(player, "Empty, press R to reload")
		return
	end
	state.lastAttack = now
	stack.mag -= 1
	PlayerState.sync(player)

	local origin = head.Position
	local muzzlePosition = origin
	local tool = character:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	if muzzle and muzzle:IsA("Attachment") then
		muzzlePosition = muzzle.WorldPosition
	end

	local params = hitParams(character)
	for _ = 1, def.pellets or 1 do
		local shot = spread(direction, def.spread)
		local result = workspace:Raycast(origin, shot * def.range, params)
		local endPosition = if result then result.Position else origin + shot * def.range
		Effects.tracer(muzzlePosition, endPosition)
		if result then
			local humanoid = humanoidOf(result.Instance)
			if humanoid then
				local amount = def.damage
					* (if result.Instance.Name == "Head" then Config.Combat.HeadshotMultiplier else 1)
				if Combat.damageHumanoid(player, humanoid, amount, false, def.bleedChance) then
					Effects.impact(result.Position, true)
				end
			else
				Building.damage(result.Instance, def.structureDamage or 0, "bullet", player)
				Effects.impact(result.Position, false)
			end
		end
	end
	Effects.sound(def.sound or "PistolShot", origin)
	Zombies.alert(origin, def.noise or 120)
end

function Combat.reload(player: Player)
	local state = PlayerState.get(player)
	if not state or state.reloading then
		return
	end
	local stack = PlayerState.equippedStack(state)
	local def = stack and Items.get(stack.id)
	if not stack or not def or def.category ~= "Gun" then
		return
	end
	if (stack.mag or 0) >= def.magSize then
		return
	end
	if PlayerState.count(state, def.ammo) <= 0 then
		local ammo = Items.get(def.ammo)
		PlayerState.notify(player, `No {ammo and ammo.name or def.ammo}`)
		return
	end
	state.reloading = true
	player:SetAttribute("Reloading", true)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		Effects.sound("Reload", root.Position)
	end
	local uid = stack.uid
	task.delay(def.reloadTime, function()
		state.reloading = false
		player:SetAttribute("Reloading", false)
		if PlayerState.get(player) ~= state then
			return
		end
		local current = PlayerState.equippedStack(state)
		if not current or current.uid ~= uid then
			return
		end
		local needed = def.magSize - (current.mag or 0)
		local available = math.min(needed, PlayerState.count(state, def.ammo))
		if available > 0 and PlayerState.remove(player, def.ammo, available) then
			current.mag = (current.mag or 0) + available
			PlayerState.sync(player)
		end
	end)
end

-- Explosives ---------------------------------------------------------------------------

local function explode(position: Vector3, def, attacker: Player?)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastRadius = def.radius
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
	Effects.sound("Explosion", position)
	Zombies.alert(position, 250)

	-- Damage falls off from full strength at the centre to half at the edge.
	for record, distance in Building.inRadius(position, def.radius) do
		local falloff = 1 - 0.5 * math.clamp(distance / def.radius, 0, 1)
		Building.damageRecord(record, def.structureDamage * falloff, "explosive", attacker)
	end

	local hitHumanoids = {}
	for _, part in workspace:GetPartBoundsInRadius(position, def.radius) do
		local humanoid = humanoidOf(part)
		if humanoid and not hitHumanoids[humanoid] then
			hitHumanoids[humanoid] = true
			local root = (humanoid.Parent :: Model):FindFirstChild("HumanoidRootPart")
			local distance = if root and root:IsA("BasePart") then (root.Position - position).Magnitude else def.radius
			local falloff = 1 - math.clamp(distance / def.radius, 0, 1)
			if falloff > 0 then
				Combat.damageHumanoid(attacker, humanoid, def.playerDamage * falloff, true)
			end
		end
	end
end

function Combat.plant(player: Player, uid: string, position: Vector3, normal: Vector3)
	local state = PlayerState.get(player)
	local character, head = aliveCharacter(player)
	if not state or not character or not head then
		return
	end
	local stack = PlayerState.findStack(state, uid)
	local def = stack and Items.get(stack.id)
	if not stack or not def or def.category ~= "Explosive" then
		return
	end
	if (position - head.Position).Magnitude > 9 then
		PlayerState.notify(player, "Too far away")
		return
	end
	if PlayerState.takeFromStack(player, uid, 1) < 1 then
		return
	end

	local size = def.model.size
	local charge = Instance.new("Part")
	charge.Name = "Charge"
	charge.Size = size
	charge.Color = def.model.color
	charge.Material = def.model.material or Enum.Material.Metal
	charge.Anchored = true
	charge.CanCollide = false
	charge.CanQuery = false
	charge.CFrame = CFrame.lookAt(position + normal * (size.Y / 2), position + normal * 2)
		* CFrame.Angles(-math.pi / 2, 0, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 60, 50)
	light.Range = 6
	light.Brightness = 2
	light.Parent = charge
	charge.Parent = workspace

	task.spawn(function()
		local remaining = def.fuse
		while remaining > 0 and charge.Parent do
			light.Enabled = not light.Enabled
			Effects.sound("ChargeBeep", charge.Position)
			local step = if remaining > 2 then 0.5 else 0.2
			task.wait(step)
			remaining -= step
		end
		if charge.Parent then
			local at = charge.Position
			charge:Destroy()
			explode(at, def, player)
		end
	end)
	PlayerState.notify(player, `{def.name} planted, {def.fuse} seconds`)
end

function Combat.init()
	Net.get("Attack").OnServerEvent:Connect(function(player, kind, direction)
		local state = PlayerState.get(player)
		local unit = validDirection(direction)
		if not state or not unit then
			return
		end
		local stack = PlayerState.equippedStack(state)
		local def = stack and Items.get(stack.id)
		if not stack or not def then
			-- Empty hands punch.
			if kind == "Melee" then
				melee(player, state, Items.Fists, unit)
			end
			return
		end
		if kind == "Melee" and def.category == "Melee" then
			melee(player, state, def, unit)
		elseif kind == "Fire" and def.category == "Gun" then
			fire(player, state, def, stack, unit)
		end
	end)
end

return Combat

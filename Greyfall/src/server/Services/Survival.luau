-- Food, water, infection, bleeding, stamina, sprinting, regeneration and fall damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerState = require(script.Parent.PlayerState)

local Survival = {}

local S = Config.Survival
local SEA_LEVEL = 0

local fallTracking: { [Player]: number } = {}

local function aliveHumanoid(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function addStat(player: Player, name: string, amount: number, max: number?)
	local value = (player:GetAttribute(name) or 0) :: number
	player:SetAttribute(name, math.clamp(value + amount, 0, max or 100))
end

function Survival.applyConsumable(player: Player, def): boolean
	local humanoid = aliveHumanoid(player)
	if not humanoid then
		return false
	end
	if def.food then
		addStat(player, "Food", def.food)
	end
	if def.water then
		addStat(player, "Water", def.water)
	end
	if def.infection then
		addStat(player, "Infection", def.infection)
	end
	if def.stamina then
		addStat(player, "Stamina", def.stamina, S.StaminaMax)
	end
	if def.health then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + def.health)
	end
	if def.stopsBleeding then
		player:SetAttribute("Bleeding", false)
	end
	return true
end

function Survival.zombieHit(player: Player, damage: number)
	local humanoid = aliveHumanoid(player)
	if not humanoid then
		return
	end
	humanoid:TakeDamage(damage)
	addStat(player, "Infection", Config.Zombies.InfectionPerHit)
	if math.random() < Config.Zombies.BleedChance then
		player:SetAttribute("Bleeding", true)
	end
end

function Survival.useStamina(player: Player, amount: number): boolean
	local stamina = (player:GetAttribute("Stamina") or 0) :: number
	if stamina < amount then
		return false
	end
	player:SetAttribute("Stamina", stamina - amount)
	local state = PlayerState.get(player)
	if state then
		state.lastStaminaUse = os.clock()
	end
	return true
end

-- Runs once per second.
local function slowTick()
	for _, player in Players:GetPlayers() do
		local humanoid = aliveHumanoid(player)
		if humanoid then
			local sprinting = player:GetAttribute("Sprinting") == true
			addStat(player, "Food", -S.FoodDrainPerSecond)
			addStat(player, "Water", -S.WaterDrainPerSecond * (if sprinting then S.SprintWaterMultiplier else 1))

			local food = player:GetAttribute("Food") :: number
			local water = player:GetAttribute("Water") :: number
			local infection = player:GetAttribute("Infection") :: number
			local damage = 0

			if food <= 0 or water <= 0 then
				damage += S.StarveDamagePerSecond
			end
			if infection > S.InfectionDamageStart then
				local severity = (infection - S.InfectionDamageStart) / (100 - S.InfectionDamageStart)
				damage += S.InfectionDamagePerSecond * severity
			end
			if player:GetAttribute("Bleeding") then
				damage += S.BleedDamagePerSecond
			end

			if damage > 0 then
				humanoid:TakeDamage(damage)
			elseif food > S.RegenThreshold and water > S.RegenThreshold and infection < 25 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + S.RegenPerSecond)
			end
		end
	end
end

-- Runs ten times per second.
local function fastTick(dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local state = PlayerState.get(player)
		local humanoid, root = aliveHumanoid(player)
		if state and humanoid and root then
			local velocity = root.AssemblyLinearVelocity
			local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
			local stamina = (player:GetAttribute("Stamina") or 0) :: number
			local sprinting = state.wantSprint and moving and stamina > 0

			if sprinting then
				stamina = math.max(0, stamina - S.StaminaDrainPerSecond * dt)
				state.lastStaminaUse = now
				if stamina <= 0 then
					state.wantSprint = false
					sprinting = false
				end
			elseif now - state.lastStaminaUse > S.StaminaRegenDelay then
				stamina = math.min(S.StaminaMax, stamina + S.StaminaRegenPerSecond * dt)
			end
			player:SetAttribute("Stamina", stamina)
			player:SetAttribute("Sprinting", sprinting)
			humanoid.WalkSpeed = if sprinting then Config.Player.SprintSpeed else Config.Player.WalkSpeed

			-- Fall damage: remember the fastest downward speed, apply it on landing.
			local fastest = fallTracking[player] or 0
			if velocity.Y < fastest then
				fallTracking[player] = velocity.Y
			elseif velocity.Y > -5 and fastest < -S.FallDamageMinSpeed then
				fallTracking[player] = 0
				if root.Position.Y > SEA_LEVEL + 3 then
					humanoid:TakeDamage((-fastest - S.FallDamageMinSpeed) * S.FallDamagePerSpeed)
				end
			elseif velocity.Y > -5 then
				fallTracking[player] = 0
			end
		end
	end
end

function Survival.init()
	Players.PlayerRemoving:Connect(function(player)
		fallTracking[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			slowTick()
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			fastTick(now - last)
			last = now
		end
	end)
end

return Survival

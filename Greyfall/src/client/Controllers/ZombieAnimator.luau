-- Draws the zombies' shambling walk on this client and plays their voices.
--
-- Zombies carry no animations on the server. Each client poses their joints every frame:
-- hunched torso, arms reaching forward, head tilted, one good leg and one stiff leg that
-- drags behind, with the body dipping on every step. Only zombies near the camera are
-- posed, so a crowded map costs little.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local ZombieAnimator = {}

local ANIMATE_DISTANCE = 160
local LUNGE_TIME = 0.4
local Voice = Config.ZombieVoice

local zombies: { [Model]: any } = {}
local rng = Random.new()
local playing = 0

local function pickSound(key: string): string?
	local value = Config.Sounds[key]
	if typeof(value) == "table" then
		if #value == 0 then
			return nil
		end
		return value[rng:NextInteger(1, #value)]
	end
	return if value ~= "" then value else nil
end

local function playVoice(record, key: string)
	if playing >= Voice.MaxPlaying then
		return
	end
	local id = pickSound(key)
	local head = record.head
	if not id or not head or not head.Parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Voice.Volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = Voice.MaxDistance
	sound.PlaybackSpeed = rng:NextNumber(0.85, 1.05)
	sound.Parent = head
	playing += 1
	local finished = false
	local function done()
		if not finished then
			finished = true
			playing -= 1
			sound:Destroy()
		end
	end
	sound.Ended:Connect(done)
	task.delay(10, done)
	sound:Play()
end

local function register(model: Instance)
	if not model:IsA("Model") or zombies[model] then
		return
	end
	local motors = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	if not motors.LeftHip or not motors.RightHip then
		return -- not an R15 rig, or not fully streamed in yet
	end
	local record = {
		model = model,
		motors = motors,
		root = model:FindFirstChild("HumanoidRootPart"),
		head = model:FindFirstChild("Head"),
		phase = rng:NextNumber(0, math.pi * 2),
		dragLeft = rng:NextNumber() < 0.5,
		armOffset = rng:NextNumber(-0.15, 0.15),
		headRoll = rng:NextNumber(0.2, 0.45) * (if rng:NextNumber() < 0.5 then -1 else 1),
		nextVoice = os.clock() + rng:NextNumber(2, Voice.MaxInterval),
		lastAttack = model:GetAttribute("AttackAt") or 0,
	}
	zombies[model] = record
	model:GetAttributeChangedSignal("AttackAt"):Connect(function()
		record.lastAttack = model:GetAttribute("AttackAt") or 0
		local camera = workspace.CurrentCamera
		if record.root and (record.root.Position - camera.CFrame.Position).Magnitude < Voice.MaxDistance then
			playVoice(record, "ZombieAttack")
		end
	end)
end

local function rx(a: number): CFrame
	return CFrame.Angles(a, 0, 0)
end

local function pose(record, dt: number, now: number, serverNow: number)
	local motors = record.motors
	local root: BasePart = record.root
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = math.clamp(speed / 6, 0, 1)

	-- A slow, uneven cadence: the phase advances with speed, plus a little idle sway.
	record.phase += dt * (0.6 + speed * 0.55)
	local phase = record.phase
	local s = math.sin(phase)
	local c = math.cos(phase)

	local lunge = math.clamp(1 - (serverNow - record.lastAttack) / LUNGE_TIME, 0, 1)

	-- Good leg swings normally, bad leg stays stiff, trails behind and turns outward.
	local goodHip = rx(s * 0.55 * moving)
	local goodKnee = rx(-math.max(0, -c) * 0.8 * moving)
	local badHip = rx((-0.22 + s * 0.12) * moving) * CFrame.Angles(0, 0.35, 0)
	local badKnee = rx(-0.08)
	local good, bad = "Right", "Left"
	if not record.dragLeft then
		good, bad = "Left", "Right"
		badHip = rx((-0.22 + s * 0.12) * moving) * CFrame.Angles(0, -0.35, 0)
	end
	local function set(name: string, value: CFrame)
		local motor = motors[name]
		if motor then
			motor.Transform = value
		end
	end
	set(good .. "Hip", goodHip)
	set(good .. "Knee", goodKnee)
	set(bad .. "Hip", badHip)
	set(bad .. "Knee", badKnee)
	set(bad .. "Ankle", CFrame.Angles(0.25, 0, 0))

	-- The body dips and rolls toward the bad leg on every step.
	local dip = math.max(0, s) * 0.22 * moving
	local roll = (if record.dragLeft then 1 else -1) * (0.08 + s * 0.06) * moving
	set("Root", CFrame.new(0, -dip, 0) * CFrame.Angles(0, 0, roll))
	set("Waist", rx(-0.38 - 0.05 * moving - lunge * 0.3) * CFrame.Angles(0, 0, math.sin(now * 0.7) * 0.06))
	set("Neck", rx(-0.12 + lunge * 0.2) * CFrame.Angles(0, 0, record.headRoll + math.sin(now * 0.9) * 0.06))

	-- Arms reach forward, swaying out of step with each other; they swipe on an attack.
	local reach = 1.15 + record.armOffset + lunge * 0.5
	set("LeftShoulder", rx(reach + math.sin(phase + 1.3) * 0.12) * CFrame.Angles(0, 0, -0.08))
	set("RightShoulder", rx(reach - 0.15 + math.sin(phase) * 0.12) * CFrame.Angles(0, 0, 0.08))
	set("LeftElbow", rx(0.25 + lunge * 0.4))
	set("RightElbow", rx(0.35 + lunge * 0.4))
end

function ZombieAnimator.init()
	local folder = workspace:WaitForChild("Zombies", math.huge)
	folder.ChildAdded:Connect(function(child)
		task.defer(register, child)
	end)
	for _, child in folder:GetChildren() do
		register(child)
	end

	RunService.Stepped:Connect(function(_, dt)
		local now = os.clock()
		local serverNow = workspace:GetServerTimeNow()
		local cameraPosition = workspace.CurrentCamera.CFrame.Position
		for model, record in zombies do
			local root = record.root
			if not model.Parent or not root or not root.Parent then
				zombies[model] = nil
				continue
			end
			local distance = (root.Position - cameraPosition).Magnitude
			if distance < ANIMATE_DISTANCE then
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					pose(record, dt, now, serverNow)
					if distance < Voice.MaxDistance and now > record.nextVoice then
						record.nextVoice = now + rng:NextNumber(Voice.MinInterval, Voice.MaxInterval)
						playVoice(record, "ZombieGroan")
					end
				end
			end
		end
	end)
end

return ZombieAnimator

-- Draws the zombies' shambling walk on this client and plays their voices.
--
-- Zombies carry no animations on the server. Each client poses their joints every frame
-- (through each joint's C0, on top of its original offset):
-- hunched torso, arms reaching forward, head tilted, one good leg and one stiff leg that
-- drags behind, with the body dipping on every step. Only zombies near the camera are
-- posed, so a crowded map costs little.
--
-- Each type moves differently: Livewires twitch, Smoulderers flail and crackle, the Behemoth
-- stomps with heavy arms, leans into its charges and raises both fists for its ground slam.

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

local function playVoice(record, key: string, force: boolean?)
	if playing >= Voice.MaxPlaying and not force then
		return
	end
	local id = pickSound(key)
	local head = record.head
	if not id or not head or not head.Parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	local boss = record.typeName == "Behemoth"
	sound.Volume = if boss then Voice.Volume * 2 else Voice.Volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = if boss then 20 else 8
	sound.RollOffMaxDistance = if boss then Voice.MaxDistance * 2.5 else Voice.MaxDistance
	-- Every type speaks at its own pitch; a dedicated roar plays at its natural pitch.
	local pitch = if key == "BossRoar" then 1 else (record.def and record.def.voicePitch or 1)
	sound.PlaybackSpeed = pitch * rng:NextNumber(0.92, 1.06)
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
	local motors, bases = {}, {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
			bases[descendant.Name] = descendant.C0
		end
	end
	if not motors.LeftHip or not motors.RightHip then
		return -- not an R15 rig, or not fully streamed in yet
	end
	local typeName = model:GetAttribute("ZombieType") or "Walker"
	local record = {
		typeName = typeName,
		def = Config.ZombieTypes[typeName],
		slamAt = model:GetAttribute("SlamAt") or 0,
		model = model,
		motors = motors,
		bases = bases,
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
	model:GetAttributeChangedSignal("SlamAt"):Connect(function()
		record.slamAt = model:GetAttribute("SlamAt") or 0
	end)
	model:GetAttributeChangedSignal("NoticeAt"):Connect(function()
		local camera = workspace.CurrentCamera
		local range = if typeName == "Behemoth" then Voice.MaxDistance * 2.5 else Voice.MaxDistance
		if record.root and (record.root.Position - camera.CFrame.Position).Magnitude < range then
			local roar = typeName == "Behemoth" and pickSound("BossRoar") ~= nil
			playVoice(record, if roar then "BossRoar" else "ZombieGroan", typeName == "Behemoth")
		end
	end)
	-- Smoulderers crackle the whole time they burn.
	if typeName == "Smoulderer" then
		local id = pickSound("FireCrackle")
		local upper = model:FindFirstChild("UpperTorso")
		if id and upper then
			local crackle = Instance.new("Sound")
			crackle.SoundId = id
			crackle.Looped = true
			crackle.Volume = 0.25
			crackle.RollOffMaxDistance = 40
			crackle.Parent = upper
			crackle:Play()
		end
	end
	if typeName == "Livewire" then
		local upper = model:FindFirstChild("UpperTorso")
		record.light = upper and upper:FindFirstChildOfClass("PointLight")
	end
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
	local bases = record.bases
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
	local typeName = record.typeName
	local heavy = typeName == "Behemoth"
	local charging = heavy and (record.model:GetAttribute("ChargeUntil") or 0) > serverNow
	local slamT = if heavy then (serverNow - record.slamAt) / 1.0 else 2
	-- Small random jolts for the electrified.
	local twitch = Vector3.zero
	if typeName == "Livewire" and rng:NextNumber() < 0.12 then
		twitch = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 0.25
	end
	if record.light then
		record.light.Brightness = 0.6 + rng:NextNumber() * 1.6
	end

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
		-- The pose is applied on top of the joint's original offset. Changing C0 locally is
		-- drawn reliably for characters this client does not simulate.
		local motor = motors[name]
		if motor then
			motor.C0 = bases[name] * value
		end
	end
	set(good .. "Hip", goodHip)
	set(good .. "Knee", goodKnee)
	set(bad .. "Hip", badHip)
	set(bad .. "Knee", badKnee)
	set(bad .. "Ankle", CFrame.Angles(0.25, 0, 0))

	-- The body dips and rolls toward the bad leg on every step.
	local dip = math.max(0, s) * (if heavy then 0.45 else 0.22) * moving
	local roll = (if record.dragLeft then 1 else -1) * (0.08 + s * 0.06) * moving
	set("Root", CFrame.new(0, -dip, 0) * CFrame.Angles(0, 0, roll))
	local lean = -0.38 - 0.05 * moving - lunge * 0.3 - (if charging then 0.45 else 0)
	set("Waist", rx(lean + twitch.X) * CFrame.Angles(twitch.Y, 0, math.sin(now * 0.7) * 0.06))
	set(
		"Neck",
		rx(-0.12 + lunge * 0.2 + twitch.Y) * CFrame.Angles(0, twitch.Z, record.headRoll + math.sin(now * 0.9) * 0.06)
	)

	-- Arms reach forward, swaying out of step with each other; they swipe on an attack.
	local reach = 1.15 + record.armOffset + lunge * 0.5
	local sway = 0.12
	if typeName == "Smoulderer" then
		-- Flailing, as if trying to beat out the flames.
		sway = 0.4
		phase *= 1.6
	elseif heavy then
		-- Huge arms hang low and swing with each stomp.
		reach = 0.35 + lunge * 1.2 + (if charging then -0.5 else 0)
		sway = 0.3
	end
	local leftArm = reach + math.sin(phase + 1.3) * sway + twitch.Z
	local rightArm = reach - 0.15 + math.sin(phase) * sway - twitch.Z
	if heavy and slamT >= 0 and slamT < 1 then
		-- Ground slam: both fists rise overhead during the wind-up, then crash down.
		local arms = if slamT < 0.7
			then 0.35 + (2.9 - 0.35) * (slamT / 0.7)
			else 2.9 - (2.9 - 0.1) * ((slamT - 0.7) / 0.3)
		leftArm, rightArm = arms, arms
		set("Waist", rx(if slamT < 0.7 then 0.15 else -0.8))
	end
	set("LeftShoulder", rx(leftArm) * CFrame.Angles(0, 0, -0.08))
	set("RightShoulder", rx(rightArm) * CFrame.Angles(0, 0, 0.08))
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

	RunService.Stepped:Connect(function()
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
				-- Close zombies are posed every frame, distant ones a few times a second.
				local interval = if distance < 45 then 0 elseif distance < 90 then 1 / 20 else 1 / 8
				if humanoid and humanoid.Health > 0 and now >= (record.nextPose or 0) then
					record.nextPose = now + interval
					local step = now - (record.lastPose or now)
					record.lastPose = now
					local ok, err = pcall(pose, record, math.min(step, 0.2), now, serverNow)
					if not ok and not record.reported then
						record.reported = true
						warn("[Greyfall] zombie pose failed:", err)
					end
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

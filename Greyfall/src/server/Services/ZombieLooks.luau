-- Builds the zombie rigs and dresses them by type. Everything is made from parts, a pixel
-- face drawn with frames and Roblox's built-in effects, so no uploaded assets are needed.
--
--   Walker      grey-green rot, torn clothes, blood stains, sunken yellow eyes
--   Smoulderer  charred black skin split by glowing embers, always on fire
--   Livewire    pale bloated skin with glowing blue veins, crackling with sparks
--   Behemoth    a hulking giant in scraps of riot armour with burning red eyes

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ZombieLooks = {}

local C = Color3.fromRGB
local V = Vector3.new

-- 8 x 8 face, top row first. e = glowing eye, s = socket, k = mouth, t = tooth, b = blood.
local FACES = {
	{ "........", "........", ".ss..ss.", ".se..es.", "........", "..kkkk..", "..ktkk..", "...bb..." },
	{ "........", ".s......", ".ss..ss.", ".es..se.", "........", ".kkkkk..", ".kttkk..", "..kkk..." },
	{ "........", "........", ".sss.ss.", ".s.e.es.", "........", "...kkk..", "..kkkkk.", "..kttk.b" },
}
local INK = { s = C(30, 26, 24), k = C(25, 15, 14), t = C(205, 200, 180), b = C(95, 20, 18) }

local function weld(part: BasePart, to: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function attach(
	model: Model,
	to: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?,
	name: string?
): BasePart
	local p = Instance.new("Part")
	p.Name = name or "Detail"
	p.Size = size
	p.CFrame = to.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	weld(p, to)
	p.Parent = model
	return p
end

local function drawFace(head: BasePart, grid, eye: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(80, 80)
	gui.LightInfluence = 1
	gui.Parent = head
	for y, row in grid do
		for x = 1, 8 do
			local ch = string.sub(row, x, x)
			if ch ~= "." then
				local pixel = Instance.new("Frame")
				pixel.BorderSizePixel = 0
				pixel.Position = UDim2.fromOffset((x - 1) * 10, (y - 1) * 10)
				pixel.Size = UDim2.fromOffset(10, 10)
				pixel.BackgroundColor3 = if ch == "e" then eye else INK[ch]
				pixel.Parent = gui
			end
		end
	end
	do
		-- Glowing eyes stay bright in the dark.
		local glow = gui:Clone()
		glow.Name = "EyeGlow"
		glow.LightInfluence = 0
		glow.Brightness = 2
		for _, pixel in glow:GetChildren() do
			if pixel:IsA("Frame") and pixel.BackgroundColor3 ~= eye then
				pixel:Destroy()
			end
		end
		glow.Parent = head
	end
end

-- Replaces the round head with a cube so the pixel face sits flat.
local function cubeHead(model: Model, skin: Color3, eye: Color3, rng: Random): BasePart?
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	head.Transparency = 1
	for _, child in head:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	local cube =
		attach(model, head, V(1.25, 1.25, 1.25), CFrame.new(0, 0.05, 0), skin, Enum.Material.SmoothPlastic, "HeadCube")
	drawFace(cube, FACES[rng:NextInteger(1, #FACES)], eye)
	return cube
end

local function part(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

-- Torn clothes and blood: a few dark patches and strips over the torso and limbs.
local function rags(model: Model, rng: Random, shirt: Color3)
	local upper = part(model, "UpperTorso")
	if upper then
		attach(
			model,
			upper,
			V(0.9, 0.7, 0.05),
			CFrame.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.3, 0.3), -upper.Size.Z / 2 - 0.02),
			C(90, 22, 20),
			Enum.Material.SmoothPlastic,
			"Blood"
		)
		attach(
			model,
			upper,
			V(0.5, 0.9, 0.05),
			CFrame.new(0.55, -0.3, -upper.Size.Z / 2 - 0.03),
			shirt:Lerp(C(0, 0, 0), 0.45),
			Enum.Material.Fabric,
			"Tear"
		)
	end
	for _, name in { "LeftUpperArm", "RightLowerLeg", "LeftLowerLeg" } do
		local limb = part(model, name)
		if limb and rng:NextNumber() < 0.6 then
			attach(
				model,
				limb,
				V(limb.Size.X + 0.04, 0.35, limb.Size.Z + 0.04),
				CFrame.new(0, rng:NextNumber(-0.3, 0.3), 0),
				C(80, 25, 22),
				Enum.Material.SmoothPlastic,
				"Blood"
			)
		end
	end
end

local function light(parentPart: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parentPart
	return l
end

local DRESS = {}

function DRESS.Walker(model: Model, rng: Random, colors)
	rags(model, rng, colors.shirt)
end

function DRESS.Smoulderer(model: Model, rng: Random)
	-- Ember cracks across the body.
	for _, name in { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" } do
		local limb = part(model, name)
		if limb then
			for _ = 1, 2 do
				attach(
					model,
					limb,
					V(limb.Size.X + 0.03, 0.08, 0.3),
					CFrame.new(0, rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.3, 0.3))
						* CFrame.Angles(0, 0, rng:NextNumber(-0.6, 0.6)),
					C(255, 120, 30),
					Enum.Material.Neon,
					"Ember"
				)
			end
		end
	end
	local upper = part(model, "UpperTorso")
	if upper then
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 7
		fire.Color = C(255, 130, 40)
		fire.SecondaryColor = C(120, 30, 10)
		fire.Parent = upper
		light(upper, C(255, 140, 50), 12, 1.6)
	end
	local cube = part(model, "HeadCube")
	if cube then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 5
		fire.Color = C(255, 150, 50)
		fire.SecondaryColor = C(140, 40, 10)
		fire.Parent = cube
	end
end

function DRESS.Livewire(model: Model, rng: Random)
	for _, name in
		{
			"UpperTorso",
			"LeftUpperArm",
			"RightUpperArm",
			"LeftLowerArm",
			"RightLowerArm",
			"LeftUpperLeg",
			"RightUpperLeg",
		}
	do
		local limb = part(model, name)
		if limb then
			attach(
				model,
				limb,
				V(0.07, limb.Size.Y * 0.9, limb.Size.Z + 0.03),
				CFrame.new(rng:NextNumber(-0.3, 0.3), 0, 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, 0),
				C(120, 230, 255),
				Enum.Material.Neon,
				"Vein"
			)
		end
	end
	local upper = part(model, "UpperTorso")
	if upper then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "Sparks"
		sparks.Color = ColorSequence.new(C(170, 240, 255), C(80, 160, 255))
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.25, 0)
		sparks.Lifetime = NumberRange.new(0.15, 0.35)
		sparks.Rate = 9
		sparks.Speed = NumberRange.new(6, 12)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Parent = upper
		light(upper, C(120, 210, 255), 9, 1.3)
	end
end

function DRESS.Behemoth(model: Model, rng: Random)
	-- Scraps of riot armour over a swollen body.
	local plate = C(55, 60, 58)
	local upper = part(model, "UpperTorso")
	if upper then
		attach(
			model,
			upper,
			V(upper.Size.X + 0.25, upper.Size.Y * 0.7, 0.35),
			CFrame.new(0, 0.15, -upper.Size.Z / 2 - 0.1),
			plate,
			Enum.Material.DiamondPlate,
			"Armour"
		)
		attach(
			model,
			upper,
			V(0.9, 0.5, upper.Size.Z + 0.5),
			CFrame.new(0, 0.55, 0),
			C(70, 75, 70),
			Enum.Material.Metal,
			"Collar"
		)
	end
	for _, name in { "LeftUpperArm", "RightUpperArm" } do
		local arm = part(model, name)
		if arm then
			attach(
				model,
				arm,
				V(arm.Size.X + 0.35, 0.6, arm.Size.Z + 0.35),
				CFrame.new(0, arm.Size.Y / 2 - 0.2, 0),
				plate,
				Enum.Material.DiamondPlate,
				"Pauldron"
			)
		end
	end
	for _, name in { "LeftLowerLeg", "RightLowerLeg" } do
		local leg = part(model, name)
		if leg then
			attach(
				model,
				leg,
				V(leg.Size.X + 0.2, leg.Size.Y * 0.7, 0.2),
				CFrame.new(0, 0, -leg.Size.Z / 2 - 0.05),
				plate,
				Enum.Material.DiamondPlate,
				"Greave"
			)
		end
	end
	rags(model, rng, C(60, 55, 50))
	local cube = part(model, "HeadCube")
	if cube then
		light(cube, C(255, 50, 40), 10, 1.2)
	end
end

local OUTFITS = {
	Walker = {
		skin = { C(118, 128, 104), C(140, 140, 120), C(125, 120, 100) },
		shirt = { C(70, 80, 95), C(110, 95, 75), C(130, 125, 115), C(90, 100, 70), C(120, 60, 55) },
		pants = { C(55, 55, 60), C(60, 60, 70), C(80, 70, 60), C(70, 75, 55) },
	},
	Smoulderer = { skin = { C(38, 30, 28), C(48, 36, 32) }, shirt = { C(30, 26, 24) }, pants = { C(35, 30, 28) } },
	Livewire = {
		skin = { C(170, 185, 195), C(155, 170, 180) },
		shirt = { C(60, 70, 85), C(80, 85, 90) },
		pants = { C(45, 50, 60) },
	},
	Behemoth = { skin = { C(105, 95, 110), C(115, 100, 105) }, shirt = { C(50, 48, 46) }, pants = { C(45, 45, 42) } },
}

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- Builds one ready-to-clone rig for a zombie type.
function ZombieLooks.build(typeName: string, rng: Random): Model?
	local outfit = OUTFITS[typeName] or OUTFITS.Walker
	local def = Config.ZombieTypes[typeName]
	local colors = { skin = pick(rng, outfit.skin), shirt = pick(rng, outfit.shirt), pants = pick(rng, outfit.pants) }

	local description = Instance.new("HumanoidDescription")
	description.HeadColor = colors.skin
	description.LeftArmColor = colors.skin
	description.RightArmColor = colors.skin
	description.TorsoColor = colors.shirt
	description.LeftLegColor = colors.pants
	description.RightLegColor = colors.pants

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Zombies] could not build a zombie rig:", model)
		return nil
	end

	-- The walk is drawn by each client (ZombieAnimator), so the rig needs no animation
	-- scripts or Animator, which also saves server work.
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end

	cubeHead(model, colors.skin, def.eyeColor, rng)
	local dress = DRESS[typeName]
	if dress then
		dress(model, rng, colors)
	end
	if def.scale and def.scale ~= 1 then
		model:ScaleTo(def.scale)
	end

	model.Name = typeName
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = def.health
	humanoid.Health = def.health
	model:SetAttribute("Zombie", true)
	model:SetAttribute("ZombieType", typeName)
	return model
end

return ZombieLooks

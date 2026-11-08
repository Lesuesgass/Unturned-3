-- Draws tracers and impacts and plays positional sounds announced by the server.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Effects = {}

local function tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(235, 220, 170)
	part.Transparency = 0.45
	part.Size = Vector3.new(0.06, 0.06, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	part.Parent = workspace.CurrentCamera
	TweenService:Create(part, TweenInfo.new(0.08), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.1)
end

local function impact(position: Vector3, isFlesh: boolean)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Color = if isFlesh then Color3.fromRGB(110, 30, 28) else Color3.fromRGB(150, 145, 135)
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(position)
	part.Parent = workspace.CurrentCamera
	TweenService:Create(part, TweenInfo.new(0.25), { Size = Vector3.new(1.2, 1.2, 1.2), Transparency = 1 }):Play()
	Debris:AddItem(part, 0.3)
end

local function sound(key: string, position: Vector3)
	local id = Config.Sounds[key]
	if typeof(id) == "table" then
		id = id[math.random(1, math.max(1, #id))]
	end
	if not id or id == "" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.RollOffMaxDistance = 300
	s.Volume = 0.8
	s.Parent = attachment
	s:Play()
	Debris:AddItem(attachment, 6)
end

local function arc(from: Vector3, to: Vector3)
	-- A jagged bolt: a few neon segments with random kinks, gone in a blink.
	local points = { from }
	local segments = 6
	for i = 1, segments - 1 do
		local t = i / segments
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.2
		table.insert(points, from:Lerp(to, t) + jitter)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		local bolt = Instance.new("Part")
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.CanTouch = false
		bolt.CastShadow = false
		bolt.Material = Enum.Material.Neon
		bolt.Color = Color3.fromRGB(150, 225, 255)
		bolt.Size = Vector3.new(0.15, 0.15, length)
		bolt.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -length / 2)
		bolt.Parent = workspace.CurrentCamera
		Debris:AddItem(bolt, 0.15)
	end
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Transparency = 1
	flash.Size = Vector3.one
	flash.CFrame = CFrame.new(to)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 225, 255)
	light.Range = 16
	light.Brightness = 4
	light.Parent = flash
	flash.Parent = workspace.CurrentCamera
	Debris:AddItem(flash, 0.12)
end

local function shockwave(position: Vector3, radius: number)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromRGB(120, 105, 85)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace.CurrentCamera
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
	-- Shake the camera of anyone close by.
	local camera = workspace.CurrentCamera
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance < radius * 3 then
		local strength = (1 - distance / (radius * 3)) * 0.6
		task.spawn(function()
			for i = 1, 10 do
				local s = strength * (1 - i / 10)
				camera.CFrame *= CFrame.Angles((math.random() - 0.5) * s * 0.1, (math.random() - 0.5) * s * 0.1, 0)
				task.wait()
			end
		end)
	end
end

local function knockback(velocity: Vector3)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		root.AssemblyLinearVelocity = velocity
	end
end

-- Played straight away on this client, for the player's own melee swings.
function Effects.playSound(key: string, position: Vector3)
	sound(key, position)
end

function Effects.playImpact(position: Vector3, isFlesh: boolean)
	impact(position, isFlesh)
end

function Effects.init()
	Net.get("Effect").OnClientEvent:Connect(function(kind, a, b)
		if kind == "Tracer" then
			tracer(a, b)
		elseif kind == "Impact" then
			impact(a, b)
		elseif kind == "Sound" then
			sound(a, b)
		elseif kind == "Arc" then
			arc(a, b)
		elseif kind == "Shockwave" then
			shockwave(a, b)
		elseif kind == "Knockback" then
			knockback(a)
		end
	end)
end

return Effects

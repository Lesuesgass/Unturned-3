-- Draws tracers and impacts and plays positional sounds announced by the server.

local Debris = game:GetService("Debris")
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

function Effects.init()
	Net.get("Effect").OnClientEvent:Connect(function(kind, a, b)
		if kind == "Tracer" then
			tracer(a, b)
		elseif kind == "Impact" then
			impact(a, b)
		elseif kind == "Sound" then
			sound(a, b)
		end
	end)
end

return Effects

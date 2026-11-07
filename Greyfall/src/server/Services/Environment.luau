-- Day and night cycle plus the muted atmosphere that gives the game its look.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Environment = {}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

function Environment.init()
	Lighting.ClockTime = Config.DayNight.StartClockTime
	Lighting.Brightness = 2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 112, 108)
	Lighting:SetAttribute("Day", 1)

	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(190, 192, 185)
	atmosphere.Decay = Color3.fromRGB(110, 115, 110)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.6

	local grade = ensure("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	grade.Saturation = -0.18
	grade.Contrast = 0.06
	grade.TintColor = Color3.fromRGB(250, 248, 240)

	-- Advance the clock. A full day takes DayLengthMinutes of real time.
	task.spawn(function()
		local hoursPerSecond = 24 / (Config.DayNight.DayLengthMinutes * 60)
		local last = os.clock()
		while true do
			task.wait(0.5)
			local now = os.clock()
			local before = Lighting.ClockTime
			local after = (before + (now - last) * hoursPerSecond) % 24
			last = now
			if after < before then
				Lighting:SetAttribute("Day", (Lighting:GetAttribute("Day") or 1) + 1)
			end
			Lighting.ClockTime = after
			-- Darker nights without going pitch black.
			local daylight = math.clamp(math.sin((after - 6) / 12 * math.pi), 0, 1)
			Lighting.Brightness = 0.4 + daylight * 1.8
			Lighting.Ambient = Color3.fromRGB(30, 32, 36):Lerp(Color3.fromRGB(70, 70, 68), daylight)
		end
	end)
end

return Environment

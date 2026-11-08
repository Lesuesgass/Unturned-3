-- Punching and swinging animations.
--
-- First person: when you punch with empty hands, two blocky fists rise into view, the
-- punching fist jabs forward (alternating left and right), and the fists stay up for about
-- a second before lowering out of sight.
-- Third person and other players: the swinging arm is posed from the SwingAt and SwingHand
-- attributes the server sets on each character, so everyone sees every swing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local State = require(script.Parent.State)

local Fists = {}

local player = Players.LocalPlayer

local PUNCH_TIME = 0.28 -- one jab, out and back
local VISIBLE_TIME = 1.1 -- fists stay raised this long after the last punch
local SWING_TIME = 0.35 -- third-person arm swing

-- Fist positions relative to the camera.
local HIDDEN = { Left = CFrame.new(-0.8, -2.4, -1.4), Right = CFrame.new(0.8, -2.4, -1.4) }
local GUARD = {
	Left = CFrame.new(-0.7, -0.85, -1.7) * CFrame.Angles(0.15, 0.12, 0.1),
	Right = CFrame.new(0.7, -0.85, -1.7) * CFrame.Angles(0.15, -0.12, -0.1),
}
local JAB = {
	Left = CFrame.new(-0.25, -0.55, -2.7) * CFrame.Angles(0.05, 0.05, 0),
	Right = CFrame.new(0.25, -0.55, -2.7) * CFrame.Angles(0.05, -0.05, 0),
}

local viewmodel: Model
local arms: { [string]: { sleeve: BasePart, fist: BasePart } } = {}
local raised = 0 -- 0 hidden, 1 fully raised
local visibleUntil = 0
local punchStart = -math.huge
local punchHand = "Left"
local swingers: { [Model]: { at: number, hand: string } } = {}

local function newPart(name: string, size: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function buildViewmodel()
	viewmodel = Instance.new("Model")
	viewmodel.Name = "Viewmodel"
	for _, side in { "Left", "Right" } do
		local sleeve = newPart(side .. "Sleeve", Vector3.new(0.5, 0.5, 1.6))
		local fist = newPart(side .. "Fist", Vector3.new(0.55, 0.55, 0.55))
		sleeve.Parent = viewmodel
		fist.Parent = viewmodel
		arms[side] = { sleeve = sleeve, fist = fist }
	end
end

local function colourFromCharacter()
	local character = player.Character
	if not character then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local sleeve = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Torso")
	for _, arm in arms do
		if hand and hand:IsA("BasePart") then
			arm.fist.Color = hand.Color
		end
		if sleeve and sleeve:IsA("BasePart") then
			arm.sleeve.Color = sleeve.Color
		end
	end
end

local function inFirstPerson(): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return false
	end
	return (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 1.5
end

local function emptyHanded(): boolean
	return State.equippedStack() == nil
end

-- Animates the local character's arm straight away (third person, and for other cameras).
function Fists.swing(hand: string)
	local character = player.Character
	if character then
		swingers[character] = { at = workspace:GetServerTimeNow(), hand = hand }
	end
end

-- Called by the input controller the moment the player punches, for instant feedback.
function Fists.punch()
	punchHand = if punchHand == "Right" then "Left" else "Right"
	punchStart = os.clock()
	Fists.swing(punchHand)
	visibleUntil = punchStart + VISIBLE_TIME
	colourFromCharacter()
end

-- 0 to 1 to 0 over the jab, quick out and slower back.
local function jabCurve(t: number): number
	if t <= 0 or t >= 1 then
		return 0
	end
	if t < 0.35 then
		local u = t / 0.35
		return 1 - (1 - u) * (1 - u)
	end
	local u = (t - 0.35) / 0.65
	return 1 - u * u
end

local function updateViewmodel(dt: number)
	local now = os.clock()
	local want = if now < visibleUntil and emptyHanded() and inFirstPerson() then 1 else 0
	raised += (want - raised) * math.min(1, dt * 14)
	if raised < 0.01 then
		viewmodel.Parent = nil
		return
	end
	viewmodel.Parent = workspace.CurrentCamera

	local camera = workspace.CurrentCamera.CFrame
	local jab = jabCurve((now - punchStart) / PUNCH_TIME)
	-- A slight bob so the fists do not look glued to the screen.
	local bob = CFrame.new(0, math.sin(now * 2.2) * 0.02, 0)
	for side, arm in arms do
		local pose = HIDDEN[side]:Lerp(GUARD[side], raised)
		if side == punchHand and jab > 0 then
			pose = pose:Lerp(JAB[side], jab)
		end
		local fistFrame = camera * bob * pose
		arm.fist.CFrame = fistFrame
		arm.sleeve.CFrame = fistFrame * CFrame.new(0, 0, 0.95)
	end
end

-- Third-person swings -----------------------------------------------------------------

local function watchCharacter(character: Model)
	local function changed()
		if character == player.Character then
			return -- our own swings are animated the moment we click (Fists.swing)
		end
		swingers[character] = {
			at = character:GetAttribute("SwingAt") or 0,
			hand = character:GetAttribute("SwingHand") or "Right",
		}
	end
	character:GetAttributeChangedSignal("SwingAt"):Connect(changed)
end

local function watchPlayer(other: Player)
	if other.Character then
		watchCharacter(other.Character)
	end
	other.CharacterAdded:Connect(watchCharacter)
end

local function updateSwings()
	local serverNow = workspace:GetServerTimeNow()
	for character, swing in swingers do
		local t = (serverNow - swing.at) / SWING_TIME
		if not character.Parent or t > 1 then
			swingers[character] = nil
			continue
		end
		local shoulder = character:FindFirstChild(swing.hand .. "UpperArm")
		local motor = shoulder and shoulder:FindFirstChild(swing.hand .. "Shoulder")
		if motor and motor:IsA("Motor6D") then
			local holding = character:FindFirstChildOfClass("Tool") ~= nil
			local k = jabCurve(t)
			if holding then
				-- Overhead chop with a held weapon: wind up, strike down, return to the hold.
				local angle
				if t < 0.3 then
					angle = 1.57 + (2.6 - 1.57) * (t / 0.3)
				elseif t < 0.55 then
					angle = 2.6 + (0.7 - 2.6) * ((t - 0.3) / 0.25)
				else
					angle = 0.7 + (1.57 - 0.7) * ((t - 0.55) / 0.45)
				end
				motor.Transform = CFrame.Angles(angle, 0, 0)
			else
				-- Straight punch forward.
				motor.Transform = CFrame.Angles(1.55 * k, 0, 0)
			end
		end
	end
end

function Fists.init()
	buildViewmodel()
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	player.CharacterAdded:Connect(function()
		visibleUntil = 0
		raised = 0
		task.defer(colourFromCharacter)
	end)

	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 1, updateViewmodel)
	-- Stepped runs after the default animations, so the swing pose wins for its arm.
	RunService.Stepped:Connect(updateSwings)
end

return Fists

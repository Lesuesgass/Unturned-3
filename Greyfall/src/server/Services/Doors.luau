-- Opening and closing doors. Doors in town buildings open for everyone; doors that players
-- build only open for the player who placed them.

local TweenService = game:GetService("TweenService")

local Effects = require(script.Parent.Effects)
local PlayerState = require(script.Parent.PlayerState)

local Doors = {}

local doors: { [BasePart]: any } = {}
local TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- owner is a UserId, or nil for a public door.
function Doors.register(part: BasePart, closed: CFrame, open: CFrame, owner: number?)
	doors[part] = { closed = closed, open = open, owner = owner, isOpen = false }
	part:SetAttribute("Door", true)
	part:SetAttribute("Open", false)
	if owner then
		part:SetAttribute("Owner", owner)
	end
	part.Destroying:Connect(function()
		doors[part] = nil
	end)
end

function Doors.init(world)
	for _, entry in world.doors do
		Doors.register(entry.part, entry.closed, entry.open, nil)
	end
end

function Doors.isDoor(part: Instance): boolean
	return part:IsA("BasePart") and doors[part] ~= nil
end

function Doors.toggle(player: Player, part: BasePart)
	local door = doors[part]
	if not door then
		return
	end
	if door.owner and door.owner ~= player.UserId then
		PlayerState.notify(player, "Locked")
		return
	end
	door.isOpen = not door.isOpen
	part:SetAttribute("Open", door.isOpen)
	TweenService:Create(part, TWEEN, { CFrame = if door.isOpen then door.open else door.closed }):Play()
	Effects.sound("DoorOpen", part.Position)
end

return Doors

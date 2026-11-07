-- Ray from the camera through the mouse (or the screen centre in first person).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Aim = {}

local player = Players.LocalPlayer
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

-- extraIgnore lists instances to skip besides the local character.
function Aim.cast(maxDistance: number, extraIgnore: { Instance }?): (RaycastResult?, Ray)
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _, item in extraIgnore or {} do
		table.insert(ignore, item)
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(ray.Origin, ray.Direction * maxDistance, params), ray
end

-- Point the player is aiming at, far away if nothing is hit.
function Aim.point(maxDistance: number, extraIgnore: { Instance }?): Vector3
	local result, ray = Aim.cast(maxDistance, extraIgnore)
	return if result then result.Position else ray.Origin + ray.Direction * maxDistance
end

return Aim

-- Visual and audio effects are drawn by every client. The server only says what happened.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Effects = {}

local remote: RemoteEvent

function Effects.init()
	remote = Net.get("Effect")
end

function Effects.sound(key: string, position: Vector3)
	local id = Config.Sounds[key]
	local hasSound = if typeof(id) == "table" then #id > 0 else id ~= nil and id ~= ""
	if hasSound then
		remote:FireAllClients("Sound", key, position)
	end
end

function Effects.tracer(from: Vector3, to: Vector3)
	remote:FireAllClients("Tracer", from, to)
end

function Effects.impact(position: Vector3, isFlesh: boolean)
	remote:FireAllClients("Impact", position, isFlesh)
end

return Effects

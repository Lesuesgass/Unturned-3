-- Visual and audio effects are drawn by every client. The server only says what happened.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Effects = {}

local remote: RemoteEvent

function Effects.init()
	remote = Net.get("Effect")
end

local Players = game:GetService("Players")

-- Sends to everyone except one player (who already played it locally), or to everyone.
local function broadcast(except: Player?, ...)
	if not except then
		remote:FireAllClients(...)
		return
	end
	for _, player in Players:GetPlayers() do
		if player ~= except then
			remote:FireClient(player, ...)
		end
	end
end

function Effects.sound(key: string, position: Vector3, except: Player?)
	local id = Config.Sounds[key]
	local hasSound = if typeof(id) == "table" then #id > 0 else id ~= nil and id ~= ""
	if hasSound then
		broadcast(except, "Sound", key, position)
	end
end

function Effects.tracer(from: Vector3, to: Vector3)
	remote:FireAllClients("Tracer", from, to)
end

-- Electric arc between two points.
function Effects.arc(from: Vector3, to: Vector3)
	remote:FireAllClients("Arc", from, to)
end

-- Expanding ring on the ground, used by the Behemoth slam.
function Effects.shockwave(position: Vector3, radius: number)
	remote:FireAllClients("Shockwave", position, radius)
end

-- Pushes one player. Characters are simulated by their own client, so the client applies it.
function Effects.knockback(player: Player, velocity: Vector3)
	remote:FireClient(player, "Knockback", velocity)
end

function Effects.impact(position: Vector3, isFlesh: boolean, except: Player?)
	broadcast(except, "Impact", position, isFlesh)
end

return Effects

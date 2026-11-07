-- Remote event setup. The server creates them, clients wait for them.
--   Action  client -> server  inventory, interaction and movement requests
--   Attack  client -> server  melee swings and gun shots
--   Sync    server -> client  inventory snapshot
--   Effect  server -> all     tracers, impacts and positional sounds
--   Notify  server -> client  short status messages
--   Setup   client -> server  main menu choices from the host

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = { "Action", "Attack", "Sync", "Effect", "Notify", "Setup" }

local Net = {}

function Net.setup()
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Net.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net

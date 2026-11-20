--!strict
-- Returning a Connection from something that has to be undone later.

local Connection = require("../src")
local Void = require("../../Void/src")

-- A function cleanup: whatever `listen` set up is undone when the connection is disconnected.
local function listen(part: BasePart, callback: (hit: BasePart) -> ())
	local touched = part.Touched:Connect(callback)

	return Connection.new(function()
		touched:Disconnect()
		print(`stopped listening to {part.Name}`)
	end)
end

local door = Instance.new("Part")
door.Name = "Door"

local connection = listen(door, print)
print(connection.connected) --> true

connection:disconnect() --> stopped listening to Door
print(connection.connected) --> false

-- Disconnecting again does nothing, the cleanup only ever runs once.
connection:disconnect()

-- A Void cleanup: disconnecting cleans every item the Void holds.
local void = Void.new()
void:add(Instance.new("Part"))
void:add(workspace.ChildAdded:Connect(print))

local group = Connection.new(void)
group:disconnect()
print(void:is_empty()) --> true

-- A Connection can itself be added to a Void, which disconnects it when cleaned.
local owner = Void.new()
local owned = owner:add(listen(door, print))
owner:clean() --> stopped listening to Door
print(owned.connected) --> false

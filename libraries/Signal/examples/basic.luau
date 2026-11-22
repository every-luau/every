--!strict
-- Connecting, firing and cleaning up a signal.

local Signal = require("../src")

local damaged = Signal.new()

-- Handlers get every fired value, in the order they were connected.
local connection = damaged:connect(function(name: string, damage: number)
	print(`{name} took {damage} damage`)
end)

-- A handler that yields doesn't hold up the others, it runs on its own thread.
damaged:connect(function(name: string)
	task.wait(0.5)
	print(`{name} can be hit again`)
end)

-- `once` disconnects itself after the first fire.
damaged:once(function()
	print("first hit!")
end)

damaged:fire("Player1", 25)

connection:disconnect()

-- `wait` yields until the next fire and returns its values.
task.delay(1, damaged.fire, damaged, "Player2", 10)
local name, damage = damaged:wait()
print(name, damage) --> Player2 10

-- A signal can follow an RBXScriptSignal, and destroying it disconnects from it.
local added = Signal.wrap(workspace.ChildAdded)
added:connect(print)
added:destroy()

-- A signal can also fire through a BindableEvent, so other scripts connected to
-- it, or to their own Signal made from it, hear the same fires.
local event = Instance.new("BindableEvent")
local round_ended = Signal.bindable(event)
round_ended:connect(function(winner: string)
	print(`{winner} won`)
end)
event.Event:Connect(function(winner: string)
	print(`another script heard that {winner} won`)
end)
round_ended:fire("Alice")
round_ended:destroy()

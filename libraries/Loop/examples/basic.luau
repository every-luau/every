--!strict
-- Running code every few seconds, then stopping it.

local Loop = require("../src")

-- The callback gets the time since its last call, a bit over the interval since
-- it runs on the first frame after it.
local connection = Loop(1, function(elapsed: number)
	print(`{elapsed} seconds passed`)
end)

-- `Loop.new` does the same as calling the module.
local spin = Loop.new(0, function(delta_time: number)
	-- An interval of 0 runs every frame, so `elapsed` is the frame's delta time.
	print(delta_time)
end)

-- Disconnecting stops the loop.
task.delay(5, function()
	connection:disconnect()
	spin:disconnect()
end)

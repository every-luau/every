--!strict
-- A round countdown and a stopwatch.

local Timer = require("../src")

-- Counts down from 60 by going at a speed of -1.
local round = Timer.new():set_time(60):set_speed(-1):start()

round:observe(function(time)
	print(Timer.format_seconds(math.max(time, 0))) --> 01:00, 00:59...
	if time <= 0 then
		round:destroy()
	end
end)

-- A stopwatch that can be paused and resumed.
local stopwatch = Timer.new():start()
task.wait(1.5)
stopwatch:stop()
print(stopwatch:format(true)) --> 01.500
stopwatch:start()

-- Twice as fast as real time.
stopwatch:set_speed(2)

print(Timer.format_seconds(3725)) --> 01:02:05

--!strict
-- Creating observables, deriving new ones from them and subscribing.

local Observable = require("../src")

-- A producer emits values, and returns what to undo when the subscription ends.
local seconds = Observable.new(function(emit: (number) -> ())
	local elapsed = 0
	local thread = task.spawn(function()
		while true do
			task.wait(1)
			elapsed += 1
			emit(elapsed)
		end
	end)

	return function()
		task.cancel(thread)
	end
end)

-- Nothing runs until something subscribes, and each subscription runs the producer again.
local connection = seconds
	:filter(function(value)
		return value % 2 == 0
	end)
	:map(function(value)
		return `{value} seconds`
	end)
	:subscribe(print) --> 2 seconds, 4 seconds...

task.wait(5)
connection:disconnect() -- cancels the thread above

-- `from_signal` follows a signal, and `changed` skips values equal to the previous one.
local humanoid = Instance.new("Humanoid")
local alive = Observable.from_signal(humanoid.HealthChanged, function(health: number)
	return health > 0
end):changed()

alive:subscribe(function(value)
	print(if value then "alive" else "dead")
end)

humanoid.Health = 50 --> alive
humanoid.Health = 20 -- still alive, skipped
humanoid.Health = 0 --> dead

-- `use` chains operators written outside the library.
local function doubled(source)
	return source:map(function(value: number)
		return value * 2
	end)
end

Observable.from_value(21):use(doubled):subscribe(print) --> 42

-- `destroy` ends every subscription to `alive`.
alive:destroy()

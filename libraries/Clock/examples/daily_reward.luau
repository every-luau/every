--!strict
-- A daily reward saved as a timestamp, checked the same way on any server.

local Clock = require("../src")

local data = { last_reward = 0, boost_ends = 0 }

if Clock.since(data.last_reward) >= Clock.DAY then
	data.last_reward = Clock.timestamp()
	print("reward given")
else
	print(`next reward in {math.ceil(Clock.left(data.last_reward + Clock.DAY))} seconds`)
end

-- A boost that ends in 30 minutes, even after the player changes server.
data.boost_ends = Clock.timestamp() + 30 * Clock.MINUTE
print(Clock.left(data.boost_ends)) --> 1800

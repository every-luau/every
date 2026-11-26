--!strict
-- A shop that shows the same items on every server and changes on the hour, with nothing sent.

local Clock = require("../src")

local items = { "sword", "shield", "bow", "staff", "axe" }

local function stock(period: number): { string }
	local random = Random.new(period)
	return { items[random:NextInteger(1, #items)], items[random:NextInteger(1, #items)] }
end

print(stock(Clock.period(Clock.HOUR)))

Clock.every(Clock.HOUR, function(period)
	print(stock(period))
end)

-- Seconds until the daily reset at 5:00 UTC.
print(Clock.left(Clock.next(Clock.DAY, 5 * Clock.HOUR)))

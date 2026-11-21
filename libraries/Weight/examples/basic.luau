--!strict
-- Picking loot, with and without luck.

local Weight = require("../src")

local loot = Weight.new({ common = 80, rare = 15, epic = 5 })

-- A key comes up as often as its weight over the total: common 80% of the time.
print(loot:generate())

-- Luck above 1 flattens the weights, so rare and epic come up more often.
print(loot:generate(5))
print(loot:get_values(5))

-- The lower the intensity, the more luck does.
loot:set_intensity(1)
print(loot:get_values(5))

-- `+` merges two weights into a new one, the right side winning.
local event = loot + Weight.new({ legendary = 1 })
print(event) --> Weight { common = 80, epic = 5, legendary = 1, rare = 15 }

-- Keys with a weight of 0 or less never come up.
local disabled = Weight.new({ common = 1, cursed = 0 })
print(disabled:generate()) --> common

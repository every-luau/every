--!strict
-- A coin counter shown in the UI.

local Atom = require("../src")

local coins = Atom.new(0)

-- Runs right away with 0, then on every change.
coins:observe(function(new, old)
	print(`{old} -> {new}`)
end)

coins:increment(10)
coins:decrement(50, 0) -- stops at 0
coins:set(0) -- the same value, so nothing is notified

-- A derived atom follows its source and is destroyed with it.
local label = coins:map(function(value)
	return `{value} coins`
end)
print(label:get()) --> 0 coins

-- Tables are compared deeply, and `get` returns a copy.
local inventory = Atom.new({ sword = 1 })
inventory:update(function(items)
	items.shield = 1
	return items
end)

-- Notifies once per atom, after both changes.
Atom.batch({ coins, inventory }, function()
	coins:increment(5)
	inventory:reset()
end)

coins:destroy()

--!strict
-- A brio holds a value while it is alive, and cleans its void once it dies.

local Brio = require("../src")

local brio = Brio.new("sword", 3)

-- get_value returns every value the brio was created with.
local name, count = brio:get_value()
print(`{count} {name}s`)

-- The void is made the first time it is asked for, and the same one comes
-- back after that.
local void = brio:to_void()
void:add(function()
	print("the brio died")
end)

-- to_void_and_value gives both in one line.
local same_void, same_name = brio:to_void_and_value()
print(same_void == void, same_name)

-- Destroying cleans the void. A dead brio has no value anymore, so check
-- is_dead after yielding.
brio:destroy()
print(brio:is_dead()) --> true

-- Brio.DEAD is a brio that is already dead.
print(Brio.DEAD:is_dead()) --> true

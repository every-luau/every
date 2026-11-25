--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Brio = require("../src")

describe("Brio", function()
	it("holds its values, nil included, until killed", function()
		local brio = Brio.new("a", nil, "c")
		local a, b, c = brio:get_value()
		expect(a).toBe("a")
		expect(b).toBeNil()
		expect(c).toBe("c")
		expect(brio:is_dead()).toBe(false)

		brio:destroy()
		expect(brio:is_dead()).toBe(true)
		expect(function()
			brio:get_value()
		end).toThrow("cannot call get_value on a dead brio")
	end)

	it("makes its void only when asked, and cleans it when killed", function()
		local brio = Brio.new(1)
		expect((brio :: any)._void).toBeNil()

		local void = brio:to_void()
		expect(brio:to_void()).toBe(void)

		local part = roblox.new("Part")
		void:add(part)
		brio:destroy()
		expect(part.destroyed).toBe(true)
		expect(function()
			brio:to_void()
		end).toThrow("cannot call to_void on a dead brio")
	end)

	it("gives the void and the values together", function()
		local brio = Brio.new("value", 2)
		local void, value, other = brio:to_void_and_value()
		expect(void).toBe(brio:to_void())
		expect(value).toBe("value")
		expect(other).toBe(2)
	end)

	it("dies once, and can be added to a void", function()
		local brio = Brio.new(1)
		local cleaned = 0
		brio:to_void():add(function()
			cleaned += 1
		end)
		brio:destroy()
		brio:destroy()
		expect(cleaned).toBe(1)

		local holder = Brio.new(2)
		local outer = Brio.new(3)
		outer:to_void():add(holder)
		outer:destroy()
		expect(holder:is_dead()).toBe(true)
	end)

	it("tells brios apart and has a dead one ready", function()
		expect(Brio.is(Brio.new(1))).toBe(true)
		expect(Brio.is({})).toBe(false)
		expect(Brio.is(Brio.DEAD)).toBe(true)
		expect(Brio.DEAD:is_dead()).toBe(true)
	end)
end)

return nil

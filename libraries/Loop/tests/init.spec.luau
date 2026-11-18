--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Loop = require("../src")

describe("Loop", function()
	it("calls back once the interval passed, with the time that passed", function()
		local calls: { number } = {}
		local connection = Loop.new(1, function(elapsed)
			table.insert(calls, elapsed)
		end)

		roblox.step(0.5)
		expect(#calls).toBe(0)
		roblox.step(0.75)
		expect(calls).toEqual({ 1.25 })
		roblox.step(0.5)
		roblox.step(0.5)
		expect(calls).toEqual({ 1.25, 1 })

		connection:disconnect()
	end)

	it("calls back every frame with an interval of 0", function()
		local calls = 0
		local connection = Loop(0, function()
			calls += 1
		end)

		roblox.step(0.1)
		roblox.step(0.1)
		expect(calls).toBe(2)

		connection:disconnect()
	end)

	it("stops once disconnected", function()
		local calls = 0
		local connection = Loop.new(0, function()
			calls += 1
		end)

		connection:disconnect()
		roblox.step(1)
		expect(calls).toBe(0)
		expect(roblox.listeners()).toBe(0)
	end)

	it("refuses a negative interval", function()
		expect(function()
			Loop.new(-1, print)
		end).toThrow("positive interval")
	end)
end)

return nil

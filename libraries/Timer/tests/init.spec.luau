--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Timer = require("../src")

describe("Timer", function()
	it("starts stopped at 0", function()
		local timer = Timer.new()
		expect(timer:get_time()).toBe(0)
		expect(timer:get_speed()).toBe(1)
		expect(timer:is_playing()).toBe(false)
		timer:destroy()
	end)

	it("only moves while playing", function()
		local timer = Timer.new()
		roblox.step(1)
		expect(timer:get_time()).toBe(0)

		timer:start()
		roblox.step(1)
		roblox.step(0.5)
		expect(timer:get_time()).toBe(1.5)

		timer:stop()
		roblox.step(1)
		expect(timer:get_time()).toBe(1.5)
		timer:destroy()
	end)

	it("does not listen to Heartbeat while stopped", function()
		local timer = Timer.new()
		expect(roblox.listeners()).toBe(0)
		timer:start():start()
		expect(roblox.listeners()).toBe(1)
		timer:stop()
		expect(roblox.listeners()).toBe(0)
		timer:destroy()
	end)

	it("counts down with a negative speed", function()
		local timer = Timer.new():set_time(10):set_speed(-2):start()
		roblox.step(1)
		expect(timer:get_time()).toBe(8)
		timer:destroy()
	end)

	it("resets to a stopped 0", function()
		local timer = Timer.new():start()
		roblox.step(3)
		timer:reset()
		expect(timer:get_time()).toBe(0)
		expect(timer:is_playing()).toBe(false)
		timer:destroy()
	end)

	it("calls observe right away then every update", function()
		local timer = Timer.new():set_time(5)
		local seen: { { number } } = {}
		timer:observe(function(time, elapsed)
			table.insert(seen, { time, elapsed })
		end)

		timer:start()
		roblox.step(1)
		expect(seen).toEqual({ { 5, 0 }, { 6, 1 } })
		timer:destroy()
	end)

	it("stops and disconnects everything once destroyed", function()
		local timer = Timer.new():start()
		local updates = 0
		timer.updated:connect(function()
			updates += 1
		end)

		timer:destroy()
		roblox.step(1)
		expect(updates).toBe(0)
		expect(roblox.listeners()).toBe(0)
	end)

	it("formats durations", function()
		expect(Timer.format_seconds(5)).toBe("05")
		expect(Timer.format_seconds(65)).toBe("01:05")
		expect(Timer.format_seconds(3725)).toBe("01:02:05")
		expect(Timer.format_seconds(65.5, true)).toBe("01:05.500")
		expect(Timer.format_seconds(-5)).toBe("-05")
		expect(Timer.new():set_time(61):format()).toBe("01:01")
	end)

	it("tells timers apart", function()
		expect(Timer.is(Timer.new())).toBe(true)
		expect(Timer.is({})).toBe(false)
	end)
end)

return nil

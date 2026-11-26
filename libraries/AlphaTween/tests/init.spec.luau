--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local AlphaTween = require("../src")

local LINEAR = Enum.EasingStyle.Linear
local IN = Enum.EasingDirection.In

local function linear(time: number, repeat_count: number?, reverses: boolean?, delay: number?): TweenInfo
	return TweenInfo.new(time, LINEAR, IN, repeat_count, reverses, delay)
end

-- a tween that records every alpha it is called with
local function recorded(info: TweenInfo): (AlphaTween.AlphaTween, { number })
	local seen: { number } = {}
	local tween = AlphaTween.new(info, function(alpha)
		table.insert(seen, alpha)
	end)
	return tween, seen
end

local function close(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

describe("AlphaTween", function()
	it("calls back with the alpha every frame until it completes", function()
		local tween, seen = recorded(linear(1))
		expect(tween:get_state()).toBe(Enum.PlaybackState.Begin)

		local states: { any } = {}
		tween.completed:connect(function(state)
			table.insert(states, state)
		end)

		tween:play()
		expect(tween:get_state()).toBe(Enum.PlaybackState.Playing)
		roblox.step(0.25)
		roblox.step(0.5)
		roblox.step(0.5)

		expect(seen).toEqual({ 0, 0.25, 0.75, 1 })
		expect(tween:get_state()).toBe(Enum.PlaybackState.Completed)
		expect(tween:is_playing()).toBe(false)
		expect(states).toEqual({ Enum.PlaybackState.Completed })
		expect(roblox.listeners()).toBe(0)
	end)

	it("eases the alpha with the style and direction", function()
		local tween, seen = recorded(TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		tween:play()
		roblox.step(0.5)
		expect(seen[2]).toBe(0.25)

		local out, seen_out = recorded(TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		out:play()
		roblox.step(0.5)
		expect(seen_out[2]).toBe(0.75)
		expect(out:get_alpha()).toBe(0.75)

		tween:destroy()
		out:destroy()
	end)

	it("waits out the delay before every repeat, and goes back when it reverses", function()
		local tween, seen = recorded(linear(1, 1, true, 0.5))
		tween:play()
		expect(tween:get_state()).toBe(Enum.PlaybackState.Delayed)
		expect(#seen).toBe(0)

		roblox.step(1) -- 0.5 into going forward
		expect(seen[#seen]).toBe(0.5)
		expect(tween:get_state()).toBe(Enum.PlaybackState.Playing)

		roblox.step(1) -- 0.5 into going back
		expect(seen[#seen]).toBe(0.5)

		roblox.step(0.75) -- in the delay of the repeat
		expect(tween:get_state()).toBe(Enum.PlaybackState.Delayed)
		local count = #seen

		roblox.step(0.5)
		expect(#seen).toBe(count + 1)
		expect(close(seen[#seen], 0.25)).toBe(true)

		roblox.step(10)
		expect(seen[#seen]).toBe(0)
		expect(tween:get_state()).toBe(Enum.PlaybackState.Completed)
	end)

	it("repeats forever with a repeat count of -1", function()
		local tween, seen = recorded(linear(1, -1))
		tween:play()
		roblox.step(10.5)
		expect(seen[#seen]).toBe(0.5)
		expect(tween:is_playing()).toBe(true)
		tween:destroy()
	end)

	it("resumes from where it was paused", function()
		local tween, seen = recorded(linear(1))
		local fired = 0
		tween.completed:connect(function()
			fired += 1
		end)

		tween:play()
		roblox.step(0.25)
		tween:pause()
		expect(tween:get_state()).toBe(Enum.PlaybackState.Paused)
		expect(roblox.listeners()).toBe(0)
		roblox.step(5)
		expect(seen[#seen]).toBe(0.25)
		expect(fired).toBe(0)

		tween:play()
		roblox.step(0.25)
		expect(seen[#seen]).toBe(0.5)
		tween:destroy()
	end)

	it("cancels back to the start, keeping the last alpha", function()
		local tween, seen = recorded(linear(1))
		local states: { any } = {}
		tween.completed:connect(function(state)
			table.insert(states, state)
		end)

		tween:play()
		roblox.step(0.5)
		tween:cancel()
		expect(tween:get_state()).toBe(Enum.PlaybackState.Cancelled)
		expect(tween:get_alpha()).toBe(0.5)
		expect(states).toEqual({ Enum.PlaybackState.Cancelled })

		tween:cancel()
		expect(#states).toBe(1)

		tween:play()
		expect(seen[#seen]).toBe(0)
		roblox.step(0.25)
		expect(seen[#seen]).toBe(0.25)
		tween:destroy()
	end)

	it("plays again from the start once completed, and does nothing while playing", function()
		local tween, seen = recorded(linear(1))
		tween:play()
		roblox.step(0.5)
		tween:play()
		expect(roblox.listeners()).toBe(1)
		roblox.step(1)
		expect(tween:get_state()).toBe(Enum.PlaybackState.Completed)

		tween:play()
		expect(seen[#seen]).toBe(0)
		tween:destroy()
	end)

	describe("values", function()
		it("lerps numbers, UDim and anything with Lerp", function()
			expect(AlphaTween.lerp(0, 10, 0.25)).toBe(2.5)

			local udim = AlphaTween.lerp(UDim.new(0, 0), UDim.new(1, 100), 0.5) :: any
			expect(udim.Scale).toBe(0.5)
			expect(udim.Offset).toBe(50)

			local Point = {}
			Point.__index = Point
			function Point.Lerp(self: any, goal: any, alpha: number)
				return setmetatable({ x = self.x + (goal.x - self.x) * alpha }, Point)
			end
			local point = AlphaTween.lerp(setmetatable({ x = 0 }, Point), setmetatable({ x = 4 }, Point), 0.5) :: any
			expect(point.x).toBe(2)

			expect(function()
				AlphaTween.lerp(true, false, 0.5)
			end).toThrow("cannot lerp a boolean")
		end)

		it("tweens from one value to another", function()
			local seen: { number } = {}
			local tween = AlphaTween.value(10, 20, linear(1), function(value)
				table.insert(seen, value)
			end)
			tween:play()
			roblox.step(0.5)
			roblox.step(0.5)
			expect(seen).toEqual({ 10, 15, 20 })

			expect(function()
				AlphaTween.value("a", "b", linear(1), function() end)
			end).toThrow("cannot lerp a string")
		end)
	end)

	it("stops without firing completed once destroyed", function()
		local tween = recorded(linear(1))
		local fired = false
		tween.completed:connect(function()
			fired = true
		end)
		tween:play()
		tween:destroy()
		roblox.step(2)
		expect(fired).toBe(false)
		expect(roblox.listeners()).toBe(0)
	end)

	it("needs a callback and tells tweens apart", function()
		expect(function()
			AlphaTween.new(nil, nil :: any)
		end).toThrow("callback")
		expect(AlphaTween.is(AlphaTween.new(nil, function() end))).toBe(true)
		expect(AlphaTween.is({})).toBe(false)
	end)
end)

return nil

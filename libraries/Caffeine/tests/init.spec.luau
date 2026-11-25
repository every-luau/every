--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Caffeine = require("../src")

describe("Caffeine.keep", function()
	it("wakes the part before every physics step until disconnected", function()
		local part = roblox.part()
		local connection = Caffeine.keep(part :: any)

		roblox.step()
		roblox.step()
		expect(#part.impulses).toBe(2)

		connection:disconnect()
		roblox.step()
		expect(#part.impulses).toBe(2)
		expect(roblox.listeners()).toBe(0)
	end)

	it("is what calling the module does", function()
		local part = roblox.part()
		local connection = Caffeine(part :: any)

		roblox.step()
		expect(#part.impulses).toBe(1)

		connection:disconnect()
	end)

	it("shakes up then down so nothing drifts, scaled by the assembly's mass", function()
		local part = roblox.part()
		part.AssemblyMass = 500
		local connection = Caffeine.keep(part :: any)

		for _ = 1, 4 do
			roblox.step()
		end
		local total = 0
		for _, impulse in part.impulses do
			expect(impulse.X).toBe(0)
			expect(impulse.Z).toBe(0)
			-- a 0.0001 studs/s change in speed, whatever the mass
			expect(math.abs(impulse.Y / part.AssemblyMass)).toBeCloseTo(1e-4)
			total += impulse.Y
		end
		expect((part.impulses[1].Y > 0) ~= (part.impulses[2].Y > 0)).toBe(true)
		expect(total).toBeCloseTo(0)

		connection:disconnect()
	end)

	it("shakes a welded assembly once, through its root", function()
		local root = roblox.part()
		local welded = roblox.part(root)
		local connection = Caffeine.keep(roblox.model({ root, welded }) :: any)

		roblox.step()
		expect(#root.impulses).toBe(1)
		expect(#welded.impulses).toBe(0)

		connection:disconnect()
	end)

	it("tags kept parts so clients keep them too, until let go", function()
		local part = roblox.part()
		local first = Caffeine.keep(part :: any)
		local second = Caffeine.keep(part :: any)
		expect(roblox.has_tag(part, "Caffeine")).toBe(true)

		first:disconnect()
		expect(roblox.has_tag(part, "Caffeine")).toBe(true)
		second:disconnect()
		expect(roblox.has_tag(part, "Caffeine")).toBe(false)
	end)

	it("keeps every part of a list", function()
		local a, b = roblox.part(), roblox.part()
		local connection = Caffeine.keep({ a, b } :: any)

		roblox.step()
		expect(#a.impulses).toBe(1)
		expect(#b.impulses).toBe(1)

		connection:disconnect()
		expect(roblox.listeners()).toBe(0)
	end)

	it("follows the parts of a model", function()
		local first, later = roblox.part(), roblox.part()
		local model = roblox.model({ first, roblox.folder() })
		local connection = Caffeine.keep(model :: any)

		roblox.step()
		expect(#first.impulses).toBe(1)

		model.add(later)
		model.remove(first)
		roblox.step()
		expect(#first.impulses).toBe(1)
		expect(#later.impulses).toBe(1)

		connection:disconnect()
		model.add(roblox.part())
		expect(roblox.listeners()).toBe(0)
	end)

	it("holds a part kept twice until both are disconnected", function()
		local part = roblox.part()
		local first = Caffeine.keep(part :: any)
		local second = Caffeine.keep({ part } :: any)

		roblox.step()
		expect(#part.impulses).toBe(1)

		first:disconnect()
		first:disconnect()
		roblox.step()
		expect(#part.impulses).toBe(2)

		second:disconnect()
		roblox.step()
		expect(#part.impulses).toBe(2)
		expect(roblox.listeners()).toBe(0)
	end)

	it("holds a part listed twice once", function()
		local part = roblox.part()
		local connection = Caffeine.keep({ part, part } :: any)

		roblox.step()
		expect(#part.impulses).toBe(1)

		connection:disconnect()
		expect(roblox.listeners()).toBe(0)
	end)

	it("shares one PreSimulation connection between parts", function()
		local a, b = roblox.part(), roblox.part()
		local keep_a = Caffeine.keep(a :: any)
		local keep_b = Caffeine.keep(b :: any)

		expect(roblox.listeners()).toBe(1)
		keep_a:disconnect()
		expect(roblox.listeners()).toBe(1)
		keep_b:disconnect()
		expect(roblox.listeners()).toBe(0)
	end)

	it("lets go once the duration passed", function()
		local part = roblox.part()
		local connection = Caffeine.keep(part :: any, 2)

		roblox.step()
		expect(#part.impulses).toBe(1)

		roblox.flush()
		expect(connection.connected).toBe(false)
		roblox.step()
		expect(#part.impulses).toBe(1)
	end)

	it("lets go of a destroyed part", function()
		local part = roblox.part()
		local connection = Caffeine.keep(part :: any)
		Caffeine.keep(part :: any)

		part:Destroy()
		roblox.step()
		expect(#part.impulses).toBe(0)
		expect(roblox.listeners()).toBe(0)
		expect(part.Destroying.count()).toBe(0)

		-- disconnecting after the part is gone does nothing
		connection:disconnect()
	end)

	it("skips anchored parts while keeping them", function()
		local part = roblox.part()
		part.Anchored = true
		local connection = Caffeine.keep(part :: any)

		roblox.step()
		expect(#part.impulses).toBe(0)

		part.Anchored = false
		roblox.step()
		expect(#part.impulses).toBe(1)

		connection:disconnect()
	end)

	it("refuses what is not a target", function()
		expect(function()
			Caffeine.keep("part" :: any)
		end).toThrow("needs a BasePart, a Model or a list of BaseParts")
		expect(function()
			Caffeine.keep(nil :: any)
		end).toThrow("needs a BasePart, a Model or a list of BaseParts")
		expect(function()
			Caffeine.keep({ roblox.part(), 5 } :: any)
		end).toThrow("got number at 2")
		expect(roblox.listeners()).toBe(0)
	end)

	it("refuses a duration that is not positive", function()
		local part = roblox.part()
		expect(function()
			Caffeine.keep(part :: any, 0)
		end).toThrow("positive duration")
		expect(function()
			Caffeine.keep(part :: any, -1)
		end).toThrow("positive duration")
		expect(roblox.listeners()).toBe(0)
	end)
end)

describe("Caffeine.wake", function()
	it("wakes the part once", function()
		local part = roblox.part()
		Caffeine.wake(part :: any)
		expect(#part.impulses).toBe(1)

		roblox.step()
		expect(#part.impulses).toBe(1)
	end)

	it("does nothing to an anchored part", function()
		local part = roblox.part()
		part.Anchored = true
		Caffeine.wake(part :: any)
		expect(#part.impulses).toBe(0)
	end)

	it("wakes every part of a model or a list", function()
		local a, b = roblox.part(), roblox.part()
		Caffeine.wake(roblox.model({ a, roblox.folder() }) :: any)
		Caffeine.wake({ b } :: any)

		expect(#a.impulses).toBe(1)
		expect(#b.impulses).toBe(1)
	end)

	it("refuses what is not a target", function()
		expect(function()
			Caffeine.wake("part" :: any)
		end).toThrow("Caffeine.wake needs a BasePart")
	end)
end)

return nil

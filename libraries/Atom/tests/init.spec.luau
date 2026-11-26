--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Atom = require("../src")
local Stream = require("../../Stream/src")

-- records every (new, old) an atom notifies, skipping the first call of observe
local function record(atom: any): { { any } }
	local changes: { { any } } = {}
	local first = true
	atom:observe(function(new, old)
		if first then
			first = false
			return
		end
		table.insert(changes, { new, old })
	end)
	return changes
end

describe("Atom", function()
	it("holds a value", function()
		local atom = Atom.new(1)
		expect(atom:get()).toBe(1)
		expect(atom:peek()).toBe(1)
	end)

	it("notifies with the new and old values", function()
		local atom = Atom.new(1)
		local changes = record(atom)
		atom:set(2)
		expect(changes).toEqual({ { 2, 1 } })
	end)

	it("does not notify when the value is deeply equal", function()
		local atom = Atom.new({ a = { b = 1 } })
		local changes = record(atom)
		atom:set({ a = { b = 1 } })
		expect(#changes).toBe(0)
		atom:set({ a = { b = 1 } }, true)
		expect(#changes).toBe(1)
	end)

	it("compares and copies tables with a metatable by reference", function()
		local class = {}
		local first, second = setmetatable({}, class), setmetatable({}, class)
		local atom = Atom.new(first)
		local changes = record(atom)
		expect(atom:get()).toBe(first)
		atom:set(second)
		expect(#changes).toBe(1)
	end)

	it("returns copies from get", function()
		local atom = Atom.new({ list = { 1 } })
		local copy = atom:get()
		table.insert(copy.list, 2)
		expect(atom:peek().list).toEqual({ 1 })
	end)

	it("calls observe right away then on changes, until disconnected", function()
		local atom = Atom.new("a")
		local seen: { any } = {}
		local connection = atom:observe(function(new)
			table.insert(seen, new)
		end)
		atom:set("b")
		connection:disconnect()
		atom:set("c")
		expect(seen).toEqual({ "a", "b" })
	end)

	it("updates, increments, decrements and toggles", function()
		local number = Atom.new(5)
		number:update(function(value)
			return value * 2
		end)
		expect(number:peek()).toBe(10)
		expect(number:increment(100, 50):peek()).toBe(50)
		expect(number:decrement(100, 0):peek()).toBe(0)

		local flag = Atom.new(false)
		expect(flag:toggle():peek()).toBe(true)
	end)

	it("resets to a copy of the initial value", function()
		local initial = { score = 0 }
		local atom = Atom.new(initial)
		atom:set({ score = 10 })
		atom:reset()
		expect(atom:peek()).toEqual({ score = 0 })
		expect(atom:peek()).toNotBe(initial)
	end)

	it("ignores changes while frozen", function()
		local atom = Atom.new(1)
		atom:freeze()
		atom:set(2)
		expect(atom:peek()).toBe(1)
		expect(atom:is_frozen()).toBe(true)
		atom:unfreeze():set(3)
		expect(atom:peek()).toBe(3)
	end)

	it("commits a transaction only when it succeeds", function()
		local atom = Atom.new(10)
		atom:transaction(function(value)
			return value - 3
		end)
		expect(atom:peek()).toBe(7)

		atom:transaction(function(): number
			error("not enough")
		end)
		expect(atom:peek()).toBe(7)
		expect(roblox.warnings[#roblox.warnings]).toContain("not enough")
	end)

	it("notifies once per atom at the end of a batch", function()
		local x = Atom.new(0)
		local y = Atom.new(0)
		local x_changes = record(x)
		local y_changes = record(y)

		Atom.batch({ x, y }, function()
			x:set(1)
			x:set(2)
			y:set(5)
			y:set(0)
			expect(#x_changes).toBe(0)
		end)

		expect(x:peek()).toBe(2)
		expect(x_changes).toEqual({ { 2, 0 } })
		expect(#y_changes).toBe(0)
	end)

	it("tells atoms apart", function()
		expect(Atom.is(Atom.new(0))).toBe(true)
		expect(Atom.is(Stream.of(0))).toBe(false)
		expect(Atom.is({})).toBe(false)
	end)
end)

describe("as a stream", function()
	it("is a stream that emits the value on listen and every change", function()
		local atom = Atom.new(1)
		expect(Stream.is(atom)).toBe(true)

		local seen: { any } = {}
		local connection = atom
			:map(function(value)
				return value * 10
			end)
			:listen(function(value)
				table.insert(seen, value)
			end)
		atom:set(1)
		atom:set(2)
		connection:disconnect()
		atom:set(3)
		expect(seen).toEqual({ 10, 20 })
		expect(atom:wait()).toBe(3)
	end)

	it("combines with other streams", function()
		local first = Atom.new("ada")
		local last = Atom.new("lovelace")
		local seen: { string } = {}
		Stream.combine(first, last, function(a, b)
			return `{a} {b}`
		end):listen(function(name)
			table.insert(seen, name)
		end)
		last:set("byron")
		expect(seen).toEqual({ "ada lovelace", "ada byron" })
	end)

	it("emits once per batch", function()
		local atom = Atom.new(0)
		local seen: { number } = {}
		atom:listen(function(value)
			table.insert(seen, value)
		end)
		Atom.batch({ atom }, function()
			atom:set(1)
			atom:set(2)
		end)
		expect(seen).toEqual({ 0, 2 })
	end)

	it("stops every listener on destroy, streams made from it included", function()
		local atom = Atom.new(0)
		local seen: { any } = {}
		local connection = atom:listen(function(value)
			table.insert(seen, value)
		end)
		atom:map(function(value)
			return value * 10
		end):listen(function(value)
			table.insert(seen, value)
		end)

		atom:destroy()
		atom:set(1)
		expect(seen).toEqual({ 0, 0 })
		expect(connection.connected).toBe(false)
		expect(atom:peek()).toBe(1)
	end)
end)

return nil

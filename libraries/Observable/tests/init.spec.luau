--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Observable = require("../src")
local Stream = require("../../Stream/src")

-- subscribes to `observable`, recording "+value" when a brio comes and
-- "-value" when it dies
local function journal(observable: any): ({ string }, any)
	local events: { string } = {}
	local connection = observable:subscribe(function(brio)
		local void, value = brio:to_void_and_value()
		local name = if typeof(value) == "Instance" then value.Name else tostring(value)
		table.insert(events, `+{name}`)
		void:add(function()
			table.insert(events, `-{name}`)
		end)
	end)
	return events, connection
end

describe("Observable", function()
	it("gives a brio per value, killed by the next value and on disconnect", function()
		local state = Stream.state("a")
		local events, connection = journal(Observable.new(state))
		state:set("b")
		connection:disconnect()
		state:set("c")
		expect(events).toEqual({ "+a", "-a", "+b", "-b" })
		expect(connection.connected).toBe(false)
	end)

	it("gives a brio per item of a life stream, killed when it leaves", function()
		local folder = roblox.new("Folder")
		local a = roblox.new("Part")
		a.Name = "a"
		a.Parent = folder

		local events, connection = journal(Observable.new(Stream.children(folder)))
		local b = roblox.new("Part")
		b.Name = "b"
		b.Parent = folder
		a.Parent = nil
		connection:disconnect()
		expect(events).toEqual({ "+a", "+b", "-a", "-b" })
	end)

	it("doesn't make a void for a brio nobody asks one of", function()
		local brios = {}
		Observable.new(Stream.of(1)):subscribe(function(brio)
			table.insert(brios, brio)
		end)
		expect((brios[1] :: any)._void).toBeNil()
		expect(brios[1]:is_dead()).toBe(false)
	end)

	it("errors on anything other than a stream", function()
		expect(function()
			Observable.new(5 :: any)
		end).toThrow("needs a Stream or a LifeStream")
	end)

	it("makes observables from a value or a signal", function()
		local events, connection = journal(Observable.from_value("only"))
		connection:disconnect()
		expect(events).toEqual({ "+only", "-only" })

		local signal = roblox.signal()
		local fired = journal(Observable.from_signal(signal :: any, function(a, b)
			return a + b
		end))
		signal.fire(1, 2)
		signal.fire(3, 4)
		expect(fired).toEqual({ "+3", "-3", "+7" })
	end)

	it("tells observables apart", function()
		expect(Observable.is(Observable.from_value(1))).toBe(true)
		expect(Observable.is(Stream.of(1))).toBe(false)
	end)

	it("filters values, still killing the brio of the value before", function()
		local state = Stream.state(1)
		local events = journal(Observable.new(state):filter(function(value)
			return value ~= 2
		end))
		state:set(2)
		state:set(3)
		expect(events).toEqual({ "+1", "-1", "+3" })
	end)

	it("filters items", function()
		local folder = roblox.new("Folder")
		local events = journal(Observable.new(Stream.children(folder)):filter(function(child)
			return child:IsA("BasePart")
		end))
		local part = roblox.new("Part")
		part.Name = "part"
		part.Parent = folder
		local other = roblox.new("Folder")
		other.Name = "other"
		other.Parent = folder
		expect(events).toEqual({ "+part" })
	end)

	it("maps values, after a filter too", function()
		local state = Stream.state(1)
		local events = journal(Observable.new(state)
			:filter(function(value)
				return value > 0
			end)
			:map(function(value)
				return value * 10
			end))
		state:set(-1)
		state:set(2)
		expect(events).toEqual({ "+10", "-10", "+20" })
	end)

	it("keeps the brio alive while the value doesn't change", function()
		local state = Stream.state({ id = 1 })
		local brios = {}
		Observable.new(state)
			:changed(function(last, new)
				return last.id == new.id
			end)
			:subscribe(function(brio)
				table.insert(brios, brio)
			end)
		state:set({ id = 1 })
		expect(#brios).toBe(1)
		state:set({ id = 2 })
		expect(#brios).toBe(2)
		expect(brios[1]:is_dead()).toBe(true)
	end)

	it("only maps and dedupes observables of values", function()
		local players = Observable.new(Stream.players())
		expect(function()
			players:map(tostring)
		end).toThrow("map only works on an observable made from a Stream")
		expect(function()
			players:changed()
		end).toThrow("changed only works on an observable made from a Stream")
	end)

	it("chains custom operators with use", function()
		local events = journal(Observable.from_value(2):use(function(source)
			return source:map(function(value)
				return value * 2
			end)
		end))
		expect(events).toEqual({ "+4" })
	end)

	it("disconnects every subscription with destroy, and works afterwards", function()
		local subject = Stream.subject()
		local observable = Observable.new(subject)
		local events, connection = journal(observable)
		subject:fire("a")
		observable:destroy()
		subject:fire("b")
		expect(events).toEqual({ "+a", "-a" })
		expect(connection.connected).toBe(false)

		local later = journal(observable)
		subject:fire("c")
		expect(later).toEqual({ "+c" })
	end)
end)

return nil

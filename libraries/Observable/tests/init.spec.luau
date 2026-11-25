--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Observable = require("../src")
local Stream = require("../../Stream/src")

-- subscribes to `observable`, recording "+item" when a brio comes and
-- "-item" when it dies
local function journal(observable: any): ({ string }, any)
	local events: { string } = {}
	local connection = observable:subscribe(function(brio)
		local void, item = brio:to_void_and_value()
		local name = if typeof(item) == "Instance" then item.Name else tostring(item)
		table.insert(events, `+{name}`)
		void:add(function()
			table.insert(events, `-{name}`)
		end)
	end)
	return events, connection
end

-- an observable of a set you change with `add` and `remove`, like a folder's
-- children
local function set()
	local items: { [any]: true } = {}
	local emitters: { [(any, boolean) -> ()]: true } = {}
	local observable = Observable.new(function(emit, void)
		emitters[emit] = true
		void:add(function()
			emitters[emit] = nil
		end)
		for item in items do
			emit(item, true)
		end
	end)
	local function change(item: any, alive: boolean)
		items[item] = if alive then true else nil
		for emit in table.clone(emitters) do
			emit(item, alive)
		end
	end
	return observable, function(item: any)
		change(item, true)
	end, function(item: any)
		change(item, false)
	end
end

describe("Observable", function()
	it("gives a brio per item, killed when it leaves and on disconnect", function()
		local observable, add, remove = set()
		add("a")
		local events, connection = journal(observable)
		add("b")
		remove("a")
		connection:disconnect()
		add("c")
		expect(events).toEqual({ "+a", "+b", "-a", "-b" })
		expect(connection.connected).toBe(false)
	end)

	it("ignores an item added twice, removed when absent, or nil", function()
		local events = journal(Observable.new(function(emit)
			emit("a", true)
			emit("a", true)
			emit("b", false)
			emit(nil, true)
			emit("a", false)
			emit("a", false)
		end))
		expect(events).toEqual({ "+a", "-a" })
	end)

	it("doesn't make a void for a brio nobody asks one of", function()
		local brios = {}
		Observable.from_value(1):subscribe(function(brio)
			table.insert(brios, brio)
		end)
		expect((brios[1] :: any)._void).toBeNil()
		expect(brios[1]:is_dead()).toBe(false)
	end)

	it("gives the latest value of a stream, nil giving nothing", function()
		local state = Stream.state("a" :: string?)
		local events, connection = journal(Observable.from_stream(state))
		state:set("b")
		state:set(nil)
		state:set("c")
		connection:disconnect()
		expect(events).toEqual({ "+a", "-a", "+b", "-b", "+c", "-c" })

		expect(function()
			Observable.from_stream(5 :: any)
		end).toThrow("needs a Stream")
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

	it("listens to items joining and leaving", function()
		local observable, add, remove = set()
		local log: { string } = {}
		local connection = observable:listen(function(item, alive)
			table.insert(log, `{item}:{alive}`)
		end)
		add("a")
		remove("a")
		connection:disconnect()
		add("b")
		expect(log).toEqual({ "a:true", "a:false" })
	end)

	it("filters items when they join", function()
		local observable, add, remove = set()
		local events = journal(observable:filter(function(item)
			return item ~= "skipped"
		end))
		add("kept")
		add("skipped")
		remove("skipped")
		remove("kept")
		expect(events).toEqual({ "+kept", "-kept" })
	end)

	it("still replaces the value before when a stream's value is filtered out", function()
		local state = Stream.state(1)
		local events = journal(Observable.from_stream(state):filter(function(value)
			return value ~= 2
		end))
		state:set(2)
		state:set(3)
		expect(events).toEqual({ "+1", "-1", "+3" })
	end)

	it("maps items, sharing what several map to", function()
		local observable, add, remove = set()
		local events = journal(observable:map(function(item: string)
			return string.sub(item, 1, 1)
		end))
		add("apple")
		add("avocado")
		add("banana")
		remove("apple")
		expect(events).toEqual({ "+a", "+b" })
		remove("avocado")
		expect(events).toEqual({ "+a", "+b", "-a" })
	end)

	it("follows an observable per item with flat_map", function()
		local outer, add, remove = set()
		local inners = { x = Stream.state("x1"), y = Stream.state("y1") }
		local events = journal(outer:flat_map(function(item)
			return Observable.from_stream(inners[item])
		end))
		add("x")
		add("y")
		inners.x:set("x2")
		remove("y")
		inners.y:set("y2")
		expect(events).toEqual({ "+x1", "+y1", "-x1", "+x2", "-y1" })
	end)

	it("counts the items", function()
		local observable, add, remove = set()
		local counts: { number } = {}
		observable:count():listen(function(count)
			table.insert(counts, count)
		end)
		add("a")
		add("b")
		remove("a")
		expect(counts).toEqual({ 0, 1, 2, 1 })
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
		local observable, add = set()
		local events, connection = journal(observable)
		local listened = observable:listen(function() end)
		add("a")
		observable:destroy()
		add("b")
		expect(events).toEqual({ "+a", "-a" })
		expect(connection.connected).toBe(false)
		expect(listened.connected).toBe(false)

		local later = journal(observable)
		table.sort(later)
		expect(later).toEqual({ "+a", "+b" })
	end)
end)

return nil

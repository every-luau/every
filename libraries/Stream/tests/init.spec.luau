--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Stream = require("../src")

-- a listener that keeps every value it gets in `values` at the index of the
-- call, so nil values leave holes, and how many calls in `count`
local function recorder()
	local record = { values = {} :: { any }, count = 0 }
	function record.listener(value: any)
		record.count += 1
		record.values[record.count] = value
	end
	return record
end

-- a stream the test drives by hand: `fire` emits to every listener. given a
-- value, it holds it too: listening emits the current one, and `set` emits a
-- new one when it is not `==` to the current one
local function manual(...: any): any
	local holds = select("#", ...) > 0
	local current = ...
	local listeners: { [{ (any) -> () }]: true } = {}

	local stream: any = Stream.new(function(emit, void)
		local subscription = { emit }
		listeners[subscription] = true
		void:add(function()
			listeners[subscription] = nil
		end)
		if holds then
			emit(current)
		end
	end)

	function stream.fire(_, value: any)
		for subscription in table.clone(listeners) do
			if listeners[subscription] then
				subscription[1](value)
			end
		end
	end
	function stream.set(this: any, value: any)
		if value ~= current then
			current = value
			this:fire(value)
		end
	end

	return stream
end

describe("making and listening to streams", function()
	it("runs the producer per listener and cleans it on disconnect", function()
		local log = {}
		local stream = Stream.new(function(emit, void)
			table.insert(log, "start")
			emit(1)
			void:add(function()
				table.insert(log, "stop")
			end)
		end)

		local record = recorder()
		local connection = stream:listen(record.listener)
		stream:listen(function() end)
		connection:disconnect()
		expect(record.values).toEqual({ 1 })
		expect(log).toEqual({ "start", "start", "stop" })
		expect(connection.connected).toBe(false)
	end)

	it("cleans whatever the producer adds to its void", function()
		local signal = roblox.signal()
		local part = roblox.new("Part")
		local called = false
		local connection = Stream.new(function(_emit, void)
			void:add(signal:Connect(function() end))
			void:add(part)
			void:add({ destroy = function()
				called = true
			end })
		end):listen(function() end)
		connection:disconnect()
		expect(signal.count()).toBe(0)
		expect(part.destroyed).toBe(true)
		expect(called).toBe(true)
	end)

	it("emits nothing after being disconnected", function()
		local subject = manual()
		local record = recorder()
		local connection = subject:listen(record.listener)
		subject:fire(1)
		connection:disconnect()
		subject:fire(2)
		expect(record.values).toEqual({ 1 })
	end)

	it("tells streams apart", function()
		expect(Stream.is(Stream.of(1))).toBe(true)
		expect(Stream.is(manual(1))).toBe(true)
		expect(Stream.is(function() end)).toBe(false)
	end)

	it("emits values in order, nil included, or never", function()
		local record = recorder()
		Stream.of(1, nil, 3):listen(record.listener)
		expect(record.count).toBe(3)
		expect(record.values[3]).toBe(3)

		local never = recorder()
		Stream.never():listen(never.listener)
		expect(never.count).toBe(0)
	end)

	it("calls each with a void cleaned at the next value", function()
		local state = manual(1)
		local log = {}
		local connection = state:each(function(value, void)
			table.insert(log, `+{value}`)
			void:add(function()
				table.insert(log, `-{value}`)
			end)
		end, function(value)
			return value ~= 2
		end)
		state:set(2)
		state:set(3)
		connection:disconnect()
		expect(log).toEqual({ "+1", "-1", "+3", "-3" })
	end)

	it("waits for the next value, or returns the current one", function()
		expect(manual("now"):wait()).toBe("now")

		local subject = manual()
		local result: any = nil
		task.spawn(function()
			result = subject:wait()
		end)
		expect(result).toBeNil()
		subject:fire("later")
		expect(result).toBe("later")
		subject:fire("ignored")
		expect(result).toBe("later")
	end)

	it("disconnects every listener of a stream with destroy", function()
		local subject = manual()
		local listened, eached = recorder(), recorder()
		local doubled = subject:map(function(n)
			return n * 2
		end)
		local listening = doubled:listen(listened.listener)
		local each = doubled:each(eached.listener)
		subject:fire(1)
		doubled:destroy()
		subject:fire(2)
		expect(listened.values).toEqual({ 2 })
		expect(eached.values).toEqual({ 2 })
		expect(listening.connected).toBe(false)
		expect(each.connected).toBe(false)

		-- it still works afterwards
		doubled:listen(listened.listener)
		subject:fire(3)
		expect(listened.values).toEqual({ 2, 6 })
	end)

	it("chains custom operators with use", function()
		local record = recorder()
		Stream.of(2)
			:use(function(stream)
				return stream:map(function(n)
					return n * 10
				end)
			end)
			:listen(record.listener)
		expect(record.values).toEqual({ 20 })
	end)
end)

describe("operators", function()
	it("maps, filters and taps", function()
		local tapped = {}
		local record = recorder()
		Stream.of(1, 2, 3, 4)
			:filter(function(n)
				return n % 2 == 0
			end)
			:map(function(n)
				return n * 10
			end)
			:tap(function(n)
				table.insert(tapped, n)
			end)
			:listen(record.listener)
		expect(record.values).toEqual({ 20, 40 })
		expect(tapped).toEqual({ 20, 40 })
	end)

	it("skips unchanged values, with equals too", function()
		local record = recorder()
		Stream.of(1, 1, 2, 2, 1):changed():listen(record.listener)
		expect(record.values).toEqual({ 1, 2, 1 })

		local by_id = recorder()
		Stream.of({ id = 1 }, { id = 1 }, { id = 2 })
			:changed(function(last, new)
				return last.id == new.id
			end)
			:listen(by_id.listener)
		expect(by_id.count).toBe(2)
	end)

	it("switches to the latest inner stream", function()
		local outer = manual("a")
		local inners = { a = manual(), b = manual() }
		local record = recorder()
		local connection = outer
			:switch(function(key)
				return if key == "none" then nil else inners[key]
			end)
			:listen(record.listener)
		inners.a:fire(1)
		outer:set("b")
		inners.a:fire(2)
		inners.b:fire(3)
		outer:set("none")
		inners.b:fire(4)
		connection:disconnect()
		expect(record.values).toEqual({ 1, 3 })
	end)

	it("replaces or skips nil", function()
		local replaced = recorder()
		Stream.of(nil, "a"):default("none"):listen(replaced.listener)
		expect(replaced.values).toEqual({ "none", "a" })

		local skipped = recorder()
		Stream.of(nil, "a", nil):skip_nil():listen(skipped.listener)
		expect(skipped.values).toEqual({ "a" })
	end)

	it("takes and skips", function()
		local taken = recorder()
		Stream.of("a", "b", "c"):take(2):listen(taken.listener)
		expect(taken.values).toEqual({ "a", "b" })

		local subject = manual()
		local once = recorder()
		subject:take(1):listen(once.listener)
		subject:fire(1)
		subject:fire(2)
		expect(once.values).toEqual({ 1 })

		local skipped = recorder()
		Stream.of("a", "b", "c"):skip(2):listen(skipped.listener)
		expect(skipped.values).toEqual({ "c" })
	end)

	it("takes and skips while a predicate holds", function()
		local function small(n: number)
			return n < 3
		end
		local taken = recorder()
		Stream.of(1, 2, 3, 1):take_while(small):listen(taken.listener)
		expect(taken.values).toEqual({ 1, 2 })

		local skipped = recorder()
		Stream.of(1, 2, 3, 1):skip_while(small):listen(skipped.listener)
		expect(skipped.values).toEqual({ 3, 1 })
	end)

	it("scans, starts with and ends with", function()
		local sums = recorder()
		Stream.of(1, 2, 3)
			:scan(function(sum, n)
				return sum + n
			end, 0)
			:listen(sums.listener)
		expect(sums.values).toEqual({ 1, 3, 6 })

		local started = recorder()
		Stream.of("middle"):start_with("start"):listen(started.listener)
		expect(started.values).toEqual({ "start", "middle" })

		-- what end_with emits reaches the operators after it, not a listener
		-- that already left
		local reset = recorder()
		manual(true)
			:end_with(false)
			:tap(reset.listener)
			:listen(function() end)
			:disconnect()
		expect(reset.values).toEqual({ true, false })
	end)

	it("combines values with the latest of another stream", function()
		local other = manual()
		local main = manual()
		local record = recorder()
		main:with(other, function(value, latest)
			return `{value}:{latest}`
		end):listen(record.listener)
		main:fire("dropped")
		other:fire(1)
		other:fire(2)
		main:fire("kept")
		expect(record.values).toEqual({ "kept:2" })
	end)

	it("buffers by count and flushes the rest when the subscription ends", function()
		local subject = manual()
		local record = recorder()
		local connection = subject:buffer(2):tap(record.listener):listen(function() end)
		subject:fire(1)
		subject:fire(2)
		subject:fire(3)
		connection:disconnect()
		expect(record.values).toEqual({ { 1, 2 }, { 3 } })
	end)

	it("warns and keeps going when a listener after catch errors", function()
		local subject = manual()
		local count = 0
		subject:catch("risky"):listen(function()
			count += 1
			error("boom")
		end)
		subject:fire()
		subject:fire()
		expect(count).toBe(2)
		expect(roblox.warnings[#roblox.warnings]).toMatch("risky")
	end)
end)

describe("time", function()
	it("subscribes after a delay, and never once disconnected before", function()
		local record = recorder()
		Stream.of("late"):after(1):listen(record.listener)
		roblox.advance(0.5)
		expect(record.count).toBe(0)
		roblox.advance(0.5)
		expect(record.values).toEqual({ "late" })

		local never = recorder()
		Stream.of("late"):after(1):listen(never.listener):disconnect()
		roblox.advance(2)
		expect(never.count).toBe(0)
	end)

	it("cleans the delayed stream's own subscription", function()
		local subject = manual()
		local seen = recorder()
		local connection = subject:after(1):tap(seen.listener):listen(function() end)
		roblox.advance(1)
		subject:fire("a")
		connection:disconnect()
		subject:fire("b")
		expect(seen.values).toEqual({ "a" })
	end)

	it("debounces to the last value once quiet", function()
		local subject = manual()
		local record = recorder()
		subject:debounce(1):listen(record.listener)
		subject:fire("a")
		roblox.advance(0.5)
		subject:fire("b")
		roblox.advance(0.5)
		expect(record.count).toBe(0)
		roblox.advance(0.5)
		expect(record.values).toEqual({ "b" })
	end)

	it("throttles to the first value of each window", function()
		local subject = manual()
		local record = recorder()
		subject:throttle(1):listen(record.listener)
		subject:fire("a")
		subject:fire("b")
		roblox.advance(1)
		subject:fire("c")
		expect(record.values).toEqual({ "a", "c" })
	end)

	it("buffers by time from the first value of a batch", function()
		local subject = manual()
		local record = recorder()
		subject:buffer_time(1):listen(record.listener)
		subject:fire(1)
		roblox.advance(0.5)
		subject:fire(2)
		roblox.advance(0.5)
		subject:fire(3)
		roblox.advance(1)
		expect(record.values).toEqual({ { 1, 2 }, { 3 } })
		expect(roblox.pending()).toBe(0)
	end)
end)

describe("sources", function()
	it("follows signals, with a transform or not", function()
		local signal = roblox.signal()
		local first, both = recorder(), recorder()
		Stream.signal(signal :: any):listen(first.listener)
		Stream.signal(signal :: any, function(a, b)
			return a + b
		end):listen(both.listener)
		signal.fire(1, 2)
		expect(first.values).toEqual({ 1 })
		expect(both.values).toEqual({ 3 })
	end)

	it("follows a property, and errors on one that doesn't exist", function()
		local camera = roblox.new("Camera")
		local record = recorder()
		local connection = Stream.property(camera, "FieldOfView"):listen(record.listener)
		camera.FieldOfView = 90
		connection:disconnect()
		camera.FieldOfView = 30
		expect(record.values).toEqual({ 70, 90 })

		expect(function()
			Stream.property(camera, "Nope")
		end).toThrow("has no property 'Nope'")
	end)

	it("follows attributes", function()
		local part = roblox.new("Part")
		local record = recorder()
		Stream.attribute(part, "Health"):listen(record.listener)
		part:SetAttribute("Health", 10)
		expect(record.count).toBe(2)
		expect(record.values[2]).toBe(10)
	end)

	it("turns anything into a stream", function()
		local value = roblox.new("IntValue")
		local record = recorder()
		Stream.from(value):listen(record.listener)
		Stream.from("plain"):listen(record.listener)
		local state = manual("state")
		expect(Stream.from(state)).toBe(state)
		value.Value = 5
		expect(record.values).toEqual({ 0, "plain", 5 })
	end)

	it("merges and races", function()
		local a, b = manual(), manual()
		local merged, first = recorder(), recorder()
		Stream.merge(a, b):listen(merged.listener)
		Stream.race(a, b):listen(first.listener)
		b:fire("b")
		a:fire("a")
		expect(merged.values).toEqual({ "b", "a" })
		expect(first.values).toEqual({ "b" })
	end)

	it("combines the latest values once all emitted, nil included", function()
		local a, b = manual(1), manual(nil :: number?)
		local record = recorder()
		Stream.combine(a, b, "c", function(x, y, z)
			return `{x}:{y}:{z}`
		end):listen(record.listener)
		b:set(2)
		a:set(3)
		expect(record.values).toEqual({ "1:nil:c", "1:2:c", "3:2:c" })

		local waiting = manual()
		local count = 0
		Stream.combine(waiting, a, function()
			count += 1
		end):listen(function() end)
		expect(count).toBe(0)
		waiting:fire(true)
		expect(count).toBe(1)
	end)

	it("combines a table of streams under the same keys", function()
		local health = manual(100)
		local record = recorder()
		Stream.combine_table({ name = Stream.of("bob"), health = health }):listen(record.listener)
		health:set(50)
		expect(record.values).toEqual({ { name = "bob", health = 100 }, { name = "bob", health = 50 } })
		expect(record.values[1] ~= record.values[2]).toBe(true)
	end)
end)

describe("instances", function()
	it("follows a property of whichever instance comes last", function()
		local holder = roblox.new("ObjectValue")
		local first, second = roblox.new("Camera"), roblox.new("Camera")
		second.FieldOfView = 50
		local record = recorder()
		Stream.property(holder, "Value"):property("FieldOfView"):listen(record.listener)
		holder.Value = first
		holder.Value = second
		first.FieldOfView = 10
		holder.Value = nil
		expect(record.count).toBe(4)
		expect(record.values[1]).toBeNil()
		expect(record.values[2]).toBe(70)
		expect(record.values[3]).toBe(50)
		expect(record.values[4]).toBeNil()
	end)

	it("follows a player's character", function()
		local player = roblox.join("character owner")
		local record = recorder()
		Stream.character(player):listen(record.listener)
		local model = roblox.new("Model")
		player.Character = model
		player.CharacterAdded.fire(model)
		player.CharacterRemoving.fire(model)
		expect(record.count).toBe(3)
		expect(record.values[1]).toBeNil()
		expect(record.values[2]).toBe(model)
		expect(record.values[3]).toBeNil()
		roblox.leave(player)
	end)

	it("emits the first child with a name, nil when there is none", function()
		local folder = roblox.new("Folder")
		local record = recorder()
		local connection = Stream.child(folder, "Hitbox"):listen(record.listener)

		local first = roblox.new("Part")
		first.Name = "Hitbox"
		first.Parent = folder
		local second = roblox.new("Part")
		second.Name = "Hitbox"
		second.Parent = folder
		first.Parent = nil
		second.Name = "Other"
		connection:disconnect()
		second.Name = "Hitbox"

		expect(record.count).toBe(4)
		expect(record.values[1]).toBeNil()
		expect(record.values[2]).toBe(first)
		expect(record.values[3]).toBe(second)
		expect(record.values[4]).toBeNil()
	end)

	it("errors when the first child isn't of the class asked", function()
		local folder = roblox.new("Folder")
		local wrong = roblox.new("Folder")
		wrong.Name = "Hitbox"
		wrong.Parent = folder
		expect(function()
			Stream.child(folder, "Hitbox", "BasePart"):listen(function() end)
		end).toThrow("should be a BasePart")
	end)

	it("emits the first descendant with a name, skipping one that leaves", function()
		local root = roblox.new("Folder")
		local inner = roblox.new("Folder")
		inner.Parent = root
		local deep = roblox.new("Part")
		deep.Name = "Target"
		deep.Parent = inner

		local record = recorder()
		Stream.descendant(root, "Target"):listen(record.listener)
		inner.Parent = nil
		expect(record.count).toBe(2)
		expect(record.values[1]).toBe(deep)
		expect(record.values[2]).toBeNil()
	end)

	it("follows an attribute and a descendant of whichever instance comes last", function()
		local holder = roblox.new("ObjectValue")
		local model = roblox.new("Model")
		model:SetAttribute("Team", "red")
		local inner = roblox.new("Folder")
		inner.Parent = model
		local target = roblox.new("Part")
		target.Name = "Target"
		target.Parent = inner

		local teams, targets = recorder(), recorder()
		Stream.property(holder, "Value"):attribute("Team"):listen(teams.listener)
		Stream.property(holder, "Value"):descendant("Target", "BasePart"):listen(targets.listener)
		holder.Value = model
		model:SetAttribute("Team", "blue")
		holder.Value = nil

		expect(teams.count).toBe(4)
		expect(teams.values[2]).toBe("red")
		expect(teams.values[3]).toBe("blue")
		expect(teams.values[4]).toBeNil()
		expect(targets.count).toBe(3)
		expect(targets.values[2]).toBe(target)
		expect(targets.values[3]).toBeNil()
	end)

	it("chains child and property through instances that come and go", function()
		local holder = roblox.new("ObjectValue")
		local model = roblox.new("Model")
		local humanoid = roblox.new("Humanoid")
		humanoid.Parent = model

		local record = recorder()
		Stream.property(holder, "Value"):child("Humanoid"):property("Health"):listen(record.listener)
		holder.Value = model
		humanoid.Health = 50
		humanoid.Parent = nil
		holder.Value = nil
		expect(record.count).toBe(5)
		expect(record.values[2]).toBe(100)
		expect(record.values[3]).toBe(50)
		expect(record.values[4]).toBeNil()
	end)
end)

return nil

--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Signal = require("../src")

-- a stand-in for an RBXScriptSignal, with a count of its live connections
local function rbx_signal(): (any, (...any) -> (), () -> number)
	local listeners: { [(...any) -> ()]: true } = {}

	local signal = {
		Connect = function(_, listener: (...any) -> ())
			listeners[listener] = true
			return {
				Disconnect = function()
					listeners[listener] = nil
				end,
			}
		end,
	}

	local function fire(...: any)
		for listener in table.clone(listeners) do
			listener(...)
		end
	end

	local function count(): number
		local total = 0
		for _ in listeners do
			total += 1
		end
		return total
	end

	return signal, fire, count
end

describe("Signal", function()
	it("calls handlers with the fired values", function()
		local signal = Signal.new()
		local received: { any } = {}
		signal:connect(function(a: number, b: string)
			received = { a, b }
		end)

		signal:fire(1, "two")

		expect(received).toEqual({ 1, "two" })
	end)

	it("calls handlers in the order they were connected", function()
		local signal = Signal.new()
		local order: { number } = {}
		for index = 1, 3 do
			signal:connect(function()
				table.insert(order, index)
			end)
		end

		signal:fire()

		expect(order).toEqual({ 1, 2, 3 })
	end)

	it("stops calling a handler once disconnected", function()
		local signal = Signal.new()
		local calls = 0
		local connection = signal:connect(function()
			calls += 1
		end)

		signal:fire()
		connection:disconnect()
		signal:fire()

		expect(calls).toBe(1)
		expect(connection.connected).toBe(false)
	end)

	it("keeps the other handlers when one is disconnected", function()
		local signal = Signal.new()
		local order: { number } = {}
		local connections = {}
		for index = 1, 3 do
			connections[index] = signal:connect(function()
				table.insert(order, index)
			end)
		end

		connections[2]:disconnect()
		signal:fire()

		expect(order).toEqual({ 1, 3 })
	end)

	it("calls a once handler a single time", function()
		local signal = Signal.new()
		local calls = 0
		local connection = signal:once(function()
			calls += 1
		end)

		signal:fire()
		signal:fire()

		expect(calls).toBe(1)
		expect(connection.connected).toBe(false)
	end)

	it("runs a handler connected while firing on the next fire only", function()
		local signal = Signal.new()
		local calls = 0
		signal:once(function()
			signal:connect(function()
				calls += 1
			end)
		end)

		signal:fire()
		expect(calls).toBe(0)

		signal:fire()
		expect(calls).toBe(1)
	end)

	it("skips a handler disconnected while firing", function()
		local signal = Signal.new()
		local later: Signal.Connection
		local calls = 0
		signal:connect(function()
			later:disconnect()
		end)
		later = signal:connect(function()
			calls += 1
		end)

		signal:fire()

		expect(calls).toBe(0)
	end)

	it("skips handlers connected while firing even when the last one is disconnected", function()
		local signal = Signal.new()
		local last: Signal.Connection
		local calls = 0
		signal:connect(function()
			last:disconnect()
			signal:connect(function()
				calls += 1
			end)
		end)
		last = signal:connect(function() end)

		signal:fire()

		expect(calls).toBe(0)
	end)

	it("keeps calling handlers after one yields", function()
		local signal = Signal.new()
		local reached = false
		signal:connect(function()
			coroutine.yield()
		end)
		signal:connect(function()
			reached = true
		end)

		signal:fire()

		expect(reached).toBe(true)
	end)

	it("lists the connections in the order they were connected", function()
		local signal = Signal.new()
		local first = signal:connect(function() end)
		local second = signal:connect(function() end)
		local third = signal:connect(function() end)
		second:disconnect()

		local connections = signal:get_connections()

		expect(#connections).toBe(2)
		expect(connections[1]).toBe(first)
		expect(connections[2]).toBe(third)
	end)

	it("defers fire_deferred to the next resumption point", function()
		local signal = Signal.new()
		local received: number?
		signal:connect(function(value: number)
			received = value
		end)

		signal:fire_deferred(5)
		expect(received).toBe(nil)

		roblox.flush()
		expect(received).toBe(5)
	end)

	it("returns the fired values from wait", function()
		local signal = Signal.new()
		local received: { any } = {}
		task.spawn(function()
			received = { signal:wait() }
		end)

		signal:fire(1, "two")

		expect(received).toEqual({ 1, "two" })
		expect(#signal:get_connections()).toBe(0)
	end)

	it("disconnects every handler with disconnect_all and stays usable", function()
		local signal = Signal.new()
		local calls = 0
		local connection = signal:connect(function()
			calls += 1
		end)

		signal:disconnect_all()
		signal:fire()
		expect(calls).toBe(0)
		expect(connection.connected).toBe(false)

		signal:connect(function()
			calls += 1
		end)
		signal:fire()
		expect(calls).toBe(1)
	end)

	it("follows an RBXScriptSignal until destroyed", function()
		local source, fire, count = rbx_signal()
		local signal = Signal.wrap(source)
		local received: { any } = {}
		signal:connect(function(...)
			received = { ... }
		end)

		fire(1, "two")
		expect(received).toEqual({ 1, "two" })

		signal:destroy()
		expect(count()).toBe(0)
		expect(#signal:get_connections()).toBe(0)
	end)

	it("tells signals apart", function()
		expect(Signal.is(Signal.new())).toBe(true)
		expect(Signal.is({})).toBe(false)
	end)
end)

return nil

--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

require("./roblox")
local Observable = require("../src")

-- an observable and a function emitting to every current subscription, with a
-- count of the subscriptions still running
local function subject(): (any, (any) -> (), () -> number)
	local emitters: { [(any) -> ()]: true } = {}
	local observable = Observable.new(function(emit)
		emitters[emit] = true
		return function()
			emitters[emit] = nil
		end
	end)

	local function emit(value: any)
		for emitter in table.clone(emitters) do
			emitter(value)
		end
	end

	local function running(): number
		local count = 0
		for _ in emitters do
			count += 1
		end
		return count
	end

	return observable, emit, running
end

local function collect(observable: any): ({ any }, any)
	local values: { any } = {}
	local connection = observable:subscribe(function(value)
		table.insert(values, value)
	end)
	return values, connection
end

describe("Observable", function()
	it("does nothing until subscribed", function()
		local runs = 0
		local observable = Observable.new(function()
			runs += 1
			return nil
		end)

		expect(runs).toBe(0)
		observable:subscribe(print)
		observable:subscribe(print)
		expect(runs).toBe(2)
	end)

	it("forwards every emitted value", function()
		local observable, emit = subject()
		local values = collect(observable)
		emit(1)
		emit(2)
		expect(values).toEqual({ 1, 2 })
	end)

	it("stops and cleans up once disconnected", function()
		local observable, emit, running = subject()
		local values, connection = collect(observable)

		emit(1)
		connection:disconnect()
		emit(2)

		expect(values).toEqual({ 1 })
		expect(running()).toBe(0)
	end)

	it("drops values emitted after disconnecting even without a cleanup", function()
		local saved_emit: any = nil
		local observable = Observable.new(function(emit)
			saved_emit = emit
			return nil
		end)

		local values, connection = collect(observable)
		connection:disconnect()
		saved_emit(1)
		expect(#values).toBe(0)
	end)

	it("emits a constant with from_value", function()
		expect((collect(Observable.from_value("hi")))).toEqual({ "hi" })
	end)

	it("wraps objects with a connect method with from_signal", function()
		local listeners: { (...any) -> () } = {}
		local signal = {
			connect = function(_, listener: (...any) -> ())
				table.insert(listeners, listener)
				return {
					disconnect = function()
						table.remove(listeners, table.find(listeners, listener))
					end,
				}
			end,
		}

		local values, connection = collect(Observable.from_signal(signal))
		local sums = collect(Observable.from_signal(signal, function(a, b)
			return a + b
		end))

		for _, listener in table.clone(listeners) do
			listener(2, 3)
		end

		expect(values).toEqual({ 2 })
		expect(sums).toEqual({ 5 })

		connection:disconnect()
		expect(#listeners).toBe(1)
	end)

	it("maps, filters and skips duplicates", function()
		local observable, emit = subject()
		local values = collect(observable
			:map(function(value)
				return value * 10
			end)
			:filter(function(value)
				return value > 10
			end)
			:changed())

		for _, value in { 1, 2, 2, 3, 1, 3 } do
			emit(value)
		end

		expect(values).toEqual({ 20, 30 })
	end)

	it("disconnects derived subscriptions upstream", function()
		local observable, emit, running = subject()
		local _, connection = collect(observable:map(tostring))

		expect(running()).toBe(1)
		connection:disconnect()
		expect(running()).toBe(0)
		emit(1)
	end)

	it("applies custom operators with use", function()
		local observable = Observable.from_value(3)
		local result = observable:use(function(source)
			return source:map(function(value)
				return value + 1
			end)
		end)

		expect((collect(result))).toEqual({ 4 })
	end)

	it("disconnects every subscription when destroyed", function()
		local observable, emit, running = subject()
		local first = collect(observable)
		local second = collect(observable)

		observable:destroy()
		emit(1)

		expect(#first + #second).toBe(0)
		expect(running()).toBe(0)
	end)

	it("cleans up when the subscription ends while the producer runs", function()
		local cleaned = 0
		local observable = Observable.new(function(emit)
			emit(1)
			emit(2)
			return function()
				cleaned += 1
			end
		end)

		local values: { any } = {}
		local connection: any
		connection = observable:subscribe(function(value)
			table.insert(values, value)
			if connection then
				connection:disconnect()
			end
		end)
		connection:disconnect()

		expect(values).toEqual({ 1, 2 })
		expect(cleaned).toBe(1)

		local first: { any } = {}
		local own: any
		own = Observable.new(function(emit)
			own:destroy()
			emit(1)
			return function()
				cleaned += 1
			end
		end)
		own:subscribe(function(value)
			table.insert(first, value)
		end)

		expect(#first).toBe(0)
		expect(cleaned).toBe(2)
	end)

	it("compares with a custom equals in changed", function()
		local observable, emit = subject()
		local values = collect(observable:changed(function(a, b)
			return math.floor(a) == math.floor(b)
		end))

		for _, value in { 1, 1.5, 2, 2.9, 1 } do
			emit(value)
		end

		expect(values).toEqual({ 1, 2, 1 })
	end)

	it("rejects values that can't be connected to", function()
		expect(function()
			Observable.from_signal(5 :: any)
		end).toThrow()
		expect(function()
			Observable.from_signal({} :: any)
		end).toThrow()
	end)

	it("tells observables apart", function()
		expect(Observable.is(Observable.from_value(1))).toBe(true)
		expect(Observable.is({})).toBe(false)
	end)
end)

return nil

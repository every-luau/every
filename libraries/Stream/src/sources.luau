-- The functions that make a stream out of something else.

const Void = require(script.Parent.Parent.Void)

const core = require("./core")
const stream_types = require("./types")

type Void = Void.Void
type Stream<T> = stream_types.Stream<T>
type State<T> = stream_types.State<T>
type Subject<T> = stream_types.Subject<T>
type SignalLike = stream_types.SignalLike

const new = core.new
const run = core.run
const until_finished = core.until_finished

-- a value a stream can't emit, for "nothing yet"
const UNSET = table.freeze({})

--[=[
	@within Stream
	@function of
	@param ... T
	@return Stream<T>

	a stream that emits each value in order when subscribed, nil included

	```lua
	Stream.of(1, 2, 3):listen(print) --> 1, 2, 3
	```
]=]
const function of<T>(...: T): Stream<T>
	const values = table.pack(...)
	return new(function(emit: (T) -> ())
		for index = 1, values.n do
			emit(values[index])
		end
	end)
end

--[=[
	@within Stream
	@function never
	@return Stream<T>

	a stream that never emits
]=]
const function never<T>(): Stream<T>
	return new(function(_emit: (T) -> ()) end)
end

const function connect_signal(signal: any, listener: (...any) -> ()): any
	if typeof(signal) == "RBXScriptSignal" then
		return signal:Connect(listener)
	end
	const method: any = signal.Connect or signal.connect
	return method(signal, listener)
end

--[=[
	@within Stream
	@function signal
	@param signal SignalLike
	@param transform ((...any) -> T)?
	@return Stream<T>

	emits the first value of every fire of `signal`, or `transform(...)` with
	every fired value when `transform` is given

	```lua
	local touched_by = Stream.signal(part.Touched, function(hit)
		return hit.Parent
	end)
	```
]=]
const function signal<T>(signal: SignalLike, transform: ((...any) -> T)?): Stream<T>
	const source: any = signal
	assert(
		typeof(source) == "RBXScriptSignal" or (type(source) == "table" and ((source :: any).Connect or (source :: any).connect) ~= nil),
		`[Stream.signal] needs a signal, got a {typeof(source)}`
	)

	const convert = transform
	return new(function(emit: (T) -> (), void: Void)
		void:add(connect_signal(
			source,
			if convert
				then function(...)
					emit((convert :: (...any) -> T)(...))
				end
				else function(first)
					emit(first)
				end
		))
	end)
end

--[=[
	@within Stream
	@function property
	@param instance Instance
	@param name string
	@return Stream<any>
	@error "... has no property '...'" -- `name` is not a property of `instance`

	emits the property `name` of `instance` when subscribed and every time it
	changes

	```lua
	Stream.property(workspace.CurrentCamera, "FieldOfView"):listen(print)
	```
]=]
const function property(instance: Instance, name: string): Stream<any>
	const ok, changed = pcall(instance.GetPropertyChangedSignal, instance, name)
	if not ok then
		error(`[Stream.property] {instance.ClassName} has no property '{name}'`, 2)
	end

	const target = instance :: any
	return new(function(emit: (any) -> (), void: Void)
		emit(target[name])
		void:add((changed :: RBXScriptSignal):Connect(function()
			emit(target[name])
		end))
	end)
end

--[=[
	@within Stream
	@function attribute
	@param instance Instance
	@param name string
	@return Stream<any>

	emits the attribute `name` of `instance` when subscribed and every time it
	changes, nil while it isn't set
]=]
const function attribute(instance: Instance, name: string): Stream<any>
	return new(function(emit: (any) -> (), void: Void)
		emit(instance:GetAttribute(name))
		void:add(instance:GetAttributeChangedSignal(name):Connect(function()
			emit(instance:GetAttribute(name))
		end))
	end)
end

--[=[
	@within Stream
	@function from
	@param source Stream<T> | ValueBase | SignalLike | T
	@return Stream<T>

	turns `source` into a stream: a stream as is, the `Value` of a ValueBase, the
	fires of a signal, and anything else emitted once
]=]
const function from(source: any): Stream<any>
	if core.is(source) then
		return source
	elseif typeof(source) == "Instance" and (source :: Instance):IsA("ValueBase") then
		return property(source, "Value")
	elseif
		typeof(source) == "RBXScriptSignal"
		or (type(source) == "table" and getmetatable(source) ~= nil and (source.Connect or source.connect) ~= nil)
	then
		return signal(source)
	end
	return of(source)
end

--[=[
	@within Stream
	@function merge
	@param ... Stream<T>
	@return Stream<T>

	emits whatever any of the streams emits, as they emit it

	```lua
	local pressed = Stream.merge(Stream.signal(button.Activated), Stream.signal(key_pressed))
	```
]=]
const function merge<T>(...: Stream<T>): Stream<T>
	const streams = { ... }
	return new(function(emit: (T) -> (), void: Void)
		for _, stream in streams do
			run(stream, emit, void)
		end
	end)
end

--[=[
	@within Stream
	@function race
	@param ... Stream<T>
	@return Stream<T>

	emits the first value any of the streams emits, then stops listening to all
	of them

	```lua
	local answer = Stream.race(Stream.signal(yes.Activated), Stream.of("timeout"):after(5))
	```
]=]
const function race<T>(...: Stream<T>): Stream<T>
	const merged = merge(...)
	return new(function(emit: (T) -> (), void: Void)
		void:add(until_finished(merged, function(finish, value: T)
			finish()
			emit(value)
		end))
	end)
end

--[=[
	@within Stream
	@function combine
	@param ... any -- streams, then the function combining their values
	@return Stream<any>

	emits the last argument called with the latest value of every other one,
	each time one of them emits once all have. nil values count. each argument
	goes through [Stream.from], so a plain value is a constant

	the result isn't typed, so annotate it

	```lua
	local label: Stream<string> = Stream.combine(first_name, last_name, function(first, last)
		return `{first} {last}`
	end)
	```
]=]
const function combine(...: any): Stream<any>
	const count = select("#", ...) - 1
	const combiner: (...any) -> any = select(count + 1, ...)
	assert(type(combiner) == "function", `[Stream.combine] needs a function last, got a {typeof(combiner)}`)

	const streams: { Stream<any> } = {}
	for index = 1, count do
		streams[index] = from((select(index, ...)))
	end

	return new(function(emit: (any) -> (), void: Void)
		if count == 0 then
			emit(combiner())
			return
		end

		const values = table.create(count, UNSET)
		local pending = count
		for index, stream in streams do
			run(stream, function(value: any)
				if values[index] == UNSET then
					pending -= 1
				end
				values[index] = value
				if pending == 0 then
					emit(combiner(table.unpack(values, 1, count)))
				end
			end, void)
		end
	end)
end

--[=[
	@within Stream
	@function combine_table
	@param streams { [K]: Stream<any> }
	@param borrow boolean? -- emit the same table every time instead of a copy
	@return Stream<{ [K]: any }>

	emits a table with the latest value of every stream in `streams`, under the
	same keys, each time one of them emits once all have. each emission is a new
	table, unless `borrow` is true: then the listener must read it right away
	and not keep it

	```lua
	Stream.combine_table({
		color = Stream.property(part, "Color"),
		health = Stream.attribute(part, "Health"),
	}):listen(function(values)
		print(values.color, values.health)
	end)
	```
]=]
const function combine_table<K>(streams: { [K]: Stream<any> }, borrow: boolean?): Stream<{ [K]: any }>
	return new(function(emit: ({ [K]: any }) -> (), void: Void)
		const values: { [K]: any } = {}
		local pending = 0
		for key in streams do
			values[key] = UNSET
			pending += 1
		end

		for key, stream in streams do
			run(stream, function(value: any)
				if values[key] == UNSET then
					pending -= 1
				end
				values[key] = value
				if pending == 0 then
					emit(if borrow then values else table.clone(values))
				end
			end, void)
		end
	end)
end

-- the listeners of a state or subject, one entry per subscription so the same
-- function subscribed twice is called twice and unsubscribed separately
type Listeners<T> = { [{ (T) -> () }]: true }

const function listen_to<T>(listeners: Listeners<T>, listener: (T) -> (), void: Void)
	const subscription = { listener }
	listeners[subscription] = true
	void:add(function()
		listeners[subscription] = nil
	end)
end

const function broadcast<T>(listeners: Listeners<T>, value: T)
	-- listeners added while broadcasting wait for the next one, and removed ones
	-- are skipped
	for subscription in table.clone(listeners) do
		if listeners[subscription] then
			subscription[1](value)
		end
	end
end

--[=[
	@within Stream
	@function state
	@param initial T
	@return State<T>

	creates a stream holding a value. subscribing emits it right away, and
	`state:set(new)` emits the new one when it is not `==` to the current one.
	`state:get()` reads it, and `state:update(transform)` sets it to
	`transform(current)`. `state:destroy()` stops every listener, streams made
	from it included

	```lua
	local count = Stream.state(0)
	count:listen(print) --> 0
	count:update(function(n)
		return n + 1
	end) --> 1
	```
]=]
const function state<T>(initial: T): State<T>
	local current = initial
	const listeners: Listeners<T> = {}

	const self: any = new(function(emit: (T) -> (), void: Void)
		listen_to(listeners, emit, void)
		emit(current)
	end)

	function self.get(_): T
		return current
	end
	function self.set(_, value: T)
		if value ~= current then
			current = value
			broadcast(listeners, value)
		end
	end
	function self.update(this: any, transform: (T) -> T)
		this:set(transform(current))
	end
	function self.destroy(this: any)
		-- streams made from it stop getting values too
		table.clear(listeners)
		this._connections:clean()
	end

	return self
end

--[=[
	@within Stream
	@function subject
	@return Subject<T>

	creates a stream you fire from outside with `subject:fire(value)`, which
	every current listener gets. listeners only get what is fired after they
	subscribe, use [Stream.state] to get the current value too.
	`subject:destroy()` stops every listener, streams made from it included

	```lua
	local clicked = Stream.subject()
	clicked:listen(print)
	clicked:fire("hello") --> hello
	```
]=]
const function subject<T>(): Subject<T>
	const listeners: Listeners<T> = {}

	const self: any = new(function(emit: (T) -> (), void: Void)
		listen_to(listeners, emit, void)
	end)

	function self.fire(_, value: T)
		broadcast(listeners, value)
	end
	function self.destroy(this: any)
		-- streams made from it stop getting values too
		table.clear(listeners)
		this._connections:clean()
	end

	return self
end

return {
	of = of,
	never = never,
	signal = signal,
	property = property,
	attribute = attribute,
	from = from,
	merge = merge,
	race = race,
	combine = combine,
	combine_table = combine_table,
	state = state,
	subject = subject,
}

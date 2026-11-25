-- The Stream class, its constructor and the methods that subscribe. The other
-- modules add their methods to `methods`.
--
-- Each subscription runs the producer with its own Void, and ending the
-- subscription cleans it. Operators subscribe with `subscribe`, which hands
-- back that Void without a Connection.

const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

const stream_types = require("./types")

type Stream<T> = stream_types.Stream<T>
type Connection = Connection.Connection
type Void = Void.Void

-- the producer of a Stream, called once per subscription
export type Producer<T> = (emit: (T) -> (), void: Void) -> ()

const methods: any = {}
methods.__index = methods

--[=[
	@within Stream
	@function new
	@param producer (emit: (T) -> (), void: Void) -> ()
	@return Stream<T>

	creates a stream that calls `producer` each time something listens. add to
	the [Void] whatever `producer` starts, so it is cleaned once that listener
	is gone

	```lua
	local heartbeat = Stream.new(function(emit, void)
		void:add(RunService.Heartbeat:Connect(emit))
	end)
	```
]=]
const function new<T>(producer: Producer<T>): Stream<T>
	return setmetatable({ _producer = producer, _connections = Void.new() }, methods) :: any
end

--[=[
	@within Stream
	@function is
	@param value any
	@return boolean

	returns whether `value` is a stream, [Stream.state] and [Stream.subject]
	included
]=]
const function is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == methods
end

-- runs the producer of `stream` for `listener`, with `void` holding what it
-- starts, and returns `void`
const function run(stream: any, listener: (...any) -> (), void: Void): Void
	stream._producer(listener, void)
	return void
end

-- subscribes `listener` to a stream without a Connection, for
-- operators. cleaning the Void it returns ends the subscription
const function subscribe(stream: any, listener: (...any) -> ()): Void
	return run(stream, listener, Void.new())
end

-- subscribes to `stream` with `on_value`, which gets a `finish` function that
-- ends the subscription. `finish` works even while `stream` is still being
-- subscribed to, and nothing is passed on once it was called
const function until_finished(stream: any, on_value: (finish: () -> (), ...any) -> ()): Void
	local finished = false
	const void = Void.new()

	const function finish()
		finished = true
		void:clean()
	end

	run(stream, function(...: any)
		if not finished then
			on_value(finish, ...)
		end
	end, void)

	-- `finish` was called while the producer still added things
	if finished then
		void:clean()
	end

	return void
end

-- subscribes to `stream`, and gives `on_value` a Void for each value, cleaned
-- when the next one comes or the subscription ends. for operators, without
-- threads
const function tidy(stream: any, on_value: (value: any, value_void: Void) -> ()): Void
	const value_void = Void.new()
	const source = subscribe(stream, function(value: any)
		value_void:clean()
		on_value(value, value_void)
	end)

	const void = Void.new()
	void:add(function()
		source:clean()
		value_void:clean()
	end)
	return void
end

-- subscribes `listener` and returns a Void that ends the subscription, after
-- which nothing is passed on
const function open(stream: any, listener: (...any) -> ()): Void
	local active = true
	const source = subscribe(stream, function(...: any)
		if active then
			listener(...)
		end
	end)

	const void = Void.new()
	void:add(function()
		active = false
		source:clean()
	end)
	return void
end

-- a Connection that cleans `void`, kept by `stream` until it is disconnected
-- so [Stream:destroy] can disconnect it
const function track(stream: any, void: Void): Connection
	const connections: Void = stream._connections
	local connection: Connection
	connection = Connection.new(function()
		connections:remove(connection)
		void:clean()
	end)
	connections:add(connection)
	return connection
end

--[=[
	@within Stream
	@method listen
	@param listener (value: T) -> ()
	@return Connection

	subscribes `listener`, which is called with every value from now on, until
	the [Connection] is disconnected

	```lua
	local connection = Stream.property(workspace.CurrentCamera, "FieldOfView"):listen(print)
	connection:disconnect()
	```
]=]
function methods.listen<T>(self: Stream<T>, listener: (value: T) -> ()): Connection
	return track(self, open(self, listener))
end

--[=[
	@within Stream
	@method each
	@param callback (value: T, void: Void) -> ()
	@param predicate ((value: T) -> boolean)?
	@return Connection

	calls `callback` with every value `predicate` accepts, with a [Void] cleaned
	when the next value comes, accepted or not, or the [Connection] is
	disconnected. `callback` runs on its own thread with [Thread], so it can
	yield

	```lua
	Stream.property(humanoid, "Sit"):each(function(sitting, void)
		if sitting then
			void:add(show_seat_menu())
		end
	end)
	```
]=]
function methods.each<T>(self: Stream<T>, callback: (value: T, void: Void) -> (), predicate: ((value: T) -> boolean)?): Connection
	const value_void = Void.new()
	const source = open(self, function(value: T)
		value_void:clean()
		if predicate and not predicate(value) then
			return
		end
		Thread(callback, value, value_void)
	end)

	const void = Void.new()
	void:add(function()
		source:clean()
		value_void:clean()
	end)
	return track(self, void)
end

--[=[
	@within Stream
	@method wait
	@yields
	@return T

	yields until the stream emits, and returns that value. a stream that emits
	when subscribed, like [Stream.property], returns right away

	```lua
	local character = Stream.property(player, "Character"):skip_nil():wait()
	```
]=]
function methods.wait<T>(self: Stream<T>): T
	const thread = coroutine.running()
	local received = false
	local yielded = false
	local result: T

	until_finished(self, function(finish, value: T)
		finish()
		received = true
		result = value
		if yielded then
			task.spawn(thread, value)
		end
	end)

	if received then
		return result
	end
	yielded = true
	return coroutine.yield()
end

--[=[
	@within Stream
	@method use
	@param operator (stream: Stream<T>) -> U
	@return U

	returns `operator(self)`, so your own operators chain like the built-in ones

	```lua
	local function doubled(stream)
		return stream:map(function(value)
			return value * 2
		end)
	end

	score:use(doubled):listen(print)
	```
]=]
function methods.use<T>(self: Stream<T>, operator: (stream: Stream<T>) -> any): any
	return operator(self)
end

--[=[
	@within Stream
	@method destroy

	disconnects every [Connection] that [Stream:listen] and [Stream:each] gave
	for this stream. it still works afterwards, and streams made from it keep
	their own listeners
]=]
function methods.destroy<T>(self: Stream<T>)
	(self :: any)._connections:clean()
end

return {
	methods = methods,
	new = new,
	is = is,
	run = run,
	subscribe = subscribe,
	until_finished = until_finished,
	tidy = tidy,
}

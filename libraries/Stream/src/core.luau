-- The two classes, Stream and LifeStream, their constructors and the methods
-- that subscribe. The other modules add their methods to `methods` and
-- `life_methods`.
--
-- Each subscription runs the producer with its own Void, and ending the
-- subscription cleans it. Operators subscribe with `subscribe`, which hands
-- back that Void without a Connection.

const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

const stream_types = require("./types")

type Stream<T> = stream_types.Stream<T>
type LifeStream<T> = stream_types.LifeStream<T>
type Connection = Connection.Connection
type Void = Void.Void

-- the producer of a Stream, called once per subscription
export type Producer<T> = (emit: (T) -> (), void: Void) -> ()
-- the producer of a LifeStream
export type LifeProducer<T> = (emit: (T, boolean) -> (), void: Void) -> ()

const methods: any = {}
methods.__index = methods

const life_methods: any = {}
life_methods.__index = life_methods

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
	@function life
	@param producer (emit: (item: T, alive: boolean) -> (), void: Void) -> ()
	@return LifeStream<T>

	creates a [LifeStream]. `producer` emits `(item, true)` when an item joins
	the set and `(item, false)` when it leaves, and adds to the [Void] whatever
	it starts

	```lua
	local friends = Stream.life(function(emit, void)
		for _, friend in get_friends() do
			emit(friend, true)
		end
		void:add(friend_added:Connect(function(friend)
			emit(friend, true)
		end))
		void:add(friend_removed:Connect(function(friend)
			emit(friend, false)
		end))
	end)
	```
]=]
const function new_life<T>(producer: LifeProducer<T>): LifeStream<T>
	return setmetatable({ _producer = producer, _connections = Void.new() }, life_methods) :: any
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

--[=[
	@within Stream
	@function is_life
	@param value any
	@return boolean

	returns whether `value` is a [LifeStream]
]=]
const function is_life(value: any): boolean
	return type(value) == "table" and getmetatable(value) == life_methods
end

-- runs the producer of `stream` for `listener`, with `void` holding what it
-- starts, and returns `void`
const function run(stream: any, listener: (...any) -> (), void: Void): Void
	stream._producer(listener, void)
	return void
end

-- subscribes `listener` to a stream or life stream without a Connection, for
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

-- subscribes to the life stream `stream`, and gives `on_item` a Void for each
-- item, cleaned when it leaves or the subscription ends
const function tidy_each(stream: any, on_item: (item: any, item_void: Void) -> ()): Void
	const voids: { [any]: Void } = {}
	const source = subscribe(stream, function(item: any, alive: boolean)
		const previous = voids[item]
		if previous then
			voids[item] = nil
			previous:clean()
		end
		if alive then
			const item_void = Void.new()
			voids[item] = item_void
			on_item(item, item_void)
		end
	end)

	const void = Void.new()
	void:add(function()
		-- cleaning an item can make the stream emit, so each one is taken out first
		local item, item_void = next(voids)
		while item ~= nil do
			voids[item] = nil
			item_void:clean()
			item, item_void = next(voids)
		end
		source:clean()
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

--[=[
	@class LifeStream

	a LifeStream follows a set of things that come and go, like the players in
	the game or the parts with a tag. it emits `(item, true)` when an item joins
	and `(item, false)` when it leaves, and [LifeStream:each] runs something for
	each item while it is there. make one with [Stream.players],
	[Stream.children], [Stream.tagged] or [Stream.life]

	```lua
	Stream.tagged("Lava"):each(function(part, void)
		void:add(part.Touched:Connect(kill))
	end)
	```
]=]

--[=[
	@within LifeStream
	@method listen
	@param listener (item: T, alive: boolean) -> ()
	@return Connection

	subscribes `listener`, called with `(item, true)` for every item there now
	and joining later, and `(item, false)` when one leaves. disconnecting emits
	nothing, use [LifeStream:each] to undo things per item
]=]
function life_methods.listen<T>(self: LifeStream<T>, listener: (item: T, alive: boolean) -> ()): Connection
	return track(self, open(self, listener))
end

--[=[
	@within LifeStream
	@method each
	@param callback (item: T, void: Void) -> ()
	@param predicate ((item: T) -> boolean)?
	@return Connection

	calls `callback` once for every item that `predicate` accepts, there now or
	joining later, with a [Void] cleaned when the item leaves or the [Connection]
	is disconnected. `callback` runs on its own thread with [Thread], so it can
	yield

	```lua
	Stream.players():each(function(player, void)
		local leaderstats = void:add(Instance.new("Folder"))
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end)
	```
]=]
function life_methods.each<T>(
	self: LifeStream<T>,
	callback: (item: T, void: Void) -> (),
	predicate: ((item: T) -> boolean)?
): Connection
	const voids: { [T]: Void } = {}
	const source = open(self, function(item: T, alive: boolean)
		if alive then
			if voids[item] or (predicate and not predicate(item)) then
				return
			end
			const item_void = Void.new()
			voids[item] = item_void
			Thread(callback, item, item_void)
		else
			const item_void = voids[item]
			if item_void then
				voids[item] = nil
				item_void:clean()
			end
		end
	end)

	const void = Void.new()
	void:add(function()
		source:clean()
		for item, item_void in voids do
			voids[item] = nil
			item_void:clean()
		end
	end)
	return track(self, void)
end

--[=[
	@within LifeStream
	@method use
	@param operator (stream: LifeStream<T>) -> U
	@return U

	returns `operator(self)`, so your own operators chain like the built-in ones
]=]
function life_methods.use<T>(self: LifeStream<T>, operator: (stream: LifeStream<T>) -> any): any
	return operator(self)
end

--[=[
	@within LifeStream
	@method destroy

	disconnects every [Connection] that [LifeStream:listen] and
	[LifeStream:each] gave for this life stream. it still works afterwards
]=]
function life_methods.destroy<T>(self: LifeStream<T>)
	(self :: any)._connections:clean()
end

return {
	methods = methods,
	life_methods = life_methods,
	new = new,
	new_life = new_life,
	is = is,
	is_life = is_life,
	run = run,
	subscribe = subscribe,
	until_finished = until_finished,
	tidy = tidy,
	tidy_each = tidy_each,
}

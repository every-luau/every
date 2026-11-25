--!optimize 2

--[=[
	@class Observable

	Observable hands out a [Brio] for every value or item of a [Stream], alive while it lasts

	wrap a stream with [Observable.new] and subscribe. the callback gets a
	[Brio] for each value of a stream, killed when the next value comes, or for
	each item of a [LifeStream], killed when the item leaves. everything added
	to [Brio:to_void] goes away with it

	```lua
	local Observable = require(path.to.Observable)
	local Stream = require(path.to.Stream)

	local lava = Observable.new(Stream.tagged("Lava"))

	local connection = lava:subscribe(function(brio)
		local void, part = brio:to_void_and_value()
		void:add(part.Touched:Connect(kill))
	end)

	connection:disconnect()
	```

	:::info
	an observable is cold like its stream: nothing runs until something
	subscribes, and each subscription runs the stream again
	:::
]=]

const Brio = require(script.Parent.Brio)
const Connection = require(script.Parent.Connection)
const Stream = require(script.Parent.Stream)
const Thread = require(script.Parent.Thread)
const Void = require(script.Parent.Void)

export type Brio<T> = Brio.Brio<T>
export type Connection = Connection.Connection
export type Void = Void.Void
type Stream<T> = Stream.Stream<T>
type LifeStream<T> = Stream.LifeStream<T>

--[=[
	@within Observable
	@type Operator (source: Observable<T>) -> Observable<U>

	a function that makes an observable from another one, see [Observable:use]
]=]
export type Operator<T, U> = (source: Observable<T>) -> Observable<U>

export type Observable<T> = {
	subscribe: (self: Observable<T>, callback: (brio: Brio<T>) -> ()) -> Connection,
	filter: (self: Observable<T>, predicate: (value: T) -> boolean) -> Observable<T>,
	map: (self: Observable<T>, transform: (value: T) -> any) -> any,
	changed: (self: Observable<T>, equals: ((last: T, new: T) -> boolean)?) -> Observable<T>,
	use: (self: Observable<T>, operator: (source: Observable<T>) -> any) -> any,
	destroy: (self: Observable<T>) -> (),
}

--[=[
	@within Observable
	@type SignalLike Stream.SignalLike

	what [Observable.from_signal] can follow: an RBXScriptSignal, a [Signal], or
	a table whose `Connect` or `connect` method returns something to disconnect
]=]
export type SignalLike = Stream.SignalLike

-- what a filtered out value of a stream becomes, so the brio of the value
-- before it still dies
const SKIP = newproxy(false)

const Observable = {}
Observable.__index = Observable

-- `life` tells whether `stream` is a life stream, whose items each get a brio
const function wrap(stream: any, life: boolean): any
	return setmetatable({ _stream = stream, _life = life, _connections = Void.new() }, Observable)
end

--[=[
	@within Observable
	@function new
	@param stream Stream<T> | LifeStream<T>
	@return Observable<T>
	@error "[Observable] needs a Stream or a LifeStream, got a ..."

	creates an observable from `stream`. a [Stream] gives a brio per value, and
	a [LifeStream] a brio per item

	```lua
	local sitting = Observable.new(Stream.property(humanoid, "Sit"))
	local players = Observable.new(Stream.players())
	```
]=]
function Observable.new<T>(stream: Stream<T> | LifeStream<T>): Observable<T>
	if Stream.is(stream) then
		return wrap(stream, false)
	elseif Stream.is_life(stream) then
		return wrap(stream, true)
	end
	error(`[Observable] needs a Stream or a LifeStream, got a {typeof(stream)}`, 2)
end

--[=[
	@within Observable
	@function from_value
	@param value T
	@return Observable<T>

	creates an observable that gives every subscription one brio for `value`,
	alive until the subscription ends
]=]
function Observable.from_value<T>(value: T): Observable<T>
	return wrap(Stream.of(value), false)
end

--[=[
	@within Observable
	@function from_signal
	@param signal SignalLike
	@param transform ((...any) -> T)?
	@return Observable<T>

	creates an observable that gives a brio for every fire of `signal`, alive
	until the next one. each fire gives its first value, or `transform(...)`
	with every fired value when `transform` is given

	```lua
	local touches = Observable.from_signal(part.Touched, function(hit)
		return hit.Parent
	end)
	```
]=]
function Observable.from_signal<T>(signal: SignalLike, transform: ((...any) -> T)?): Observable<T>
	return wrap(Stream.signal(signal, transform), false)
end

--[=[
	@within Observable
	@function is
	@param value any
	@return boolean

	returns whether `value` is an observable
]=]
function Observable.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Observable
end

-- a Connection that ends with `stop`, kept by `observable` until it is
-- disconnected so [Observable:destroy] can disconnect it
const function track(observable: any, stop: () -> ()): Connection
	const connections: Void = observable._connections
	local connection: Connection
	connection = Connection.new(function()
		connections:remove(connection)
		stop()
	end)
	connections:add(connection)
	return connection
end

--[=[
	@within Observable
	@method subscribe
	@param callback (brio: Brio<T>) -> ()
	@return Connection

	calls `callback` with a [Brio] for every value or item, until the
	[Connection] is disconnected. the brio of a value dies when the next value
	comes, the brio of an item when the item leaves, and every brio dies on
	disconnect. `callback` runs on its own thread with [Thread], so it can
	yield, and [Brio:is_dead] tells if the brio died meanwhile

	```lua
	Observable.new(Stream.players()):subscribe(function(brio)
		local void, player = brio:to_void_and_value()
		local leaderstats = void:add(Instance.new("Folder"))
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end)
	```
]=]
function Observable.subscribe<T>(self: Observable<T>, callback: (brio: Brio<T>) -> ()): Connection
	const internal = self :: any

	if internal._life then
		const brios: { [any]: Brio<T> } = {}
		const listening = internal._stream:listen(function(item: T, alive: boolean)
			if alive then
				if brios[item] then
					return
				end
				const brio = Brio.new(item)
				brios[item] = brio
				Thread(callback, brio)
			else
				const brio = brios[item]
				if brio then
					brios[item] = nil
					brio:destroy()
				end
			end
		end)

		return track(self, function()
			listening:disconnect()
			for item, brio in brios do
				brios[item] = nil
				brio:destroy()
			end
		end)
	end

	local current: Brio<T>? = nil
	const listening = internal._stream:listen(function(value: any)
		if current then
			const last = current
			current = nil
			last:destroy()
		end
		if value == SKIP then
			return
		end
		const brio = Brio.new(value)
		current = brio
		Thread(callback, brio)
	end)

	return track(self, function()
		listening:disconnect()
		if current then
			const last = current
			current = nil
			last:destroy()
		end
	end)
end

--[=[
	@within Observable
	@method filter
	@param predicate (value: T) -> boolean
	@return Observable<T>

	returns an observable giving a brio only for what `predicate` accepts. a
	value that is rejected still kills the brio of the value before it

	```lua
	local low_health = Observable.new(Stream.property(humanoid, "Health")):filter(function(health)
		return health < 20
	end)
	```
]=]
function Observable.filter<T>(self: Observable<T>, predicate: (value: T) -> boolean): Observable<T>
	const internal = self :: any
	if internal._life then
		return wrap(internal._stream:filter(predicate), true)
	end
	return wrap(
		internal._stream:map(function(value: any)
			return if value == SKIP or not predicate(value) then SKIP else value
		end),
		false
	)
end

-- errors when `self` follows a life stream, for operators that only make
-- sense on values
const function expect_values(self: any, method: string)
	if self._life then
		error(`[Observable] {method} only works on an observable made from a Stream, not a LifeStream`, 3)
	end
end

--[=[
	@within Observable
	@method map
	@param transform (value: T) -> U
	@return Observable<U>
	@error "[Observable] map only works on an observable made from a Stream, not a LifeStream"

	returns an observable giving a brio for `transform(value)` instead of
	`value`
]=]
function Observable.map<T>(self: Observable<T>, transform: (value: T) -> any): any
	expect_values(self, "map")
	return wrap(
		(self :: any)._stream:map(function(value: any)
			return if value == SKIP then SKIP else transform(value)
		end),
		false
	)
end

--[=[
	@within Observable
	@method changed
	@param equals ((last: T, new: T) -> boolean)?
	@return Observable<T>
	@error "[Observable] changed only works on an observable made from a Stream, not a LifeStream"

	returns an observable that skips a value equal to the last one, compared
	with `==` or with `equals` when it is given, so its brio stays alive

	:::info
	the first value always gets a brio, and each subscription remembers its
	own last value
	:::
]=]
function Observable.changed<T>(self: Observable<T>, equals: ((last: T, new: T) -> boolean)?): Observable<T>
	expect_values(self, "changed")
	return wrap(
		(self :: any)._stream:changed(function(last: any, new: any): boolean
			if last ~= SKIP and new ~= SKIP and equals then
				return equals(last, new)
			end
			return last == new
		end),
		false
	)
end

--[=[
	@within Observable
	@method use
	@param operator Operator<T, U>
	@return Observable<U>

	returns `operator(self)`, so your own operators chain like `map` and `filter`

	```lua
	local function alive(source)
		return source:filter(function(humanoid)
			return humanoid.Health > 0
		end)
	end

	humanoids:use(alive):subscribe(print)
	```
]=]
function Observable.use<T>(self: Observable<T>, operator: (source: Observable<T>) -> any): any
	return operator(self)
end

--[=[
	@within Observable
	@method destroy

	disconnects every subscription to this observable, which kills their
	brios. you can still subscribe to it afterwards, and observables made from
	it keep working
]=]
function Observable.destroy<T>(self: Observable<T>)
	(self :: any)._connections:clean()
end

table.freeze(Observable)

return table.freeze({
	new = Observable.new,
	from_value = Observable.from_value,
	from_signal = Observable.from_signal,
	is = Observable.is,
})

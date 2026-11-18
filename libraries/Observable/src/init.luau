--!optimize 2

--[=[
	@class Observable

	a reactive stream of values: wrap anything that produces values, then
	`subscribe`, `map`, `filter` or `changed` it

	an observable is cold: nothing runs until something subscribes, and each
	subscription runs the producer again

	```lua
	local Observable = require(path.to.Observable)

	local health = Observable.from_signal(humanoid.HealthChanged)
	local danger = health:filter(function(value)
		return value < 20
	end)

	local connection = danger:subscribe(function(value)
		warn(`low health: {value}`)
	end)

	connection:disconnect()
	```
]=]

const Connection = require(script.Parent.Connection)
const Void = require(script.Parent.Void)

export type Connection = Connection.Connection

--[=[
	@within Observable
	@type Producer (emit: (T) -> ()) -> (() -> ())?

	calls `emit` once per value. it can return a function, called when the
	subscription that ran it ends
]=]
export type Producer<T> = (emit: (T) -> ()) -> (() -> ())?

--[=[
	@within Observable
	@type Operator (source: Observable<T>) -> Observable<U>

	a function creating an observable from another, see [Observable:use]
]=]
export type Operator<T, U> = (source: Observable<T>) -> Observable<U>

export type Observable<T> = setmetatable<{
	_producer: Producer<T>,
	_subscriptions: Void.Void,

	subscribe: (self: Observable<T>, listener: (T) -> ()) -> Connection,
	use: (self: Observable<T>, operator: (source: Observable<T>) -> any) -> any,
	map: (self: Observable<T>, transform: (T) -> any) -> any,
	filter: (self: Observable<T>, predicate: (T) -> boolean) -> Observable<T>,
	changed: (self: Observable<T>, equals: ((T, T) -> boolean)?) -> Observable<T>,
	destroy: (self: Observable<T>) -> (),
}, { __index: Observable<T> }>

--[=[
	@within Observable
	@type SignalLike RBXScriptSignal | { connect: (self, (...any) -> ()) -> any } | { Connect: (self, (...any) -> ()) -> any }

	anything [Observable.from_signal] can follow: an RBXScriptSignal, a Signal, or
	any table with a `connect` or `Connect` method returning something with a
	`disconnect` or `Disconnect` method
]=]
export type SignalLike = RBXScriptSignal | { connect: (any, (...any) -> ()) -> any } | { Connect: (any, (...any) -> ()) -> any }

const function connect(signal: any, listener: (...any) -> ()): any
	if typeof(signal) == "RBXScriptSignal" then
		return signal:Connect(listener)
	end

	const method: any = signal.connect or signal.Connect
	return method(signal, listener)
end

const function disconnect(connection: any)
	-- RBXScriptConnection only has `Disconnect`, and indexing a missing member of
	-- it throws, so it's checked first
	const method: any = if typeof(connection) == "RBXScriptConnection"
		then connection.Disconnect
		else connection.disconnect or connection.Disconnect
	method(connection)
end

const Observable = {}
Observable.__index = Observable

--[=[
	@within Observable
	@function new
	@param producer Producer<T>
	@return Observable<T>

	creates an observable that runs `producer` once per subscription

	```lua
	local ticks = Observable.new(function(emit)
		local connection = RunService.Heartbeat:Connect(emit)
		return function()
			connection:Disconnect()
		end
	end)
	```
]=]
function Observable.new<T>(producer: Producer<T>): Observable<T>
	return setmetatable(
		{
			_producer = producer,
			_subscriptions = Void.new(),
		},
		Observable
	) :: any
end

--[=[
	@within Observable
	@function from_value
	@param value T
	@return Observable<T>

	creates an observable that emits `value` once to every subscription
]=]
function Observable.from_value<T>(value: T): Observable<T>
	return Observable.new(function(emit: (T) -> ())
		emit(value)
		return nil
	end)
end

--[=[
	@within Observable
	@function from_signal
	@param signal SignalLike
	@param transform ((...any) -> T)?
	@return Observable<T>
	@error "Cannot observe value of type '...'" -- `signal` is not a [SignalLike]

	creates an observable that connects to `signal` for every subscription, and
	disconnects when the subscription ends

	each fire emits its first value, or what `transform` returns when called with
	every fired value

	```lua
	local health = Observable.from_signal(humanoid.HealthChanged)
	local touches = Observable.from_signal(part.Touched, function(hit)
		return hit.Parent
	end)
	```
]=]
function Observable.from_signal<T>(signal: SignalLike, transform: ((...any) -> T)?): Observable<T>
	const value: any = signal
	assert(
		typeof(value) == "RBXScriptSignal" or (type(value) == "table" and ((value :: any).connect or (value :: any).Connect) ~= nil),
		`Cannot observe value of type '{typeof(value)}'.`
	)

	return Observable.new(function(emit: (T) -> ())
		const connection = connect(
			value,
			if transform
				then function(...)
					emit((transform :: (...any) -> T)(...))
				end
				else function(first)
					emit(first)
				end
		)

		return function()
			disconnect(connection)
		end
	end)
end

--[=[
	@within Observable
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is an Observable
]=]
function Observable.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Observable
end

--[=[
	@within Observable
	@method subscribe
	@param listener (T) -> ()
	@return Connection

	runs the producer and calls `listener` with every value it emits, until the
	returned [Connection] is disconnected. disconnecting calls the producer's
	cleanup, and values emitted afterwards are dropped

	:::info
	`listener` is called on the thread that emitted, so values arrive in order
	and derived observables see them right away. a producer can emit while it
	runs, so `listener` may be called before `subscribe` returns
	:::
]=]
function Observable.subscribe<T>(self: Observable<T>, listener: (T) -> ()): Connection
	const subscriptions = self._subscriptions
	local cleanup: (() -> ())? = nil

	local connection: Connection
	connection = Connection.new(function()
		subscriptions:remove(connection :: any)

		if cleanup then
			cleanup()
		end
	end) :: any
	subscriptions:add(connection :: any)

	cleanup = self._producer(function(value: T)
		if connection.connected then
			listener(value)
		end
	end)

	-- the subscription can end while the producer runs, before its cleanup is known
	if cleanup and not connection.connected then
		cleanup()
	end

	return connection
end

-- an observable whose subscriptions each subscribe to `source`. `step` is called
-- once per subscription and returns the listener given to `source`, so it can
-- keep state for that subscription only
const function derive<T, U>(source: Observable<T>, step: (emit: (U) -> ()) -> (T) -> ()): Observable<U>
	return Observable.new(function(emit: (U) -> ())
		const connection = source:subscribe(step(emit))

		return function()
			connection:disconnect()
		end
	end)
end

--[=[
	@within Observable
	@method use
	@param operator Operator<T, U>
	@return Observable<U>

	returns `operator(self)`, so operators made outside the library chain like
	the built-in ones

	```lua
	local function doubled(source)
		return source:map(function(value)
			return value * 2
		end)
	end

	health:use(doubled):subscribe(print)
	```
]=]
function Observable.use<T>(self: Observable<T>, operator: (source: Observable<T>) -> any): any
	return operator(self)
end

--[=[
	@within Observable
	@method map
	@param transform (T) -> U
	@return Observable<U>

	returns an observable emitting `transform(value)` for every value
]=]
function Observable.map<T>(self: Observable<T>, transform: (T) -> any): any
	return derive(self, function(emit)
		return function(value: T)
			emit(transform(value))
		end
	end)
end

--[=[
	@within Observable
	@method filter
	@param predicate (T) -> boolean
	@return Observable<T>

	returns an observable emitting only the values `predicate` returns true for
]=]
function Observable.filter<T>(self: Observable<T>, predicate: (T) -> boolean): Observable<T>
	return derive(self, function(emit: (T) -> ())
		return function(value: T)
			if predicate(value) then
				emit(value)
			end
		end
	end)
end

--[=[
	@within Observable
	@method changed
	@param equals ((T, T) -> boolean)?
	@return Observable<T>

	returns an observable that skips values equal to the one it emitted last.
	values are compared with `==` unless `equals` is given

	:::info
	the first value is always emitted, and each subscription remembers its own
	last value
	:::
]=]
function Observable.changed<T>(self: Observable<T>, equals: ((T, T) -> boolean)?): Observable<T>
	return derive(self, function(emit: (T) -> ())
		local has_last = false
		local last: T

		return function(value: T)
			if has_last and (if equals then equals(last, value) else last == value) then
				return
			end

			has_last = true
			last = value
			emit(value)
		end
	end)
end

--[=[
	@within Observable
	@method destroy

	disconnects every subscription to this observable. it can still be
	subscribed to afterwards, and observables made from it keep working
]=]
function Observable.destroy<T>(self: Observable<T>): ()
	self._subscriptions:clean()
end

return table.freeze({
	new = Observable.new,
	from_value = Observable.from_value,
	from_signal = Observable.from_signal,
	is = Observable.is,
})

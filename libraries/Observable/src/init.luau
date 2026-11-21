--!optimize 2

--[=[
	@class Observable

	Observable is a reactive stream of values to subscribe to, map, filter and dedupe

	create one from a signal with [Observable.from_signal] or from any producer
	with [Observable.new], chain `map`, `filter` and `changed`, then subscribe.
	subscribing returns a [Connection]

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

	:::info
	an observable is cold: nothing runs until something subscribes, and each
	subscription runs the producer again
	:::
]=]

const Connection = require(script.Parent.Connection)
const Signal = require(script.Parent.Signal)
const Void = require(script.Parent.Void)

export type Connection = Connection.Connection

--[=[
	@within Observable
	@type Producer (emit: (T) -> ()) -> (() -> ())?

	calls `emit` once per value, and can return a function that runs when the
	subscription ends
]=]
export type Producer<T> = (emit: (T) -> ()) -> (() -> ())?

--[=[
	@within Observable
	@type Operator (source: Observable<T>) -> Observable<U>

	a function that makes an observable from another one, see [Observable:use]
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
	@type SignalLike RBXScriptSignal | Signal<...any> | { Connect: (self, (...any) -> ()) -> any }

	what [Observable.from_signal] can follow: an RBXScriptSignal, a [Signal], or
	a table whose `Connect` method returns something with a `Disconnect` method
]=]
export type SignalLike = RBXScriptSignal | Signal.Signal<...any> | { Connect: (any, (...any) -> ()) -> any }

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

	creates an observable that connects to `signal` for each subscription, and
	disconnects when the subscription ends

	each fire emits its first value, or `transform(...)` with every fired value
	when `transform` is given

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
	returned [Connection] is disconnected. disconnecting runs the producer's
	cleanup and drops any value emitted after it

	:::info
	`listener` runs on the thread that emitted, so values arrive in order. a
	producer can emit while it runs, so `listener` may be called before
	`subscribe` returns
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

	returns `operator(self)`, so your own operators chain like `map` and `filter`

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

	returns an observable that skips a value equal to the last one it emitted,
	compared with `==` or with `equals` when it is given

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

	disconnects every subscription to this observable. you can still subscribe
	to it afterwards, and observables made from it keep working
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

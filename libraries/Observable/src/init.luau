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

return {}

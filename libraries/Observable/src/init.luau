--!optimize 2

--[=[
	@class Observable

	Observable follows a set of things that come and go, and hands out a [Brio] for each while it is there

	an observable announces when an item joins and when it leaves, like the
	players in the game or the parts with a tag. [Observable:subscribe] gives a
	[Brio] for every item there now and joining later, killed when it leaves.
	everything added to [Brio:to_void] goes away with it

	```lua
	local Observable = require(path.to.Observable)

	local friends = Observable.new(function(emit, void)
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

	local connection = friends:subscribe(function(brio)
		local void, friend = brio:to_void_and_value()
		void:add(show_online_badge(friend))
	end)

	connection:disconnect()
	```

	[Observable.from_stream] turns a [Stream] into an observable whose only item
	is its latest value, so a value and a set are used the same way

	:::info
	an observable is cold: nothing runs until something subscribes, and each
	subscription runs the producer again
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

--[=[
	@within Observable
	@type Producer (emit: (item: T, alive: boolean) -> (), void: Void) -> ()

	emits `(item, true)` when an item joins and `(item, false)` when it
	leaves, and adds to the [Void] whatever it starts. emitting an item that
	is already there, or one that isn't, does nothing, and nil is never an item
]=]
export type Producer<T> = (emit: (item: T, alive: boolean) -> (), void: Void) -> ()

--[=[
	@within Observable
	@type Operator (source: Observable<T>) -> Observable<U>

	a function that makes an observable from another one, see [Observable:use]
]=]
export type Operator<T, U> = (source: Observable<T>) -> Observable<U>

export type Observable<T> = {
	subscribe: (self: Observable<T>, callback: (brio: Brio<T>) -> ()) -> Connection,
	listen: (self: Observable<T>, listener: (item: T, alive: boolean) -> ()) -> Connection,
	filter: (self: Observable<T>, predicate: (item: T) -> boolean) -> Observable<T>,
	map: (self: Observable<T>, transform: (item: T) -> any) -> any,
	flat_map: (self: Observable<T>, project: (item: T) -> any) -> any,
	count: (self: Observable<T>) -> Stream<number>,
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

const Observable = {}
Observable.__index = Observable

--[=[
	@within Observable
	@function new
	@param producer Producer<T>
	@return Observable<T>

	creates an observable that runs `producer` once per subscription. the
	items it emits are kept track of, so emitting one twice or removing one
	that isn't there is safe

	```lua
	local children = Observable.new(function(emit, void)
		void:add(folder.ChildAdded:Connect(function(child)
			emit(child, true)
		end))
		void:add(folder.ChildRemoved:Connect(function(child)
			emit(child, false)
		end))
		for _, child in folder:GetChildren() do
			emit(child, true)
		end
	end)
	```
]=]
function Observable.new<T>(producer: Producer<T>): Observable<T>
	return setmetatable({ _producer = producer, _connections = Void.new() }, Observable) :: any
end

-- runs the producer of `observable` for `listener`, which only hears about
-- each item joining once and leaving once, with `void` holding what it starts
const function run(observable: any, listener: (item: any, alive: boolean) -> (), void: Void)
	const items: { [any]: true } = {}
	observable._producer(function(item: any, alive: boolean)
		if item == nil then
			return
		elseif alive and not items[item] then
			items[item] = true
			listener(item, true)
		elseif not alive and items[item] then
			items[item] = nil
			listener(item, false)
		end
	end, void)
end

--[=[
	@within Observable
	@function from_stream
	@param stream Stream<T>
	@return Observable<T>

	creates an observable whose only item is the latest value of `stream`. a
	new value replaces it, and nil leaves nothing there, so a brio lives until
	the value changes

	```lua
	local sitting = Observable.from_stream(Stream.property(humanoid, "Sit"))
	```
]=]
function Observable.from_stream<T>(stream: Stream<T>): Observable<T>
	assert(Stream.is(stream), `[Observable.from_stream] needs a Stream, got a {typeof(stream)}`)
	return Observable.new(function(emit: (T, boolean) -> (), void: Void)
		-- the item there now, nil when there is none
		local current: any = nil
		void:add(stream:listen(function(value: any)
			if current ~= nil then
				const last = current
				current = nil
				emit(last, false)
			end
			if value ~= nil then
				current = value
				emit(value, true)
			end
		end))
	end)
end

--[=[
	@within Observable
	@function from_value
	@param value T
	@return Observable<T>

	creates an observable whose only item is `value`, there until the
	subscription ends
]=]
function Observable.from_value<T>(value: T): Observable<T>
	return Observable.new(function(emit: (T, boolean) -> ())
		emit(value, true)
	end)
end

--[=[
	@within Observable
	@function from_signal
	@param signal SignalLike
	@param transform ((...any) -> T)?
	@return Observable<T>

	creates an observable whose only item is the latest fire of `signal`,
	replaced by the next one. each fire gives its first value, or
	`transform(...)` with every fired value when `transform` is given

	```lua
	local touching = Observable.from_signal(part.Touched, function(hit)
		return hit.Parent
	end)
	```
]=]
function Observable.from_signal<T>(signal: SignalLike, transform: ((...any) -> T)?): Observable<T>
	return Observable.from_stream(Stream.signal(signal, transform))
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

-- runs `observable` for `listener` until the returned function is called,
-- after which nothing is passed on
const function open(observable: any, listener: (item: any, alive: boolean) -> ()): () -> ()
	local active = true
	const void = Void.new()
	run(observable, function(item: any, alive: boolean)
		if active then
			listener(item, alive)
		end
	end, void)
	return function()
		active = false
		void:clean()
	end
end

--[=[
	@within Observable
	@method subscribe
	@param callback (brio: Brio<T>) -> ()
	@return Connection

	calls `callback` with a [Brio] for every item there now and joining later,
	killed when the item leaves or the [Connection] is disconnected.
	`callback` runs on its own thread with [Thread], so it can yield, and
	[Brio:is_dead] tells if the item left meanwhile

	```lua
	players:subscribe(function(brio)
		local void, player = brio:to_void_and_value()
		local leaderstats = void:add(Instance.new("Folder"))
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end)
	```
]=]
function Observable.subscribe<T>(self: Observable<T>, callback: (brio: Brio<T>) -> ()): Connection
	const brios: { [any]: Brio<T> } = {}
	const stop = open(self, function(item: T, alive: boolean)
		if alive then
			const brio = Brio.new(item)
			brios[item] = brio
			Thread(callback, brio)
		else
			const brio = brios[item]
			brios[item] = nil
			brio:destroy()
		end
	end)

	return track(self, function()
		stop()
		for item, brio in brios do
			brios[item] = nil
			brio:destroy()
		end
	end)
end

--[=[
	@within Observable
	@method listen
	@param listener (item: T, alive: boolean) -> ()
	@return Connection

	calls `listener` with `(item, true)` for every item there now and joining
	later, and `(item, false)` when one leaves, until the [Connection] is
	disconnected. disconnecting calls nothing, use [Observable:subscribe] to
	undo things per item
]=]
function Observable.listen<T>(self: Observable<T>, listener: (item: T, alive: boolean) -> ()): Connection
	return track(self, open(self, listener))
end

--[=[
	@within Observable
	@method filter
	@param predicate (item: T) -> boolean
	@return Observable<T>

	keeps the items `predicate` accepts when they join. with
	[Observable.from_stream], a rejected value still replaces the one before

	```lua
	local parts = Observe.descendants(workspace):filter(function(instance)
		return instance:IsA("BasePart")
	end)
	```
]=]
function Observable.filter<T>(self: Observable<T>, predicate: (item: T) -> boolean): Observable<T>
	return Observable.new(function(emit: (T, boolean) -> (), void: Void)
		run(self, function(item: T, alive: boolean)
			if not alive or predicate(item) then
				emit(item, alive)
			end
		end, void)
	end)
end

--[=[
	@within Observable
	@method map
	@param transform (item: T) -> U
	@return Observable<U>

	gives `transform(item)` for every item instead. items mapped to the same
	value share it, which leaves once all of them left, and nil is left out
]=]
function Observable.map<T>(self: Observable<T>, transform: (item: T) -> any): any
	return Observable.new(function(emit: (any, boolean) -> (), void: Void)
		const mapped: { [any]: any } = {}
		const counts: { [any]: number } = {}
		run(self, function(item: T, alive: boolean)
			if alive then
				const value = transform(item)
				if value == nil then
					return
				end
				mapped[item] = value
				counts[value] = (counts[value] or 0) + 1
				if counts[value] == 1 then
					emit(value, true)
				end
			else
				const value = mapped[item]
				if value == nil then
					return
				end
				mapped[item] = nil
				counts[value] -= 1
				if counts[value] == 0 then
					counts[value] = nil
					emit(value, false)
				end
			end
		end, void)
	end)
end

--[=[
	@within Observable
	@method flat_map
	@param project (item: T) -> Observable<U>?
	@return Observable<U>

	gives the items of the observable `project` returns for each item, which
	leave when that item does. returning nil gives nothing for that item

	```lua
	-- the character of every player
	local characters = Observe.players():flat_map(Observe.character)
	```
]=]
function Observable.flat_map<T>(self: Observable<T>, project: (item: T) -> any): any
	return Observable.new(function(emit: (any, boolean) -> (), void: Void)
		-- what each item's observable gives, counted, since two items can give
		-- the same thing
		const counts: { [any]: number } = {}
		const stops: { [any]: () -> () } = {}

		const function inner_listener(owned: { [any]: true })
			return function(value: any, alive: boolean)
				if alive then
					owned[value] = true
					counts[value] = (counts[value] or 0) + 1
					if counts[value] == 1 then
						emit(value, true)
					end
				elseif owned[value] then
					owned[value] = nil
					counts[value] -= 1
					if counts[value] == 0 then
						counts[value] = nil
						emit(value, false)
					end
				end
			end
		end

		run(self, function(item: T, alive: boolean)
			if alive then
				const inner = project(item)
				if inner == nil then
					return
				end
				const owned: { [any]: true } = {}
				const listener = inner_listener(owned)
				const stop = open(inner, listener)
				stops[item] = function()
					stop()
					for value in table.clone(owned) do
						listener(value, false)
					end
				end
			else
				const stop = stops[item]
				if stop then
					stops[item] = nil
					stop()
				end
			end
		end, void)

		void:add(function()
			for item, stop in stops do
				stops[item] = nil
				stop()
			end
		end)
	end)
end

--[=[
	@within Observable
	@method count
	@return Stream<number>

	a [Stream] of how many items are there, emitted when subscribed and each
	time it changes

	```lua
	Observe.players():count():listen(function(count)
		print(`{count} players`)
	end)
	```
]=]
function Observable.count<T>(self: Observable<T>): Stream<number>
	return Stream.new(function(emit: (number) -> (), void: Void)
		local count = 0
		local ready = false
		run(self, function(_item: T, alive: boolean)
			count += if alive then 1 else -1
			if ready then
				emit(count)
			end
		end, void)
		ready = true
		emit(count)
	end)
end

--[=[
	@within Observable
	@method use
	@param operator Operator<T, U>
	@return Observable<U>

	returns `operator(self)`, so your own operators chain like `map` and `filter`

	```lua
	local function anchored(source)
		return source:filter(function(part)
			return part.Anchored
		end)
	end

	parts:use(anchored):subscribe(print)
	```
]=]
function Observable.use<T>(self: Observable<T>, operator: (source: Observable<T>) -> any): any
	return operator(self)
end

--[=[
	@within Observable
	@method destroy

	disconnects every [Connection] that [Observable:subscribe] and
	[Observable:listen] gave for this observable, which kills their brios. you
	can still subscribe to it afterwards, and observables made from it keep
	working
]=]
function Observable.destroy<T>(self: Observable<T>)
	(self :: any)._connections:clean()
end

table.freeze(Observable)

return table.freeze({
	new = Observable.new,
	from_stream = Observable.from_stream,
	from_value = Observable.from_value,
	from_signal = Observable.from_signal,
	is = Observable.is,
})

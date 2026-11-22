--!native
--!optimize 2

--[=[
	@class Signal

	Signal is a yield-safe signal whose handlers run on a recycled thread

	connect handlers, then fire values to all of them. each handler runs with
	[Thread], so one that yields doesn't hold up the others, and connecting
	returns a [Connection] that removes it

	```lua
	local Signal = require(path.to.Signal)

	local signal = Signal.new()
	local connection = signal:connect(function(message)
		print(message)
	end)

	signal:fire("hello") --> hello
	connection:disconnect()
	```

	:::info
	handlers are called in the order they were connected. a handler connected
	while the signal fires only runs on the next fire, and one disconnected while
	it fires is skipped. handlers are kept in a doubly linked list, so connecting
	and disconnecting never walk the list
	:::
]=]

const Connection = require(script.Parent.Connection)
const Thread = require(script.Parent.Thread)

export type Connection = Connection.Connection

type Node = {
	_connection: Connection,
	_callback: (...any) -> (),
	_previous: Node | false,
	_next: Node | false,
	_id: number,
}

export type Signal<T...> = setmetatable<{
	_head: Node | false,
	_tail: Node | false,
	_count: number,
	_proxy: RBXScriptConnection | false,
	_event: BindableEvent | false,
	connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	get_connections: (self: Signal<T...>) -> { Connection },
	fire: (self: Signal<T...>, T...) -> (),
	fire_deferred: (self: Signal<T...>, T...) -> (),
	wait: (self: Signal<T...>) -> T...,
	disconnect_all: (self: Signal<T...>) -> (),
	destroy: (self: Signal<T...>) -> (),
}, { __index: Signal<T...> }>

-- the node keeps its own `_next`, so a fire currently on it can still move on
const function unlink(signal: Signal<...any>, node: Node)
	const previous, following = node._previous, node._next

	if previous then
		previous._next = following
	else
		signal._head = following
	end

	if following then
		following._previous = previous
	else
		signal._tail = previous
	end
end

-- calls the handlers connected before this fire started
const function fire_handlers(signal: Signal<...any>, ...: any)
	const last = signal._count

	local node = signal._head
	while node and node._id <= last do
		if node._connection.connected then
			Thread(node._callback, ...)
		end

		node = node._next
	end
end

const Signal = {}
Signal.__index = Signal

--[=[
	@within Signal
	@function new
	@return Signal<T...>

	creates a Signal with no handlers
]=]
function Signal.new<T...>(): Signal<T...>
	return setmetatable(
		{
			_head = false,
			_tail = false,
			_count = 0,
			_proxy = false,
			_event = false,
		},
		Signal
	) :: any
end

--[=[
	@within Signal
	@function wrap
	@param rbx_signal RBXScriptSignal
	@return Signal<T...>

	creates a Signal that fires whenever `rbx_signal` fires, until it is destroyed

	```lua
	local added = Signal.wrap(workspace.ChildAdded)
	```
]=]
function Signal.wrap<T...>(rbx_signal: RBXScriptSignal): Signal<T...>
	const signal = Signal.new()
	signal._proxy = rbx_signal:Connect(function(...)
		signal:fire(...)
	end)

	return signal :: any
end

--[=[
	@within Signal
	@function bindable
	@param event BindableEvent
	@return Signal<T...>

	creates a Signal that fires through `event`. firing it fires `event`, and
	its handlers run whenever `event` fires, so scripts that don't share the
	Signal, like ones connected to `event.Event` or another Signal made from the
	same `event`, all hear the same fires

	```lua
	local event = ReplicatedStorage:WaitForChild("RoundEnded")
	local round_ended = Signal.bindable(event)

	round_ended:connect(function(winner)
		print(`{winner} won`)
	end)
	round_ended:fire("Alice")
	```

	:::info
	the fired values follow the rules of `BindableEvent`: tables are copied
	without their metatable, and with deferred signal behavior the handlers run
	at the next resumption point instead of right away. destroying the Signal
	disconnects it from `event` but leaves `event` alone
	:::
]=]
function Signal.bindable<T...>(event: BindableEvent): Signal<T...>
	const signal = Signal.new()
	signal._event = event
	signal._proxy = event.Event:Connect(function(...)
		fire_handlers(signal, ...)
	end)

	return signal :: any
end

--[=[
	@within Signal
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Signal
]=]
function Signal.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Signal
end

--[=[
	@within Signal
	@method connect
	@param callback (T...) -> ()
	@return Connection

	calls `callback` with the fired values every time the signal fires, until the
	returned [Connection] is disconnected
]=]
function Signal.connect<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection
	const id = self._count + 1
	self._count = id

	const tail = self._tail
	const node: Node = {
		_connection = nil :: any,
		_callback = callback :: any,
		_previous = tail,
		_next = false,
		_id = id,
	}

	node._connection = Connection.new(function()
		unlink(self, node)
	end) :: any

	if tail then
		tail._next = node
	else
		self._head = node
	end
	self._tail = node

	return node._connection
end

--[=[
	@within Signal
	@method once
	@param callback (T...) -> ()
	@return Connection

	the same as [Signal:connect], but disconnects after the first fire
]=]
function Signal.once<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection
	local connection: Connection
	connection = self:connect(function(...)
		connection:disconnect()
		callback(...)
	end)

	return connection
end

--[=[
	@within Signal
	@method get_connections
	@return { Connection }

	returns the connections of every connected handler, in the order they were
	connected
]=]
function Signal.get_connections<T...>(self: Signal<T...>): { Connection }
	const connections = {}

	local node = self._head
	while node do
		table.insert(connections, node._connection)
		node = node._next
	end

	return connections
end

--[=[
	@within Signal
	@method fire
	@param ... T...

	calls every connected handler with `...`, each on its own recycled thread.
	a Signal made with [Signal.bindable] fires its `BindableEvent` instead,
	which then calls the handlers
]=]
function Signal.fire<T...>(self: Signal<T...>, ...: T...)
	const event = self._event
	if event then
		event:Fire(...)
		return
	end

	fire_handlers(self, ...)
end

--[=[
	@within Signal
	@method fire_deferred
	@param ... T...

	the same as [Signal:fire], but deferred with `task.defer`
]=]
function Signal.fire_deferred<T...>(self: Signal<T...>, ...: T...)
	task.defer(Signal.fire, self, ...)
end

--[=[
	@within Signal
	@method wait
	@yields
	@return T...

	yields the current thread until the signal fires, then returns the fired values
]=]
function Signal.wait<T...>(self: Signal<T...>): T...
	const thread = coroutine.running()

	self:once(function(...)
		task.spawn(thread, ...)
	end)

	return coroutine.yield()
end

--[=[
	@within Signal
	@method disconnect_all

	disconnects every handler. the signal can still be connected to afterwards
]=]
function Signal.disconnect_all<T...>(self: Signal<T...>)
	local node = self._head
	while node do
		node._connection.connected = false
		node = node._next
	end

	self._head = false
	self._tail = false
end

--[=[
	@within Signal
	@method destroy

	disconnects every handler, and stops following the RBXScriptSignal or the
	BindableEvent if the signal was made with [Signal.wrap] or [Signal.bindable]
]=]
function Signal.destroy<T...>(self: Signal<T...>)
	self:disconnect_all()

	const proxy = self._proxy
	if proxy then
		proxy:Disconnect()
		self._proxy = false
	end
	self._event = false
end

return table.freeze({
	new = Signal.new,
	wrap = Signal.wrap,
	bindable = Signal.bindable,
	is = Signal.is,
})

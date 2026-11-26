--[=[
	@class Atom

	Atom is a value you set and follow like a stream

	create one with a starting value, then change it with [Atom:set] or
	[Atom:update] and listen with [Atom:observe]. it only notifies when the value
	really changes: tables are compared deeply, so setting an equal table does
	nothing. a table with a metatable is an object, compared by reference

	an atom is a [Stream]: listening emits the value right away, then every
	change. `map`, `filter`, `changed`, `Stream.combine`, [Mount] props and the
	rest of Stream all work with it

	```lua
	local Atom = require(path.to.Atom)

	local coins = Atom.new(0)

	coins:observe(function(new, old)
		label.Text = `{new} coins`
	end)

	coins:increment(10)

	-- a stream that follows coins
	local doubled = coins:map(function(value)
		return value * 2
	end)
	```

	:::info
	[Atom:get] returns a deep copy, so changing what it returns never changes the
	atom, except for tables with a metatable, which are kept as is. listeners
	and [Atom:peek] get the value itself without copying, so don't change it
	:::
]=]

const Connection = require(script.Parent.Connection)
const Stream = require(script.Parent.Stream)
const Thread = require(script.Parent.Thread)

export type Connection = Connection.Connection
export type Stream<T> = Stream.Stream<T>
type Void = Stream.Void

export type Atom<T> = Stream<T> & {
	get: (self: Atom<T>) -> T,
	peek: (self: Atom<T>) -> T,
	set: (self: Atom<T>, value: T, force: boolean?) -> Atom<T>,
	update: (self: Atom<T>, callback: (value: T) -> T) -> Atom<T>,
	increment: (self: Atom<T>, amount: number, max: number?) -> Atom<T>,
	decrement: (self: Atom<T>, amount: number, min: number?) -> Atom<T>,
	toggle: (self: Atom<T>) -> Atom<T>,
	reset: (self: Atom<T>) -> Atom<T>,
	freeze: (self: Atom<T>) -> Atom<T>,
	unfreeze: (self: Atom<T>) -> Atom<T>,
	is_frozen: (self: Atom<T>) -> boolean,
	transaction: (self: Atom<T>, callback: (value: T) -> T) -> Atom<T>,
	observe: (self: Atom<T>, callback: (new: T, old: T?) -> ()) -> Connection,
}

-- the subscriptions to an atom, one entry each so the same function subscribed
-- twice is called twice and removed separately
type Listeners = { [{ (value: any) -> () }]: true }

-- an atom keeps the metatable of a stream so Stream treats it as one, so its
-- own methods are copied onto it
const methods: any = {}

-- what [Atom:observe] has before the first value
const UNSET = table.freeze({})

-- the destroy of every stream, which disconnects what `listen` and `each` gave
const destroy_stream: (stream: any) -> () = (Stream.never() :: any).destroy

-- whether `value` is a table without a metatable. a table with one is an
-- object, kept as is and compared by reference
const function is_plain(value: any): boolean
	return type(value) == "table" and getmetatable(value) == nil
end

-- a copy of `value` with every plain table inside copied too
const function deep_copy<T>(value: T): T
	if not is_plain(value) then
		return value
	end

	const copy = {}
	for key, item in value :: any do
		copy[deep_copy(key)] = deep_copy(item)
	end
	return copy :: any
end

-- whether `left` and `right` are equal, comparing plain tables key by key
const function deep_equal(left: any, right: any): boolean
	if left == right then
		return true
	end
	if not is_plain(left) or not is_plain(right) then
		return false
	end

	for key, item in left do
		if not deep_equal(item, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

-- emits `value` to every subscription of `atom`. subscriptions added meanwhile
-- wait for the next change, and removed ones are skipped
const function notify(atom: any, value: any)
	const listeners: Listeners = atom._listeners
	for subscription in table.clone(listeners) do
		if listeners[subscription] then
			subscription[1](value)
		end
	end
end

const Atom = {}

--[=[
	@within Atom
	@function new
	@param value T
	@return Atom<T>

	creates an Atom holding `value`. [Atom:reset] goes back to a copy of it
]=]
function Atom.new<T>(value: T): Atom<T>
	const listeners: Listeners = {}

	local atom: any
	atom = Stream.new(function(emit: (T) -> (), void: Void)
		const subscription = { emit }
		listeners[subscription] = true
		void:add(function()
			listeners[subscription] = nil
		end)
		emit(atom._value)
	end) :: any

	atom._value = value
	atom._initial = deep_copy(value)
	atom._frozen = false
	-- the value when the running Atom.batch started, while there is one
	atom._batch = false
	atom._listeners = listeners
	for name, method in methods do
		atom[name] = method
	end

	return atom
end

--[=[
	@within Atom
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is an Atom
]=]
function Atom.is(obj: any): boolean
	return Stream.is(obj) and obj.set == methods.set
end

--[=[
	@within Atom
	@function batch
	@param atoms { Atom<any> }
	@param callback () -> ()

	calls `callback`, holding back the notifications of `atoms` until it returns.
	then each atom that ended on a different value notifies once, with its value
	from before the batch as the old value. an error in `callback` is warned

	```lua
	Atom.batch({ x, y }, function()
		x:set(10)
		y:set(20)
	end)
	```
]=]
function Atom.batch(atoms: { Atom<any> }, callback: () -> ())
	const batching: { any } = {}
	for _, atom: any in atoms do
		if not atom._batch then
			atom._batch = { old = deep_copy(atom._value) }
			table.insert(batching, atom)
		end
	end

	const ok, err = pcall(callback)

	for _, atom in batching do
		const old = atom._batch.old
		atom._batch = false
		if not deep_equal(atom._value, old) then
			notify(atom, atom._value)
		end
	end

	if not ok then
		warn("Atom.batch failed:", err)
	end
end

--[=[
	@within Atom
	@method get
	@return T

	returns a deep copy of the value
]=]
function methods.get<T>(self: Atom<T>): T
	return deep_copy((self :: any)._value)
end

--[=[
	@within Atom
	@method peek
	@return T

	returns the value itself, without copying it. don't change it, use
	[Atom:set] or [Atom:update]
]=]
function methods.peek<T>(self: Atom<T>): T
	return (self :: any)._value
end

--[=[
	@within Atom
	@method set
	@param value T
	@param force boolean?
	@return Atom<T>

	sets the value and emits it, unless it is deeply equal to the current one
	and `force` isn't true. does nothing while frozen
]=]
function methods.set<T>(self: Atom<T>, value: T, force: boolean?): Atom<T>
	const atom: any = self
	if atom._frozen or (not force and deep_equal(atom._value, value)) then
		return self
	end

	atom._value = value
	if not atom._batch then
		notify(atom, value)
	end

	return self
end

--[=[
	@within Atom
	@method update
	@param callback (value: T) -> T
	@return Atom<T>

	sets the value to what `callback` returns from a copy of the current one
]=]
function methods.update<T>(self: Atom<T>, callback: (value: T) -> T): Atom<T>
	return self:set(callback(self:get()))
end

--[=[
	@within Atom
	@method increment
	@param amount number
	@param max number?
	@return Atom<T>

	adds `amount` to a number value, without going over `max`
]=]
function methods.increment<T>(self: Atom<T>, amount: number, max: number?): Atom<T>
	return self:update(function(value: any)
		const new = value + amount
		return if max then math.min(new, max) else new
	end)
end

--[=[
	@within Atom
	@method decrement
	@param amount number
	@param min number?
	@return Atom<T>

	subtracts `amount` from a number value, without going under `min`
]=]
function methods.decrement<T>(self: Atom<T>, amount: number, min: number?): Atom<T>
	return self:update(function(value: any)
		const new = value - amount
		return if min then math.max(new, min) else new
	end)
end

--[=[
	@within Atom
	@method toggle
	@return Atom<T>

	flips a boolean value
]=]
function methods.toggle<T>(self: Atom<T>): Atom<T>
	return self:update(function(value: any): any
		return not value
	end)
end

--[=[
	@within Atom
	@method reset
	@return Atom<T>

	sets the value back to a copy of the one the atom was created with
]=]
function methods.reset<T>(self: Atom<T>): Atom<T>
	return self:set(deep_copy((self :: any)._initial))
end

--[=[
	@within Atom
	@method freeze
	@return Atom<T>

	ignores every change until [Atom:unfreeze] is called
]=]
function methods.freeze<T>(self: Atom<T>): Atom<T>
	(self :: any)._frozen = true
	return self
end

--[=[
	@within Atom
	@method unfreeze
	@return Atom<T>

	lets the value change again after [Atom:freeze]
]=]
function methods.unfreeze<T>(self: Atom<T>): Atom<T>
	(self :: any)._frozen = false
	return self
end

--[=[
	@within Atom
	@method is_frozen
	@return boolean

	returns whether the atom is frozen
]=]
function methods.is_frozen<T>(self: Atom<T>): boolean
	return (self :: any)._frozen
end

--[=[
	@within Atom
	@method transaction
	@param callback (value: T) -> T
	@return Atom<T>

	sets the value to what `callback` returns from the current one, only if it
	doesn't error. the atom is frozen while `callback` runs, and an error is
	warned
]=]
function methods.transaction<T>(self: Atom<T>, callback: (value: T) -> T): Atom<T>
	const atom: any = self
	const was_frozen = atom._frozen
	atom._frozen = true
	const ok, result = pcall(callback, self:get())
	atom._frozen = was_frozen

	if ok then
		self:set(result)
	else
		warn("Atom transaction failed:", result)
	end

	return self
end

--[=[
	@within Atom
	@method observe
	@param callback (new: T, old: T?) -> ()
	@return Connection

	calls `callback` right away with the value, then on every change with the
	new and old values, until the [Connection] is disconnected. `callback` runs
	on its own thread with [Thread], so it can yield

	```lua
	coins:observe(function(new, old)
		print(`{old} -> {new}`)
	end)
	```
]=]
function methods.observe<T>(self: Atom<T>, callback: (new: T, old: T?) -> ()): Connection
	local last: any = UNSET
	return self:listen(function(value: T)
		const old = if last == UNSET then nil else last
		last = value
		Thread(callback, value, old)
	end)
end

--[=[
	@within Atom
	@method destroy

	disconnects everything listening to the atom, streams made from it included.
	the value can still be read and set afterwards
]=]
function methods.destroy<T>(self: Atom<T>)
	table.clear((self :: any)._listeners)
	destroy_stream(self)
end

return table.freeze({
	new = Atom.new,
	is = Atom.is,
	batch = Atom.batch,
})

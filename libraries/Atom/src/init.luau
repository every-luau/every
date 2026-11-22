--[=[
	@class Atom

	Atom is a value that can be observed, derived and updated

	create one with a starting value, then change it with [Atom:set] or
	[Atom:update] and listen with [Atom:observe]. it only notifies when the value
	really changes: tables are compared deeply, so setting an equal table does
	nothing

	```lua
	local Atom = require(path.to.Atom)

	local coins = Atom.new(0)

	coins:observe(function(new, old)
		label.Text = `{new} coins`
	end)

	coins:increment(10)
	local doubled = coins:map(function(value)
		return value * 2
	end)
	```

	:::info
	[Atom:get] returns a deep copy, so changing what it returns never changes the
	atom. use [Atom:peek] to read the value itself without copying. derived atoms
	from [Atom:map], [Atom:filter] and [Atom:throttle] are destroyed with the atom
	they come from
	:::
]=]

const Signal = require(script.Parent.Signal)
const Thread = require(script.Parent.Thread)
const Void = require(script.Parent.Void)

export type Connection = Signal.Connection
export type Signal<T...> = Signal.Signal<T...>

export type Atom<T> = setmetatable<{
	_value: T,
	_initial: T,
	_frozen: boolean,
	-- the value when the running Atom.batch started, while there is one
	_batch: { old: T } | false,
	_changed: Signal<T, T>,
	_void: Void.Void,
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
	get_signal: (self: Atom<T>) -> Signal<T, T>,
	-- any, since a type can't refer to itself with other parameters
	map: <U>(self: Atom<T>, mapper: (value: T) -> U) -> any,
	filter: (self: Atom<T>, predicate: (value: T) -> boolean) -> Atom<T>,
	throttle: (self: Atom<T>, seconds: number) -> Atom<T>,
	destroy: (self: Atom<T>) -> (),
}, { __index: Atom<T> }>

-- a copy of `value` with every table inside copied too, metatables kept
const function deep_copy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	const copy = {}
	for key, item in value :: any do
		copy[deep_copy(key)] = deep_copy(item)
	end
	return setmetatable(copy, getmetatable(value :: any)) :: any
end

-- whether `a` and `b` are equal, comparing tables key by key
const function deep_equal(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	for key, item in a do
		if not deep_equal(item, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

const Atom = {}
Atom.__index = Atom

--[=[
	@within Atom
	@function new
	@param value T
	@return Atom<T>

	creates an Atom holding `value`. [Atom:reset] goes back to a copy of it
]=]
function Atom.new<T>(value: T): Atom<T>
	const void = Void.new()

	return setmetatable(
		{
			_value = value,
			_initial = deep_copy(value),
			_frozen = false,
			_batch = false,
			_changed = void:add(Signal.new()),
			_void = void,
		},
		Atom
	) :: any
end

--[=[
	@within Atom
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is an Atom
]=]
function Atom.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Atom
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
	const batching: { Atom<any> } = {}
	for _, atom in atoms do
		if not atom._batch then
			atom._batch = { old = deep_copy(atom._value) }
			table.insert(batching, atom)
		end
	end

	const ok, err = pcall(callback)

	for _, atom in batching do
		const old = (atom._batch :: { old: any }).old
		atom._batch = false
		if not deep_equal(atom._value, old) then
			atom._changed:fire(atom._value, old)
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
function Atom.get<T>(self: Atom<T>): T
	return deep_copy(self._value)
end

--[=[
	@within Atom
	@method peek
	@return T

	returns the value itself, without copying it. don't change it, use
	[Atom:set] or [Atom:update]
]=]
function Atom.peek<T>(self: Atom<T>): T
	return self._value
end

--[=[
	@within Atom
	@method set
	@param value T
	@param force boolean?
	@return Atom<T>

	sets the value and notifies with the new and old values, unless it is deeply
	equal to the current one and `force` isn't true. does nothing while frozen
]=]
function Atom.set<T>(self: Atom<T>, value: T, force: boolean?): Atom<T>
	if self._frozen or (not force and deep_equal(self._value, value)) then
		return self
	end

	const old = self._value
	self._value = value

	if not self._batch then
		self._changed:fire(value, old)
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
function Atom.update<T>(self: Atom<T>, callback: (value: T) -> T): Atom<T>
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
function Atom.increment<T>(self: Atom<T>, amount: number, max: number?): Atom<T>
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
function Atom.decrement<T>(self: Atom<T>, amount: number, min: number?): Atom<T>
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
function Atom.toggle<T>(self: Atom<T>): Atom<T>
	return self:update(function(value: any)
		return not value
	end)
end

--[=[
	@within Atom
	@method reset
	@return Atom<T>

	sets the value back to a copy of the one the atom was created with
]=]
function Atom.reset<T>(self: Atom<T>): Atom<T>
	return self:set(deep_copy(self._initial))
end

--[=[
	@within Atom
	@method freeze
	@return Atom<T>

	ignores every change until [Atom:unfreeze] is called
]=]
function Atom.freeze<T>(self: Atom<T>): Atom<T>
	self._frozen = true
	return self
end

--[=[
	@within Atom
	@method unfreeze
	@return Atom<T>

	lets the value change again after [Atom:freeze]
]=]
function Atom.unfreeze<T>(self: Atom<T>): Atom<T>
	self._frozen = false
	return self
end

--[=[
	@within Atom
	@method is_frozen
	@return boolean

	returns whether the atom is frozen
]=]
function Atom.is_frozen<T>(self: Atom<T>): boolean
	return self._frozen
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
function Atom.transaction<T>(self: Atom<T>, callback: (value: T) -> T): Atom<T>
	const was_frozen = self._frozen
	self._frozen = true
	const ok, result = pcall(callback, self:get())
	self._frozen = was_frozen

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

	calls `callback` right away with a copy of the value, then on every change
	with the new and old values
]=]
function Atom.observe<T>(self: Atom<T>, callback: (new: T, old: T?) -> ()): Connection
	Thread(callback, self:get())
	return self._changed:connect(callback)
end

--[=[
	@within Atom
	@method get_signal
	@return Signal<T, T>

	returns the [Signal] that fires with the new and old values on every change
]=]
function Atom.get_signal<T>(self: Atom<T>): Signal<T, T>
	return self._changed
end

-- creates an atom destroyed with `self`, that stops following it once destroyed
const function derive(self: Atom<any>, value: any, follow: (derived: Atom<any>, new: any) -> ()): any
	const derived: Atom<any> = self._void:add(Atom.new(value) :: any)
	const following = self._changed:connect(function(new)
		follow(derived, new)
	end)
	derived._void:add(following :: any)
	return derived
end

--[=[
	@within Atom
	@method map
	@param mapper (value: T) -> U
	@return Atom<U>

	returns an atom holding what `mapper` returns from this one's value, kept up
	to date

	```lua
	local label = coins:map(function(value)
		return `{value} coins`
	end)
	```
]=]
function Atom.map<T, U>(self: Atom<T>, mapper: (value: T) -> U): Atom<U>
	return derive(self, mapper(self:get()), function(derived, new)
		derived:set(mapper(deep_copy(new)))
	end)
end

--[=[
	@within Atom
	@method filter
	@param predicate (value: T) -> boolean
	@return Atom<T>

	returns an atom that starts with this one's value, then only follows the
	values `predicate` returns true for
]=]
function Atom.filter<T>(self: Atom<T>, predicate: (value: T) -> boolean): Atom<T>
	return derive(self, self:get(), function(derived, new)
		if predicate(new) then
			derived:set(deep_copy(new))
		end
	end)
end

--[=[
	@within Atom
	@method throttle
	@param seconds number
	@return Atom<T>

	returns an atom that follows this one at most once every `seconds`. a change
	coming sooner is held, and the latest held value is set once the time passed
]=]
function Atom.throttle<T>(self: Atom<T>, seconds: number): Atom<T>
	local last = -math.huge
	local held: { value: T } | false = false

	return derive(self, self:get(), function(derived, new)
		const now = os.clock()
		if now - last >= seconds then
			last = now
			derived:set(deep_copy(new))
			return
		end

		const waiting = held ~= false
		held = { value = deep_copy(new) }
		if not waiting then
			task.delay(seconds - (now - last), function()
				const latest = held
				held = false
				if latest then
					last = os.clock()
					derived:set(latest.value)
				end
			end)
		end
	end)
end

--[=[
	@within Atom
	@method destroy

	disconnects everything listening to the atom and destroys the atoms derived
	from it
]=]
function Atom.destroy<T>(self: Atom<T>)
	self._void:clean()
end

return table.freeze({
	new = Atom.new,
	is = Atom.is,
	batch = Atom.batch,
})

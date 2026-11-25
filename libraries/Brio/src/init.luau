--[=[
	@class Brio

	Brio holds a value while it is alive, and cleans what was made for it once it dies

	a brio is handed out for something that exists for a while, like a player in
	the game or the current value of a property. [Brio:get_value] reads it, and
	[Brio:to_void] gives a [Void] cleaned when the brio dies. the Void is only
	made the first time it is asked for, so a brio nobody adds anything to costs
	almost nothing

	```lua
	local Brio = require(path.to.Brio)

	local brio = Brio.new(player)
	local void, value = brio:to_void_and_value()
	void:add(function()
		print(`{value.Name} is gone`)
	end)

	brio:destroy()
	print(brio:is_dead()) --> true
	```
]=]

const Void = require(script.Parent.Void)

export type Void = Void.Void

export type Brio<T> = {
	get_value: (self: Brio<T>) -> T,
	to_void: (self: Brio<T>) -> Void,
	to_void_and_value: (self: Brio<T>) -> (Void, T),
	is_dead: (self: Brio<T>) -> boolean,
	destroy: (self: Brio<T>) -> (),
}

const Brio = {}
Brio.__index = Brio

-- the values of a brio are packed, so nil values in the middle are kept. a
-- dead brio has none
type Internal = {
	_values: { n: number, [number]: any }?,
	_void: Void?,
}

const function alive_values(self: Internal, method: string): { n: number, [number]: any }
	const values = self._values
	if values == nil then
		error(`[Brio] cannot call {method} on a dead brio`, 3)
	end
	return values
end

--[=[
	@within Brio
	@function new
	@param ... T
	@return Brio<T>

	creates a brio alive with `...`. a brio can hold several values, and
	[Brio:get_value] returns them all

	```lua
	local brio = Brio.new(player, character)
	local player, character = brio:get_value()
	```
]=]
function Brio.new<T>(...: T): Brio<T>
	return setmetatable({ _values = table.pack(...), _void = nil }, Brio) :: any
end

--[=[
	@within Brio
	@function is
	@param value any
	@return boolean

	returns whether `value` is a brio, dead or alive
]=]
function Brio.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Brio
end

--[=[
	@within Brio
	@method get_value
	@return T
	@error "[Brio] cannot call get_value on a dead brio"

	returns the values the brio was created with. check [Brio:is_dead] first
	when the brio may have died, like after yielding
]=]
function Brio.get_value<T>(self: Brio<T>): T
	const values = alive_values(self :: any, "get_value")
	return table.unpack(values, 1, values.n)
end

--[=[
	@within Brio
	@method to_void
	@return Void
	@error "[Brio] cannot call to_void on a dead brio"

	returns the [Void] cleaned when the brio dies. it is made the first time
	this is called, and every later call returns the same one

	```lua
	observable:subscribe(function(brio)
		local void = brio:to_void()
		local part = brio:get_value()
		void:add(part.Touched:Connect(kill))
	end)
	```
]=]
function Brio.to_void<T>(self: Brio<T>): Void
	const internal = self :: any
	alive_values(internal, "to_void")

	local void = internal._void
	if void == nil then
		void = Void.new()
		internal._void = void
	end
	return void
end

--[=[
	@within Brio
	@method to_void_and_value
	@return (Void, T)
	@error "[Brio] cannot call to_void_and_value on a dead brio"

	returns [Brio:to_void] then the values, to get both in one line

	```lua
	observable:subscribe(function(brio)
		local void, part = brio:to_void_and_value()
		void:add(part.Touched:Connect(kill))
	end)
	```
]=]
function Brio.to_void_and_value<T>(self: Brio<T>): (Void, T)
	const values = alive_values(self :: any, "to_void_and_value")
	return self:to_void(), table.unpack(values, 1, values.n)
end

--[=[
	@within Brio
	@method is_dead
	@return boolean

	returns whether the brio died, after which its values are gone
]=]
function Brio.is_dead<T>(self: Brio<T>): boolean
	return (self :: any)._values == nil
end

--[=[
	@within Brio
	@method destroy

	kills the brio: drops its values and cleans its [Void] if one was made.
	destroying a dead brio does nothing, and a brio can be added to a [Void]
]=]
function Brio.destroy<T>(self: Brio<T>)
	const internal = self :: any
	if internal._values == nil then
		return
	end

	internal._values = nil
	const void = internal._void
	if void then
		internal._void = nil
		void:clean()
	end
end

--[=[
	@within Brio
	@prop DEAD Brio<nil>

	a brio that is already dead, for code that needs a brio but has nothing
	alive to give
]=]
const DEAD = Brio.new()
DEAD:destroy()

table.freeze(Brio)

return table.freeze({
	new = Brio.new,
	is = Brio.is,
	DEAD = DEAD,
})

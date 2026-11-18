--!native
--!optimize 2

--[=[
	@class Void

	keeps track of things that need to be cleaned up, and cleans them all at once

	every item is cleaned the way its type expects: instances are destroyed,
	connections are disconnected, threads are cancelled, functions are called on a
	recycled thread (see Thread), and tables have their `Destroy`, `Disconnect`,
	`destroy` or `disconnect` method called

	:::info
	items are stored as keys, so adding the same item twice keeps a single entry.
	items are cleaned in no particular order
	:::

	```lua
	local Void = require(path.to.Void)

	local void = Void.new()
	local part = void:add(Instance.new("Part"))
	void:add(workspace.ChildAdded:Connect(print))
	void:add(function()
		print("cleaned")
	end)

	void:clean() --> cleaned
	```
]=]

const Thread = require(script.Parent.Thread)

--[=[
	@within Void
	@type Item Instance | RBXScriptConnection | thread | (...any) -> ...any | { Destroy: () -> () } | { destroy: () -> () } | { disconnect: () -> () } | Void

	anything a Void knows how to clean. a table is only accepted if it has a
	`Destroy`, `Disconnect`, `destroy` or `disconnect` method, which is checked when
	it is added
]=]
export type Item = Instance | { Destroy: () -> () } | { destroy: () -> () } | { disconnect: () -> () } | RBXScriptConnection | ((...any) -> ...any) | { [any]: any } | thread | Void | () -> ()

export type Void = setmetatable<{ [Item]: (value: unknown) -> () } & {
	add: <T>(self: Void, item: T & Item) -> T,
	remove: <T>(self: Void, item: T & Item) -> T,
	remove_all: (self: Void) -> (),
	attach_to_instance: (self: Void, instance: Instance) -> RBXScriptConnection,
--
	is_empty: (self: Void) -> boolean,
	get_items: (self: Void) -> { Item },
--
	clone: <T>(self: Void, instance: T & Instance) -> T,
	extend: (self: Void) -> Void,
	construct: <T, A...>(self: Void, item: ((A...) -> T) | { new: (A...) -> T }, A...) -> T,
--
	clean: (self: Void) -> (),
	wrap_clean: (self: Void) -> () -> (),
	destroy: (self: Void) -> (),
	clean_item: <T>(self: Void, item: T & Item) -> T,
}, { __index: Void }>

const finalizers = {
	["thread"] = function(thread: thread)
		local cancelled: boolean?
		if coroutine.running() ~= thread then
			cancelled = pcall(function()
				task.cancel(thread)
			end)
		end

		if not cancelled then
			task.defer(function()
				task.cancel(thread)
			end)
		end
	end,
	["function"] = Thread,
	["Instance"] = game.Destroy,
	["RBXScriptConnection"] = function(connection: RBXScriptConnection)
		connection:Disconnect()
	end,
}

const function get_finalizer(item: any): (any, string)
	local typeName = typeof(item)
	local finalizer = finalizers[typeName]

	if not finalizer and typeName == "table" then
		finalizer = item.Destroy or item.Disconnect or item.destroy or item.disconnect
	end

	return finalizer, typeName
end

const Void = {}
Void.__index = Void

--[=[
	@within Void
	@function new
	@return Void

	creates an empty Void
]=]
function Void.new(): Void
	return setmetatable({}, Void) :: any
end

--[=[
	@within Void
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Void
]=]
function Void.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Void
end

--[=[
	@within Void
	@method add
	@param item T
	@return T
	@error "Cannot add item of type '...'" -- `item` is not an [Item]

	adds `item` and returns it, so an item can be created and added on one line

	```lua
	local part = void:add(Instance.new("Part"))
	```
]=]
function Void.add<T>(self: Void, item: T & Item): T
	local finalizer, typeName = get_finalizer(item)
	assert(finalizer, `Cannot add item of type '{typeName}'.`)

	self[item] = finalizer
	return item
end

--[=[
	@within Void
	@method remove
	@param item T
	@return T

	stops tracking `item` without cleaning it, and returns it
]=]
function Void.remove<T>(self: Void, item: T & Item): T
	self[item] = nil
	return item
end

--[=[
	@within Void
	@method remove_all

	stops tracking every item without cleaning any of them
]=]
function Void.remove_all(self: Void): ()
	table.clear(self)
end

--[=[
	@within Void
	@method attach_to_instance
	@param instance Instance
	@return RBXScriptConnection

	cleans the Void when `instance` or one of its ancestors is parented to nil,
	which includes `instance` being destroyed. returns the connection, which is
	also an item of the Void

	:::caution
	the Void is cleaned as soon as `instance` leaves the tree, even if it is
	parented back right after. an instance that has no parent yet can't lose it,
	so attach it after parenting it
	:::
]=]
function Void.attach_to_instance(self: Void, instance: Instance): RBXScriptConnection
	return self:add(
		-- NOTE: doesn't wait for garbage collector to collect the instance
		instance.AncestryChanged:Connect(function(_, parent: Instance?)
			if parent then
				return
			end

			self:destroy()
		end)
	)
end

--[=[
	@within Void
	@method is_empty
	@return boolean

	returns whether the Void has no items
]=]
function Void.is_empty(self: Void): boolean
	return next(self) == nil
end

--[=[
	@within Void
	@method get_items
	@return { Item }

	returns a new list of the items, in no particular order
]=]
function Void.get_items(self: Void): { Item }
	const items = {}

	for item in self do
		table.insert(items, item)
	end

	return items
end

--[=[
	@within Void
	@method clone
	@param instance T
	@return T

	clones `instance`, adds the clone and returns it

	`instance` doesn't need to be archivable: it is made archivable for the clone
	and set back right after

	:::info
	descendants of `instance` that aren't archivable are still left out of the
	clone, and the clone itself stays archivable
	:::
]=]
function Void.clone<T>(self: Void, instance: T & Instance): T
	const archivable = instance.Archivable -- NOTE: archivable is needed to clone an instance
	instance.Archivable = true

	const clone = instance:Clone()
	instance.Archivable = archivable

	return self:add(clone) :: any
end

--[=[
	@within Void
	@method extend
	@return Void

	creates a Void that is an item of this one, so cleaning this one cleans it
	too. it can still be cleaned on its own
]=]
function Void.extend(self: Void): Void
	return self:add(Void.new())
end

--[=[
	@within Void
	@method construct
	@param item ((A...) -> T) | { new: (A...) -> T }
	@param ... A...
	@return T
	@error "Cannot add item of type '...'" -- the constructed object is not an [Item]

	calls `item(...)`, or `item.new(...)` when `item` is a table, then adds the
	result and returns it

	```lua
	local signal = void:construct(Signal)
	local part = void:construct(Instance, "Part")
	```
]=]
function Void.construct<T, A...>(self: Void, item: ((A...) -> T) | { new: (A...) -> T }, ...: A...): T
	const object = if type(item) == "table" then item.new(...) else item(...)
	return self:add(object :: any)
end

--[=[
	@within Void
	@method clean

	cleans every item and empties the Void, which can be used again afterwards
]=]
function Void.clean(self: Void): ()
	for item, finalizer in self do
		finalizer(item)
	end

	table.clear(self)
end

--[=[
	@within Void
	@method wrap_clean
	@return () -> ()

	returns a function that cleans the Void when called, for anything that expects
	a callback

	```lua
	instance.Destroying:Once(void:wrap_clean())
	```
]=]
function Void.wrap_clean(self: Void): () -> ()
	return function(): ()
		return self:clean()
	end
end

--[=[
	@within Void
	@method clean_item
	@param item T
	@return T

	cleans `item` right away, stops tracking it and returns it. does nothing if
	`item` isn't in the Void
]=]
function Void.clean_item<T>(self: Void, item: T & Item): T
	const finalizer = self[item]
	if finalizer then
		finalizer(item)
		self[item] = nil
	end

	return item
end

--[=[
	@within Void
	@method destroy

	the same as Void:clean(), so a Void can be added to anything that cleans
	objects through a `destroy` method, another Void included
]=]
Void.destroy = Void.clean

return table.freeze({
	new = Void.new,
	is = Void.is,
})

--!native
--!optimize 2

--[=[
	@class Void

	Void keeps track of things to clean up, and cleans them all at once

	add what a feature creates as you go, then call [Void:clean] when it ends.
	instances are destroyed, connections disconnected, threads cancelled,
	functions called with [Thread], and objects have their `Destroy`,
	`Disconnect`, `destroy` or `disconnect` method called

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

	:::info
	adding the same item twice keeps a single entry, and items are cleaned in no
	particular order
	:::
]=]

const Thread = require(script.Parent.Thread)

--[=[
	@within Void
	@type Item Instance | RBXScriptConnection | thread | (...any) -> ...any | { Destroy: () -> () } | { destroy: () -> () } | { disconnect: () -> () } | Void

	anything a Void can clean. a table needs a `Destroy`, `Disconnect`, `destroy`
	or `disconnect` method, checked when it is added
]=]
export type Item = Instance | { Destroy: () -> () } | { destroy: () -> () } | { disconnect: () -> () } | RBXScriptConnection | ((...any) -> ...any) | { [any]: any } | thread | Void | () -> ()

export type Void = setmetatable<{ [Item]: (value: unknown) -> () } & {
	add: <T>(self: Void, item: T) -> T,
	remove: <T>(self: Void, item: T) -> T,
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
	clean_item: <T>(self: Void, item: T) -> T,
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
	local type_name = typeof(item)
	local finalizer = finalizers[type_name]

	if not finalizer and type_name == "table" then
		finalizer = item.Destroy or item.Disconnect or item.destroy or item.disconnect
	end

	return finalizer, type_name
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

	adds `item` and returns it, so you can create and add it on one line

	```lua
	local part = void:add(Instance.new("Part"))
	```
]=]
function Void.add<T>(self: Void, item: T): T
	local finalizer, type_name = get_finalizer(item)
	assert(finalizer, `Cannot add item of type '{type_name}'.`)

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
function Void.remove<T>(self: Void, item: T): T
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

	cleans the Void when `instance` leaves the tree, destroyed or not. returns
	the connection, which is also added to the Void

	:::caution
	the Void is cleaned even if `instance` is parented back right after. attach
	an instance after parenting it, since one with no parent can't lose it
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

	clones `instance`, adds the clone and returns it. `instance` doesn't need to
	be archivable

	:::info
	descendants that aren't archivable are still left out, and the clone itself
	stays archivable
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

	creates a Void inside this one. cleaning this one cleans it too, and it can
	still be cleaned on its own
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

	returns a function that cleans the Void, to pass where a callback is expected

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
function Void.clean_item<T>(self: Void, item: T): T
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

	the same as [Void:clean], so a Void can be added to another Void
]=]
Void.destroy = Void.clean

return table.freeze({
	new = Void.new,
	is = Void.is,
})

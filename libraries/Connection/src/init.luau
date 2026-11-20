--[=[
	@class Connection

	a handle that runs some cleanup once, when it is disconnected

	it is what [Signal:connect] and [Observable:subscribe] return, and what a
	library can return from anything that has to be undone later. the cleanup is
	either a function, called on a recycled thread (see Thread), or a [Void],
	cleaned with every item it holds

	:::info
	disconnecting twice does nothing the second time, so the cleanup never runs
	more than once. a Connection has `disconnect` and `destroy` methods, so it can
	be added to a [Void]
	:::

	```lua
	local Connection = require(path.to.Connection)

	local connection = Connection.new(function()
		print("cleaned up")
	end)

	print(connection.connected) --> true
	connection:disconnect() --> cleaned up
	print(connection.connected) --> false
	```
]=]

const Void = require(script.Parent.Void)
const Thread = require(script.Parent.Thread)

--[=[
	@within Connection
	@type CleanupItem () -> () | Void

	what a Connection runs when it is disconnected: a function, or a [Void] to
	clean
]=]
type CleanupItem = () -> () | Void.Void
export type Connection = {
	_cleanup: CleanupItem,
	connected: boolean,
	--
	disconnect: (self: Connection) -> (),
	destroy: (self: Connection) -> (),
}

const Connection = {}
Connection.__index = Connection

--[=[
	@within Connection
	@prop connected boolean
	@readonly

	whether the connection is still connected. it starts true and becomes false
	once [Connection:disconnect] is called
]=]

--[=[
	@within Connection
	@function new
	@param cleanup_item CleanupItem
	@return Connection

	creates a connected Connection that runs `cleanup_item` when disconnected

	```lua
	local void = Void.new()
	local connection = Connection.new(void)

	void:add(workspace.ChildAdded:Connect(print))
	connection:disconnect() -- cleans the void
	```
]=]
function Connection.new(cleanup_item: CleanupItem)
	return setmetatable(
		{
			_cleanup = cleanup_item,
			connected = true,
		},
		Connection
	)
end

--[=[
	@within Connection
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Connection
]=]
function Connection.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Connection
end

--[=[
	@within Connection
	@method disconnect

	marks the connection as disconnected and runs its cleanup: a function is
	called on a recycled thread, so a cleanup that yields doesn't hold up the
	caller, and a [Void] is cleaned right away. does nothing if it is already
	disconnected
]=]
function Connection.disconnect(self: Connection)
	if not self.connected then
		return
	end

	self.connected = false

	if type(self._cleanup) == "function" then
		Thread(self._cleanup)
	else
		self._cleanup:destroy()
	end
end

--[=[
	@within Connection
	@method destroy

	the same as Connection:disconnect(), so a Connection can be added to anything
	that cleans objects through a `destroy` method, a [Void] included
]=]
Connection.destroy = Connection.disconnect

return table.freeze({
	new = Connection.new,
	is = Connection.is,
})

--[=[
	@class Connection

	Connection is like Roblox's RBXScriptConnection, but for your own code

	create it with a function, a [Void] or an RBXScriptConnection, then return it
	from anything that has to be undone later. disconnecting calls the function,
	cleans the Void or disconnects the RBXScriptConnection

	```lua
	local Connection = require(path.to.Connection)

	local connection = Connection.new(function()
		print("cleaned up")
	end)

	print(connection.connected) --> true
	connection:disconnect() --> cleaned up
	print(connection.connected) --> false
	```

	:::info
	disconnecting twice does nothing. the function runs on a recycled thread with
	[Thread], so it can yield
	:::
]=]

const Void = require(script.Parent.Void)
const Thread = require(script.Parent.Thread)

--[=[
	@within Connection
	@type CleanupItem (() -> ()) | Void | RBXScriptConnection

	what a Connection runs when it is disconnected: a function, a [Void] to clean,
	or an RBXScriptConnection to disconnect
]=]
type CleanupItem = (() -> ()) | Void.Void | RBXScriptConnection
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

	true until [Connection:disconnect] is called
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
function Connection.new(cleanup_item: CleanupItem): Connection
	return setmetatable(
		{
			_cleanup = cleanup_item,
			connected = true,
		},
		Connection
	) :: any
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

	sets `connected` to false and runs the cleanup. a function runs on a recycled
	thread, so it can yield without holding up the caller. a [Void] is cleaned and
	an RBXScriptConnection disconnected right away. does nothing if the connection
	is already disconnected
]=]
function Connection.disconnect(self: Connection)
	if not self.connected then
		return
	end

	self.connected = false
	const cleanup = self._cleanup

	if type(cleanup) == "function" then
		Thread(cleanup)
	elseif typeof(cleanup) == "RBXScriptConnection" then
		cleanup:Disconnect()
	else
		cleanup:destroy()
	end
end

--[=[
	@within Connection
	@method destroy

	the same as [Connection:disconnect], so a Connection can be added to a [Void]
]=]
Connection.destroy = Connection.disconnect

return table.freeze({
	new = Connection.new,
	is = Connection.is,
})

const Void = require(script.Parent.Void)
const Thread = require(script.Parent.Thread)

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

function Connection.new(cleanup_item: CleanupItem)
	return setmetatable(
		{
			_cleanup = cleanup_item,
			connected = true,
		},
		Connection
	)
end

function Connection.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Connection
end

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

Connection.destroy = Connection.disconnect

return table.freeze({
	new = Connection.new,
	is = Connection.is,
})

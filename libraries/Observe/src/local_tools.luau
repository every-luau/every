const Players = game:GetService("Players")

const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

const tools = require("./tools")

--[=[
	@within Observe
	@function local_tools
	@param callback (tool: Tool, void: Void) -> ()
	@param predicate ((tool: Tool) -> boolean)?
	@return Connection
	@error "Observe.local_tools only exists on the client"

	[Observe.tools] for the local player, on the client
]=]
return function(
	callback: (tool: Tool, void: Void.Void) -> (),
	predicate: ((tool: Tool) -> boolean)?
): Connection.Connection
	const player = Players.LocalPlayer
	if not player then
		error("Observe.local_tools only exists on the client", 2)
	end

	return tools(player, callback, predicate)
end

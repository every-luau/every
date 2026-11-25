const Players = game:GetService("Players")

const Observable = require(script.Parent.Parent.Observable)

const tools = require("./tools")

--[=[
	@within Observe
	@function local_tools
	@return Observable<Tool>
	@error "Observe.local_tools only exists on the client"

	[Observe.tools] for the local player, on the client
]=]
return function(): Observable.Observable<Tool>
	const player = Players.LocalPlayer
	if not player then
		error("Observe.local_tools only exists on the client", 2)
	end

	return tools(player)
end

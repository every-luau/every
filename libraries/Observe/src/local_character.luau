const Players = game:GetService("Players")

const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

const character = require("./character")

--[=[
	@within Observe
	@function local_character
	@param callback (character: Model, void: Void) -> ()
	@param predicate ((character: Model) -> boolean)?
	@return Connection
	@error "Observe.local_character only exists on the client"

	[Observe.character] for the local player, on the client
]=]
return function(
	callback: (character: Model, void: Void.Void) -> (),
	predicate: ((character: Model) -> boolean)?
): Connection.Connection
	const player = Players.LocalPlayer
	if not player then
		error("Observe.local_character only exists on the client", 2)
	end

	return character(player, callback, predicate)
end

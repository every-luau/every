const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

const character = require("./character")
const players = require("./players")

--[=[
	@within Observe
	@function characters
	@param callback (player: Player, character: Model, void: Void) -> ()
	@param predicate ((player: Player, character: Model) -> boolean)?
	@return Connection

	calls `callback` for the character of every player, now and on every spawn,
	if `predicate` accepts it. the void is cleaned when the character is
	removed, on respawn or when its player leaves

	```lua
	Observe.characters(function(player, character, void)
		local highlight = void:add(Instance.new("Highlight"))
		highlight.Parent = character
	end)
	```
]=]
return function(
	callback: (player: Player, character: Model, void: Void.Void) -> (),
	predicate: ((player: Player, character: Model) -> boolean)?
): Connection.Connection
	return players(function(player, player_void)
		local accepts: ((model: Model) -> boolean)? = nil
		if predicate then
			const accept_player = predicate
			accepts = function(model: Model): boolean
				return accept_player(player, model)
			end
		end

		const observed = character(player, function(model, character_void)
			callback(player, model, character_void)
		end, accepts)
		player_void:add(observed :: any)
	end)
end

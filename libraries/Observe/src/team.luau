const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

const players = require("./players")
const property = require("./property")

--[=[
	@within Observe
	@function team
	@param team Team
	@param callback (player: Player, void: Void) -> ()
	@param predicate ((player: Player) -> boolean)?
	@return Connection

	calls `callback` for every player on `team`, now and when they join it, if
	`predicate` accepts them. the void is cleaned when they change team or leave
	the game

	```lua
	Observe.team(Teams.Red, function(player, void)
		local highlight = void:add(Instance.new("Highlight"))
		highlight.FillColor = Color3.new(1, 0, 0)
		highlight.Parent = player.Character
	end)
	```
]=]
return function(
	team: Team,
	callback: (player: Player, void: Void.Void) -> (),
	predicate: ((player: Player) -> boolean)?
): Connection.Connection
	return players(function(player, player_void)
		const observed = property(player, "Team", function(_, team_void)
			callback(player, team_void)
		end, function(current)
			return current == team and (predicate == nil or predicate(player))
		end)
		player_void:add(observed :: any)
	end)
end

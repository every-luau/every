const Observable = require(script.Parent.Parent.Observable)

const players = require("./players")
const property = require("./property")

--[=[
	@within Observe
	@function team
	@param team Team
	@return Observable<Player>

	observes the players on `team`: a brio for each one now and when they join
	it, killed when they change team or leave the game

	```lua
	Observe.team(Teams.Red):subscribe(function(brio)
		local void, player = brio:to_void_and_value()
		local highlight = void:add(Instance.new("Highlight"))
		highlight.FillColor = Color3.new(1, 0, 0)
		highlight.Parent = player.Character
	end)
	```
]=]
return function(team: Team): Observable.Observable<Player>
	return players():flat_map(function(player: Player)
		-- the player, while their team is `team`
		return property(player, "Team")
			:filter(function(current: Team): boolean
				return current == team
			end)
			:map(function(): Player
				return player
			end)
	end)
end

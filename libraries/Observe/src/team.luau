const Observable = require(script.Parent.Parent.Observable)
const Stream = require(script.Parent.Parent.Stream)

type Void = Stream.Void

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
	return Observable.new(Stream.life(function(emit: (Player, boolean) -> (), void: Void)
		void:add(Stream.players():each(function(player: Player, player_void: Void)
			local on_team = false

			player_void:add(Stream.property(player, "Team"):listen(function(current: Team?)
				const now = current == team
				if now ~= on_team then
					on_team = now
					emit(player, now)
				end
			end))

			-- the player left, or observing stopped
			player_void:add(function()
				if on_team then
					on_team = false
					emit(player, false)
				end
			end)
		end))
	end))
end

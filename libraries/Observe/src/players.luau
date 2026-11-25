const Observable = require(script.Parent.Parent.Observable)
const Stream = require(script.Parent.Parent.Stream)

--[=[
	@within Observe
	@function players
	@return Observable<Player>

	observes every player in the game: a brio for each one now and later,
	killed when the player leaves

	```lua
	Observe.players():subscribe(function(brio)
		local void, player = brio:to_void_and_value()
		local leaderstats = void:add(Instance.new("Folder"))
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end)
	```
]=]
return function(): Observable.Observable<Player>
	return Observable.new(Stream.players())
end

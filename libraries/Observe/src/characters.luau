const Observable = require(script.Parent.Parent.Observable)
const Stream = require(script.Parent.Parent.Stream)

--[=[
	@within Observe
	@function characters
	@return Observable<Model>

	observes the character of every player: a brio for each one now and on
	every spawn, killed when the character is removed or its player leaves.
	`Players:GetPlayerFromCharacter` gives the player

	```lua
	Observe.characters():subscribe(function(brio)
		local void, character = brio:to_void_and_value()
		local highlight = void:add(Instance.new("Highlight"))
		highlight.Parent = character
	end)
	```
]=]
return function(): Observable.Observable<Model>
	return Observable.new(Stream.characters())
end

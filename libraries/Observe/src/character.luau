const Observable = require(script.Parent.Parent.Observable)
const Stream = require(script.Parent.Parent.Stream)

--[=[
	@within Observe
	@function character
	@param player Player
	@return Observable<Model>

	observes the character of `player`: a brio for it now and on every spawn,
	killed when the character is removed

	```lua
	Observe.character(player):subscribe(function(brio)
		local void, character = brio:to_void_and_value()
		local highlight = void:add(Instance.new("Highlight"))
		highlight.Parent = character
	end)
	```
]=]
return function(player: Player): Observable.Observable<Model>
	return Observable.from_stream(Stream.character(player)) :: any
end

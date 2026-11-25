const CollectionService = game:GetService("CollectionService")

const Observable = require(script.Parent.Parent.Observable)

const signals = require("./signals")

--[=[
	@within Observe
	@function tag
	@param tag string
	@return Observable<Instance>

	observes every instance with `tag`: a brio for each one now and later,
	killed when the tag is removed or the instance leaves the game

	```lua
	Observe.tag("Lava"):subscribe(function(brio)
		local void, part = brio:to_void_and_value()
		void:add(part.Touched:Connect(kill))
	end)
	```
]=]
return function(tag: string): Observable.Observable<Instance>
	return signals(function()
		return CollectionService:GetTagged(tag)
	end, CollectionService:GetInstanceAddedSignal(tag), CollectionService:GetInstanceRemovedSignal(tag))
end

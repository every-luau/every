const Observable = require(script.Parent.Parent.Observable)

const descendants = require("./descendants")

--[=[
	@within Observe
	@function class_name
	@param class_name string
	@param root Instance?
	@return Observable<Instance>

	observes every instance in `root` that is a `class_name`, with `IsA`: a
	brio for each one now and later, killed when it leaves `root`. `root`
	defaults to the whole game, and a smaller one like `workspace` listens to
	fewer instances

	```lua
	Observe.class_name("Seat"):subscribe(function(brio)
		local void, seat = brio:to_void_and_value()
		void:add(seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			print(seat.Occupant)
		end))
	end)
	```
]=]
return function(class_name: string, root: Instance?): Observable.Observable<Instance>
	return descendants(root or game):filter(function(instance: Instance): boolean
		return instance:IsA(class_name)
	end)
end

const Observable = require(script.Parent.Parent.Observable)

const descendants = require("./descendants")

--[=[
	@within Observe
	@function instance
	@param name string
	@param root Instance?
	@return Observable<Instance>

	observes every instance named `name` in `root`: a brio for each one now
	and later, killed when it leaves `root`. `root` defaults to the whole game,
	and a smaller one like `workspace` listens to fewer instances

	```lua
	Observe.instance("SpawnDoor"):subscribe(function(brio)
		local void, door = brio:to_void_and_value()
		void:add(door.Touched:Connect(open))
	end)
	```

	:::info
	the name is read when the instance is added, so renaming it afterwards
	doesn't give or kill a brio
	:::
]=]
return function(name: string, root: Instance?): Observable.Observable<Instance>
	return descendants(root or game):filter(function(instance: Instance): boolean
		return instance.Name == name
	end)
end

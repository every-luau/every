const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

const descendants = require("./descendants")

--[=[
	@within Observe
	@function instance
	@param name string
	@param callback (instance: Instance, void: Void) -> ()
	@param predicate ((instance: Instance) -> boolean)?
	@param root Instance?
	@return Connection

	calls `callback` for every instance named `name` in `root`, now and later,
	if `predicate` accepts it. the void is cleaned when the instance leaves
	`root`. `root` defaults to the whole game, and a smaller one like
	`workspace` listens to fewer instances

	```lua
	Observe.instance("SpawnDoor", function(door, void)
		void:add(door.Touched:Connect(open))
	end)
	```

	:::info
	the name is read when the instance is added, so renaming it afterwards
	doesn't add or clean it
	:::
]=]
return function(
	name: string,
	callback: (instance: Instance, void: Void.Void) -> (),
	predicate: ((instance: Instance) -> boolean)?,
	root: Instance?
): Connection.Connection
	return descendants(root or game, callback, function(instance)
		return instance.Name == name and (predicate == nil or predicate(instance))
	end)
end

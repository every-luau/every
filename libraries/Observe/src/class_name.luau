const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

const descendants = require("./descendants")

--[=[
	@within Observe
	@function class_name
	@param class_name string
	@param callback (instance: Instance, void: Void) -> ()
	@param predicate ((instance: Instance) -> boolean)?
	@param root Instance?
	@return Connection

	calls `callback` for every instance in `root` that is a `class_name`, with
	`IsA`, now and later, if `predicate` accepts it. the void is cleaned when the
	instance leaves `root`. `root` defaults to the whole game, and a smaller one
	like `workspace` listens to fewer instances

	```lua
	Observe.class_name("Seat", function(seat, void)
		void:add(seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			print(seat.Occupant)
		end))
	end)
	```
]=]
return function(
	class_name: string,
	callback: (instance: Instance, void: Void.Void) -> (),
	predicate: ((instance: Instance) -> boolean)?,
	root: Instance?
): Connection.Connection
	return descendants(root or game, callback, function(instance)
		return instance:IsA(class_name) and (predicate == nil or predicate(instance))
	end)
end

const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

--[=[
	@within Observe
	@function children
	@param parent Instance
	@param callback (child: Instance, void: Void) -> ()
	@param predicate ((child: Instance) -> boolean)?
	@return Connection

	calls `callback` for every child of `parent`, now and later, that `predicate`
	accepts. the void is cleaned when the child is removed

	```lua
	Observe.children(workspace.Doors, function(door, void)
		void:add(door.Touched:Connect(open))
	end)
	```
]=]
return function(
	parent: Instance,
	callback: (child: Instance, void: Void.Void) -> (),
	predicate: ((child: Instance) -> boolean)?
): Connection.Connection
	const void = Void.new()
	const voids: { [Instance]: Void.Void } = {}

	const function add(child: Instance)
		if voids[child] or (predicate and not predicate(child)) then
			return
		end

		const child_void = void:extend()
		voids[child] = child_void
		Thread(callback, child, child_void)
	end

	void:add(parent.ChildAdded:Connect(add))
	void:add(parent.ChildRemoved:Connect(function(child)
		const child_void = voids[child]
		if child_void then
			voids[child] = nil
			void:clean_item(child_void)
		end
	end))

	for _, child in parent:GetChildren() do
		add(child)
	end

	return Connection.new(void)
end

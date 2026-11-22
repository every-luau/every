const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

--[=[
	@within Observe
	@function descendants
	@param root Instance
	@param callback (descendant: Instance, void: Void) -> ()
	@param predicate ((descendant: Instance) -> boolean)?
	@return Connection

	calls `callback` for every descendant of `root`, now and later, that
	`predicate` accepts. the void is cleaned when the descendant leaves `root`,
	so removing a folder cleans the voids of everything in it too
]=]
return function(
	root: Instance,
	callback: (descendant: Instance, void: Void.Void) -> (),
	predicate: ((descendant: Instance) -> boolean)?
): Connection.Connection
	const void = Void.new()
	const voids: { [Instance]: Void.Void } = {}

	const function add(descendant: Instance)
		if voids[descendant] or (predicate and not predicate(descendant)) then
			return
		end

		const descendant_void = void:extend()
		voids[descendant] = descendant_void
		Thread(callback, descendant, descendant_void)
	end

	void:add(root.DescendantAdded:Connect(add))
	void:add(root.DescendantRemoving:Connect(function(descendant)
		const descendant_void = voids[descendant]
		if descendant_void then
			voids[descendant] = nil
			void:clean_item(descendant_void)
		end
	end))

	for _, descendant in root:GetDescendants() do
		add(descendant)
	end

	return Connection.new(void)
end

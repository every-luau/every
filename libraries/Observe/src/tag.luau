const CollectionService = game:GetService("CollectionService")

const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

--[=[
	@within Observe
	@function tag
	@param tag string
	@param callback (instance: Instance, void: Void) -> ()
	@param predicate ((instance: Instance) -> boolean)?
	@return Connection

	calls `callback` for every instance with `tag`, now and later, that
	`predicate` accepts. the void is cleaned when the tag is removed or the
	instance leaves the game
]=]
return function(
	tag: string,
	callback: (instance: Instance, void: Void.Void) -> (),
	predicate: ((instance: Instance) -> boolean)?
): Connection.Connection
	const void = Void.new()
	const voids: { [Instance]: Void.Void } = {}

	const function add(instance: Instance)
		if voids[instance] or (predicate and not predicate(instance)) then
			return
		end

		const instance_void = void:extend()
		voids[instance] = instance_void
		Thread(callback, instance, instance_void)
	end

	void:add(CollectionService:GetInstanceAddedSignal(tag):Connect(add))
	void:add(CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		const instance_void = voids[instance]
		if instance_void then
			voids[instance] = nil
			void:clean_item(instance_void)
		end
	end))

	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end

	return Connection.new(void)
end

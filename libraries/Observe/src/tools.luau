const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

const character = require("./character")
const children = require("./children")

--[=[
	@within Observe
	@function tools
	@param player Player
	@param callback (tool: Tool, void: Void) -> ()
	@param predicate ((tool: Tool) -> boolean)?
	@return Connection

	calls `callback` for every tool `player` has, in their backpack or held by
	their character, now and later, if `predicate` accepts it. moving a tool
	between the backpack and the character keeps it, and its void is cleaned
	once it goes anywhere else, like when it is dropped or the character
	respawns

	```lua
	Observe.tools(player, function(tool, void)
		void:add(tool.Activated:Connect(function()
			print(`{player.Name} used {tool.Name}`)
		end))
	end)
	```
]=]
return function(
	player: Player,
	callback: (tool: Tool, void: Void.Void) -> (),
	predicate: ((tool: Tool) -> boolean)?
): Connection.Connection
	const void = Void.new()
	const voids: { [Instance]: Void.Void } = {}
	-- the character tools can be held by, until it is removed
	local current: Model? = nil

	const function owns(parent: Instance?): boolean
		if parent == nil then
			return false
		end
		return parent == current or (parent:IsA("Backpack") and parent.Parent == player)
	end

	const function remove(tool: Instance)
		const tool_void = voids[tool]
		if tool_void then
			voids[tool] = nil
			void:clean_item(tool_void)
		end
	end

	const function add(instance: Instance)
		if voids[instance] or not instance:IsA("Tool") or (predicate and not predicate(instance :: Tool)) then
			return
		end

		const tool_void = void:extend()
		voids[instance] = tool_void

		-- fires when the tool moves, and when one of its ancestors does, like
		-- the backpack being replaced on respawn
		tool_void:add(instance.AncestryChanged:Connect(function()
			if not owns(instance.Parent) then
				remove(instance)
			end
		end))

		Thread(callback, instance :: Tool, tool_void)
	end

	const observed_character = character(player, function(model, character_void)
		current = model
		character_void:add(function()
			if current == model then
				current = nil
			end
			for tool in table.clone(voids) do
				if tool.Parent == model then
					remove(tool)
				end
			end
		end)

		character_void:add(model.ChildAdded:Connect(add))
		for _, child in model:GetChildren() do
			add(child)
		end
	end)
	void:add(observed_character :: any)

	const observed_backpacks = children(player, function(backpack, backpack_void)
		backpack_void:add(children(backpack, add) :: any)
	end, function(child)
		return child:IsA("Backpack")
	end)
	void:add(observed_backpacks :: any)

	return Connection.new(void)
end

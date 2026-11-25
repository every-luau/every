const Observable = require(script.Parent.Parent.Observable)
const Stream = require(script.Parent.Parent.Stream)
const Void = require(script.Parent.Parent.Void)

type Void = Void.Void

--[=[
	@within Observe
	@function tools
	@param player Player
	@return Observable<Tool>

	observes the tools `player` has, in their backpack or held by their
	character: a brio for each one now and later. moving a tool between the
	backpack and the character keeps its brio alive, and it dies once the tool
	goes anywhere else, like when it is dropped or the character respawns

	```lua
	Observe.tools(player):subscribe(function(brio)
		local void, tool = brio:to_void_and_value()
		void:add(tool.Activated:Connect(function()
			print(`{player.Name} used {tool.Name}`)
		end))
	end)
	```
]=]
return function(player: Player): Observable.Observable<Tool>
	return Observable.new(Stream.life(function(emit: (Tool, boolean) -> (), void: Void)
		-- what follows each tool, cleaned when it stops being owned
		const owned: { [Tool]: Void } = {}
		-- the character tools can be held by, until it is removed
		local current: Model? = nil

		const function owns(parent: Instance?): boolean
			if parent == nil then
				return false
			end
			return parent == current or (parent:IsA("Backpack") and parent.Parent == player)
		end

		const function remove(tool: Tool)
			const tool_void = owned[tool]
			if tool_void then
				owned[tool] = nil
				tool_void:clean()
				emit(tool, false)
			end
		end

		const function add(instance: Instance)
			if not instance:IsA("Tool") or owned[instance :: Tool] then
				return
			end
			const tool = instance :: Tool

			const tool_void = Void.new()
			owned[tool] = tool_void

			-- fires when the tool moves, and when one of its ancestors does, like
			-- the backpack being replaced on respawn
			tool_void:add(tool.AncestryChanged:Connect(function()
				if not owns(tool.Parent) then
					remove(tool)
				end
			end))

			emit(tool, true)
		end

		const function follow_children(parent: Instance): any
			return Stream.children(parent):listen(function(child: Instance, alive: boolean)
				if alive then
					add(child)
				end
			end)
		end

		void:add(Stream.character(player):each(function(model: Model?, character_void: Void)
			if model == nil then
				return
			end

			current = model
			character_void:add(function()
				if current == model then
					current = nil
				end
				for tool in table.clone(owned) do
					if tool.Parent == model then
						remove(tool)
					end
				end
			end)
			character_void:add(follow_children(model))
		end))

		void:add(Stream.children(player)
			:filter(function(child: Instance): boolean
				return child:IsA("Backpack")
			end)
			:each(function(backpack: Instance, backpack_void: Void)
				backpack_void:add(follow_children(backpack))
			end))

		void:add(function()
			for tool, tool_void in owned do
				owned[tool] = nil
				tool_void:clean()
			end
		end)
	end))
end

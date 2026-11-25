-- Streams of instances, and the methods that follow them.

const Void = require(script.Parent.Parent.Void)

const core = require("./core")
const sources = require("./sources")
const stream_types = require("./types")

type Void = Void.Void
type Stream<T> = stream_types.Stream<T>

const methods = core.methods
const new = core.new

--[=[
	@within Stream
	@function character
	@param player Player
	@return Stream<Model?>

	emits the character of `player` when subscribed, the new one each time it
	spawns, and nil when it is removed

	```lua
	Stream.character(player):each(function(character, void)
		void:add(attach_nametag(character))
	end, function(character)
		return character ~= nil
	end)
	```
]=]
const function character(player: Player): Stream<Model?>
	return new(function(emit: (Model?) -> (), void: Void)
		void:add(player.CharacterAdded:Connect(emit))
		void:add(player.CharacterRemoving:Connect(function()
			emit(nil)
		end))
		emit(player.Character)
	end)
end

-- the first child, or descendant when `deep`, of `root` named `name`, kept up
-- to date as instances are added, removed and renamed
const function first_in(root: Instance, name: string, class_name: string?, deep: boolean, label: string): Stream<Instance?>
	const added = if deep then root.DescendantAdded else root.ChildAdded
	const removed = if deep then root.DescendantRemoving else root.ChildRemoved

	-- the first match, skipping `leaving` and what is inside it, since
	-- DescendantRemoving fires before it is gone
	const function find(leaving: Instance?): Instance?
		const found = root:FindFirstChild(name, deep)
		if found == nil or leaving == nil or (found ~= leaving and not found:IsDescendantOf(leaving)) then
			return found
		end

		for _, candidate in if deep then root:GetDescendants() else root:GetChildren() do
			if candidate.Name == name and candidate ~= leaving and not candidate:IsDescendantOf(leaving) then
				return candidate
			end
		end
		return nil
	end

	return new(function(emit: (Instance?) -> (), void: Void)
		-- off while the current instances are added and after cleanup, so it
		-- searches once on subscribe and never emits once stopped
		local active = false
		local last: any = {}

		const function update(leaving: Instance?)
			if not active then
				return
			end

			const found = find(leaving)
			if found == last then
				return
			end
			if found and class_name and not found:IsA(class_name) then
				error(`[Stream.{label}] '{name}' in {root:GetFullName()} should be a {class_name}, got a {found.ClassName}`)
			end
			last = found
			emit(found)
		end

		-- follows the name of every instance inside `root`, since a rename can
		-- change the match
		const renamed: { [Instance]: RBXScriptConnection } = {}

		const function watch(instance: Instance)
			if renamed[instance] then
				return
			end
			renamed[instance] = instance:GetPropertyChangedSignal("Name"):Connect(function()
				update(nil)
			end)
			update(nil)
		end

		const function unwatch(instance: Instance)
			const connection = renamed[instance]
			if connection then
				renamed[instance] = nil
				connection:Disconnect()
				update(instance)
			end
		end

		-- connected first, so what changes while the current instances are
		-- watched isn't missed
		void:add(added:Connect(watch))
		void:add(removed:Connect(unwatch))
		for _, instance in if deep then root:GetDescendants() else root:GetChildren() do
			watch(instance)
		end

		active = true
		update(nil)

		void:add(function()
			active = false
			for _, connection in renamed do
				connection:Disconnect()
			end
			table.clear(renamed)
		end)
	end)
end

--[=[
	@within Stream
	@function child
	@param parent Instance
	@param name string
	@param class_name string?
	@return Stream<Instance?>
	@error "'...' in ... should be a ..., got a ..." -- the match isn't a `class_name`

	emits `parent:FindFirstChild(name)` when subscribed, and again when it
	changes because a child was added, removed or renamed

	```lua
	Stream.child(character, "Humanoid", "Humanoid"):listen(print)
	```
]=]
const function child(parent: Instance, name: string, class_name: string?): Stream<Instance?>
	return first_in(parent, name, class_name, false, "child")
end

--[=[
	@within Stream
	@function descendant
	@param root Instance
	@param name string
	@param class_name string?
	@return Stream<Instance?>
	@error "'...' in ... should be a ..., got a ..." -- the match isn't a `class_name`

	[Stream.child] searching every descendant, with
	`root:FindFirstChild(name, true)`
]=]
const function descendant(root: Instance, name: string, class_name: string?): Stream<Instance?>
	return first_in(root, name, class_name, true, "descendant")
end

-- the stream `project` returns for the latest instance, or nil while it is nil
const function follow(stream: Stream<any>, project: (instance: Instance) -> Stream<any>): any
	return stream:switch(function(instance: Instance?): Stream<any>
		return if instance then project(instance) else sources.of(nil)
	end)
end

--[=[
	@within Stream
	@method property
	@param name string
	@return Stream<any>

	[Stream.property] for the latest instance this stream emits, and nil while
	it emits nil

	```lua
	local health = Stream.character(player):child("Humanoid"):property("Health")
	```
]=]
function methods.property<T>(self: Stream<T>, name: string): any
	return follow(self, function(instance: Instance)
		return sources.property(instance, name)
	end)
end

--[=[
	@within Stream
	@method attribute
	@param name string
	@return Stream<any>

	[Stream.attribute] for the latest instance this stream emits, and nil while
	it emits nil
]=]
function methods.attribute<T>(self: Stream<T>, name: string): any
	return follow(self, function(instance: Instance)
		return sources.attribute(instance, name)
	end)
end

--[=[
	@within Stream
	@method child
	@param name string
	@param class_name string?
	@return Stream<Instance?>

	[Stream.child] for the latest instance this stream emits, and nil while it
	emits nil
]=]
function methods.child<T>(self: Stream<T>, name: string, class_name: string?): any
	return follow(self, function(instance: Instance)
		return child(instance, name, class_name)
	end)
end

--[=[
	@within Stream
	@method descendant
	@param name string
	@param class_name string?
	@return Stream<Instance?>

	[Stream.descendant] for the latest instance this stream emits, and nil while
	it emits nil
]=]
function methods.descendant<T>(self: Stream<T>, name: string, class_name: string?): any
	return follow(self, function(instance: Instance)
		return descendant(instance, name, class_name)
	end)
end

return {
	character = character,
	child = child,
	descendant = descendant,
}

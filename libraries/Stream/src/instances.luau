-- Streams and life streams of instances, and the methods that follow them.

const CollectionService = game:GetService("CollectionService")
const Players = game:GetService("Players")

const Void = require(script.Parent.Parent.Void)

const core = require("./core")
const sources = require("./sources")
const stream_types = require("./types")

type Void = Void.Void
type Stream<T> = stream_types.Stream<T>
type LifeStream<T> = stream_types.LifeStream<T>

const methods = core.methods
const life_methods = core.life_methods
const new = core.new
const new_life = core.new_life
const run = core.run
const subscribe = core.subscribe
const tidy = core.tidy
const tidy_each = core.tidy_each

-- a life stream of what `list` returns when subscribed, then of what `added`
-- and `removed` fire with. each item is only emitted alive once, and dead once
const function life_of<T>(list: () -> { T }, added: RBXScriptSignal, removed: RBXScriptSignal): LifeStream<T>
	return new_life(function(emit: (T, boolean) -> (), void: Void)
		const alive: { [T]: true } = {}

		const function add(item: T)
			if not alive[item] then
				alive[item] = true
				emit(item, true)
			end
		end

		-- connected first, so what changes while the current items are emitted
		-- isn't missed
		void:add(added:Connect(add))
		void:add(removed:Connect(function(item: T)
			if alive[item] then
				alive[item] = nil
				emit(item, false)
			end
		end))
		for _, item in list() do
			add(item)
		end
	end)
end

-- a life stream of the items of the life stream `project` returns for the
-- latest value of `stream`. the items of the last one die when it is replaced
const function switch_life(stream: Stream<any>, project: (value: any) -> LifeStream<any>?): LifeStream<any>
	return new_life(function(emit: (any, boolean) -> (), void: Void)
		void:add(tidy(stream, function(value: any, value_void: Void)
			const inner = if value ~= nil then project(value) else nil
			if inner == nil then
				return
			end

			const items: { [any]: true } = {}
			const source = subscribe(inner, function(item: any, alive: boolean)
				if alive and not items[item] then
					items[item] = true
					emit(item, true)
				elseif not alive and items[item] then
					items[item] = nil
					emit(item, false)
				end
			end)

			value_void:add(function()
				source:clean()
				for item in table.clone(items) do
					items[item] = nil
					emit(item, false)
				end
			end)
		end))
	end)
end

--[=[
	@within Stream
	@function players
	@return LifeStream<Player>

	every player in the game, alive until they leave

	```lua
	Stream.players():each(function(player, void)
		print(`{player.Name} joined`)
		void:add(function()
			print(`{player.Name} left`)
		end)
	end)
	```
]=]
const function players(): LifeStream<Player>
	return life_of(function()
		return Players:GetPlayers()
	end, Players.PlayerAdded, Players.PlayerRemoving)
end

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

--[=[
	@within Stream
	@function characters
	@return LifeStream<Model>

	the character of every player, alive from its spawn until it is removed or
	its player leaves
]=]
const function characters(): LifeStream<Model>
	return new_life(function(emit: (Model, boolean) -> (), void: Void)
		void:add(tidy_each(players(), function(player: Player, player_void: Void)
			player_void:add(tidy(character(player), function(model: Model?, character_void: Void)
				if model == nil then
					return
				end
				emit(model, true)
				character_void:add(function()
					emit(model, false)
				end)
			end))
		end))
	end)
end

--[=[
	@within Stream
	@function children
	@param parent Instance
	@return LifeStream<Instance>

	every child of `parent`, alive while it is a child

	```lua
	Stream.children(workspace.Doors):each(function(door, void)
		void:add(door.Touched:Connect(open))
	end)
	```
]=]
const function children(parent: Instance): LifeStream<Instance>
	return life_of(function()
		return parent:GetChildren()
	end, parent.ChildAdded, parent.ChildRemoved)
end

--[=[
	@within Stream
	@function descendants
	@param root Instance
	@return LifeStream<Instance>

	every descendant of `root`, alive while it is inside it. a big tree costs
	more than [Stream.children]
]=]
const function descendants(root: Instance): LifeStream<Instance>
	return life_of(function()
		return root:GetDescendants()
	end, root.DescendantAdded, root.DescendantRemoving)
end

--[=[
	@within Stream
	@function tagged
	@param tag string
	@param ancestor Instance?
	@return LifeStream<Instance>

	every instance with the CollectionService tag `tag`, alive while it has it.
	with `ancestor`, it is only alive while it is also inside `ancestor`

	```lua
	Stream.tagged("Door", workspace):each(function(door, void)
		void:add(door.Touched:Connect(open))
	end)
	```
]=]
const function tagged(tag: string, ancestor: Instance?): LifeStream<Instance>
	const anywhere: LifeStream<Instance> = life_of(function()
		return CollectionService:GetTagged(tag)
	end, CollectionService:GetInstanceAddedSignal(tag), CollectionService:GetInstanceRemovedSignal(tag))

	if ancestor == nil then
		return anywhere
	end

	return new_life(function(emit: (Instance, boolean) -> (), void: Void)
		void:add(tidy_each(anywhere, function(instance: Instance, instance_void: Void)
			local inside = instance:IsDescendantOf(ancestor)
			if inside then
				emit(instance, true)
			end

			const moved = instance.AncestryChanged:Connect(function()
				const now_inside = instance:IsDescendantOf(ancestor)
				if now_inside ~= inside then
					inside = now_inside
					emit(instance, now_inside)
				end
			end)

			instance_void:add(function()
				moved:Disconnect()
				if inside then
					inside = false
					emit(instance, false)
				end
			end)
		end))
	end)
end

-- the first child, or descendant when `deep`, of `root` named `name`, kept up
-- to date as instances are added, removed and renamed
const function first_in(root: Instance, name: string, class_name: string?, deep: boolean, label: string): Stream<Instance?>
	const items = if deep then descendants(root) else children(root)

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

		const source = tidy_each(items, function(instance: Instance, instance_void: Void)
			const name = subscribe(sources.property(instance, "Name"), function()
				update(nil)
			end)
			instance_void:add(function()
				name:clean()
				update(instance)
			end)
		end)

		active = true
		update(nil)

		void:add(function()
			active = false
			source:clean()
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

--[=[
	@within Stream
	@method children
	@return LifeStream<Instance>

	[Stream.children] of the latest instance this stream emits. its children die
	when it is replaced, and nothing is alive while it is nil

	```lua
	Stream.character(player):children():each(function(part, void)
		print(part)
	end)
	```
]=]
function methods.children<T>(self: Stream<T>): LifeStream<Instance>
	return switch_life(self :: any, children)
end

--[=[
	@within Stream
	@method descendants
	@return LifeStream<Instance>

	[Stream.descendants] of the latest instance this stream emits
]=]
function methods.descendants<T>(self: Stream<T>): LifeStream<Instance>
	return switch_life(self :: any, descendants)
end

--[=[
	@within LifeStream
	@method filter
	@param predicate (item: T) -> boolean
	@return LifeStream<T>

	keeps the items `predicate` accepts when they join

	```lua
	local parts = Stream.descendants(workspace):filter(function(instance)
		return instance:IsA("BasePart")
	end)
	```
]=]
function life_methods.filter<T>(self: LifeStream<T>, predicate: (item: T) -> boolean): LifeStream<T>
	return new_life(function(emit: (T, boolean) -> (), void: Void)
		const accepted: { [T]: true } = {}
		run(self, function(item: T, alive: boolean)
			if alive then
				if not accepted[item] and predicate(item) then
					accepted[item] = true
					emit(item, true)
				end
			elseif accepted[item] then
				accepted[item] = nil
				emit(item, false)
			end
		end, void)
	end)
end

--[=[
	@within LifeStream
	@method named
	@param name string
	@return LifeStream<T>

	keeps the instances named `name`, following renames: a rename is like
	leaving or joining

	```lua
	Stream.children(model):named("Hitbox"):each(function(hitbox, void)
		void:add(hitbox.Touched:Connect(on_hit))
	end)
	```
]=]
function life_methods.named<T>(self: LifeStream<T>, name: string): LifeStream<T>
	return new_life(function(emit: (T, boolean) -> (), void: Void)
		void:add(tidy_each(self, function(item: T, item_void: Void)
			local alive = false
			const name = subscribe(sources.property(item :: any, "Name"), function(current: string)
				const matches = current == name
				if matches ~= alive then
					alive = matches
					emit(item, matches)
				end
			end)

			item_void:add(function()
				name:clean()
				if alive then
					alive = false
					emit(item, false)
				end
			end)
		end))
	end)
end

--[=[
	@within LifeStream
	@method count
	@return Stream<number>

	emits how many items are alive when subscribed and each time it changes

	```lua
	Stream.players():count():listen(function(count)
		print(`{count} players`)
	end)
	```
]=]
function life_methods.count<T>(self: LifeStream<T>): any
	return new(function(emit: (number) -> (), void: Void)
		const items: { [T]: true } = {}
		local count = 0
		local ready = false

		run(self, function(item: T, alive: boolean)
			if alive and not items[item] then
				items[item] = true
				count += 1
			elseif not alive and items[item] then
				items[item] = nil
				count -= 1
			else
				return
			end
			if ready then
				emit(count)
			end
		end, void)

		ready = true
		emit(count)
	end)
end

return {
	players = players,
	character = character,
	characters = characters,
	children = children,
	descendants = descendants,
	tagged = tagged,
	child = child,
	descendant = descendant,
}

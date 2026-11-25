--[=[
	@class Mount
	
	# TO REWORK

	Mount builds instances out of props, where any property can be a [Stream]

	calling the module applies props to an instance you already have, and
	[Mount.create] makes a new one. a prop given a stream or a ValueBase follows
	it, so the instance stays up to date on its own. everything a mount starts
	goes away once its [Connection] is disconnected

	```lua
	local Mount = require(path.to.Mount)
	local Stream = require(path.to.Stream)

	local count = Stream.state(0)

	local connection = Mount(Instance.new("TextButton"), {
		Size = UDim2.fromOffset(200, 50),
		Text = count:map(function(count)
			return `clicked {count} times`
		end),
		Activated = function()
			count:update(function(n)
				return n + 1
			end)
		end,
		Parent = screen_gui,
	})
	```
]=]

const Connection = require(script.Parent.Connection)
const Stream = require(script.Parent.Stream)
const Void = require(script.Parent.Void)

export type Connection = Connection.Connection
export type Void = Void.Void
type Stream<T> = Stream.Stream<T>

-- what the module is called with, see [Mount.apply]
export type Props = { [any]: any }

const function is_instance_of(value: any, class_name: string): boolean
	return typeof(value) == "Instance" and (value :: Instance):IsA(class_name)
end

-- what calling a handler key's value does: a function as is, a ValueBase or a
-- State is set
const function to_handler(target: any, what: string): (...any) -> ...any
	if type(target) == "function" then
		return target
	elseif is_instance_of(target, "ValueBase") then
		return function(value: any)
			target.Value = value
		end
	elseif Stream.is(target) and type(target.set) == "function" then
		return function(value: any)
			(target :: any):set(value)
		end
	end
	error(`[Mount] {what} needs a function, a ValueBase or a state, got a {typeof(target)}`, 4)
end

-- whether `value` changes over time, so a property is set to each value
const function is_dynamic(value: any): boolean
	return Stream.is(value) or is_instance_of(value, "ValueBase")
end

-- a stream of the instance `source` stands for: an instance, the `Value` of an
-- ObjectValue, or the latest instance of a stream
local function nested_instance(source: any): Stream<any>
	if source == nil or (typeof(source) == "Instance" and not is_instance_of(source, "ObjectValue")) then
		return Stream.of(source)
	elseif is_instance_of(source, "ObjectValue") then
		return Stream.property(source, "Value")
	elseif Stream.is(source) then
		return source:switch(nested_instance)
	end
	error(`[Mount] expected an Instance or a stream of them, got a {typeof(source)}`, 3)
end

-- calls `listener` with every value of `stream` until `void` is cleaned
const function follow(stream: Stream<any>, listener: (...any) -> (), void: Void)
	void:add(stream:listen(listener))
end

-- applies `props` to `instance`, adding to `void` what undoes them
local function apply_to(instance: Instance, props: Props, void: Void)
	const target = instance :: any
	local parent: any = nil

	for key, value in props do
		if key == "Parent" then
			parent = value
			continue
		end

		if type(key) == "function" then
			-- an output key like Mount.output, called with the instance
			const output = (key :: (Instance) -> Stream<any>)(instance)
			follow(output, to_handler(value, "an output key"), void)
		elseif Stream.is(key) then
			follow(key, to_handler(value, "a stream key"), void)
		elseif typeof(key) == "RBXScriptSignal" then
			void:add((key :: RBXScriptSignal):Connect(to_handler(value, "a signal key")))
		elseif type(key) == "number" then
			if typeof(value) == "Instance" then
				value.Parent = instance
				void:add(value)
			elseif Stream.is(value) then
				follow(
					nested_instance(value),
					function(child: Instance?)
						if child then
							child.Parent = instance
						end
					end,
					void
				)
			elseif type(value) == "table" then
				apply_to(instance, value, void)
			else
				error(`[Mount] a child must be an Instance, a stream or a table, got a {typeof(value)}`, 3)
			end
		elseif key == "instance" then
			const cleanup = to_handler(value, "['instance']")(instance)
			if cleanup ~= nil then
				void:add(cleanup)
			end
		elseif key == "cleanup" then
			void:add(value)
		elseif typeof(target[key]) == "RBXScriptSignal" then
			void:add(target[key]:Connect(to_handler(value, `{instance.ClassName}.{key}`)))
		elseif is_dynamic(value) then
			follow(
				Stream.from(value),
				function(new: any)
					target[key] = new
				end,
				void
			)
		else
			target[key] = value
		end
	end

	if parent == nil then
		return
	elseif typeof(parent) == "Instance" and not is_instance_of(parent, "ObjectValue") then
		instance.Parent = parent
	else
		follow(
			nested_instance(parent),
			function(new_parent: Instance?)
				instance.Parent = new_parent
			end,
			void
		)
	end
end

--[=[
	@within Mount
	@function apply
	@param instance Instance
	@param props { [any]: any }
	@return Connection

	applies `props` to `instance`, and returns a [Connection] that undoes them.
	calling the module does the same. what an entry does depends on its key:

	- a property name sets it to the value, or to every value of a stream or a
	  ValueBase
	- an event name connects the value to it: a function, a ValueBase or a
	  `Stream.state` to set
	- a number parents the value under `instance`: an instance, a stream of
	  instances, or a table of props applied to `instance` too
	- `Parent` is set last, once everything else is in place. it can be an
	  instance, an ObjectValue whose `Value` to follow or a stream of instances
	- `instance` calls the value with `instance`, and adds what it returns to
	  a [Void]
	- `cleanup` adds the value to a [Void], so anything `void:add` takes works
	- a stream or a signal connects the value to it
	- a function is called with `instance` for a stream to connect the value
	  to, see [Mount.output]

	children given as instances are destroyed when the connection is
	disconnected

	```lua
	local hovered = Stream.state(false)
	local connection = Mount(frame, {
		BackgroundColor3 = hovered:map(function(is_hovered)
			return if is_hovered then BLUE else GRAY
		end),
		MouseEnter = function()
			hovered:set(true)
		end,
		MouseLeave = function()
			hovered:set(false)
		end,
		Mount.create("TextLabel", { Text = "hi" }),
	})
	```
]=]
const function apply(instance: Instance, props: Props): Connection
	assert(typeof(instance) == "Instance", `[Mount] needs an Instance, got a {typeof(instance)}`)

	const void = Void.new()
	apply_to(instance, props, void)
	return Connection.new(void)
end

--[=[
	@within Mount
	@function create
	@param class_name string
	@param props { [any]: any }
	@return Stream<Instance>

	a stream that creates a `class_name` instance when subscribed, applies
	`props` to it like [Mount.apply] and emits it. ending the subscription
	undoes the props and destroys the instance. as a child in props, it is
	created along with its parent

	```lua
	Mount.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		Parent = screen_gui,
	}):listen(function(frame)
		print(frame)
	end)
	```
]=]
const function create(class_name: string, props: Props): Stream<Instance>
	return Stream.new(function(emit: (Instance) -> (), void: Void)
		const instance = void:add(Instance.new(class_name))
		apply_to(instance, props, void)
		emit(instance)
	end)
end

--[=[
	@within Mount
	@function output
	@param name string
	@return (Instance) -> Stream<any>

	a props key for the property `name` of the instance: its value is called
	with every value of the property

	```lua
	local absolute_size = Mount.output("AbsoluteSize")
	Mount(frame, {
		[absolute_size] = function(size)
			print(size)
		end,
	})
	```
]=]
const function output(name: string): (Instance) -> Stream<any>
	return function(instance: Instance): Stream<any>
		return Stream.property(instance, name)
	end
end

return table.freeze(
	setmetatable(
		{
			apply = apply,
			create = create,
			output = output,
		},
		{
			__call = function(_, instance: Instance, props: Props): Connection
				return apply(instance, props)
			end,
		}
	)
)

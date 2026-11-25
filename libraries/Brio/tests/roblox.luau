--!strict
-- Minimal stand-in for the Roblox globals Stream uses, since lest's native
-- backend has none:
--
-- - `Instance.new` makes fake instances that know a few classes, keep a tree
--   with the signals that go with it, and fire property changed signals
-- - `task.delay` and `os.clock` follow a fake clock moved with `advance`
-- - `players` and the tag helpers drive Players and CollectionService
-- - `warn` records what it is given in `warnings`

-- CollectionService's helpers, defined with it further down
local add_tag: (instance: any, name: string) -> ()
local remove_tag: (instance: any, name: string) -> ()

-- the values `typeof` sees as Roblox types
local kinds: { [any]: string } = setmetatable({}, { __mode = "k" }) :: any

export type Signal = {
	Connect: (self: Signal, listener: (...any) -> ()) -> any,
	Once: (self: Signal, listener: (...any) -> ()) -> any,
	fire: (...any) -> (),
	count: () -> number,
}

local function signal(): Signal
	-- one entry per connection, so the same function connected twice counts twice
	local connections: { [{ (...any) -> () }]: true } = {}
	local self = {}

	local function connect(listener: (...any) -> ())
		local entry = { listener }
		connections[entry] = true
		local connection = {
			Connected = true,
		}
		function connection.Disconnect(_)
			connection.Connected = false
			connections[entry] = nil
		end
		kinds[connection] = "RBXScriptConnection"
		return connection
	end

	function self.Connect(_, listener: (...any) -> ())
		return connect(listener)
	end
	function self.Once(_, listener: (...any) -> ())
		local connection: any
		connection = connect(function(...)
			connection:Disconnect()
			listener(...)
		end)
		return connection
	end
	function self.fire(...: any)
		for entry in table.clone(connections) do
			if connections[entry] then
				entry[1](...)
			end
		end
	end
	function self.count(): number
		local total = 0
		for _ in connections do
			total += 1
		end
		return total
	end

	kinds[self] = "RBXScriptSignal"
	return self :: any
end

-- the clock `os.clock` reads and delayed threads wait on
local now = 0
local scheduled: { { thread: thread, due: number, args: { n: number, [number]: any } } } = {}

local function resume(thread: thread, ...: any)
	local ok, message = coroutine.resume(thread, ...)
	if not ok then
		error(message, 0)
	end
end

local function to_thread(callback: thread | (...any) -> ...any): thread
	return if type(callback) == "thread" then callback else coroutine.create(callback)
end

local function spawn(callback: thread | (...any) -> ...any, ...: any): thread
	local thread = to_thread(callback)
	resume(thread, ...)
	return thread
end

local function delay(seconds: number?, callback: thread | (...any) -> ...any, ...: any): thread
	local thread = to_thread(callback)
	table.insert(scheduled, { thread = thread, due = now + (seconds or 0), args = table.pack(...) })
	return thread
end

local function defer(callback: thread | (...any) -> ...any, ...: any): thread
	return delay(0, callback, ...)
end

local function cancel(thread: thread)
	for index = #scheduled, 1, -1 do
		if scheduled[index].thread == thread then
			table.remove(scheduled, index)
		end
	end
	if coroutine.status(thread) == "suspended" then
		coroutine.close(thread)
	end
end

-- moves the clock forward and runs the threads that are due, in order
local function advance(seconds: number?)
	now += seconds or 0
	while true do
		local next_index: number? = nil
		for index, entry in scheduled do
			if entry.due <= now and (next_index == nil or entry.due < scheduled[next_index].due) then
				next_index = index
			end
		end
		if next_index == nil then
			return
		end
		local entry = table.remove(scheduled, next_index) :: any
		resume(entry.thread, table.unpack(entry.args, 1, entry.args.n))
	end
end

local function pending(): number
	return #scheduled
end

-- the classes `Instance.new` knows: their properties with defaults, their
-- events, and what else they are
type Class = { properties: { [string]: any }, events: { string }, is: { string } }

local classes: { [string]: Class } = {
	Folder = { properties = {}, events = {}, is = {} },
	Model = { properties = {}, events = {}, is = { "PVInstance" } },
	Part = {
		properties = { Transparency = 0, Color = "gray" },
		events = { "Touched" },
		is = { "BasePart", "PVInstance" },
	},
	Humanoid = { properties = { Health = 100 }, events = { "Died" }, is = {} },
	Player = {
		properties = { Character = false, UserId = 0 },
		events = { "CharacterAdded", "CharacterRemoving" },
		is = {},
	},
	Camera = { properties = { FieldOfView = 70 }, events = {}, is = {} },
	Frame = {
		properties = { Size = "0,0", BackgroundTransparency = 0, AbsoluteSize = "0,0" },
		events = { "MouseEnter", "MouseLeave" },
		is = { "GuiObject" },
	},
	TextLabel = {
		properties = { Size = "0,0", Text = "Label", BackgroundTransparency = 0 },
		events = { "MouseEnter", "MouseLeave" },
		is = { "GuiObject" },
	},
	TextButton = {
		properties = { Size = "0,0", Text = "Button", BackgroundTransparency = 0 },
		events = { "MouseEnter", "MouseLeave", "Activated" },
		is = { "GuiObject", "GuiButton" },
	},
	IntValue = { properties = { Value = 0 }, events = {}, is = { "ValueBase" } },
	StringValue = { properties = { Value = "" }, events = {}, is = { "ValueBase" } },
	ObjectValue = { properties = { Value = false }, events = {}, is = { "ValueBase" } },
}

-- properties set to `false` in `classes` stand for nil, since nil can't be a
-- table value
local NIL = false

local function new(class_name: string): any
	local class = classes[class_name]
	assert(class, `the fake Instance.new doesn't know {class_name}`)

	local properties: { [string]: any } = { Name = class_name }
	for name, default in class.properties do
		properties[name] = if default == NIL then nil else default
	end

	local known: { [string]: true } = { Name = true, Parent = true }
	for name in class.properties do
		known[name] = true
	end

	local children: { any } = {}
	local attributes: { [string]: any } = {}
	local changed_signals: { [string]: Signal } = {}
	local attribute_signals: { [string]: Signal } = {}
	local destroyed = false

	local signals: { [string]: Signal } = {
		Changed = signal(),
		ChildAdded = signal(),
		ChildRemoved = signal(),
		DescendantAdded = signal(),
		DescendantRemoving = signal(),
		AncestryChanged = signal(),
		Destroying = signal(),
	}
	for _, event in class.events do
		signals[event] = signal()
	end

	local self: any = setmetatable({}, {})
	local methods: { [string]: any } = {}

	local function descendants(): { any }
		local list = {}
		for _, child in children do
			table.insert(list, child)
			for _, descendant in child:GetDescendants() do
				table.insert(list, descendant)
			end
		end
		return list
	end

	-- fires the property's signals
	local function changed(name: string)
		local value = if name == "Parent" then properties.Parent else properties[name]
		if changed_signals[name] then
			changed_signals[name].fire()
		end
		if table.find(class.is, "ValueBase") and name == "Value" then
			signals.Changed.fire(value)
		elseif not table.find(class.is, "ValueBase") then
			signals.Changed.fire(name)
		end
	end

	local function ancestry_changed(source: any)
		signals.AncestryChanged.fire(source, source.Parent)
		for _, child in children do
			(child :: any)._ancestry_changed(source)
		end
	end

	local function set_parent(parent: any)
		local old = properties.Parent
		if old == parent then
			return
		end
		assert(not destroyed, "can't set the Parent of a destroyed instance")
		assert(parent == nil or (parent ~= self and not parent:IsDescendantOf(self)), "can't parent an instance under itself")

		if old then
			-- DescendantRemoving fires on the ancestors before the instance leaves
			local ancestor = old
			while ancestor do
				ancestor._descendant_removing(self)
				for _, descendant in descendants() do
					ancestor._descendant_removing(descendant)
				end
				ancestor = ancestor.Parent
			end
			old._remove_child(self)
		end

		properties.Parent = parent

		if parent then
			(parent :: any)._add_child(self)
		end
		changed("Parent")
		ancestry_changed(self)

		if parent then
			local ancestor = properties.Parent
			while ancestor do
				ancestor._descendant_added(self)
				for _, descendant in descendants() do
					ancestor._descendant_added(descendant)
				end
				ancestor = ancestor.Parent
			end
		end
	end

	function methods._add_child(child: any)
		table.insert(children, child)
		signals.ChildAdded.fire(child)
	end
	function methods._remove_child(child: any)
		table.remove(children, table.find(children, child) :: number)
		signals.ChildRemoved.fire(child)
	end
	function methods._descendant_added(descendant: any)
		signals.DescendantAdded.fire(descendant)
	end
	function methods._descendant_removing(descendant: any)
		signals.DescendantRemoving.fire(descendant)
	end
	methods._ancestry_changed = ancestry_changed

	function methods.IsA(_, name: string): boolean
		return name == class_name or name == "Instance" or table.find(class.is, name) ~= nil
	end
	function methods.GetChildren(_): { any }
		return table.clone(children)
	end
	function methods.GetDescendants(_): { any }
		return descendants()
	end
	function methods.FindFirstChild(_, name: string, recursive: boolean?): any
		for _, child in if recursive then descendants() else children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods.IsDescendantOf(_, ancestor: any): boolean
		local current = properties.Parent
		while current do
			if current == ancestor then
				return true
			end
			current = current.Parent
		end
		return false
	end
	function methods.GetFullName(_): string
		local parent = properties.Parent
		return if parent then `{parent:GetFullName()}.{properties.Name}` else properties.Name
	end
	function methods.GetPropertyChangedSignal(_, name: string): Signal
		if not known[name] then
			error(`{name} is not a valid property name.`)
		end
		if not changed_signals[name] then
			changed_signals[name] = signal()
		end
		return changed_signals[name]
	end
	function methods.GetAttribute(_, name: string): any
		return attributes[name]
	end
	function methods.SetAttribute(_, name: string, value: any)
		if attributes[name] ~= value then
			attributes[name] = value
			if attribute_signals[name] then
				attribute_signals[name].fire()
			end
		end
	end
	function methods.GetAttributeChangedSignal(_, name: string): Signal
		if not attribute_signals[name] then
			attribute_signals[name] = signal()
		end
		return attribute_signals[name]
	end
	function methods.AddTag(_, name: string)
		add_tag(self, name)
	end
	function methods.RemoveTag(_, name: string)
		remove_tag(self, name)
	end
	function methods.Destroy(_)
		if destroyed then
			return
		end
		signals.Destroying.fire()
		for index = #children, 1, -1 do
			children[index]:Destroy()
		end
		set_parent(nil)
		destroyed = true
	end

	local metatable = getmetatable(self)
	metatable.__index = function(_, key: string): any
		if key == "ClassName" then
			return class_name
		elseif key == "destroyed" then
			return destroyed
		elseif key == "Parent" or known[key] then
			return properties[key]
		elseif signals[key] then
			return signals[key]
		elseif methods[key] then
			return methods[key]
		end
		error(`{key} is not a valid member of {class_name}`, 2)
	end
	metatable.__newindex = function(_, key: string, value: any)
		if key == "Parent" then
			set_parent(value)
		elseif known[key] then
			if properties[key] ~= value then
				properties[key] = value
				changed(key)
			end
		else
			error(`{key} is not a valid member of {class_name}`, 2)
		end
	end
	metatable.__tostring = function()
		return properties.Name
	end

	kinds[self] = "Instance"
	return self
end

-- CollectionService, with the instances carrying each tag
local tagged: { [string]: { any } } = {}
local tag_added: { [string]: Signal } = {}
local tag_removed: { [string]: Signal } = {}

local function tag(name: string)
	if not tagged[name] then
		tagged[name] = {}
		tag_added[name] = signal()
		tag_removed[name] = signal()
	end
end

function add_tag(instance: any, name: string)
	tag(name)
	if not table.find(tagged[name], instance) then
		table.insert(tagged[name], instance)
		tag_added[name].fire(instance)
	end
end

function remove_tag(instance: any, name: string)
	tag(name)
	local index = table.find(tagged[name], instance)
	if index then
		table.remove(tagged[name], index)
		tag_removed[name].fire(instance)
	end
end

local CollectionService = {
	GetTagged = function(_, name: string): { any }
		tag(name)
		return table.clone(tagged[name])
	end,
	GetInstanceAddedSignal = function(_, name: string): Signal
		tag(name)
		return tag_added[name]
	end,
	GetInstanceRemovedSignal = function(_, name: string): Signal
		tag(name)
		return tag_removed[name]
	end,
}

-- Players, with `join` and `leave` to change who is in the game
local players: { any } = {}
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function(_): { any }
		return table.clone(players)
	end,
}

local function join(name: string): any
	local player = new("Player")
	player.Name = name
	table.insert(players, player)
	Players.PlayerAdded.fire(player)
	return player
end

local function leave(player: any)
	Players.PlayerRemoving.fire(player)
	table.remove(players, table.find(players, player) :: number)
end

local warnings: { string } = {}

local globals = _G :: any
local builtin_typeof = typeof
globals.typeof = function(value: any): string
	return kinds[value] or builtin_typeof(value)
end
globals.warn = function(...: any)
	local parts = {}
	for index = 1, select("#", ...) do
		table.insert(parts, tostring((select(index, ...))))
	end
	table.insert(warnings, table.concat(parts, " "))
end
globals.Instance = { new = new }
globals.task = { spawn = spawn, defer = defer, delay = delay, cancel = cancel }
globals.os = setmetatable({
	clock = function(): number
		return now
	end,
}, { __index = os })
globals.game = {
	-- Void cleans instances with `game.Destroy`
	Destroy = function(instance: any)
		instance:Destroy()
	end,
	GetService = function(_, name: string): any
		if name == "CollectionService" then
			return CollectionService
		elseif name == "Players" then
			return Players
		end
		error(`the fake game has no {name}`)
	end,
}

-- `script.Parent.Parent.Name` resolves to the path of the `Name` library next
-- to this one, the same way package managers put dependencies next to each
-- other. every module of Brio is one folder away from the libraries
local parent = setmetatable({}, {
	__index = function(_, name: string)
		return `../../{name}/src`
	end,
}) :: any
parent.Parent = parent
globals.script = { Parent = parent }

return {
	new = new,
	signal = signal,
	advance = advance,
	pending = pending,
	join = join,
	leave = leave,
	add_tag = add_tag,
	remove_tag = remove_tag,
	warnings = warnings,
}

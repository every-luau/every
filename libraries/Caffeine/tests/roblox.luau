--!strict
-- Minimal stand-in for the Roblox globals the library and its dependencies use,
-- since lest's native backend has none. `RunService.PreSimulation` only fires on
-- `step`, delayed callbacks only run on `flush`, and `part` makes a fake
-- BasePart that records its impulses. `side.server` is the side the library
-- sees when it is required, and tags go through a fake CollectionService.
--
-- `script.Parent.Name` resolves to the path of the `Name` library next to this
-- one, the same way package managers put dependencies next to each other.

local queued: { { thread: thread, args: { any } } } = {}

local function spawn(callback: thread | (...any) -> ...any, ...: any): thread
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	local ok, message = coroutine.resume(thread, ...)

	if not ok then
		error(message, 0)
	end

	return thread
end

local function queue(callback: thread | (...any) -> ...any, ...: any): thread
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	table.insert(queued, { thread = thread, args = { ... } })
	return thread
end

local function delay(_seconds: number, callback: (...any) -> ...any, ...: any): thread
	return queue(callback, ...)
end

local function flush()
	local entries = table.clone(queued)
	table.clear(queued)
	for _, entry in entries do
		spawn(entry.thread, table.unpack(entry.args))
	end
end

-- the values `typeof` calls RBXScriptConnections and Instances
local rbx_connections: { [any]: true } = setmetatable({}, { __mode = "k" }) :: any
local instances: { [any]: true } = setmetatable({}, { __mode = "k" }) :: any

type FakeSignal = {
	Connect: (self: FakeSignal, listener: (...any) -> ()) -> any,
	fire: (...any) -> (),
	count: () -> number,
}

local function signal(): FakeSignal
	local listeners: { [(...any) -> ()]: true } = {}

	local self = {}
	function self.Connect(_, listener: (...any) -> ())
		-- a fresh function per connection, so connecting the same listener twice counts twice
		local wrapped = function(...)
			listener(...)
		end
		listeners[wrapped] = true
		local connection = {
			Disconnect = function(_)
				listeners[wrapped] = nil
			end,
		}
		rbx_connections[connection] = true
		return connection
	end
	function self.fire(...: any)
		for listener in table.clone(listeners) do
			listener(...)
		end
	end
	function self.count(): number
		local total = 0
		for _ in listeners do
			total += 1
		end
		return total
	end

	return self :: any
end

local PreSimulation = signal()

-- fires PreSimulation once
local function step()
	PreSimulation.fire(1 / 60)
end

-- which side the library thinks it runs on, read when it is required
local side = { server = true }

-- the instances carrying each tag, and the signals CollectionService fires for it
local tagged: { [string]: { [any]: true } } = {}
local tag_added: { [string]: FakeSignal } = {}
local tag_removed: { [string]: FakeSignal } = {}

local function tag(name: string)
	if not tagged[name] then
		tagged[name] = {}
		tag_added[name] = signal()
		tag_removed[name] = signal()
	end
end

local CollectionService = {
	GetTagged = function(_, name: string): { any }
		tag(name)
		local list = {}
		for instance in tagged[name] do
			table.insert(list, instance)
		end
		return list
	end,
	GetInstanceAddedSignal = function(_, name: string)
		tag(name)
		return tag_added[name]
	end,
	GetInstanceRemovedSignal = function(_, name: string)
		tag(name)
		return tag_removed[name]
	end,
}

local function add_tag(instance: any, name: string)
	tag(name)
	if not tagged[name][instance] then
		tagged[name][instance] = true
		tag_added[name].fire(instance)
	end
end

local function remove_tag(instance: any, name: string)
	tag(name)
	if tagged[name][instance] then
		tagged[name][instance] = nil
		tag_removed[name].fire(instance)
	end
end

local function has_tag(instance: any, name: string): boolean
	tag(name)
	return tagged[name][instance] == true
end

type Vector = { X: number, Y: number, Z: number }

local vector_meta = {}
local function vector(x: number?, y: number?, z: number?): Vector
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vector_meta) :: any
end
vector_meta.__mul = function(a: Vector, b: number): Vector
	return vector(a.X * b, a.Y * b, a.Z * b)
end
vector_meta.__unm = function(a: Vector): Vector
	return vector(-a.X, -a.Y, -a.Z)
end

export type Part = {
	Anchored: boolean,
	AssemblyMass: number,
	AssemblyRootPart: Part?,
	impulses: { Vector },
	Destroying: FakeSignal,
	IsA: (self: Part, class: string) -> boolean,
	ApplyImpulse: (self: Part, impulse: Vector) -> (),
	AddTag: (self: Part, name: string) -> (),
	RemoveTag: (self: Part, name: string) -> (),
	Destroy: (self: Part) -> (),
}

-- a fake BasePart that records each impulse it gets. it is its own assembly's
-- root, or welded to `root` when given
local function part(root: Part?): Part
	local self = {
		Anchored = false,
		AssemblyMass = 1,
		impulses = {},
		Destroying = signal(),
	}
	self.AssemblyRootPart = root or self
	function self.IsA(_, class: string): boolean
		return class == "BasePart" or class == "Instance"
	end
	function self.ApplyImpulse(_, impulse: Vector)
		table.insert(self.impulses, impulse)
	end
	function self.AddTag(_, name: string)
		add_tag(self, name)
	end
	function self.RemoveTag(_, name: string)
		remove_tag(self, name)
	end
	function self.Destroy(_)
		self.Destroying.fire()
		for name in tagged do
			remove_tag(self, name)
		end
	end
	instances[self] = true
	return self :: any
end

-- a fake Folder, an Instance that is not a part
local function folder()
	local self = {}
	function self.IsA(_, class: string): boolean
		return class == "Folder" or class == "Instance"
	end
	instances[self] = true
	return self
end

-- a fake Model holding `descendants`, with `add` and `remove` to change them
local function model(descendants: { any })
	local self = {
		DescendantAdded = signal(),
		DescendantRemoving = signal(),
	}
	function self.IsA(_, class: string): boolean
		return class == "Model" or class == "Instance"
	end
	function self.GetDescendants(_)
		return table.clone(descendants)
	end
	function self.add(descendant: any)
		table.insert(descendants, descendant)
		self.DescendantAdded.fire(descendant)
	end
	function self.remove(descendant: any)
		self.DescendantRemoving.fire(descendant)
		table.remove(descendants, table.find(descendants, descendant) :: number)
	end
	instances[self] = true
	return self
end

local RunService = {
	PreSimulation = PreSimulation,
	IsServer = function(_): boolean
		return side.server
	end,
	IsClient = function(_): boolean
		return not side.server
	end,
}

local globals = _G :: any
local builtin_typeof = typeof
globals.typeof = function(value: any): string
	if rbx_connections[value] then
		return "RBXScriptConnection"
	elseif instances[value] then
		return "Instance"
	end
	return builtin_typeof(value)
end
globals.Vector3 = { new = vector }
globals.task = { spawn = spawn, defer = queue, delay = delay }
globals.game = {
	GetService = function(_, name: string)
		if name == "RunService" then
			return RunService
		elseif name == "CollectionService" then
			return CollectionService
		end
		-- services Observe reads when it is required, never used by Caffeine
		return {}
	end,
}
-- `script.Parent.Parent` is `script.Parent`, since every source file is one
-- folder away from the libraries, whether it is the library or one of the
-- modules inside it like Observe's
local parent = setmetatable({}, {
	__index = function(_, name: string)
		return `../../{name}/src`
	end,
}) :: any
parent.Parent = parent
globals.script = { Parent = parent }

return {
	flush = flush,
	step = step,
	part = part,
	model = model,
	folder = folder,
	side = side,
	add_tag = add_tag,
	remove_tag = remove_tag,
	has_tag = has_tag,
	-- how many PreSimulation listeners are connected
	listeners = PreSimulation.count,
}

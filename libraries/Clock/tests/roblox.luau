--!nonstrict
-- Minimal stand-in for the Roblox engine the library and its dependencies use,
-- since lest's native backend has none: a server time moved by `advance`, delays
-- that run when that time reaches them, Heartbeat, and folders with attributes.
--
-- the server and a client share one process here. `set_server(false)` makes the
-- library act as a client, which then reads the folders the server made.
--
-- `script.Parent.Name` resolves to the path of the `Name` library next to this
-- one, the same way package managers put dependencies next to each other.

local server_time = 1000
local is_server = true

-- Signals

-- the connections Connect returns, so `typeof` can call them RBXScriptConnections
local rbx_connections = setmetatable({}, { __mode = "k" })

local function signal()
	local listeners = {}
	local self = {}

	function self:Connect(listener)
		listeners[listener] = true
		local connection = {
			Disconnect = function()
				listeners[listener] = nil
			end,
		}
		rbx_connections[connection] = true
		return connection
	end

	function self:fire(...)
		for listener in table.clone(listeners) do
			listener(...)
		end
	end

	function self:count()
		local count = 0
		for _ in listeners do
			count += 1
		end
		return count
	end

	return self
end

-- Tasks

local delayed = {}
local deferred = {}

local function resume(thread, ...)
	local ok, message = coroutine.resume(thread, ...)
	if not ok then
		error(message, 0)
	end
end

local function spawn(callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	resume(thread, ...)
	return thread
end

local function defer(callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	table.insert(deferred, { thread = thread, args = table.pack(...) })
	return thread
end

local function delay(seconds, callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	table.insert(delayed, { at = server_time + (seconds or 0), thread = thread, args = table.pack(...) })
	return thread
end

local function cancel(thread)
	for index, entry in delayed do
		if entry.thread == thread then
			table.remove(delayed, index)
			break
		end
	end
	for index, entry in deferred do
		if entry.thread == thread then
			table.remove(deferred, index)
			break
		end
	end
	if coroutine.status(thread) == "suspended" then
		coroutine.close(thread)
	end
end

local function flush()
	while #deferred > 0 do
		local entry = table.remove(deferred, 1)
		resume(entry.thread, table.unpack(entry.args, 1, entry.args.n))
	end
end

local Heartbeat = signal()

-- moves the server time by `seconds`, running the delays it passes in order,
-- then fires Heartbeat once
local function advance(seconds)
	local target = server_time + seconds

	while true do
		local earliest, index = nil, nil
		for i, entry in delayed do
			if entry.at <= target and (earliest == nil or entry.at < earliest.at) then
				earliest, index = entry, i
			end
		end

		if not earliest then
			break
		end

		table.remove(delayed, index)
		server_time = math.max(server_time, earliest.at)
		resume(earliest.thread, table.unpack(earliest.args, 1, earliest.args.n))
		flush()
	end

	server_time = target
	Heartbeat:fire(seconds)
	flush()
end

-- Instances

local Instance = {}
Instance.__index = Instance

local function new_instance(class_name)
	local self = setmetatable({
		ClassName = class_name,
		Name = class_name,
		_parent = nil,
		_children = {},
		_attributes = {},
		_attribute_signals = {},
		AncestryChanged = signal(),
	}, Instance)
	return self
end

local game = new_instance("DataModel")

function Instance:__index(key)
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	return Instance[key]
end

function Instance:__newindex(key, value)
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old then
			old._children[self] = nil
		end
		rawset(self, "_parent", value)
		if value then
			value._children[self] = true
		end
		self.AncestryChanged:fire(self, value)
		return
	end
	rawset(self, key, value)
end

function Instance:FindFirstChild(name)
	for child in self._children do
		if child.Name == name then
			return child
		end
	end
	return nil
end

function Instance:WaitForChild(name)
	return self:FindFirstChild(name)
end

function Instance:IsDescendantOf(ancestor)
	local parent = self.Parent
	while parent do
		if parent == ancestor then
			return true
		end
		parent = parent.Parent
	end
	return false
end

function Instance:GetAttribute(name)
	return self._attributes[name]
end

function Instance:SetAttribute(name, value)
	self._attributes[name] = value
	local changed = self._attribute_signals[name]
	if changed then
		changed:fire()
	end
end

function Instance:GetAttributeChangedSignal(name)
	local changed = self._attribute_signals[name]
	if not changed then
		changed = signal()
		self._attribute_signals[name] = changed
	end
	return changed
end

function Instance:Destroy()
	for child in table.clone(self._children) do
		child:Destroy()
	end
	self.Parent = nil
end

local ReplicatedStorage = new_instance("ReplicatedStorage")
ReplicatedStorage.Name = "ReplicatedStorage"
ReplicatedStorage.Parent = game

local workspace = new_instance("Workspace")
workspace.Parent = game
function workspace:GetServerTimeNow()
	return server_time
end

local RunService = {
	Heartbeat = Heartbeat,
	IsServer = function()
		return is_server
	end,
	IsClient = function()
		return not is_server
	end,
}

local services = {
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
}

function game:GetService(name)
	return services[name]
end

local globals = _G :: any
globals.game = game
globals.workspace = workspace
globals.Instance = {
	new = function(class_name)
		return new_instance(class_name)
	end,
}
globals.task = {
	spawn = spawn,
	defer = defer,
	delay = delay,
	cancel = cancel,
	wait = function()
		return 0
	end,
}
local builtin_typeof = typeof
globals.typeof = function(value)
	if type(value) == "table" and getmetatable(value) == Instance then
		return "Instance"
	end
	if rbx_connections[value] then
		return "RBXScriptConnection"
	end
	return builtin_typeof(value)
end
-- `script.Parent.Parent` is the same, for the modules of Stream that Atom
-- requires, which are one folder deeper
local parent = setmetatable({}, {
	-- Lync needs the engine, so it is the stand-in in `tests/lync.luau`
	__index = function(_, name: string)
		return if name == "Lync" then "../tests/lync" else `../../{name}/src`
	end,
}) :: any
parent.Parent = parent
globals.script = { Parent = parent }

return {
	advance = advance,
	flush = flush,
	heartbeat_listeners = function()
		return Heartbeat:count()
	end,
	delays = function()
		return #delayed
	end,
	set_server = function(value: boolean)
		is_server = value
	end,
	ReplicatedStorage = ReplicatedStorage,
}

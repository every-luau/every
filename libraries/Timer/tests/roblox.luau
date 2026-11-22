--!strict
-- Minimal stand-in for the Roblox globals the library and its dependencies use,
-- since lest's native backend has none. Delayed and deferred callbacks only run
-- when `flush` is called, and `RunService.Heartbeat` only fires on `step`.
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

local function cancel(thread: thread)
	for index, entry in queued do
		if entry.thread == thread then
			table.remove(queued, index)
			break
		end
	end

	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
	end
end

local function flush()
	local entries = table.clone(queued)
	table.clear(queued)
	for _, entry in entries do
		spawn(entry.thread, table.unpack(entry.args))
	end
end

local heartbeat_listeners: { [(delta_time: number) -> ()]: true } = {}

-- the connections Connect returns, so `typeof` can call them RBXScriptConnections
local rbx_connections: { [any]: true } = setmetatable({}, { __mode = "k" }) :: any

local Heartbeat = {
	Connect = function(_, listener: (delta_time: number) -> ())
		heartbeat_listeners[listener] = true
		local connection = {
			Disconnect = function(_)
				heartbeat_listeners[listener] = nil
			end,
		}
		rbx_connections[connection] = true
		return connection
	end,
}

-- fires Heartbeat once with `delta_time`
local function step(delta_time: number)
	for listener in table.clone(heartbeat_listeners) do
		listener(delta_time)
	end
end

local function listeners(): number
	local count = 0
	for _ in heartbeat_listeners do
		count += 1
	end
	return count
end

local services = {
	RunService = { Heartbeat = Heartbeat },
}

local warnings: { string } = {}

local globals = _G :: any
local builtin_typeof = typeof
globals.typeof = function(value: any): string
	return if rbx_connections[value] then "RBXScriptConnection" else builtin_typeof(value)
end
globals.task = { spawn = spawn, defer = queue, delay = delay, cancel = cancel }
globals.warn = function(...: any)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[index] = tostring((select(index, ...)))
	end
	table.insert(warnings, table.concat(parts, " "))
end
globals.game = {
	Destroy = function(instance: any)
		instance:Destroy()
	end,
	GetService = function(_, name: string)
		return services[name]
	end,
}
globals.script = {
	Parent = setmetatable({}, {
		__index = function(_, name: string)
			return `../../{name}/src`
		end,
	}),
}

return {
	flush = flush,
	step = step,
	listeners = listeners,
	warnings = warnings,
}

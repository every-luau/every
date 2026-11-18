--!strict
-- Minimal stand-in for Roblox's `task` library, since lest's native backend has
-- none. Delayed callbacks only run when `flush` is called.

local delayed: { { thread: thread, args: { any } } } = {}

local function spawn(callback: thread | (...any) -> ...any, ...: any): thread
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	local ok, message = coroutine.resume(thread, ...)

	if not ok then
		error(message, 0)
	end

	return thread
end

local function delay(_seconds: number, callback: (...any) -> ...any, ...: any): thread
	local thread = coroutine.create(callback)
	table.insert(delayed, { thread = thread, args = { ... } })
	return thread
end

local function cancel(thread: thread)
	for index, entry in delayed do
		if entry.thread == thread then
			table.remove(delayed, index)
			break
		end
	end
	coroutine.close(thread)
end

local function flush()
	local queue = table.clone(delayed)
	table.clear(delayed)
	for _, entry in queue do
		spawn(entry.thread, table.unpack(entry.args))
	end
end

return {
	spawn = spawn,
	delay = delay,
	cancel = cancel,
	flush = flush,
}

--!strict
-- Minimal stand-in for Roblox's `task` library, since lest's native backend has
-- none. Delayed callbacks only run when `flush` is called.

local delayed: { { callback: (...any) -> (), args: { any } } } = {}

local function delay(_seconds: number, callback: (...any) -> (), ...: any)
	table.insert(delayed, { callback = callback, args = { ... } })
end

local function flush()
	local queue = table.clone(delayed)
	table.clear(delayed)
	for _, entry in queue do
		entry.callback(table.unpack(entry.args))
	end
end

return {
	delay = delay,
	flush = flush,
}

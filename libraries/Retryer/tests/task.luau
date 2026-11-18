--!strict
-- Minimal stand-in for Roblox's `task` library, since lest's native backend has
-- none. `wait` returns right away and records how long it was asked to wait.

local waits: { number } = {}

local function wait(seconds: number): number
	table.insert(waits, seconds)
	return seconds
end

return {
	wait = wait,
	waits = waits,
}

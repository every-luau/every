--[=[
	@class Loop

	Loop calls a callback every few seconds, driven by Heartbeat

	call the module or [Loop.new] with an interval and a callback. the callback
	gets the time that passed since its last call, and the loop runs until the
	returned [Connection] is disconnected

	```lua
	local Loop = require(path.to.Loop)

	local connection = Loop(1, function(elapsed)
		print(`{elapsed} seconds passed`)
	end)

	connection:disconnect()
	```

	:::info
	the callback runs on the first frame at or after the interval, so `elapsed` is
	often a bit more than it. an interval of 0 calls it every frame
	:::
]=]

const RunService = game:GetService("RunService")

const Connection = require(script.Parent.Connection)

export type Connection = Connection.Connection

--[=[
	@within Loop
	@function new
	@param interval number
	@param callback (elapsed: number) -> ()
	@return Connection

	calls `callback` every `interval` seconds with the time that passed since its
	last call, until the returned [Connection] is disconnected. errors when
	`interval` is negative
]=]
const function new(interval: number, callback: (elapsed: number) -> ()): Connection
	assert(interval >= 0, `Loop needs a positive interval or 0, got {interval}`)
	local elapsed = 0

	return Connection.new(
		RunService.Heartbeat:Connect(function(delta_time: number)
			elapsed += delta_time
			if elapsed >= interval then
				callback(elapsed)
				elapsed = 0
			end
		end)
	)
end

return table.freeze(
	setmetatable(
		{ new = new },
		{
			__call = function(_, interval: number, callback: (elapsed: number) -> ()): Connection
				return new(interval, callback)
			end,
		}
	)
)

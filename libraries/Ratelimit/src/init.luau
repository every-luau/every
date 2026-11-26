--[=[
	@class Ratelimit

	Ratelimit limits how many times something can happen per key within an interval

	call the module or [Ratelimit.new] with a limit and an interval in seconds.
	it returns a function that takes a key, often a player, and returns whether
	that key can act now

	```lua
	local Ratelimit = require(path.to.Ratelimit)

	-- 3 purchases per player every 10 seconds
	local can_buy = Ratelimit(3, 10)

	remote.OnServerEvent:Connect(function(player, item)
		if not can_buy(player) then
			return
		end
		buy(player, item)
	end)
	```

	:::info
	the interval starts on a key's first call, and its count goes back to 0 once
	it ends. calling without a key counts for one shared key
	:::
]=]

--[=[
	@within Ratelimit
	@type Limiter (key: K?) -> boolean

	returns whether `key` can act now, and counts the call when it can
]=]
export type Limiter<K> = (key: K?) -> boolean

const NO_KEY = newproxy() -- the key calls without one count for

--[=[
	@within Ratelimit
	@function new
	@param limit number
	@param interval number
	@return Limiter<K>

	creates a [Limiter] that allows `limit` calls per key every `interval`
	seconds. errors when `limit` is 0 or less
]=]
const function new<K>(limit: number, interval: number): Limiter<K>
	if limit <= 0 then
		error(`Ratelimit needs a limit above 0, got {limit}`, 2)
	end

	const counts: { [any]: number } = {}

	return function(key: K?): boolean
		const bucket: any = if key == nil then NO_KEY else key
		const count = counts[bucket] or 0
		if count >= limit then
			return false
		end

		if count == 0 then
			task.delay(
				interval,
				function()
					counts[bucket] = nil
				end
			)
		end

		counts[bucket] = count + 1
		return true
	end
end

return table.freeze(
	setmetatable(
		{ new = new },
		{
			__call = function<K>(_, limit: number, interval: number): Limiter<K>
				return new(limit, interval)
			end,
		}
	)
)

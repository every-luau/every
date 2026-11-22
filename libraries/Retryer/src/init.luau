--[=[
	@class Retryer

	Retryer calls a function again until it stops erroring, with different waits

	every function takes the function to call and its arguments last, and calls it
	in a `pcall` until it succeeds. the bounded ones give up after a number of
	attempts and return like `pcall`, the `inf_` ones never give up and return
	what the function returns

	```lua
	local Retryer = require(path.to.Retryer)

	local ok, data = Retryer.exp(1, 2, 5, store.GetAsync, store, key)
	if not ok then
		warn(`couldn't load {key}: {data}`)
	end
	```

	:::info
	the waits use `task.wait`, so every function yields except
	[Retryer.zero_delay]. there is no wait after the last attempt
	:::
]=]

-- calls `callback` until it succeeds or `attempts` ran out, waiting
-- `wait_for(attempt)` seconds between attempts
const function retry<A..., R...>(
	attempts: number,
	wait_for: ((attempt: number) -> number)?,
	callback: (A...) -> R...,
	...: A...
): (boolean, R...)
	if attempts < 1 then
		error(`Retryer needs at least 1 attempt, got {attempts}`, 3)
	end

	local results: any
	for attempt = 1, attempts do
		results = (table.pack :: any)(pcall(callback, ...))
		if results[1] or attempt == attempts then
			break
		end

		if wait_for then
			task.wait(wait_for(attempt))
		end
	end

	return (table.unpack :: any)(results, 1, results.n)
end

-- calls `callback` until it succeeds, waiting `wait_for(attempt)` seconds
-- between attempts, and returns what it returned
const function retry_forever<A..., R...>(wait_for: (attempt: number) -> number, callback: (A...) -> R..., ...: A...): R...
	local attempt = 0
	while true do
		const results = (table.pack :: any)(pcall(callback, ...))
		if results[1] then
			return (table.unpack :: any)(results, 2, results.n)
		end

		attempt += 1
		task.wait(wait_for(attempt))
	end
end

--[=[
	@within Retryer
	@function zero_delay
	@param attempts number
	@param callback (A...) -> R...
	@param ... A...
	@return (boolean, R...)

	calls `callback` up to `attempts` times without waiting, and returns like
	`pcall` for the last attempt
]=]
const function zero_delay<A..., R...>(attempts: number, callback: (A...) -> R..., ...: A...): (boolean, R...)
	return retry(attempts, nil, callback, ...)
end

--[=[
	@within Retryer
	@function delay
	@param seconds number
	@param attempts number
	@param callback (A...) -> R...
	@param ... A...
	@return (boolean, R...)
	@yields

	calls `callback` up to `attempts` times, waiting `seconds` between attempts,
	and returns like `pcall` for the last attempt
]=]
const function delay<A..., R...>(seconds: number, attempts: number, callback: (A...) -> R..., ...: A...): (boolean, R...)
	return retry(attempts, function()
		return seconds
	end, callback, ...)
end

--[=[
	@within Retryer
	@function exp
	@param seconds number
	@param base number
	@param attempts number
	@param callback (A...) -> R...
	@param ... A...
	@return (boolean, R...)
	@yields

	calls `callback` up to `attempts` times, waiting `seconds + base ^ attempt`
	after each failed attempt, and returns like `pcall` for the last attempt

	```lua
	-- waits 2.5, then 4.5, then 8.5 seconds
	Retryer.exp(0.5, 2, 4, request)
	```
]=]
const function exp<A..., R...>(
	seconds: number,
	base: number,
	attempts: number,
	callback: (A...) -> R...,
	...: A...
): (boolean, R...)
	return retry(attempts, function(attempt)
		return seconds + base ^ attempt
	end, callback, ...)
end

--[=[
	@within Retryer
	@function inf_delay
	@param seconds number
	@param callback (A...) -> R...
	@param ... A...
	@return R...
	@yields

	calls `callback` until it succeeds, waiting `seconds` between attempts, and
	returns what it returned
]=]
const function inf_delay<A..., R...>(seconds: number, callback: (A...) -> R..., ...: A...): R...
	return retry_forever(function()
		return seconds
	end, callback, ...)
end

--[=[
	@within Retryer
	@function inf_exp
	@param seconds number
	@param base number
	@param callback (A...) -> R...
	@param ... A...
	@return R...
	@yields

	calls `callback` until it succeeds, waiting `seconds + base ^ attempt` after
	each failed attempt, and returns what it returned
]=]
const function inf_exp<A..., R...>(seconds: number, base: number, callback: (A...) -> R..., ...: A...): R...
	return retry_forever(function(attempt)
		return seconds + base ^ attempt
	end, callback, ...)
end

return table.freeze({
	zero_delay = zero_delay,
	delay = delay,
	exp = exp,
	inf_delay = inf_delay,
	inf_exp = inf_exp,
})

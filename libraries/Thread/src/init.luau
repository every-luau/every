--!native
--!optimize 2

--[=[
	@class Thread

	Thread runs callbacks on a recycled thread instead of creating a new one per call

	use it like `task.spawn`, by calling the module or [Thread.spawn]. idle
	threads are reused, and a new one is only created when every idle thread is
	busy with a callback that yielded

	```lua
	local Thread = require(path.to.Thread)

	Thread(print, "hello", "world")
	Thread.spawn(print, "hello", "world")
	```
]=]

export type Spawn = <T...>(callback: (T...) -> (), T...) -> thread

export type Thread = setmetatable<{ spawn: Spawn, idle: { thread }, runner: () -> () }, {
	__call: <T...>(self: any, callback: (T...) -> (), T...) -> thread,
}>

-- idle threads beyond this are dropped, so a burst of yielding callbacks doesn't
-- keep its threads alive forever
const MAX_IDLE = 64

const idle: { thread } = {}

-- runs on the pooled thread, which then puts itself back in the pool. returns
-- false when the pool is full so the thread can end
const function call(thread: thread, callback: (...any) -> (), ...: any): boolean
	callback(...)

	const count = #idle
	if count == MAX_IDLE then
		return false
	end

	idle[count + 1] = thread
	return true
end

const function runner()
	repeat
		const keep = call(coroutine.yield())
	until not keep
end

--[=[
	@within Thread
	@type Spawn <T...>(callback: (T...) -> (), T...) -> thread

	the signature of [Thread.spawn], and of calling the module directly
]=]

--[=[
	@within Thread
	@function spawn
	@param callback (T...) -> ()
	@param ... T...
	@return thread

	runs `callback(...)` right away on an idle thread, or on a new one if none is
	free, and returns that thread

	:::info
	a callback that yields keeps its thread busy until it finishes, so the next
	call takes another one. the thread goes back to the pool once its callback
	finishes
	:::

	```lua
	Thread.spawn(function(name)
		task.wait(1)
		print(`hello {name}`)
	end, "world")
	```
]=]
const function spawn<T...>(callback: (T...) -> (), ...: T...): thread
	local thread: thread
	const count = #idle
	if count > 0 then
		thread = idle[count]
		idle[count] = nil
	else
		thread = coroutine.create(runner)
		coroutine.resume(thread)
	end

	task.spawn(thread, thread, callback, ...)
	return thread
end

--[=[
	@within Thread
	@prop idle { thread }
	@readonly

	the pool of idle threads, for code that wants to reuse them without calling
	[Thread.spawn]. take the last thread out of the pool and resume it with
	`task.spawn(thread, thread, callback, ...)`. when the pool is empty, create
	one with `coroutine.create(Thread.runner)` and resume it once first
]=]

--[=[
	@within Thread
	@prop runner () -> ()
	@readonly

	the body of every pooled thread, see [Thread.idle]
]=]

return table.freeze(
	setmetatable(
		{
			spawn = spawn,
			idle = idle,
			runner = runner,
		},
		{
			__call = function<T...>(_, callback: (T...) -> (), ...: T...): thread
				return spawn(callback, ...)
			end,
		}
	)
) :: Thread

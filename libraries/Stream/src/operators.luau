-- The methods that make a new stream out of a stream.

const Void = require(script.Parent.Parent.Void)

const core = require("./core")
const stream_types = require("./types")

type Stream<T> = stream_types.Stream<T>
type Void = Void.Void

const methods = core.methods
const new = core.new
const run = core.run
const subscribe = core.subscribe
const until_finished = core.until_finished

-- a value a stream can't emit, for "nothing yet"
const UNSET = table.freeze({})

--[=[
	@within Stream
	@method map
	@param transform (value: T) -> U
	@return Stream<U>

	emits `transform(value)` for every value

	```lua
	local names: Stream<string> = Stream.property(part, "Parent"):map(function(parent)
		return if parent then parent.Name else "nowhere"
	end)
	```
]=]
function methods.map<T>(self: Stream<T>, transform: (value: T) -> any): any
	return new(function(emit, void: Void)
		run(self, function(value: T)
			emit(transform(value))
		end, void)
	end)
end

--[=[
	@within Stream
	@method filter
	@param predicate (value: T) -> boolean
	@return Stream<T>

	emits only the values `predicate` returns true for
]=]
function methods.filter<T>(self: Stream<T>, predicate: (value: T) -> boolean): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		run(self, function(value: T)
			if predicate(value) then
				emit(value)
			end
		end, void)
	end)
end

--[=[
	@within Stream
	@method tap
	@param callback (value: T) -> ()
	@return Stream<T>

	calls `callback` with every value before passing it on, to log or debug
	without changing anything
]=]
function methods.tap<T>(self: Stream<T>, callback: (value: T) -> ()): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		run(self, function(value: T)
			callback(value)
			emit(value)
		end, void)
	end)
end

--[=[
	@within Stream
	@method changed
	@param equals ((last: T, new: T) -> boolean)?
	@return Stream<T>

	skips a value equal to the last one emitted, compared with `==` or with
	`equals`. the first value always passes

	```lua
	Stream.of(1, 1, 2, 2, 1):changed():listen(print) --> 1, 2, 1

	local by_id = players:changed(function(last, new)
		return last.UserId == new.UserId
	end)
	```
]=]
function methods.changed<T>(self: Stream<T>, equals: ((last: T, new: T) -> boolean)?): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		local last: any = UNSET
		run(self, function(value: T)
			if last ~= UNSET and (if equals then equals(last, value) else last == value) then
				return
			end
			last = value
			emit(value)
		end, void)
	end)
end

--[=[
	@within Stream
	@method switch
	@param project (value: T) -> Stream<U>?
	@return Stream<U>

	turns each value into a stream with `project` and follows the latest one,
	dropping the one before. to follow "the current" something: the current
	character, the selected unit, the loaded map. a nil stream emits nothing
	until the next value

	```lua
	local health = Stream.character(player):switch(function(character)
		return if character then Stream.property(character.Humanoid, "Health") else Stream.of(0)
	end)
	```
]=]
function methods.switch<T>(self: Stream<T>, project: (value: T) -> any): any
	return new(function(emit, void: Void)
		void:add(core.tidy(self, function(value: T, value_void: Void)
			const inner = project(value)
			if inner then
				run(inner, emit, value_void)
			end
		end))
	end)
end

--[=[
	@within Stream
	@method default
	@param fallback T
	@return Stream<T>

	emits `fallback` in place of nil

	```lua
	local nickname = Stream.attribute(player, "Nickname"):default(player.Name)
	```
]=]
function methods.default<T>(self: Stream<T>, fallback: T): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		run(self, function(value: T?)
			emit(if value == nil then fallback else value :: T)
		end, void)
	end)
end

--[=[
	@within Stream
	@method skip_nil
	@return Stream<T>

	drops nil values. [Stream:default] keeps the information that a value is
	missing, so prefer it unless nil means nothing
]=]
function methods.skip_nil<T>(self: Stream<T>): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		run(self, function(value: T)
			if value ~= nil then
				emit(value :: T)
			end
		end, void)
	end)
end

--[=[
	@within Stream
	@method take
	@param count number
	@return Stream<T>

	emits the first `count` values, then stops listening

	```lua
	Stream.of("a", "b", "c"):take(2):listen(print) --> a, b
	```
]=]
function methods.take<T>(self: Stream<T>, count: number): Stream<T>
	assert(count >= 0, `[Stream:take] needs a count of 0 or more, got {count}`)
	return new(function(emit: (T) -> (), void: Void)
		if count == 0 then
			return
		end
		local remaining = count
		void:add(until_finished(self, function(finish, value: T)
			remaining -= 1
			emit(value)
			if remaining <= 0 then
				finish()
			end
		end))
	end)
end

--[=[
	@within Stream
	@method skip
	@param count number
	@return Stream<T>

	drops the first `count` values and emits the rest
]=]
function methods.skip<T>(self: Stream<T>, count: number): Stream<T>
	assert(count >= 0, `[Stream:skip] needs a count of 0 or more, got {count}`)
	return new(function(emit: (T) -> (), void: Void)
		local remaining = count
		run(self, function(value: T)
			if remaining > 0 then
				remaining -= 1
			else
				emit(value)
			end
		end, void)
	end)
end

--[=[
	@within Stream
	@method take_while
	@param predicate (value: T) -> boolean
	@return Stream<T>

	emits values while `predicate` returns true, and stops listening at the
	first one it rejects, which is dropped
]=]
function methods.take_while<T>(self: Stream<T>, predicate: (value: T) -> boolean): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		void:add(until_finished(self, function(finish, value: T)
			if predicate(value) then
				emit(value)
			else
				finish()
			end
		end))
	end)
end

--[=[
	@within Stream
	@method skip_while
	@param predicate (value: T) -> boolean
	@return Stream<T>

	drops values while `predicate` returns true, then emits the first it
	rejects and everything after, without calling it again
]=]
function methods.skip_while<T>(self: Stream<T>, predicate: (value: T) -> boolean): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		local skipping = true
		run(self, function(value: T)
			if skipping and predicate(value) then
				return
			end
			skipping = false
			emit(value)
		end, void)
	end)
end

--[=[
	@within Stream
	@method scan
	@param reducer (accumulator: A, value: T) -> A
	@param seed A
	@return Stream<A>

	keeps a running value starting at `seed`, updated with `reducer` for every
	value, and emits it after each update. `seed` itself isn't emitted

	```lua
	Stream.of(1, 2, 3):scan(function(sum, n)
		return sum + n
	end, 0):listen(print) --> 1, 3, 6
	```
]=]
function methods.scan<T>(self: Stream<T>, reducer: (accumulator: any, value: T) -> any, seed: any): any
	return new(function(emit, void: Void)
		local accumulator = seed
		run(self, function(value: T)
			accumulator = reducer(accumulator, value)
			emit(accumulator)
		end, void)
	end)
end

--[=[
	@within Stream
	@method start_with
	@param first T
	@return Stream<T>

	emits `first` when subscribed, then every value
]=]
function methods.start_with<T>(self: Stream<T>, first: T): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		emit(first)
		run(self, emit, void)
	end)
end

--[=[
	@within Stream
	@method end_with
	@param last T
	@return Stream<T>

	emits `last` once the subscription ends, to reset whatever the values drove

	```lua
	hovered:end_with(false):listen(function(is_hovered)
		highlight.Enabled = is_hovered
	end)
	```
]=]
function methods.end_with<T>(self: Stream<T>, last: T): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		const source = subscribe(self, emit)
		void:add(function()
			source:clean()
			emit(last)
		end)
	end)
end

--[=[
	@within Stream
	@method with
	@param other Stream<U>
	@param combine (value: T, other: U) -> Z
	@return Stream<Z>

	emits `combine(value, latest)` for every value, with the latest value of
	`other`. `other` emitting alone emits nothing, and values before its first
	are dropped

	```lua
	local clicked_at = clicks:with(mouse_position, function(_, position)
		return position
	end)
	```
]=]
function methods.with<T>(self: Stream<T>, other: any, combine: (value: T, other: any) -> any): any
	return new(function(emit, void: Void)
		local latest: any = UNSET
		run(other, function(value: any)
			latest = value
		end, void)
		run(self, function(value: T)
			if latest ~= UNSET then
				emit(combine(value, latest))
			end
		end, void)
	end)
end

--[=[
	@within Stream
	@method after
	@param seconds number
	@return Stream<T>

	subscribes to the stream `seconds` after being subscribed to, without
	yielding. ending the subscription before then means it never subscribes

	```lua
	Stream.of("late"):after(1):listen(print)
	```
]=]
function methods.after<T>(self: Stream<T>, seconds: number): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		const thread = task.delay(seconds, function()
			run(self, emit, void)
		end)
		void:add(function()
			if coroutine.status(thread) ~= "dead" then
				task.cancel(thread)
			end
		end)
	end)
end

--[=[
	@within Stream
	@method debounce
	@param seconds number
	@return Stream<T>

	emits the last value once the stream stayed quiet for `seconds`. each value
	restarts the wait. use [Stream:throttle] to react to the first value instead

	```lua
	local search = Stream.property(box, "Text"):debounce(0.3)
	```
]=]
function methods.debounce<T>(self: Stream<T>, seconds: number): Stream<T>
	assert(seconds >= 0, `[Stream:debounce] needs 0 seconds or more, got {seconds}`)
	return new(function(emit: (T) -> (), void: Void)
		local waiting: thread? = nil
		run(self, function(value: T)
			if waiting then
				task.cancel(waiting)
			end
			waiting = task.delay(seconds, function()
				waiting = nil
				emit(value)
			end)
		end, void)

		void:add(function()
			if waiting then
				task.cancel(waiting)
				waiting = nil
			end
		end)
	end)
end

--[=[
	@within Stream
	@method throttle
	@param seconds number
	@return Stream<T>

	emits a value, then drops every other one for `seconds`. use
	[Stream:debounce] to react once things calm down instead
]=]
function methods.throttle<T>(self: Stream<T>, seconds: number): Stream<T>
	assert(seconds >= 0, `[Stream:throttle] needs 0 seconds or more, got {seconds}`)
	return new(function(emit: (T) -> (), void: Void)
		local last = -math.huge
		run(self, function(value: T)
			const now = os.clock()
			if now - last >= seconds then
				last = now
				emit(value)
			end
		end, void)
	end)
end

--[=[
	@within Stream
	@method buffer
	@param count number
	@return Stream<{ T }>

	collects values and emits them `count` at a time in a new array. what is
	left is emitted when the subscription ends
]=]
function methods.buffer<T>(self: Stream<T>, count: number): any
	assert(count >= 1, `[Stream:buffer] needs a count of 1 or more, got {count}`)
	return new(function(emit, void: Void)
		local batch: { T } = {}
		const source = subscribe(self, function(value: T)
			table.insert(batch, value)
			if #batch >= count then
				const full = batch
				batch = {}
				emit(full)
			end
		end)

		void:add(function()
			source:clean()
			if #batch > 0 then
				const rest = batch
				batch = {}
				emit(rest)
			end
		end)
	end)
end

--[=[
	@within Stream
	@method buffer_time
	@param seconds number
	@return Stream<{ T }>

	collects values and emits them in a new array `seconds` after the first of
	the batch, so quiet periods emit nothing. what is left is emitted when the
	subscription ends
]=]
function methods.buffer_time<T>(self: Stream<T>, seconds: number): any
	assert(seconds > 0, `[Stream:buffer_time] needs more than 0 seconds, got {seconds}`)
	return new(function(emit, void: Void)
		local batch: { T } = {}
		local waiting: thread? = nil

		const function flush()
			waiting = nil
			if #batch > 0 then
				const full = batch
				batch = {}
				emit(full)
			end
		end

		const source = subscribe(self, function(value: T)
			table.insert(batch, value)
			if waiting == nil then
				waiting = task.delay(seconds, flush)
			end
		end)

		void:add(function()
			if waiting then
				task.cancel(waiting)
			end
			source:clean()
			flush()
		end)
	end)
end

--[=[
	@within Stream
	@method catch
	@param label string
	@return Stream<T>

	catches errors from whatever listens after it and warns them with `label`
	and a traceback, so an error deep in a chain says where it came from. the
	subscription keeps going

	```lua
	source:map(parse):catch("parsed"):listen(use)
	```
]=]
function methods.catch<T>(self: Stream<T>, label: string): Stream<T>
	return new(function(emit: (T) -> (), void: Void)
		run(self, function(value: T)
			local message = ""
			const ok = xpcall(emit, function(problem: any)
				message = debug.traceback(tostring(problem), 2)
			end, value)
			if not ok then
				warn(`[Stream:catch '{label}'] {message}`)
			end
		end, void)
	end)
end

return nil

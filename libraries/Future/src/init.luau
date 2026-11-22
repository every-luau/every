--[=[
	@class Future

	Future is a value available later, with chaining, combinators and cancellation

	create one with an executor that gets a `pass` and a `fail` function, and
	settle it by calling one of them. the executor runs right away with [Thread],
	so it can yield, and an error in it fails the future. then read the value with
	[Future:await], or chain [Future:and_then], [Future:catch] and
	[Future:finally]

	```lua
	local Future = require(path.to.Future)

	local profile = Future.new(function(pass, fail)
		local ok, data = pcall(store.GetAsync, store, key)
		if ok then
			pass(data)
		else
			fail(data)
		end
	end)

	profile:and_then(function(data)
		print(data.coins)
	end):catch(warn)
	```

	:::info
	a future settles once: calling `pass` or `fail` again does nothing. it is
	pending, then resolved, rejected or cancelled
	:::
]=]

const Thread = require(script.Parent.Thread)

--[=[
	@within Future
	@type Status "pending" | "resolved" | "rejected" | "cancelled"

	where a future is: still waiting, resolved with values, rejected with an
	error, or cancelled with [Future:cancel]
]=]
export type Status = "pending" | "resolved" | "rejected" | "cancelled"

export type Future<T...> = setmetatable<{
	_status: Status,
	_values: { n: number, [number]: any },
	_error: any,
	_after: { (T...) -> () },
	_listeners: { () -> () },
	get_status: (self: Future<T...>) -> Status,
	is_pending: (self: Future<T...>) -> boolean,
	await: (self: Future<T...>) -> T...,
	unwrap: (self: Future<T...>) -> T...,
	expect: (self: Future<T...>, message: string) -> T...,
	unwrap_or: (self: Future<T...>, T...) -> T...,
	unwrap_or_else: (self: Future<T...>, callback: (err: any) -> T...) -> T...,
	after: (self: Future<T...>, callback: (T...) -> ()) -> Future<T...>,
	-- any, since a type can't refer to itself with other parameters
	and_then: <U...>(self: Future<T...>, callback: (T...) -> U...) -> any,
	catch: (self: Future<T...>, callback: (err: any) -> T...) -> Future<T...>,
	finally: (self: Future<T...>, callback: () -> ()) -> Future<T...>,
	timeout: (self: Future<T...>, seconds: number, message: string?) -> Future<T...>,
	cancel: (self: Future<T...>) -> (),
}, { __index: Future<T...> }>

const CANCELLED = "Future was cancelled"

const Future = {}
Future.__index = Future

const function create(): Future<...any>
	return setmetatable(
		{
			_status = "pending",
			_values = { n = 0 },
			_error = nil,
			_after = {},
			_listeners = {},
		},
		Future
	) :: any
end

-- moves a pending future to `status`, then tells everything waiting on it
const function settle(self: Future<...any>, status: Status, values: { n: number, [number]: any }, err: any)
	if self._status ~= "pending" then
		return
	end

	self._status = status
	self._values = values
	self._error = err

	const after, listeners = self._after, self._listeners
	self._after, self._listeners = {}, {}

	if status == "resolved" then
		for _, callback in after do
			Thread(callback, table.unpack(values, 1, values.n))
		end
	end

	for _, listener in listeners do
		listener()
	end
end

-- calls `listener` once the future settles, right away if it already has
const function on_settle(self: Future<...any>, listener: () -> ())
	if self._status == "pending" then
		table.insert(self._listeners, listener)
	else
		listener()
	end
end

-- the error a settled but not resolved future fails with
const function failure(self: Future<...any>): any
	return if self._status == "cancelled" then CANCELLED else self._error
end

--[=[
	@within Future
	@function new
	@param executor (pass: (T...) -> (), fail: (err: any) -> (), A...) -> ()
	@param ... A...
	@return Future<T...>

	creates a pending future and runs `executor` right away on a recycled thread,
	with `pass`, `fail` and `...`. an error in `executor` fails the future

	```lua
	local ready = Future.new(function(pass)
		task.wait(1)
		pass("ready")
	end)
	```
]=]
function Future.new<T..., A...>(
	executor: (pass: (T...) -> (), fail: (err: any) -> (), A...) -> (),
	...: A...
): Future<T...>
	const self = create()

	const function pass(...: any)
		settle(self, "resolved", (table.pack :: any)(...), nil)
	end

	const function fail(err: any)
		settle(self, "rejected", { n = 0 }, err)
	end

	Thread(function(...: any)
		const ok, err = pcall(executor :: any, pass, fail, ...)
		if not ok then
			fail(err)
		end
	end, ...)

	return self :: any
end

--[=[
	@within Future
	@function resolve
	@param ... T...
	@return Future<T...>

	creates a future already resolved with `...`
]=]
function Future.resolve<T...>(...: T...): Future<T...>
	const self = create()
	settle(self, "resolved", (table.pack :: any)(...), nil)
	return self :: any
end

--[=[
	@within Future
	@function reject
	@param err any
	@return Future<...any>

	creates a future already rejected with `err`
]=]
function Future.reject(err: any): Future<...any>
	const self = create()
	settle(self, "rejected", { n = 0 }, err)
	return self
end

--[=[
	@within Future
	@function try
	@param callback (A...) -> R...
	@param ... A...
	@return Future<(boolean, R...)>

	calls `callback` with `...` in a `pcall` on a recycled thread, and resolves
	with what the `pcall` returns. it never rejects

	```lua
	local ok, data = Future.try(store.GetAsync, store, key):await()
	```
]=]
function Future.try<A..., R...>(callback: (A...) -> R..., ...: A...): Future<(boolean, R...)>
	return Future.new(function(pass, _, ...)
		pass(pcall(callback, ...))
	end, ...) :: any
end

--[=[
	@within Future
	@function all
	@param futures { Future<T> }
	@return Future<{ T }>

	resolves with the first value of every future, in the same order, once they
	all resolved. rejects as soon as one of them rejects or is cancelled
]=]
function Future.all<T>(futures: { Future<T> }): Future<{ T }>
	return Future.new(function(pass, fail)
		const results = {}
		local remaining = #futures
		if remaining == 0 then
			pass(results)
			return
		end

		for index, future in futures do
			on_settle(future, function()
				if future._status ~= "resolved" then
					fail(failure(future))
					return
				end

				results[index] = future._values[1]
				remaining -= 1
				if remaining == 0 then
					pass(results)
				end
			end)
		end
	end)
end

--[=[
	@within Future
	@function race
	@param futures { Future<T...> }
	@return Future<T...>

	settles the same way as the first of `futures` to settle
]=]
function Future.race<T...>(futures: { Future<T...> }): Future<T...>
	return Future.new(function(pass, fail)
		for _, future in futures do
			on_settle(future, function()
				if future._status == "resolved" then
					pass(table.unpack(future._values, 1, future._values.n))
				else
					fail(failure(future))
				end
			end)
		end
	end) :: any
end

--[=[
	@within Future
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Future
]=]
function Future.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Future
end

--[=[
	@within Future
	@method get_status
	@return Status

	returns where the future is, see [Status]
]=]
function Future.get_status<T...>(self: Future<T...>): Status
	return self._status
end

--[=[
	@within Future
	@method is_pending
	@return boolean

	returns whether the future hasn't settled yet
]=]
function Future.is_pending<T...>(self: Future<T...>): boolean
	return self._status == "pending"
end

--[=[
	@within Future
	@method await
	@yields
	@return T...

	yields until the future settles, then returns its values. errors with the
	error of a rejected future, or when it is cancelled
]=]
function Future.await<T...>(self: Future<T...>): T...
	if self._status == "pending" then
		const thread = coroutine.running()
		on_settle(self, function()
			task.spawn(thread)
		end)
		coroutine.yield()
	end

	return self:unwrap()
end

--[=[
	@within Future
	@method unwrap
	@return T...

	returns the values of a resolved future without yielding. errors when it is
	pending, rejected or cancelled
]=]
function Future.unwrap<T...>(self: Future<T...>): T...
	const status = self._status
	if status == "resolved" then
		return (table.unpack :: any)(self._values, 1, self._values.n)
	elseif status == "pending" then
		error("Future is still pending", 2)
	end

	error(failure(self), 0)
end

--[=[
	@within Future
	@method expect
	@param message string
	@return T...

	the same as [Future:unwrap], but errors with `message` when the future isn't
	resolved
]=]
function Future.expect<T...>(self: Future<T...>, message: string): T...
	if self._status ~= "resolved" then
		error(message, 2)
	end

	return (table.unpack :: any)(self._values, 1, self._values.n)
end

--[=[
	@within Future
	@method unwrap_or
	@param ... T...
	@return T...

	returns the values of a resolved future, or `...` when it isn't resolved
]=]
function Future.unwrap_or<T...>(self: Future<T...>, ...: T...): T...
	if self._status == "resolved" then
		return (table.unpack :: any)(self._values, 1, self._values.n)
	end

	return ...
end

--[=[
	@within Future
	@method unwrap_or_else
	@param callback (err: any) -> T...
	@return T...

	returns the values of a resolved future, or what `callback` returns when it
	isn't resolved. `callback` gets the error, nil while the future is pending
]=]
function Future.unwrap_or_else<T...>(self: Future<T...>, callback: (err: any) -> T...): T...
	const status = self._status
	if status == "resolved" then
		return (table.unpack :: any)(self._values, 1, self._values.n)
	end

	return callback(if status == "pending" then nil else failure(self))
end

--[=[
	@within Future
	@method after
	@param callback (T...) -> ()
	@return Future<T...>

	calls `callback` with the values once the future resolves, right away if it
	already has, on a recycled thread. it isn't called when the future rejects or
	is cancelled. returns the same future
]=]
function Future.after<T...>(self: Future<T...>, callback: (T...) -> ()): Future<T...>
	const status = self._status
	if status == "resolved" then
		Thread(callback, (table.unpack :: any)(self._values, 1, self._values.n))
	elseif status == "pending" then
		table.insert(self._after, callback)
	end

	return self
end

--[=[
	@within Future
	@method and_then
	@param callback (T...) -> U...
	@return Future<U...>

	returns a future of what `callback` returns once this one resolves. it rejects
	with the same error when this one rejects, and when `callback` errors

	```lua
	local name = profile:and_then(function(data)
		return data.name
	end)
	```
]=]
function Future.and_then<T..., U...>(self: Future<T...>, callback: (T...) -> U...): Future<U...>
	return Future.new(function(pass)
		pass(callback(self:await()))
	end) :: any
end

--[=[
	@within Future
	@method catch
	@param callback (err: any) -> T...
	@return Future<T...>

	returns a future resolved with the same values when this one resolves, or with
	what `callback` returns from the error when it rejects or is cancelled
]=]
function Future.catch<T...>(self: Future<T...>, callback: (err: any) -> T...): Future<T...>
	return Future.new(function(pass)
		const results = (table.pack :: any)(pcall(self.await, self))
		if results[1] then
			pass(table.unpack(results, 2, results.n))
		else
			(pass :: any)(callback(results[2]))
		end
	end) :: any
end

--[=[
	@within Future
	@method finally
	@param callback () -> ()
	@return Future<T...>

	calls `callback` once the future settles, however it does, then returns a
	future settled the same way
]=]
function Future.finally<T...>(self: Future<T...>, callback: () -> ()): Future<T...>
	return Future.new(function(pass, fail)
		const results = (table.pack :: any)(pcall(self.await, self))
		callback()

		if results[1] then
			pass(table.unpack(results, 2, results.n))
		else
			fail(results[2])
		end
	end) :: any
end

--[=[
	@within Future
	@method timeout
	@param seconds number
	@param message string?
	@return Future<T...>

	returns a future settled the same way as this one, or rejected with `message`
	if this one takes longer than `seconds`
]=]
function Future.timeout<T...>(self: Future<T...>, seconds: number, message: string?): Future<T...>
	return Future.new(function(pass, fail)
		const timer = task.delay(seconds, fail, message or `Future timed out after {seconds} seconds`)

		on_settle(self, function()
			task.cancel(timer)
			if self._status == "resolved" then
				pass((table.unpack :: any)(self._values, 1, self._values.n))
			else
				fail(failure(self))
			end
		end)
	end) :: any
end

--[=[
	@within Future
	@method cancel

	cancels a pending future: it never settles, its [Future:after] callbacks are
	dropped, and [Future:await] errors. does nothing once it has settled
]=]
function Future.cancel<T...>(self: Future<T...>)
	settle(self, "cancelled", { n = 0 }, nil)
end

return table.freeze({
	new = Future.new,
	resolve = Future.resolve,
	reject = Future.reject,
	try = Future.try,
	all = Future.all,
	race = Future.race,
	is = Future.is,
})

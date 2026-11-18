--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

-- the source requires Thread with `script.Parent.Thread`, which is a path
-- relative to it here, the same way package managers put Thread next to it
local task = require("./task")
;(_G :: any).task = task
;(_G :: any).script = { Parent = { Thread = "../../Thread/src" } }

local Future = require("../src")

-- a future and the functions settling it, to settle it from the test
local function manual(): (any, (...any) -> (), (any) -> ())
	local pass: any, fail: any = nil, nil
	local future = Future.new(function(p, f)
		pass, fail = p, f
	end)
	return future, pass :: any, fail :: any
end

describe("Future", function()
	it("resolves right away when the executor does not yield", function()
		local future = Future.new(function(pass, _, a, b)
			pass(a + b)
		end, 1, 2)

		expect(future:get_status()).toBe("resolved")
		expect(future:unwrap()).toBe(3)
	end)

	it("keeps nil values", function()
		local a, b, c = Future.resolve(nil, nil, 3):unwrap()
		expect(a).toBeNil()
		expect(b).toBeNil()
		expect(c).toBe(3)
	end)

	it("only settles once", function()
		local future = Future.new(function(pass, fail)
			pass(1)
			pass(2)
			fail("nope")
		end)

		expect(future:unwrap()).toBe(1)
	end)

	it("rejects when the executor errors", function()
		local future = Future.new(function()
			error("boom", 0)
		end)

		expect(future:get_status()).toBe("rejected")
		expect(function()
			future:unwrap()
		end).toThrow("boom")
	end)

	it("resumes awaiting threads once settled", function()
		local future, pass = manual()
		local received: any = nil

		task.spawn(function()
			received = future:await()
		end)

		expect(received).toBeNil()
		pass("value")
		expect(received).toBe("value")
	end)

	it("errors in await when rejected", function()
		local future, _, fail = manual()
		local ok: boolean?, err: any = nil, nil

		task.spawn(function()
			ok, err = pcall(future.await, future)
		end)

		fail("bad")
		expect(ok).toBe(false)
		expect(err).toBe("bad")
	end)

	it("calls after callbacks only when resolved", function()
		local resolved, pass = manual()
		local rejected, _, fail = manual()
		local calls: { any } = {}

		resolved:after(function(value)
			table.insert(calls, value)
		end)
		rejected:after(function(value)
			table.insert(calls, value)
		end)

		pass("ok")
		fail("bad")
		Future.resolve("now"):after(function(value)
			table.insert(calls, value)
		end)

		expect(calls).toEqual({ "ok", "now" })
	end)

	it("does not settle a cancelled future", function()
		local future, pass = manual()
		local called = false
		future:after(function()
			called = true
		end)

		future:cancel()
		pass("late")

		expect(future:get_status()).toBe("cancelled")
		expect(called).toBe(false)
		expect(future:unwrap_or("fallback")).toBe("fallback")
	end)

	it("errors in await when cancelled", function()
		local future = manual()
		local ok: boolean?, err: any = nil, nil

		task.spawn(function()
			ok, err = pcall(future.await, future)
		end)

		future:cancel()
		expect(ok).toBe(false)
		expect(tostring(err)).toContain("cancelled")
	end)

	it("wraps pcall with try", function()
		expect({ Future.try(error, "oops", 0):unwrap() }).toEqual({ false, "oops" })
		expect({ Future.try(math.max, 1, 5):unwrap() }).toEqual({ true, 5 })
	end)

	it("chains with and_then", function()
		local future, pass = manual()
		local doubled = future:and_then(function(value)
			return value * 2
		end)

		pass(21)
		expect(doubled:unwrap()).toBe(42)
	end)

	it("recovers with catch", function()
		local recovered = Future.reject("bad"):catch(function(err)
			return `recovered from {err}`
		end)

		expect(recovered:unwrap()).toBe("recovered from bad")
		expect(Future.resolve(1):catch(error):unwrap()).toBe(1)
	end)

	it("runs finally and settles the same way", function()
		local calls = 0
		local function count()
			calls += 1
		end

		expect(Future.resolve(1):finally(count):unwrap()).toBe(1)
		expect(Future.reject("bad"):finally(count):get_status()).toBe("rejected")
		expect(calls).toBe(2)
	end)

	it("collects every value with all", function()
		local a, passA = manual()
		local b, passB = manual()
		local all = Future.all({ a, b })

		passB("b")
		expect(all:is_pending()).toBe(true)
		passA("a")
		expect(all:unwrap()).toEqual({ "a", "b" })
	end)

	it("rejects all when one rejects", function()
		local all = Future.all({ Future.resolve(1), Future.reject("bad") })
		expect(all:get_status()).toBe("rejected")
	end)

	it("settles like the first with race", function()
		local a = manual()
		local b, passB = manual()
		local race = Future.race({ a, b })

		passB("b")
		expect(race:unwrap()).toBe("b")
	end)

	it("rejects with timeout when too slow", function()
		local future = manual()
		local timed = future:timeout(1, "too slow")

		expect(timed:is_pending()).toBe(true)
		task.flush()
		expect(timed:get_status()).toBe("rejected")
		expect(function()
			timed:unwrap()
		end).toThrow("too slow")
	end)

	it("settles like the future with timeout when fast enough", function()
		local future, pass = manual()
		local timed = future:timeout(1)

		pass("fast")
		task.flush()
		expect(timed:unwrap()).toBe("fast")
	end)

	it("errors in expect when not resolved", function()
		expect(function()
			manual():expect("not ready")
		end).toThrow("not ready")
	end)

	it("tells futures apart", function()
		expect(Future.is(Future.resolve())).toBe(true)
		expect(Future.is({ await = print })).toBe(false)
	end)
end)

return nil

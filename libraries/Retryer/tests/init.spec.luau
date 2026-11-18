--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local task = require("./task")
;(_G :: any).task = task

local Retryer = require("../src")

-- fails `failures` times, then returns its arguments
local function flaky(failures: number)
	local calls = 0
	return function(...: any): ...any
		calls += 1
		if calls <= failures then
			error("failed", 0)
		end
		return ...
	end
end

describe("Retryer", function()
	it("returns like pcall when it succeeds", function()
		expect({ Retryer.zero_delay(3, flaky(2), "a", "b") }).toEqual({ true, "a", "b" })
	end)

	it("returns the last error when every attempt fails", function()
		expect({ Retryer.zero_delay(3, flaky(3)) }).toEqual({ false, "failed" })
	end)

	it("keeps nil results", function()
		local ok, a, b, c = Retryer.zero_delay(1, function()
			return nil, nil, 3
		end)
		expect(ok).toBe(true)
		expect(a).toBeNil()
		expect(b).toBeNil()
		expect(c).toBe(3)
	end)

	it("waits between attempts but not after the last one", function()
		table.clear(task.waits)
		Retryer.delay(2, 3, flaky(5))
		expect(task.waits).toEqual({ 2, 2 })
	end)

	it("waits exponentially longer", function()
		table.clear(task.waits)
		Retryer.exp(0.5, 2, 4, flaky(5))
		expect(task.waits).toEqual({ 2.5, 4.5, 8.5 })
	end)

	it("retries forever until it succeeds", function()
		table.clear(task.waits)
		expect({ Retryer.inf_delay(1, flaky(4), "done") }).toEqual({ "done" })
		expect(#task.waits).toBe(4)
	end)

	it("retries forever with exponential waits", function()
		table.clear(task.waits)
		expect({ Retryer.inf_exp(0, 3, flaky(2), "done") }).toEqual({ "done" })
		expect(task.waits).toEqual({ 3, 9 })
	end)

	it("refuses fewer than 1 attempt", function()
		expect(function()
			Retryer.zero_delay(0, print)
		end).toThrow("at least 1 attempt")
	end)
end)

return nil

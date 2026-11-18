--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local task = require("./task")
;(_G :: any).task = task

local Ratelimit = require("../src")

describe("Ratelimit", function()
	it("allows `limit` calls then refuses", function()
		local limit = Ratelimit.new(2, 1)
		expect(limit()).toBe(true)
		expect(limit()).toBe(true)
		expect(limit()).toBe(false)
	end)

	it("counts each key on its own", function()
		local limit = Ratelimit(1, 1)
		expect(limit("a")).toBe(true)
		expect(limit("a")).toBe(false)
		expect(limit("b")).toBe(true)
	end)

	it("allows calls again once the interval passed", function()
		local limit = Ratelimit.new(1, 1)
		expect(limit("a")).toBe(true)
		expect(limit("a")).toBe(false)
		task.flush()
		expect(limit("a")).toBe(true)
	end)

	it("refuses a limit of 0", function()
		expect(function()
			Ratelimit.new(0, 1)
		end).toThrow("limit above 0")
	end)
end)

return nil

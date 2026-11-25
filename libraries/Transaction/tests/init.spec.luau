--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Transaction = require("../src")

describe("Transaction", function()
	it("says hello", function()
		expect(Transaction.hello()).toBe("hello")
	end)
end)

return nil

--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Connection = require("../src")

describe("Connection", function()
	it("says hello", function()
		expect(Connection.hello()).toBe("hello")
	end)
end)

return nil

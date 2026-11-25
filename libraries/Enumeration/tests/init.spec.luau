--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Enumeration = require("../src")

describe("Enumeration", function()
	it("says hello", function()
		expect(Enumeration.hello()).toBe("hello")
	end)
end)

return nil

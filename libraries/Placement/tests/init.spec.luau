--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Placement = require("../src")

describe("Placement", function()
	it("says hello", function()
		expect(Placement.hello()).toBe("hello")
	end)
end)

return nil

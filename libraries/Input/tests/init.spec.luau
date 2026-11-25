--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Input = require("../src")

describe("Input", function()
	it("says hello", function()
		expect(Input.hello()).toBe("hello")
	end)
end)

return nil

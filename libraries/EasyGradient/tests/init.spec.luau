--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local EasyGradient = require("../src")

describe("EasyGradient", function()
	it("says hello", function()
		expect(EasyGradient.hello()).toBe("hello")
	end)
end)

return nil

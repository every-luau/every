--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Void = require("../src")

describe("Void", function()
	it("says hello", function()
		expect(Void.hello()).toBe("hello")
	end)
end)

return nil

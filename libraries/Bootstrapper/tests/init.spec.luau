--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Bootstrapper = require("../src")

describe("Bootstrapper", function()
	it("says hello", function()
		expect(Bootstrapper.hello()).toBe("hello")
	end)
end)

return nil

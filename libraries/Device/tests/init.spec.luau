--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Device = require("../src")

describe("Device", function()
	it("says hello", function()
		expect(Device.hello()).toBe("hello")
	end)
end)

return nil

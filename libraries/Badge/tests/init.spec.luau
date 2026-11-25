--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Badge = require("../src")

describe("Badge", function()
	it("says hello", function()
		expect(Badge.hello()).toBe("hello")
	end)
end)

return nil

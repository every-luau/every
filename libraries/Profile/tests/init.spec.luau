--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Profile = require("../src")

describe("Profile", function()
	it("says hello", function()
		expect(Profile.hello()).toBe("hello")
	end)
end)

return nil

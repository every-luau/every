--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Friend = require("../src")

describe("Friend", function()
	it("says hello", function()
		expect(Friend.hello()).toBe("hello")
	end)
end)

return nil

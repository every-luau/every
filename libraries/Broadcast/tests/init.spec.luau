--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Broadcast = require("../src")

describe("Broadcast", function()
	it("says hello", function()
		expect(Broadcast.hello()).toBe("hello")
	end)
end)

return nil

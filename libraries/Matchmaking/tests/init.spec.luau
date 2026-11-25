--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Matchmaking = require("../src")

describe("Matchmaking", function()
	it("says hello", function()
		expect(Matchmaking.hello()).toBe("hello")
	end)
end)

return nil

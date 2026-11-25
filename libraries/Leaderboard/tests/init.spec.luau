--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Leaderboard = require("../src")

describe("Leaderboard", function()
	it("says hello", function()
		expect(Leaderboard.hello()).toBe("hello")
	end)
end)

return nil

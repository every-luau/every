--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Elo = require("../src")

describe("Elo", function()
	it("says hello", function()
		expect(Elo.hello()).toBe("hello")
	end)
end)

return nil

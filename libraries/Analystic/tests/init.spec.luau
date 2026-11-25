--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Analystic = require("../src")

describe("Analystic", function()
	it("says hello", function()
		expect(Analystic.hello()).toBe("hello")
	end)
end)

return nil

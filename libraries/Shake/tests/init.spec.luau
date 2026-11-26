--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Shake = require("../src")

describe("Shake", function()
	it("says hello", function()
		expect(Shake.hello()).toBe("hello")
	end)
end)

return nil

--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Thumb = require("../src")

describe("Thumb", function()
	it("says hello", function()
		expect(Thumb.hello()).toBe("hello")
	end)
end)

return nil

--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local AlphaTween = require("../src")

describe("AlphaTween", function()
	it("says hello", function()
		expect(AlphaTween.hello()).toBe("hello")
	end)
end)

return nil

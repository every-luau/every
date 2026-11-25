--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Format = require("../src")

describe("Format", function()
	it("says hello", function()
		expect(Format.hello()).toBe("hello")
	end)
end)

return nil

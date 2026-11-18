--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Template = require("../src")

describe("Template", function()
	it("says hello", function()
		expect(Template.hello()).toBe("hello")
	end)
end)

return nil

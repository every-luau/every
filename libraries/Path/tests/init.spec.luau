--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Path = require("../src")

describe("Path", function()
	it("says hello", function()
		expect(Path.hello()).toBe("hello")
	end)
end)

return nil

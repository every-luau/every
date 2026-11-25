--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Table = require("../src")

describe("Table", function()
	it("says hello", function()
		expect(Table.hello()).toBe("hello")
	end)
end)

return nil

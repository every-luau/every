--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Audio = require("../src")

describe("Audio", function()
	it("says hello", function()
		expect(Audio.hello()).toBe("hello")
	end)
end)

return nil

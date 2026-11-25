--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Chat = require("../src")

describe("Chat", function()
	it("says hello", function()
		expect(Chat.hello()).toBe("hello")
	end)
end)

return nil

--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")

-- required as a client, where it follows what the server keeps
roblox.side.server = false
local already = roblox.part()
roblox.add_tag(already, "Caffeine")
local Caffeine = require("../src")

describe("Caffeine on a client", function()
	it("keeps parts the server tagged before it was required", function()
		roblox.step()
		expect(#already.impulses).toBe(1)

		roblox.remove_tag(already, "Caffeine")
		roblox.step()
		expect(#already.impulses).toBe(1)
		expect(roblox.listeners()).toBe(0)
	end)

	it("keeps parts the server tags later, until untagged", function()
		local part = roblox.part()
		roblox.add_tag(part, "Caffeine")
		roblox.step()
		expect(#part.impulses).toBe(1)

		roblox.remove_tag(part, "Caffeine")
		roblox.step()
		expect(#part.impulses).toBe(1)
		expect(roblox.listeners()).toBe(0)
	end)

	it("holds a part the server tagged and the client kept until both let go", function()
		local part = roblox.part()
		roblox.add_tag(part, "Caffeine")
		local connection = Caffeine(part :: any)

		roblox.remove_tag(part, "Caffeine")
		roblox.step()
		expect(#part.impulses).toBe(1)

		connection:disconnect()
		roblox.step()
		expect(#part.impulses).toBe(1)
	end)

	it("does not tag what it keeps", function()
		local part = roblox.part()
		local connection = Caffeine(part :: any)
		expect(roblox.has_tag(part, "Caffeine")).toBe(false)
		connection:disconnect()
	end)
end)

return nil

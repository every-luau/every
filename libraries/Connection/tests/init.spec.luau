--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

require("./roblox")
local Connection = require("../src")

describe("Connection", function()
	it("starts connected", function()
		local connection = Connection.new(function() end)
		expect(connection.connected).toBe(true)
	end)

	it("calls its cleanup function once when disconnected", function()
		local calls = 0
		local connection = Connection.new(function()
			calls += 1
		end)

		connection:disconnect()
		connection:disconnect()

		expect(connection.connected).toBe(false)
		expect(calls).toBe(1)
	end)

	it("destroys a cleanup object when disconnected", function()
		local destroyed = 0
		local item = {
			destroy = function()
				destroyed += 1
			end,
		}

		local connection = Connection.new(item :: any)
		connection:disconnect()

		expect(destroyed).toBe(1)
	end)

	it("disconnects when destroyed", function()
		local calls = 0
		local connection = Connection.new(function()
			calls += 1
		end)

		connection:destroy()

		expect(connection.connected).toBe(false)
		expect(calls).toBe(1)
	end)

	it("tells connections apart", function()
		expect(Connection.is(Connection.new(function() end))).toBe(true)
		expect(Connection.is({ connected = true })).toBe(false)
	end)
end)

return nil

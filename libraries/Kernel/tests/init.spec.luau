--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Konsole = require("./konsole") :: any
local Kernel = require("../src")

local entries: { Kernel.Entry } = {}
Kernel.executed:connect(function(entry)
	table.insert(entries, entry)
end)

Kernel.role("admin", 100, { users = { 1 } })
Kernel.role("moderator", 50, { groups = { [7] = 200 }, aliases = { "mod" } })
Kernel.role("vip", 5, { passes = { 99 } })
Kernel.role("tester", 20, {
	check = function(player)
		return player.UserId == 4
	end,
})

local given: { [string]: number } = {}

Kernel.command({
	name = "Give",
	description = "Gives coins",
	rank = "mod",
	args = { { name = "amount", type = "number" } },
	run = function(context, amount)
		given[(context.entity :: any).Name] = amount
		return `gave {amount}`
	end,
})

Kernel.command({
	name = "ping",
	run = function()
		return "pong"
	end,
})

Kernel.type("double", function(token)
	local value = tonumber(token)
	if value == nil then
		return false, "expected a number"
	end
	return true, value * 2
end)

Kernel.command({
	name = "twice",
	args = { { name = "value", type = "double" } },
	run = function(_, value)
		return tostring(value)
	end,
})

Kernel.start({ limit = 3, interval = 10 })

local admin = roblox.add_player(1)
local moderator = roblox.add_player(2, { groups = { [7] = 250 } })
local vip = roblox.add_player(3, { passes = { 99 } })
local tester = roblox.add_player(4)
local guest = roblox.add_player(5, { groups = { [7] = 100 } })

local function last(): Kernel.Entry
	return entries[#entries]
end

describe("Kernel", function()
	it("resolves roles from users, groups, passes and checks", function()
		expect(Kernel.level(admin)).toBe(100)
		expect(Kernel.level(moderator)).toBe(50)
		expect(Kernel.level(vip)).toBe(5)
		expect(Kernel.level(tester)).toBe(20)
		expect(Kernel.level(guest)).toBe(0)
	end)

	it("gives the highest role a player has", function()
		local both = roblox.add_player(1, { groups = { [7] = 255 } })
		expect(Kernel.level(both)).toBe(100)
	end)

	it("remembers a level until refreshed", function()
		local player = roblox.add_player(6, { groups = { [7] = 210 } })
		expect(Kernel.level(player)).toBe(50)
		expect(Kernel.level(player)).toBe(50)
		expect(player._group_calls[7]).toBe(1)

		player._groups[7] = 0
		expect(Kernel.level(player)).toBe(50)
		Kernel.refresh(player)
		expect(Kernel.level(player)).toBe(0)
	end)

	it("asks again when a web call failed", function()
		local player = roblox.add_player(8, { groups_fail = true })
		expect(Kernel.level(player)).toBe(0)
		expect(Kernel.level(player)).toBe(0)
		expect(player._group_calls[7]).toBe(2)
	end)

	it("forgets a level when a game pass is bought", function()
		local player = roblox.add_player(9)
		expect(Kernel.level(player)).toBe(0)
		table.insert(player._passes, 99)
		roblox.MarketplaceService.PromptGamePassPurchaseFinished:fire(player, 99, true)
		expect(Kernel.level(player)).toBe(5)
	end)

	it("checks ranks by level or role name", function()
		expect(Kernel.allows(moderator, "moderator")).toBe(true)
		expect(Kernel.allows(moderator, "admin")).toBe(false)
		expect(Kernel.allows(vip, 5)).toBe(true)
	end)

	it("runs server commands sent by players", function()
		local outcome = Konsole.invoke(moderator, "give 25")
		expect(outcome.ok).toBe(true)
		expect(outcome.message).toBe("gave 25")
		expect(given[moderator.Name]).toBe(25)
	end)

	it("refuses players below the rank", function()
		local outcome = Konsole.invoke(guest, "give 5")
		expect(outcome.ok).toBe(false)
		expect(outcome.code).toBe("not-authorized")
		expect(given[guest.Name]).toBe(nil)
	end)

	it("logs every command, refused or not", function()
		Konsole.invoke(vip, "ping")
		local entry = last()
		expect(entry.player).toBe(vip)
		expect(entry.command).toBe("ping")
		expect(entry.ok).toBe(true)
		expect(entry.message).toBe("pong")

		Konsole.invoke(vip, "nothing")
		expect(last().command).toBe(nil)
		expect(last().code).toBe("unknown-command")
	end)

	it("refuses text that is not a string", function()
		local outcome = Konsole.invoke(vip, 5)
		expect(outcome.code).toBe("bad-request")
	end)

	it("limits how fast a player sends commands", function()
		local player = roblox.add_player(10)
		for _ = 1, 3 do
			expect(Konsole.invoke(player, "ping").ok).toBe(true)
		end

		local outcome = Konsole.invoke(player, "ping")
		expect(outcome.code).toBe("ratelimit")
		expect(last().code).toBe("ratelimit")

		roblox.flush()
		expect(Konsole.invoke(player, "ping").ok).toBe(true)
	end)

	it("runs commands from the server through the log", function()
		local before = #entries
		expect(Kernel.run("ping").message).toBe("pong")
		expect(#entries).toBe(before + 1)
		expect(last().player).toBe(nil)
	end)

	it("uses argument types added with type", function()
		expect(Kernel.run("twice 4").message).toBe("8")
		expect(Kernel.run("twice x").code).toBe("bad-argument")
	end)

	it("refuses a command without a run function", function()
		expect(function()
			Kernel.command({ name = "broken" } :: any)
		end).toThrow("run function")
	end)

	it("can only start once", function()
		expect(function()
			Kernel.start()
		end).toThrow("already")
	end)
end)

return nil

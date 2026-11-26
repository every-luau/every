--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Clock = require("../src")

local lync = require("./lync")

-- the client the stand-in Lync delivers to, and another player
local me = Instance.new("Player") :: Player
local other = Instance.new("Player") :: Player
lync.player = me

-- runs `callback` as the client, after what the server sent has arrived
local function as_client<T>(callback: () -> T): T
	roblox.set_server(false)
	lync.deliver()
	local result = callback()
	roblox.set_server(true)
	return result
end

local names = 0
local function unique(): string
	names += 1
	return `Clock{names}`
end

describe("Clock", function()
	it("starts stopped at 0", function()
		local clock = Clock.new()
		expect(clock:get_time()).toBe(0)
		expect(clock:get_speed()).toBe(1)
		expect(clock:is_playing()).toBe(false)
		clock:destroy()
	end)

	it("moves with the server time only while playing", function()
		local clock = Clock.new()
		roblox.advance(1)
		expect(clock:get_time()).toBe(0)

		clock:start()
		roblox.advance(2)
		expect(clock:get_time()).toBe(2)

		clock:stop()
		roblox.advance(5)
		expect(clock:get_time()).toBe(2)
		clock:destroy()
	end)

	it("keeps the time passed when the speed changes", function()
		local clock = Clock.new():start()
		roblox.advance(2)
		clock:set_speed(-3)
		roblox.advance(1)
		expect(clock:get_time()).toBe(-1)
		clock:destroy()
	end)

	it("resets to a stopped 0", function()
		local clock = Clock.new():set_time(5):start()
		roblox.advance(1)
		clock:reset()
		expect(clock:get_time()).toBe(0)
		expect(clock:is_playing()).toBe(false)
		clock:destroy()
	end)

	it("fires changed on every change but not while it moves", function()
		local clock = Clock.new()
		local changes = 0
		clock.changed:connect(function()
			changes += 1
		end)

		clock:start()
		roblox.advance(1)
		clock:set_time(3)
		clock:set_speed(2)
		clock:start()
		clock:stop()
		expect(changes).toBe(4)
		clock:destroy()
	end)

	describe("replication", function()
		it("replicates a clock to clients at the same time", function()
			local name = unique()
			local server = Clock.new():set_time(60):set_speed(-1):start():replicate(name)
			roblox.advance(10)

			local client = as_client(function()
				return Clock.get(name):await()
			end)
			expect(client).toNotBe(server)
			expect(client:get_name()).toBe(name)
			expect(client:get_time()).toBe(50)
			expect(client:is_playing()).toBe(true)

			server:stop()
			roblox.advance(5)
			as_client(function()
				expect(client:is_playing()).toBe(false)
				expect(client:get_time()).toBe(50)
			end)

			server:destroy()
			as_client(function()
				expect(Clock.find(name)).toBe(nil)
			end)
		end)

		it("sends nothing while a replicated clock runs", function()
			local name = unique()
			local server = Clock.new():start():replicate(name)

			local client = as_client(function()
				return Clock.get(name):await()
			end)
			local received = 0
			client.changed:connect(function()
				received += 1
			end)

			roblox.advance(100)
			as_client(function()
				expect(received).toBe(0)
				expect(client:get_time()).toBe(server:get_time())
			end)

			server:set_speed(2)
			roblox.advance(10)
			as_client(function()
				expect(received).toBe(1)
				expect(client:get_time()).toBe(server:get_time())
			end)

			server:destroy()
		end)

		it("flushes the Clock namespace every frame once a clock is replicated", function()
			local clock = Clock.new():replicate(unique())
			local before = lync.flushes
			roblox.advance(1)
			expect(lync.flushes > before).toBe(true)
			clock:destroy()
		end)

		it("gives a future that resolves once the clock arrives", function()
			local name = unique()
			local future = as_client(function()
				return Clock.get(name)
			end)
			expect(future:is_pending()).toBe(true)

			local clock = Clock.new():replicate(name)
			expect(future:is_pending()).toBe(true)

			as_client(function()
				expect(future:get_status()).toBe("resolved")
				expect(future:await()).toBe(Clock.find(name))
				expect(Clock.get(name):await()).toBe(Clock.find(name))
			end)

			clock:destroy()
		end)

		it("leaves find and get to clients", function()
			expect(function()
				Clock.find("Round")
			end).toThrow("for clients")
			expect(function()
				Clock.get("Round")
			end).toThrow("for clients")
		end)

		it("keeps the time a clock had before it was replicated", function()
			local name = unique()
			local server = Clock.new():start()
			roblox.advance(7)
			server:replicate(name)

			as_client(function()
				expect(Clock.get(name):await():get_time()).toBe(7)
			end)

			server:destroy()
		end)

		it("keeps the copy on a client read only", function()
			local name = unique()
			local server = Clock.new():replicate(name)

			as_client(function()
				local client = Clock.get(name):await()
				expect(function()
					client:start()
				end).toThrow("only the server")
				expect(function()
					Clock.new():replicate(unique())
				end).toThrow("only the server")
			end)

			server:destroy()
		end)

		it("replicates to some players only", function()
			local name = unique()
			local clock = Clock.new():replicate(name, other)
			expect(clock:is_replicated_to(other)).toBe(true)
			expect(clock:is_replicated_to(me)).toBe(false)

			as_client(function()
				expect(Clock.find(name)).toBe(nil)
			end)

			clock:add_players(me)
			expect(clock:is_replicated_to(me)).toBe(true)
			local copy = as_client(function()
				return Clock.find(name)
			end)
			expect(copy).toNotBe(nil)

			clock:remove_players({ me })
			as_client(function()
				expect(Clock.find(name)).toBe(nil)
			end)

			expect(function()
				Clock.new():replicate(unique()):add_players(me)
			end).toThrow("some players")

			clock:destroy()
		end)

		it("lets a name hold one clock per player", function()
			local name = unique()
			local mine = Clock.new():set_time(1):replicate(name, me)
			local theirs = Clock.new():set_time(2):replicate(name, other)

			expect(mine:is_replicated_to(me)).toBe(true)
			expect(theirs:is_replicated_to(me)).toBe(false)

			expect(function()
				Clock.new():replicate(name)
			end).toThrow("same players")
			expect(function()
				mine:add_players(other)
			end).toThrow("already gets")

			as_client(function()
				expect(Clock.get(name):await():get_time()).toBe(1)
			end)

			mine:destroy()
			theirs:destroy()
		end)

		it("unreplicates without stopping the clock", function()
			local name = unique()
			local clock = Clock.new():start():replicate(name)
			as_client(function()
				expect(Clock.find(name)).toNotBe(nil)
			end)

			clock:unreplicate()
			expect(clock:get_name()).toBe(nil)
			expect(clock:is_playing()).toBe(true)
			as_client(function()
				expect(Clock.find(name)).toBe(nil)
			end)

			local again = Clock.new():replicate(name)
			again:destroy()
			clock:destroy()
		end)

		it("replicates a clock once", function()
			local clock = Clock.new():replicate(unique())
			expect(function()
				clock:replicate(unique())
			end).toThrow("already replicated")
			clock:destroy()
		end)
	end)

	it("calls at once when the time is reached", function()
		local clock = Clock.new():set_time(10):set_speed(-1):start()
		local calls = 0
		local connection = clock:at(4, function()
			calls += 1
		end)

		roblox.advance(5)
		expect(calls).toBe(0)
		roblox.advance(1)
		expect(calls).toBe(1)
		expect(connection.connected).toBe(false)
		roblox.advance(10)
		expect(calls).toBe(1)
		clock:destroy()
	end)

	it("follows changes before calling at", function()
		local clock = Clock.new():start()
		local called_at: number? = nil
		clock:at(10, function()
			called_at = Clock.synced_time()
		end)

		local started = Clock.synced_time()
		roblox.advance(2)
		clock:stop()
		roblox.advance(100)
		expect(called_at).toBe(nil)

		clock:set_speed(2):start()
		roblox.advance(10)
		expect(called_at).toBe(started + 106)
		clock:destroy()
	end)

	it("waits in at while the clock moves away", function()
		local clock = Clock.new():set_time(5):start()
		local calls = 0
		clock:at(1, function()
			calls += 1
		end)

		roblox.advance(10)
		expect(calls).toBe(0)
		expect(roblox.delays()).toBe(0)

		clock:set_time(0)
		roblox.advance(1)
		expect(calls).toBe(1)
		clock:destroy()
	end)

	it("cancels at when disconnected", function()
		local clock = Clock.new():start()
		local calls = 0
		clock:at(1, function()
			calls += 1
		end):disconnect()

		roblox.advance(2)
		expect(calls).toBe(0)
		expect(roblox.delays()).toBe(0)
		clock:destroy()
	end)

	it("observes every frame only while playing", function()
		local base = roblox.heartbeat_listeners()
		local clock = Clock.new()
		local seen: { number } = {}
		local connection = clock:observe(function(time)
			table.insert(seen, time)
		end)

		expect(roblox.heartbeat_listeners()).toBe(base)
		clock:start()
		expect(roblox.heartbeat_listeners()).toBe(base + 1)
		roblox.advance(1)
		clock:stop()
		expect(roblox.heartbeat_listeners()).toBe(base)
		expect(seen).toEqual({ 0, 0, 1, 1 })

		connection:disconnect()
		clock:set_time(5)
		expect(#seen).toBe(4)
		clock:destroy()
	end)

	it("gives an atom of the time that follows the clock", function()
		local base = roblox.heartbeat_listeners()
		local clock = Clock.new()
		local atom = clock:atom()
		expect(clock:atom()).toBe(atom)
		expect(atom:get()).toBe(0)

		local seconds = atom:map(math.floor)
		local seen: { number } = {}
		seconds:observe(function(value)
			table.insert(seen, value)
		end)

		clock:start()
		roblox.advance(0.5)
		roblox.advance(0.5)
		roblox.advance(0.5)
		expect(atom:get()).toBe(1.5)
		expect(seen).toEqual({ 0, 1 })

		clock:set_time(10)
		expect(atom:get()).toBe(10)
		expect(seen).toEqual({ 0, 1, 10 })

		clock:destroy()
		expect(roblox.heartbeat_listeners()).toBe(base)
	end)

	it("disconnects everything once destroyed", function()
		local base = roblox.heartbeat_listeners()
		local clock = Clock.new():start()
		local calls = 0
		clock:observe(function()
			calls += 1
		end)
		clock:at(5, function()
			calls += 1
		end)

		clock:destroy()
		roblox.flush()
		calls = 0
		roblox.advance(10)
		expect(calls).toBe(0)
		expect(roblox.heartbeat_listeners()).toBe(base)
		expect(roblox.delays()).toBe(0)
	end)

	it("tells clocks apart", function()
		expect(Clock.is(Clock.new())).toBe(true)
		expect(Clock.is({})).toBe(false)
	end)
end)

describe("shared time", function()
	it("gives the synced time and the data time, and measures from it", function()
		local stamp = Clock.timestamp()
		expect(stamp).toBe(math.floor(Clock.synced_time()))

		roblox.advance(30)
		expect(Clock.since(stamp) >= 30).toBe(true)
		expect(Clock.left(stamp + 100) <= 70).toBe(true)
		expect(Clock.left(stamp)).toBe(0)
	end)

	it("counts periods from the epoch, shifted by the offset", function()
		-- move to the start of a period of 100 seconds
		roblox.advance(Clock.next(100) - Clock.synced_time())
		local period = Clock.period(100)
		expect(Clock.synced_time()).toBe(period * 100)
		expect(Clock.next(100)).toBe((period + 1) * 100)

		roblox.advance(99)
		expect(Clock.period(100)).toBe(period)
		expect(Clock.period(100, 50)).toBe(period)
		roblox.advance(1)
		expect(Clock.period(100)).toBe(period + 1)
		expect(Clock.next(100, 50)).toBe(period * 100 + 150)
	end)

	it("calls back at the start of every period", function()
		local seen = {}
		local connection = Clock.every(10, function(period)
			table.insert(seen, { period, Clock.synced_time() })
		end)

		local first = Clock.next(10)
		roblox.advance(first - Clock.synced_time() + 25)
		expect(#seen).toBe(3)
		expect(seen[1][2]).toBe(first)
		expect(seen[1][1]).toBe(first / 10)
		expect(seen[3][1]).toBe(first / 10 + 2)

		connection:disconnect()
		roblox.advance(30)
		expect(#seen).toBe(3)
	end)

	it("stops when disconnected from its callback", function()
		local calls = 0
		local connection
		connection = Clock.every(5, function()
			calls += 1
			connection:disconnect()
		end)
		roblox.advance(20)
		expect(calls).toBe(1)
	end)

	it("refuses a period that is not above 0", function()
		expect(function()
			Clock.period(0)
		end).toThrow("above 0")
		expect(function()
			Clock.every(-1, function() end)
		end).toThrow("above 0")
	end)
end)

return nil

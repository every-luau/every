--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Elo = require("../src")

local function round(value: number, places: number?): number
	local scale = 10 ^ (places or 1)
	return math.round(value * scale) / scale
end

describe("config", function()
	it("chains setters and reads the initial rating", function()
		local config = Elo.new():set_k(20):set_factor(200):set_initial(1000):set_floor(0):set_group(true)
		expect(Elo.is(config)).toBe(true)
		expect(Elo.is({})).toBe(false)
		expect(config:get_initial()).toBe(1000)
		expect(Elo.new():get_initial()).toBe(1400)
	end)

	it("errors on bad settings and a missing config", function()
		expect(function()
			Elo.new():set_k("a" :: any)
		end).toThrow("set_k needs")
		expect(function()
			Elo.new():set_factor(0)
		end).toThrow("above 0")
		expect(function()
			Elo.rate({} :: any, 1, 2, Elo.WIN)
		end).toThrow("needs a config")
	end)

	it("moves less at high ratings with the fide K", function()
		expect(Elo.fide(1400)).toBe(32)
		expect(Elo.fide(2100)).toBe(24)
		expect(Elo.fide(2400)).toBe(16)
	end)
end)

describe("rating", function()
	local config = Elo.new()

	it("expects the stronger player to win more", function()
		expect(Elo.expected(config, 1400, 1400)).toBe(0.5)
		expect(round(Elo.expected(config, 1800, 1400), 2)).toBe(0.91)
		expect(round(Elo.expected(config, 1400, 1800) + Elo.expected(config, 1800, 1400), 6)).toBe(1)
	end)

	it("moves both players after a win, a draw or a loss", function()
		local rating_a, rating_b = Elo.rate(config, 1400, 1800, Elo.WIN)
		expect(round(rating_a)).toBe(1429.1)
		expect(round(rating_b)).toBe(1770.9)

		rating_a, rating_b = Elo.rate(config, 1400, 1800, Elo.DRAW)
		expect(rating_a > 1400 and rating_b < 1800).toBe(true)

		rating_a, rating_b = Elo.rate(config, 1400, 1800, Elo.LOSS)
		expect(round(rating_a)).toBe(1397.1)
		expect(round(rating_b)).toBe(1802.9)
	end)

	it("matches the example with a K of 24", function()
		local custom = Elo.new():set_k(24):set_initial(1000)
		local alice, bob = Elo.rate(custom, 1000, 1200, Elo.WIN)
		expect(round(alice)).toBe(1018.2)
		expect(round(bob)).toBe(1181.8)
		expect(round(Elo.expected(custom, alice, bob), 2)).toBe(0.28)
	end)

	it("moves each player by their own K", function()
		local rating_a, rating_b = Elo.rate(config, 2500, 1400, Elo.LOSS)
		expect(round(2500 - rating_a, 2)).toBe(round(16 * Elo.expected(config, 2500, 1400), 2))
		expect(round(rating_b - 1400, 2)).toBe(round(32 * Elo.expected(config, 2500, 1400), 2))
	end)

	it("keeps ratings above the floor", function()
		-- an even loss takes 16, which would leave 94
		local rating_a = Elo.rate(config, 110, 110, Elo.LOSS)
		expect(rating_a).toBe(100)
		local none = Elo.rate(Elo.new():set_floor(-math.huge), 110, 110, Elo.LOSS)
		expect(none).toBe(94)
	end)

	it("adds up every game of a series", function()
		local rating_a, rating_b = Elo.rate(config, 1400, 1400, { Elo.WIN, Elo.WIN, Elo.LOSS })
		expect(rating_a).toBe(1416)
		expect(rating_b).toBe(1384)
	end)

	it("counts a series as one match when grouped, a tie as a draw", function()
		local grouped = Elo.new():set_group(true)
		local rating_a = Elo.rate(grouped, 1400, 1400, { Elo.WIN, Elo.WIN, Elo.LOSS })
		expect(rating_a).toBe(1432)

		local tie, other = Elo.rate(grouped, 1400, 1400, { Elo.WIN, Elo.LOSS })
		expect(tie).toBe(1400)
		expect(other).toBe(1400)
	end)

	it("gives the change of each player", function()
		local win, lose = Elo.change(config, 1400, 1800, Elo.WIN)
		expect(round(win)).toBe(29.1)
		expect(round(lose)).toBe(-29.1)
	end)

	it("errors on a result outside 0 to 1", function()
		expect(function()
			Elo.rate(config, 1400, 1400, 2)
		end).toThrow("score from 0 to 1")
		expect(function()
			Elo.rate(config, 1400, 1400, { 1, -1 })
		end).toThrow("score from 0 to 1")
	end)
end)

describe("percentiles", function()
	local config = Elo.new()

	it("gives the share of players below a rating", function()
		expect(round(Elo.percentile(config, 1400), 3)).toBe(0.5)
		expect(round(Elo.percentile(config, 1800), 2)).toBe(0.92)
		expect(round(Elo.percentile(config, 1000), 2)).toBe(0.08)
	end)

	it("gives the rating at a share, the other way around", function()
		expect(round(Elo.rating_at(config, 0.9))).toBe(1762.5)
		for _, share in { 0.001, 0.01, 0.2, 0.5, 0.75, 0.99, 0.999 } do
			expect(round(Elo.percentile(config, Elo.rating_at(config, share)), 4)).toBe(round(share, 4))
		end
		expect(function()
			Elo.rating_at(config, 1)
		end).toThrow("above 0 and below 1")
	end)
end)

return nil

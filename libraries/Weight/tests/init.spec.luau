--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

require("./roblox")
local Cryptography = require("./cryptography")
local Weight = require("../src")

local function count(weight: any, luck: number?, rolls: number): { [string]: number }
	local counts: { [string]: number } = {}
	for _ = 1, rolls do
		local key = weight:generate(luck)
		counts[key] = (counts[key] or 0) + 1
	end
	return counts
end

describe(
	"Weight",
	function()
		it(
			"only generates keys of the table",
			function()
				local weight = Weight.new({ a = 1, b = 1 })
				for _ = 1, 100 do
					local key = weight:generate()
					expect(key == "a" or key == "b").toBe(true)
				end
			end
		)

		it(
			"never generates keys with a weight of 0 or less",
			function()
				local counts = count(Weight.new({ a = 1, b = 0, c = -5 }), nil, 500)
				expect(counts.a).toBe(500)
				expect(counts.b).toBeNil()
				expect(counts.c).toBeNil()
			end
		)

		it(
			"follows the weights",
			function()
				local counts = count(Weight.new({ common = 9, rare = 1 }), nil, 10000)
				expect(counts.common > 8500 and counts.common < 9500).toBe(true)
			end
		)

		it(
			"rolls with the CSPRNG",
			function()
				local CSPRNG = Cryptography.Utilities.CSPRNG
				local random = CSPRNG.Random
				local calls = 0
				CSPRNG.Random = function()
					calls += 1
					return 0
				end

				Weight.new({ a = 1 }):generate()
				CSPRNG.Random = random
				expect(calls).toBe(1)
			end
		)

		it(
			"makes rare keys more likely with luck",
			function()
				local weight = Weight.new({ common = 100, rare = 1 }, 1)
				local values = weight:get_values(10)
				expect(values.common / values.rare < 100).toBe(true)
			end
		)

		it(
			"errors when nothing can be generated",
			function()
				expect(function()
					Weight.new({ a = 0 }):generate()
				end).toThrow("no positive weight")
			end
		)

		it(
			"sums the weights",
			function()
				expect(Weight.new({ a = 2, b = 3, c = 0 }):get_total_weight()).toBe(5)
			end
		)

		it(
			"copies the table it is given",
			function()
				local weights = { a = 1 }
				local weight = Weight.new(weights)
				weights.a = 0
				expect(weight:get_values().a).toBe(1)
			end
		)

		it(
			"merges with +, the right side winning",
			function()
				local merged = Weight.new({ a = 1, b = 2 }) + Weight.new({ b = 5, c = 3 }, 4)
				expect(merged:get_values()).toEqual({ a = 1, b = 5, c = 3 })
				expect(merged:get_intensity()).toBe(4)
			end
		)

		it(
			"sets and resets the intensity",
			function()
				local weight = Weight.new({ a = 1 })
				expect(weight:set_intensity(3):get_intensity()).toBe(3)
				expect(weight:set_intensity():get_intensity()).toBe(10)
			end
		)

		it(
			"tells weights apart",
			function()
				expect(Weight.is(Weight.new({}))).toBe(true)
				expect(Weight.is({})).toBe(false)
			end
		)

		it(
			"prints its weights",
			function()
				expect(tostring(Weight.new({ b = 2, a = 1 }))).toBe("Weight { a = 1, b = 2 }")
			end
		)
	end
)

return nil

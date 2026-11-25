--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

require("./roblox")
const Cieluv = require("../src")

const function rgb(r: number, g: number, b: number): Color3
	return Color3.new(r, g, b)
end

const function expect_color(color: Color3, r: number, g: number, b: number)
	expect(color.R).toBeCloseTo(r, 4)
	expect(color.G).toBeCloseTo(g, 4)
	expect(color.B).toBeCloseTo(b, 4)
end

describe("Cieluv.from_color3", function()
	it("gives white a lightness of 100 and no hue", function()
		const l, u, v = Cieluv.from_color3(rgb(1, 1, 1))
		expect(l).toBeCloseTo(100, 3)
		expect(u).toBeCloseTo(0, 3)
		expect(v).toBeCloseTo(0, 3)
	end)

	it("gives black zeros", function()
		const l, u, v = Cieluv.from_color3(rgb(0, 0, 0))
		expect(l).toBe(0)
		expect(u).toBe(0)
		expect(v).toBe(0)
	end)

	it("matches the reference values for the sRGB primaries", function()
		const cases = {
			{ rgb(1, 0, 0), 53.2408, 175.0151, 37.7564 },
			{ rgb(0, 1, 0), 87.7347, -83.0776, 107.3985 },
			{ rgb(0, 0, 1), 32.2970, -9.4054, -130.3423 },
		}
		for _, case in cases do
			const l, u, v = Cieluv.from_color3(case[1])
			expect(l).toBeCloseTo(case[2], 2)
			expect(u).toBeCloseTo(case[3], 2)
			expect(v).toBeCloseTo(case[4], 2)
		end
	end)

	it("uses the linear part of lightness for very dark colors", function()
		const l = Cieluv.from_color3(rgb(0.01, 0.01, 0.01))
		expect(l > 0 and l < 8).toBe(true)
	end)
end)

describe("Cieluv.to_color3", function()
	it("turns back every color it converted", function()
		const colors = {
			rgb(1, 0, 0),
			rgb(0.2, 0.6, 0.9),
			rgb(0.5, 0.5, 0.5),
			rgb(0.01, 0.02, 0.005),
			rgb(1, 1, 0),
			rgb(0.9, 0.1, 0.7),
		}
		for _, color in colors do
			expect_color(Cieluv.to_color3(Cieluv.from_color3(color)), color.R, color.G, color.B)
		end
	end)

	it("gives black for a lightness of 0", function()
		expect_color(Cieluv.to_color3(0, 50, 50), 0, 0, 0)
	end)

	it("clamps colors RGB can't show", function()
		const color = Cieluv.to_color3(60, 200, -200)
		for _, channel in { color.R, color.G, color.B } do
			expect(channel >= 0 and channel <= 1).toBe(true)
		end
	end)
end)

describe("Cieluv.lerp", function()
	it("gives the first color at 0 and the second at 1", function()
		const red, blue = rgb(1, 0, 0), rgb(0, 0, 1)
		expect_color(Cieluv.lerp(red, blue, 0), 1, 0, 0)
		expect_color(Cieluv.lerp(red, blue, 1), 0, 0, 1)
	end)

	it("blends black and white into the gray halfway in lightness", function()
		const gray = Cieluv.lerp(rgb(0, 0, 0), rgb(1, 1, 1), 0.5)
		const l, u, v = Cieluv.from_color3(gray)
		expect(l).toBeCloseTo(50, 3)
		expect(u).toBeCloseTo(0, 3)
		expect(v).toBeCloseTo(0, 3)
		expect(gray.R).toBeCloseTo(0.4663, 3)
	end)

	it("blends lightness linearly", function()
		const red, blue = rgb(1, 0, 0), rgb(0, 0, 1)
		const l0 = Cieluv.from_color3(red)
		const l1 = Cieluv.from_color3(blue)
		const l = Cieluv.from_color3(Cieluv.lerp(red, blue, 0.25))
		expect(l).toBeCloseTo(l0 + (l1 - l0) * 0.25, 1)
	end)
end)

describe("Cieluv.lerper", function()
	it("blends like lerp", function()
		const from, to = rgb(0.9, 0.3, 0.1), rgb(0.1, 0.4, 0.8)
		const blend = Cieluv.lerper(from, to)
		for _, alpha in { 0, 0.3, 0.5, 0.8, 1 } do
			const expected = Cieluv.lerp(from, to, alpha)
			expect_color(blend(alpha), expected.R, expected.G, expected.B)
		end
	end)
end)

return nil

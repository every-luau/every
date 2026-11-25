--!optimize 2

--[=[
	@class Cieluv

	Cieluv converts Color3 to and from CIELUV, and blends colors through it

	CIELUV is a color space built so that equal steps look equally different to
	the eye. blending two colors in it, instead of in RGB like `Color3:Lerp`,
	keeps the brightness even and avoids the muddy gray in the middle of a
	blend between opposite colors

	```lua
	local Cieluv = require(path.to.Cieluv)

	local l, u, v = Cieluv.from_color3(Color3.new(1, 0, 0))
	print(l, u, v) --> 53.24 175.01 37.76

	local purple = Cieluv.lerp(Color3.new(1, 0, 0), Color3.new(0, 0, 1), 0.5)
	```

	:::info
	`l` is the lightness, from 0 for black to 100 for white. `u` goes from green
	to red and `v` from blue to yellow. both are 0 for grays and reach about 175
	away from it for the most saturated colors. colors use sRGB with a D65 white
	point, like Roblox
	:::
]=]

-- the white point the Luv values are relative to: D65, as the sRGB matrix sees it
const WHITE_X = 0.4124564 + 0.3575761 + 0.1804375
const WHITE_Y = 0.2126729 + 0.7151522 + 0.0721750
const WHITE_Z = 0.0193339 + 0.1191920 + 0.9503041
const WHITE_DENOMINATOR = WHITE_X + 15 * WHITE_Y + 3 * WHITE_Z
const WHITE_U = 4 * WHITE_X / WHITE_DENOMINATOR
const WHITE_V = 9 * WHITE_Y / WHITE_DENOMINATOR

-- under EPSILON, lightness is linear with luminance instead of a cube root
const EPSILON = 216 / 24389
const KAPPA = 24389 / 27

const function to_linear(channel: number): number
	if channel <= 0.04045 then
		return channel / 12.92
	end
	return ((channel + 0.055) / 1.055) ^ 2.4
end

const function to_srgb(channel: number): number
	-- colors outside what RGB can show come out of range, so they are clamped
	if channel <= 0 then
		return 0
	elseif channel >= 1 then
		return 1
	elseif channel <= 0.0031308 then
		return channel * 12.92
	end
	return 1.055 * channel ^ (1 / 2.4) - 0.055
end

--[=[
	@within Cieluv
	@function from_color3
	@param color Color3
	@return number -- lightness, from 0 to 100
	@return number -- u
	@return number -- v

	converts `color` to CIELUV

	```lua
	local l, u, v = Cieluv.from_color3(Color3.new(1, 1, 1)) --> 100, 0, 0
	```
]=]
const function from_color3(color: Color3): (number, number, number)
	const r, g, b = to_linear(color.R), to_linear(color.G), to_linear(color.B)

	const x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b
	const y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
	const z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b

	const luminance = y / WHITE_Y
	const l = if luminance > EPSILON then 116 * luminance ^ (1 / 3) - 16 else KAPPA * luminance

	const denominator = x + 15 * y + 3 * z
	if denominator == 0 then
		-- black has no hue
		return 0, 0, 0
	end

	const u = 13 * l * (4 * x / denominator - WHITE_U)
	const v = 13 * l * (9 * y / denominator - WHITE_V)
	return l, u, v
end

--[=[
	@within Cieluv
	@function to_color3
	@param l number
	@param u number
	@param v number
	@return Color3

	converts a CIELUV color to a Color3. a color RGB can't show, like a very
	saturated one, is clamped to the closest it can

	```lua
	local gray = Cieluv.to_color3(50, 0, 0)
	```
]=]
const function to_color3(l: number, u: number, v: number): Color3
	if l <= 0 then
		return Color3.new(0, 0, 0)
	end

	const u_prime = u / (13 * l) + WHITE_U
	const v_prime = v / (13 * l) + WHITE_V
	const y = WHITE_Y * (if l > KAPPA * EPSILON then ((l + 16) / 116) ^ 3 else l / KAPPA)
	const x = y * 9 * u_prime / (4 * v_prime)
	const z = y * (12 - 3 * u_prime - 20 * v_prime) / (4 * v_prime)

	return Color3.new(
		to_srgb(3.2404542 * x - 1.5371385 * y - 0.4985314 * z),
		to_srgb(-0.9692660 * x + 1.8760108 * y + 0.0415560 * z),
		to_srgb(0.0556434 * x - 0.2040259 * y + 1.0572252 * z)
	)
end

--[=[
	@within Cieluv
	@function lerper
	@param from Color3
	@param to Color3
	@return (alpha: number) -> Color3

	returns a function blending `from` into `to` by `alpha` in CIELUV, like
	[Cieluv.lerp]. both colors are converted once, so it is the one to use every
	frame

	```lua
	local blend = Cieluv.lerper(Color3.new(1, 0, 0), Color3.new(0, 0, 1))

	RunService.Heartbeat:Connect(function()
		part.Color = blend(math.sin(os.clock()) / 2 + 0.5)
	end)
	```
]=]
const function lerper(from: Color3, to: Color3): (alpha: number) -> Color3
	const l0, u0, v0 = from_color3(from)
	const l1, u1, v1 = from_color3(to)
	const dl, du, dv = l1 - l0, u1 - u0, v1 - v0

	return function(alpha: number): Color3
		return to_color3(l0 + dl * alpha, u0 + du * alpha, v0 + dv * alpha)
	end
end

--[=[
	@within Cieluv
	@function lerp
	@param from Color3
	@param to Color3
	@param alpha number
	@return Color3

	blends `from` into `to` by `alpha` in CIELUV: 0 gives `from`, 1 gives `to`.
	use [Cieluv.lerper] to blend the same two colors many times

	```lua
	local orange = Cieluv.lerp(Color3.new(1, 0, 0), Color3.new(1, 1, 0), 0.5)
	```
]=]
const function lerp(from: Color3, to: Color3, alpha: number): Color3
	const l0, u0, v0 = from_color3(from)
	const l1, u1, v1 = from_color3(to)

	return to_color3(l0 + (l1 - l0) * alpha, u0 + (u1 - u0) * alpha, v0 + (v1 - v0) * alpha)
end

return table.freeze({
	from_color3 = from_color3,
	to_color3 = to_color3,
	lerp = lerp,
	lerper = lerper,
})

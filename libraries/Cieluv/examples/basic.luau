--!strict
-- Converting colors to CIELUV and blending them through it.

local Cieluv = require("../src")

-- `l` is the lightness from 0 to 100, `u` and `v` the hue and saturation.
local l, u, v = Cieluv.from_color3(Color3.new(1, 0, 0))
print(l, u, v) --> 53.24 175.01 37.76

-- Making a color lighter without changing its hue.
local light_red = Cieluv.to_color3(l + 20, u, v)
print(light_red)

-- Halfway between red and blue. Color3:Lerp gives a dark purple here, while
-- CIELUV keeps the lightness between the two.
local purple = Cieluv.lerp(Color3.new(1, 0, 0), Color3.new(0, 0, 1), 0.5)
print(purple)

-- A lerper converts both colors once, for blending them every frame.
local blend = Cieluv.lerper(Color3.new(1, 0, 0), Color3.new(0, 0, 1))
for step = 0, 4 do
	print(blend(step / 4))
end

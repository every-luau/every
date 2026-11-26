-- The presets of Gradient.preset, after the effects of ezVisualz. each one
-- builds a gradient with `new`, from `speed`, the turns a second of its colors,
-- and `color`, the color of Shine, ShineOutline and Wave.
--
-- the ezVisualz presets with and without a stroke, like Gold and GoldStroke,
-- are one preset here: its stroke gradient is only used on the strokes it is
-- added to. the outline presets only paint strokes.

const colors = require("./colors")

-- what a preset gets: `new` builds a gradient from colors and a transparency
type Build = (new: (color: ColorSequence, transparency: (number | NumberSequence)?) -> any, speed: number, color: Color3) -> any

-- degrees a second an outline turns at speed 1
const TURN = 360

-- a ColorSequence from `color` to a lighter `color` in the middle and back
const function shine(color: Color3, light: number): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.5, color:Lerp(Color3.new(1, 1, 1), light)),
		ColorSequenceKeypoint.new(1, color),
	})
end

-- a preset whose stroke uses the same colors, from the fill and stroke angles
-- and speeds, the stroke speed relative to the fill one
const function paired(sequence: ColorSequence, fill_rotation: number, stroke_rotation: number, stroke_speed: number): Build
	return function(new, speed)
		return new(sequence)
			:set_rotation(fill_rotation)
			:set_speed(speed)
			:set_stroke(new(sequence):set_rotation(stroke_rotation):set_speed(speed * stroke_speed))
	end
end

-- a preset that only paints strokes, turning around them
const function outline(sequence: ColorSequence, transparency: NumberSequence?, rotation: number): Build
	return function(new, speed)
		return new(sequence, transparency):set_fill(false):set_rotation(rotation):set_rotation_speed(TURN * speed)
	end
end

const presets: { [string]: Build } = {
	Bubblegum = function(new, speed)
		return new(colors.Bubblegum):set_rotation(-90):set_speed(speed):set_stroke(
			new(colors.Bubblegum):set_rotation(-45):set_speed(speed * 0.9):set_pulse(0.5, 3.25, speed)
		)
	end,
	Chrome = paired(colors.Chrome, -90, -89, 0.58),
	Death = paired(colors.Death, -90, -85, -1),
	Electric = function(new, speed)
		return new(colors.Electric):set_rotation(-60):set_speed(speed * 2.5):set_sway(30, speed * 0.8):set_stroke(
			new(colors.Electric)
				:set_rotation(60)
				:set_speed(-speed * 2)
				:set_sway(-30, speed * 0.72)
				:set_pulse(1, 1.4, speed)
		)
	end,
	Fire = function(new, speed)
		return new(colors.Fire):set_rotation(-75):set_rotation_speed(20 * speed):set_speed(speed):set_stroke(
			new(colors.Fire):set_rotation(75):set_speed(-speed)
		)
	end,
	Galaxy = function(new, speed)
		return new(colors.Galaxy):set_rotation(90):set_rotation_speed(30 * speed):set_speed(speed * 0.5):set_stroke(
			new(colors.Galaxy):set_rotation(-90):set_rotation_speed(-30 * speed):set_speed(-speed * 0.3)
		)
	end,
	Ghost = function(new, speed)
		return new(colors.Ghost, colors.Hollow):set_speed(speed):set_transparency_speed(speed * 0.9):set_stroke(
			new(colors.Ghost, colors.Hollow):set_speed(-speed * 0.9):set_transparency_speed(-speed * 0.9)
		)
	end,
	Gold = paired(colors.Gold, -75, 75, -1),
	Ice = paired(colors.Ice, -65, -61, 0.23),
	Lava = paired(colors.Lava, 0, 0, -1),
	Matrix = function(new, speed)
		return new(colors.Matrix):set_rotation(90):set_speed(speed):set_stroke(
			new(colors.Matrix):set_rotation(90):set_offset(0.5):set_speed(speed)
		)
	end,
	Neon = function(new, speed)
		return new(colors.Neon):set_rotation(45):set_rotation_speed(60 * speed):set_speed(speed):set_stroke(
			new(colors.Neon):set_rotation(-45):set_speed(-speed * 0.7)
		)
	end,
	Oceanic = function(new, speed)
		return new(colors.Oceanic):set_rotation(-75):set_rotation_speed(10 * speed):set_speed(speed):set_stroke(
			new(colors.Oceanic):set_speed(-speed)
		)
	end,
	Rainbow = paired(colors.Rainbow, 0, 0, -1),
	Shine = function(new, speed, color)
		return new(shine(color, 0.42)):set_rotation(60):set_speed(speed * 0.6)
	end,
	Silver = paired(colors.Silver, -75, -79, 0.56),
	Sunset = function(new, speed)
		return new(colors.Sunset):set_rotation(-60):set_speed(speed * 0.8):set_sway(20, speed * 0.4):set_stroke(
			new(colors.Sunset):set_rotation(60):set_speed(-speed * 0.6):set_sway(-20, speed * 0.4)
		)
	end,
	Zebra = function(new, speed)
		return new(colors.Zebra):set_rotation(90):set_speed(speed):set_stroke(
			new(colors.Zebra):set_rotation(90):set_offset(0.5):set_speed(speed)
		)
	end,

	GreenOutline = outline(colors.Green, colors.Arc, 5),
	RainbowOutline = outline(colors.Rainbow, nil, 5),
	ShineOutline = function(new, speed, color)
		return outline(shine(color, 0.6), nil, 0.75)(new, speed, color)
	end,
	Wave = function(new, speed, color)
		return new(ColorSequence.new(color), colors.Band):set_fill(false):set_transparency_speed(speed * 0.9)
	end,
}

return table.freeze(presets)

--!native
--!optimize 2

--[=[
	@class Gradient

	Gradient animates UIGradients: their colors and transparency slide, and
	their angle turns or sways

	a gradient paints every target added to it: the UIGradient of a GuiObject,
	of a UIStroke, or a UIGradient itself. it works out its sequences once a
	frame for all of them, so share one gradient between the things that look
	the same. [Gradient.preset] builds a ready one, like `Rainbow` or `Gold`

	```lua
	local Gradient = require(path.to.Gradient)

	local rainbow = Gradient.preset("Rainbow")
	rainbow:add(title)
	-- paints button, and a 2 pixel outline with the stroke colors
	rainbow:add(button, 2)

	local fade = Gradient.new(ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)))
		:set_speed(0.25)
		:set_rotation(45)
	fade:add(frame)
	```

	:::info
	a UIGradient multiplies the color under it, so keep the text, background,
	image or stroke white to see its colors as they are
	:::

	Credits: m7ttxo, and the presets of [ezVisualz](https://github.com/arxkdev/ezVisualz)
	by Arxk and RhodesDigital
]=]

const RunService = game:GetService("RunService")

const presets = require("@self/presets")

-- the positions an offset is rounded to. each sequence is made once per
-- position and kept, so a looping gradient stops allocating after one loop
const STEPS = 512

-- a ColorSequence takes 20 keypoints, and shifting one adds a keypoint at
-- each end
const MAX_KEYPOINTS = 18

const TAU = 2 * math.pi
const WHITE = Color3.new(1, 1, 1)

--[=[
	@within Gradient
	@type Target GuiObject | UIStroke | UIGradient

	what [Gradient:add] paints: the UIGradient inside a GuiObject or a UIStroke,
	made when there is none, or a UIGradient itself
]=]
export type Target = GuiObject | UIStroke | UIGradient

--[=[
	@within Gradient
	@type Preset "Bubblegum" | "Chrome" | "Death" | "Electric" | "Fire" | "Galaxy" | "Ghost" | "Gold" | "Ice" | "Lava" | "Matrix" | "Neon" | "Oceanic" | "Rainbow" | "Shine" | "Silver" | "Sunset" | "Zebra" | "GreenOutline" | "RainbowOutline" | "ShineOutline" | "Wave"

	the names [Gradient.preset] takes. the ones ending in `Outline`, and
	`Wave`, only paint strokes
]=]
export type Preset =
	"Bubblegum"
	| "Chrome"
	| "Death"
	| "Electric"
	| "Fire"
	| "Galaxy"
	| "Ghost"
	| "Gold"
	| "Ice"
	| "Lava"
	| "Matrix"
	| "Neon"
	| "Oceanic"
	| "Rainbow"
	| "Shine"
	| "Silver"
	| "Sunset"
	| "Zebra"
	| "GreenOutline"
	| "RainbowOutline"
	| "ShineOutline"
	| "Wave"

--[=[
	@within Gradient
	@interface PresetOptions
	.speed number? -- turns a second of the colors, 0.5 by default
	.color Color3? -- the color of `Shine`, `ShineOutline` and `Wave`, white by default

	what [Gradient.preset] takes besides the name
]=]
export type PresetOptions = {
	speed: number?,
	color: Color3?,
}

export type Gradient = {
	set_color: (self: Gradient, color: ColorSequence) -> Gradient,
	set_transparency: (self: Gradient, transparency: number | NumberSequence) -> Gradient,
	set_speed: (self: Gradient, speed: number) -> Gradient,
	set_offset: (self: Gradient, offset: number) -> Gradient,
	set_transparency_speed: (self: Gradient, speed: number) -> Gradient,
	set_transparency_offset: (self: Gradient, offset: number) -> Gradient,
	set_rotation: (self: Gradient, rotation: number) -> Gradient,
	set_rotation_speed: (self: Gradient, speed: number) -> Gradient,
	set_sway: (self: Gradient, amplitude: number, speed: number) -> Gradient,
	set_pulse: (self: Gradient, min: number, max: number, speed: number) -> Gradient,
	set_stroke: (self: Gradient, stroke: Gradient?) -> Gradient,
	set_fill: (self: Gradient, fill: boolean) -> Gradient,
	add: (self: Gradient, target: Target, stroke: (boolean | number)?) -> Gradient,
	remove: (self: Gradient, target: Target) -> Gradient,
	play: (self: Gradient) -> Gradient,
	pause: (self: Gradient) -> Gradient,
	is_playing: (self: Gradient) -> boolean,
	destroy: (self: Gradient) -> (),
}

-- a UIGradient a gradient paints
type Paint = {
	gradient: UIGradient,
	-- the gradient whose colors it shows, the stroke gradient for strokes
	painter: any,
	-- the gradient it was added to, and the target given to it
	owner: any,
	target: Instance,
	created: boolean,
	-- what a UIGradient that was already there showed, put back on remove
	saved: { color: ColorSequence, transparency: NumberSequence, rotation: number }?,
	-- the UIStroke it is in, its thickness before any pulse, and whether
	-- the gradient made it
	stroke: UIStroke?,
	thickness: number,
	created_stroke: boolean,
	destroying: RBXScriptConnection,
}

-- a looping sequence, as the times and values of its keypoints
type Track = {
	times: { number },
	values: { any },
	-- the sequence itself when every value is the same, so it never moves
	constant: any,
	-- the shifted sequences made so far, by position
	cache: { [number]: any },
}

const Gradient = {}
Gradient.__index = Gradient

-- the gradients that move, stepped every frame while there are some
const moving: { [any]: true } = {}
local heartbeat: RBXScriptConnection? = nil

const function lerp_color(a: Color3, b: Color3, alpha: number): Color3
	return a:Lerp(b, alpha)
end

const function lerp_number(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

-- reads the keypoints of a ColorSequence or a NumberSequence as a loop. the
-- last keypoint stands where the first one does on the next loop, so it is
-- dropped when it shows the same value, and moved just before it otherwise
const function track(sequence: any, label: string): Track
	const keypoints = sequence.Keypoints
	local count = #keypoints
	const times: { number } = table.create(count) :: { number }
	const values: { any } = table.create(count)
	for index, keypoint in keypoints do
		times[index] = keypoint.Time
		values[index] = keypoint.Value
	end

	if values[count] == values[1] then
		times[count] = nil
		values[count] = nil
		count -= 1
	else
		times[count] = math.max(1 - 1e-4, times[count - 1])
	end
	if count > MAX_KEYPOINTS then
		error(`[Gradient] {label} has too many keypoints, 19 at most, or 18 when the last one differs from the first`, 3)
	end

	local constant = sequence
	for index = 2, count do
		if values[index] ~= values[1] then
			constant = false
			break
		end
	end

	return { times = times, values = values, constant = constant, cache = {} }
end

-- the sequence of `loop` moved forward by `offset`, from 0 to 1. the
-- keypoints pushed past the end come back from the start, so their order
-- only rotates, and both ends get the value between the last keypoint and the
-- first one of the next loop
const function shift(loop: Track, offset: number, lerp: (any, any, number) -> any, keypoint: (number, any) -> any, sequence: (any) -> any): any
	const times, values = loop.times, loop.values
	const count = #times

	-- the first keypoint pushed past the end, count + 1 for none
	local split = count + 1
	for index = 1, count do
		if times[index] + offset >= 1 then
			split = index
			break
		end
	end

	const first = if split <= count then split else 1
	const last = if split > 1 then split - 1 else count
	const first_time = times[first] + offset - (if first >= split then 1 else 0)
	const last_time = times[last] + offset - (if last >= split then 1 else 0)
	const edge = lerp(values[last], values[first], (1 - last_time) / (first_time + 1 - last_time))

	const keypoints = table.create(count + 2)
	if first_time > 0 then
		table.insert(keypoints, keypoint(0, edge))
	end
	for index = split, count do
		table.insert(keypoints, keypoint(times[index] + offset - 1, values[index]))
	end
	for index = 1, split - 1 do
		table.insert(keypoints, keypoint(times[index] + offset, values[index]))
	end
	table.insert(keypoints, keypoint(1, edge))

	return sequence(keypoints)
end

-- the position of `offset` among the STEPS ones, 0 for a sequence that
-- never moves
const function position(loop: Track, offset: number): number
	return if loop.constant then 0 else offset * STEPS // 1
end

const function color_at(self: any, slot: number): ColorSequence
	const loop: Track = self._color
	if loop.constant then
		return loop.constant
	end
	local cached = loop.cache[slot]
	if not cached then
		cached = shift(loop, slot / STEPS, lerp_color, ColorSequenceKeypoint.new, ColorSequence.new)
		loop.cache[slot] = cached
	end
	return cached
end

const function transparency_at(self: any, slot: number): NumberSequence
	const loop: Track = self._transparency
	if loop.constant then
		return loop.constant
	end
	local cached = loop.cache[slot]
	if not cached then
		cached = shift(loop, slot / STEPS, lerp_number, NumberSequenceKeypoint.new, NumberSequence.new)
		loop.cache[slot] = cached
	end
	return cached
end

const function rotation_of(self: any): number
	return self._rotation + self._sway_amplitude * math.sin(self._time * self._sway_speed * TAU)
end

-- how much the pulse scales the thickness of strokes now
const function scale_of(self: any): number
	if self._pulse_speed == 0 then
		return 1
	end
	const wave = (math.sin(self._time * self._pulse_speed * TAU) + 1) / 2
	return self._pulse_min + (self._pulse_max - self._pulse_min) * wave
end

-- shows the current state on one paint
const function show(self: any, paint: Paint)
	const gradient = paint.gradient
	gradient.Color = color_at(self, position(self._color, self._offset))
	gradient.Transparency = transparency_at(self, position(self._transparency, self._transparency_offset))
	gradient.Rotation = rotation_of(self)
	const stroke = paint.stroke
	if stroke then
		stroke.Thickness = paint.thickness * scale_of(self)
	end
end

-- shows what changed since the last render on every paint. what stays the
-- same is not set again
const function render(self: any)
	const color_slot = position(self._color, self._offset)
	if color_slot ~= self._shown_color then
		self._shown_color = color_slot
		const color = color_at(self, color_slot)
		for paint in self._paints do
			paint.gradient.Color = color
		end
	end

	const transparency_slot = position(self._transparency, self._transparency_offset)
	if transparency_slot ~= self._shown_transparency then
		self._shown_transparency = transparency_slot
		const transparency = transparency_at(self, transparency_slot)
		for paint in self._paints do
			paint.gradient.Transparency = transparency
		end
	end

	const rotation = rotation_of(self)
	if rotation ~= self._shown_rotation then
		self._shown_rotation = rotation
		for paint in self._paints do
			paint.gradient.Rotation = rotation
		end
	end

	const scale = scale_of(self)
	if scale ~= self._shown_scale then
		self._shown_scale = scale
		for paint in self._paints do
			const stroke = paint.stroke
			if stroke then
				stroke.Thickness = paint.thickness * scale
			end
		end
	end
end

const function step(dt: number)
	for self in moving do
		self._time += dt
		self._offset = (self._offset + self._speed * dt) % 1
		self._transparency_offset = (self._transparency_offset + self._transparency_speed * dt) % 1
		self._rotation = (self._rotation + self._rotation_speed * dt) % 360
		render(self)
	end
end

-- whether `self` changes over time
const function is_moving(self: any): boolean
	return (self._speed ~= 0 and not self._color.constant)
		or (self._transparency_speed ~= 0 and not self._transparency.constant)
		or self._rotation_speed ~= 0
		or (self._sway_amplitude ~= 0 and self._sway_speed ~= 0)
		or self._pulse_speed ~= 0
end

-- steps `self` every frame while it plays, moves and paints something, and
-- shows what changed
const function update(self: any)
	if self._playing and next(self._paints) ~= nil and is_moving(self) then
		moving[self] = true
		if not heartbeat then
			heartbeat = RunService.Heartbeat:Connect(step)
		end
	else
		moving[self] = nil
		if heartbeat and next(moving) == nil then
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end
	render(self)
end

-- stops painting `paint`, without touching its UIGradient
const function forget(paint: Paint)
	paint.destroying:Disconnect()
	paint.painter._paints[paint] = nil

	const owner = paint.owner
	const paints = owner._added[paint.target]
	if paints then
		const index = table.find(paints, paint)
		if index then
			table.remove(paints, index)
		end
		if #paints == 0 then
			owner._added[paint.target] = nil
		end
	end
	update(paint.painter)
end

-- stops painting `paint`, and puts its UIGradient and UIStroke back as they
-- were
const function unpaint(paint: Paint)
	paint.destroying:Disconnect()
	paint.painter._paints[paint] = nil

	const gradient = paint.gradient
	const saved = paint.saved
	if paint.created then
		gradient:Destroy()
	elseif saved then
		gradient.Color = saved.color
		gradient.Transparency = saved.transparency
		gradient.Rotation = saved.rotation
	end

	const stroke = paint.stroke
	if stroke then
		if paint.created_stroke then
			stroke:Destroy()
		else
			stroke.Thickness = paint.thickness
		end
	end
end

-- paints `gradient` with `painter`, for `target` added to `owner`
const function paint(owner: any, painter: any, target: Instance, gradient: UIGradient, created: boolean, stroke: UIStroke?): Paint
	const new: Paint = {
		gradient = gradient,
		painter = painter,
		owner = owner,
		target = target,
		created = created,
		saved = if created
			then nil
			else { color = gradient.Color, transparency = gradient.Transparency, rotation = gradient.Rotation },
		stroke = stroke,
		thickness = if stroke then stroke.Thickness else 0,
		created_stroke = false,
		destroying = nil :: any,
	}
	new.destroying = gradient.Destroying:Connect(function()
		forget(new)
	end)

	painter._paints[new] = true
	show(painter, new)
	return new
end

-- paints the UIGradient in `container`, made when there is none
const function paint_inside(owner: any, painter: any, target: Instance, container: GuiObject | UIStroke): Paint
	local gradient = container:FindFirstChildWhichIsA("UIGradient")
	const created = gradient == nil
	if not gradient then
		const made = Instance.new("UIGradient")
		made.Parent = container
		gradient = made
	end

	return paint(
		owner,
		painter,
		target,
		gradient :: UIGradient,
		created,
		if container:IsA("UIStroke") then container :: UIStroke else nil
	)
end

const function new_gradient(color: ColorSequence, transparency: (number | NumberSequence)?): Gradient
	const self = setmetatable({
		_color = nil :: any,
		_transparency = nil :: any,
		_offset = 0,
		_speed = 0,
		_transparency_offset = 0,
		_transparency_speed = 0,
		_rotation = 0,
		_rotation_speed = 0,
		_sway_amplitude = 0,
		_sway_speed = 0,
		_pulse_min = 1,
		_pulse_max = 1,
		_pulse_speed = 0,
		-- seconds it played, for the sway and the pulse
		_time = 0,
		_shown_color = -1,
		_shown_transparency = -1,
		_shown_rotation = 0,
		_shown_scale = 1,
		_paints = {} :: { [Paint]: true },
		_added = {} :: { [Instance]: { Paint } },
		_stroke = false :: any,
		_fill = true,
		_playing = true,
		_destroyed = false,
	}, Gradient)

	self._color = track(color, "the color")
	self._transparency = track(
		if typeof(transparency) == "NumberSequence" then transparency else NumberSequence.new(transparency or 0),
		"the transparency"
	)
	return self :: any
end

--[=[
	@within Gradient
	@function new
	@param color ColorSequence
	@param transparency (number | NumberSequence)? -- 0 by default
	@return Gradient
	@error "... has too many keypoints ..." -- a sequence has more than 19 keypoints

	creates a gradient that shows `color` and `transparency`. it plays already,
	but stays still until a speed is set

	```lua
	local gradient = Gradient.new(ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)))
		:set_speed(0.5)
	gradient:add(frame)
	```
]=]
function Gradient.new(color: ColorSequence, transparency: (number | NumberSequence)?): Gradient
	assert(typeof(color) == "ColorSequence", `[Gradient] needs a ColorSequence, got a {typeof(color)}`)
	return new_gradient(color, transparency)
end

--[=[
	@within Gradient
	@function preset
	@param name Preset
	@param options PresetOptions?
	@return Gradient
	@error "no preset named ..." -- `name` is not a preset

	builds a new gradient from a preset. most presets have a stroke gradient
	too, used on the strokes [Gradient:add] paints. the ones ending in
	`Outline`, and `Wave`, only paint strokes

	| preset | look |
	| --- | --- |
	| `Rainbow` | the colors of the rainbow sliding |
	| `Gold`, `Silver`, `Chrome`, `Ice` | metal with a glint passing |
	| `Fire`, `Lava`, `Death`, `Oceanic` | warm, molten, blood red or red and blue bands |
	| `Neon`, `Galaxy` | pink and cyan, or deep violets, turning |
	| `Electric`, `Sunset` | swaying, with a pulsing outline for `Electric` |
	| `Bubblegum`, `Ghost` | pink or pale, fading in the middle, `Bubblegum` with a pulsing outline |
	| `Matrix`, `Zebra` | green or white on black, the stroke opposite to the fill |
	| `Shine` | a light band passing over `options.color` |
	| `RainbowOutline`, `GreenOutline`, `ShineOutline` | an outline whose colors turn around it |
	| `Wave` | a band of `options.color` running along an outline |

	```lua
	local gold = Gradient.preset("Gold", { speed = 0.25 })
	gold:add(title, 3)
	```
]=]
function Gradient.preset(name: Preset, options: PresetOptions?): Gradient
	const build = presets[name]
	if not build then
		error(`[Gradient] no preset named {name}`, 2)
	end
	const given: PresetOptions = options or {}
	return build(new_gradient, given.speed or 0.5, given.color or WHITE)
end

--[=[
	@within Gradient
	@function is
	@param value any
	@return boolean

	returns whether `value` is a gradient
]=]
function Gradient.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Gradient
end

--[=[
	@within Gradient
	@method set_color
	@param color ColorSequence
	@return Gradient

	shows `color`, keeping where it slid to
]=]
function Gradient.set_color(self: Gradient, color: ColorSequence): Gradient
	const gradient = self :: any
	gradient._color = track(color, "the color")
	gradient._shown_color = -1
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_transparency
	@param transparency number | NumberSequence
	@return Gradient

	shows `transparency`, keeping where it slid to
]=]
function Gradient.set_transparency(self: Gradient, transparency: number | NumberSequence): Gradient
	const gradient = self :: any
	gradient._transparency = track(
		if typeof(transparency) == "NumberSequence" then transparency else NumberSequence.new(transparency),
		"the transparency"
	)
	gradient._shown_transparency = -1
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_speed
	@param speed number
	@return Gradient

	slides the colors by `speed` turns a second, backwards when negative, or
	stops them with 0
]=]
function Gradient.set_speed(self: Gradient, speed: number): Gradient
	const gradient = self :: any
	gradient._speed = speed
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_offset
	@param offset number
	@return Gradient

	moves the colors to `offset` of a turn, from 0 to 1
]=]
function Gradient.set_offset(self: Gradient, offset: number): Gradient
	const gradient = self :: any
	gradient._offset = offset % 1
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_transparency_speed
	@param speed number
	@return Gradient

	slides the transparency by `speed` turns a second, like [Gradient:set_speed]
]=]
function Gradient.set_transparency_speed(self: Gradient, speed: number): Gradient
	const gradient = self :: any
	gradient._transparency_speed = speed
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_transparency_offset
	@param offset number
	@return Gradient

	moves the transparency to `offset` of a turn, from 0 to 1
]=]
function Gradient.set_transparency_offset(self: Gradient, offset: number): Gradient
	const gradient = self :: any
	gradient._transparency_offset = offset % 1
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_rotation
	@param rotation number
	@return Gradient

	turns the gradient to `rotation` degrees
]=]
function Gradient.set_rotation(self: Gradient, rotation: number): Gradient
	const gradient = self :: any
	gradient._rotation = rotation % 360
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_rotation_speed
	@param speed number
	@return Gradient

	turns the gradient by `speed` degrees a second, or stops it with 0
]=]
function Gradient.set_rotation_speed(self: Gradient, speed: number): Gradient
	const gradient = self :: any
	gradient._rotation_speed = speed
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_sway
	@param amplitude number -- degrees on each side
	@param speed number -- swings a second
	@return Gradient

	swings the angle `amplitude` degrees around its rotation, `speed` times a
	second. 0 for either stops it
]=]
function Gradient.set_sway(self: Gradient, amplitude: number, speed: number): Gradient
	const gradient = self :: any
	gradient._sway_amplitude = amplitude
	gradient._sway_speed = speed
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_pulse
	@param min number -- the smallest scale of the thickness
	@param max number -- the largest scale of the thickness
	@param speed number -- pulses a second
	@return Gradient

	scales the thickness of the UIStrokes it paints between `min` and `max`
	times what it was, `speed` times a second. a speed of 0 stops it and puts
	the thickness back
]=]
function Gradient.set_pulse(self: Gradient, min: number, max: number, speed: number): Gradient
	const gradient = self :: any
	gradient._pulse_min = min
	gradient._pulse_max = max
	gradient._pulse_speed = speed
	update(gradient)
	return self
end

--[=[
	@within Gradient
	@method set_stroke
	@param stroke Gradient? -- nil to paint strokes with this gradient
	@return Gradient

	paints the strokes added from now on with `stroke`: a UIStroke target, the
	strokes of a GuiObject target and a UIGradient inside a UIStroke. playing,
	pausing and destroying this gradient does the same to `stroke`
]=]
function Gradient.set_stroke(self: Gradient, stroke: Gradient?): Gradient
	assert(stroke == nil or Gradient.is(stroke), "[Gradient] set_stroke needs a gradient or nil")
	const gradient = self :: any
	gradient._stroke = stroke or false
	return self
end

--[=[
	@within Gradient
	@method set_fill
	@param fill boolean
	@return Gradient

	whether a GuiObject added from now on gets its own UIGradient painted, true
	by default. without it, only its strokes are
]=]
function Gradient.set_fill(self: Gradient, fill: boolean): Gradient
	const gradient = self :: any
	gradient._fill = fill
	return self
end

--[=[
	@within Gradient
	@method add
	@param target Target
	@param stroke (boolean | number)? -- paint the strokes of a GuiObject, a number to make one that thick when it has none
	@return Gradient
	@error "... cannot be painted" -- `target` is not a GuiObject, a UIStroke or a UIGradient

	paints `target` until [Gradient:remove] is called with it. a GuiObject gets
	its UIGradient painted, and with `stroke` its UIStrokes too, with the
	stroke gradient. a UIGradient that was already there shows its old
	sequences again once removed, and what the gradient made is destroyed.
	adding the same target twice does nothing

	```lua
	local neon = Gradient.preset("Neon")
	neon:add(title, 2)
	neon:add(frame.UIStroke)
	```
]=]
function Gradient.add(self: Gradient, target: Target, stroke: (boolean | number)?): Gradient
	const gradient = self :: any
	if gradient._destroyed or gradient._added[target] then
		return self
	end
	assert(typeof(target) == "Instance", `[Gradient] add needs an Instance, got a {typeof(target)}`)

	const painter = gradient
	const stroke_painter = gradient._stroke or gradient
	const paints: { Paint } = {}

	if target:IsA("UIGradient") then
		const parent = target.Parent
		const inside_stroke = parent ~= nil and parent:IsA("UIStroke")
		table.insert(
			paints,
			paint(
				gradient,
				if inside_stroke then stroke_painter else painter,
				target,
				target,
				false,
				if inside_stroke then parent :: UIStroke else nil
			)
		)
	elseif target:IsA("UIStroke") then
		table.insert(paints, paint_inside(gradient, stroke_painter, target, target))
	elseif target:IsA("GuiObject") then
		if gradient._fill then
			table.insert(paints, paint_inside(gradient, painter, target, target))
		end
		if stroke or not gradient._fill then
			for _, child in target:GetChildren() do
				if child:IsA("UIStroke") then
					table.insert(paints, paint_inside(gradient, stroke_painter, target, child))
				end
			end
			if type(stroke) == "number" and #paints == (if gradient._fill then 1 else 0) then
				const made = Instance.new("UIStroke")
				made.Color = WHITE
				made.Thickness = stroke
				made.Parent = target
				const added = paint_inside(gradient, stroke_painter, target, made)
				added.created_stroke = true
				table.insert(paints, added)
			end
		end
	else
		error(`[Gradient] a {target.ClassName} cannot be painted`, 2)
	end

	if #paints > 0 then
		gradient._added[target] = paints
	end
	update(painter)
	if stroke_painter ~= painter then
		update(stroke_painter)
	end
	return self
end

--[=[
	@within Gradient
	@method remove
	@param target Target
	@return Gradient

	stops painting what [Gradient:add] painted for `target`, destroys what it
	made and gives back their old sequences and thickness to the others
]=]
function Gradient.remove(self: Gradient, target: Target): Gradient
	const gradient = self :: any
	const paints: { Paint }? = gradient._added[target]
	if not paints then
		return self
	end
	gradient._added[target] = nil

	const painters: { [any]: true } = {}
	for _, entry in paints do
		painters[entry.painter] = true
		unpaint(entry)
	end
	for painter in painters do
		update(painter)
	end
	return self
end

--[=[
	@within Gradient
	@method play
	@return Gradient

	moves again after [Gradient:pause], its stroke gradient too
]=]
function Gradient.play(self: Gradient): Gradient
	const gradient = self :: any
	if gradient._destroyed then
		return self
	end
	gradient._playing = true
	update(gradient)
	if gradient._stroke then
		gradient._stroke:play()
	end
	return self
end

--[=[
	@within Gradient
	@method pause
	@return Gradient

	stops moving where it is, its stroke gradient too
]=]
function Gradient.pause(self: Gradient): Gradient
	const gradient = self :: any
	gradient._playing = false
	update(gradient)
	if gradient._stroke then
		gradient._stroke:pause()
	end
	return self
end

--[=[
	@within Gradient
	@method is_playing
	@return boolean

	returns whether it plays, which it does from the start
]=]
function Gradient.is_playing(self: Gradient): boolean
	return (self :: any)._playing
end

--[=[
	@within Gradient
	@method destroy

	removes every target and destroys the stroke gradient. adding to it does
	nothing afterwards
]=]
function Gradient.destroy(self: Gradient)
	const gradient = self :: any
	if gradient._destroyed then
		return
	end
	for target in table.clone(gradient._added) do
		self:remove(target)
	end
	gradient._destroyed = true
	gradient._playing = false
	update(gradient)
	if gradient._stroke then
		gradient._stroke:destroy()
	end
end

return table.freeze({
	new = Gradient.new,
	preset = Gradient.preset,
	is = Gradient.is,
})

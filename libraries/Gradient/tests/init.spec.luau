--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Gradient = require("../src")

local RED = Color3.new(1, 0, 0)
local BLUE = Color3.new(0, 0, 1)

-- the times and colors of a ColorSequence, rounded to 3 decimals
local function keys(sequence: any): { { any } }
	local result = {}
	for index, keypoint in sequence.Keypoints do
		local value = keypoint.Value
		result[index] = {
			math.round(keypoint.Time * 1000) / 1000,
			if type(value) == "number"
				then math.round(value * 1000) / 1000
				else `{math.round(value.R * 1000) / 1000} {math.round(value.G * 1000) / 1000} {math.round(value.B * 1000) / 1000}`,
		}
	end
	return result
end

local function red_to_blue(): any
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, RED),
		ColorSequenceKeypoint.new(0.5, BLUE),
		ColorSequenceKeypoint.new(1, RED),
	})
end

describe("painting", function()
	it("makes a UIGradient in a GuiObject and destroys it on remove", function()
		local frame = Instance.new("Frame")
		local gradient = Gradient.new(red_to_blue()):set_rotation(45)
		gradient:add(frame)

		local made: any = frame:FindFirstChildWhichIsA("UIGradient")
		expect(made).toBeTruthy()
		expect(keys(made.Color)).toEqual({ { 0, "1 0 0" }, { 0.5, "0 0 1" }, { 1, "1 0 0" } })
		expect(made.Rotation).toBe(45)

		gradient:remove(frame)
		expect(frame:FindFirstChildWhichIsA("UIGradient")).toBeNil()
	end)

	it("paints a UIGradient that was there, and puts it back on remove", function()
		local frame = Instance.new("Frame")
		local existing: any = Instance.new("UIGradient")
		existing.Rotation = 10
		existing.Parent = frame
		local before = existing.Color

		local gradient = Gradient.new(red_to_blue()):set_rotation(90)
		gradient:add(existing)
		expect(existing.Rotation).toBe(90)
		expect(existing.Color).toNotBe(before)

		gradient:remove(existing)
		expect(existing.Rotation).toBe(10)
		expect(existing.Color).toBe(before)
		expect(existing.Parent).toBe(frame)
	end)

	it("makes a stroke that thick with the stroke gradient, and paints the strokes there", function()
		local label = Instance.new("TextLabel")
		local stroke = Gradient.new(ColorSequence.new(BLUE)):set_rotation(30)
		local gradient = Gradient.new(red_to_blue()):set_stroke(stroke)
		gradient:add(label, 3)

		local made: any = label:FindFirstChildWhichIsA("UIStroke")
		expect(made.Thickness).toBe(3)
		expect(made.Color).toEqual(Color3.new(1, 1, 1))
		local inside: any = made:FindFirstChildWhichIsA("UIGradient")
		expect(inside.Rotation).toBe(30)

		gradient:remove(label)
		expect(label:FindFirstChildWhichIsA("UIStroke")).toBeNil()
		expect(label:FindFirstChildWhichIsA("UIGradient")).toBeNil()

		local existing: any = Instance.new("UIStroke")
		existing.Parent = label
		gradient:add(label, 3)
		expect(existing.Thickness).toBe(1)
		expect(existing:FindFirstChildWhichIsA("UIGradient").Rotation).toBe(30)
	end)

	it("paints a UIStroke, or a UIGradient inside one, with the stroke gradient", function()
		local stroke_gradient = Gradient.new(ColorSequence.new(BLUE)):set_rotation(30)
		local gradient = Gradient.new(red_to_blue()):set_stroke(stroke_gradient)

		local stroke: any = Instance.new("UIStroke")
		gradient:add(stroke)
		expect(stroke:FindFirstChildWhichIsA("UIGradient").Rotation).toBe(30)

		local other: any = Instance.new("UIStroke")
		local inside: any = Instance.new("UIGradient")
		inside.Parent = other
		gradient:add(inside)
		expect(inside.Rotation).toBe(30)
	end)

	it("only paints strokes without fill", function()
		local label = Instance.new("TextLabel")
		local gradient = Gradient.new(red_to_blue()):set_fill(false)
		gradient:add(label, 2)
		expect(label:FindFirstChildWhichIsA("UIGradient")).toBeNil()
		expect((label:FindFirstChildWhichIsA("UIStroke") :: any):FindFirstChildWhichIsA("UIGradient")).toBeTruthy()
	end)

	it("forgets a UIGradient once destroyed", function()
		local frame = Instance.new("Frame")
		local gradient = Gradient.new(red_to_blue()):set_speed(1)
		gradient:add(frame)
		expect(roblox.heartbeats()).toBe(1)

		frame:Destroy()
		expect(roblox.heartbeats()).toBe(0)
		gradient:add(frame)
		gradient:remove(frame)
	end)

	it("errors on what it cannot paint", function()
		expect(function()
			Gradient.new(red_to_blue()):add(Instance.new("Folder") :: any)
		end).toThrow("cannot be painted")
	end)
end)

describe("motion", function()
	it("slides the colors, wrapping around", function()
		local frame = Instance.new("Frame")
		local gradient = Gradient.new(red_to_blue()):set_speed(0.25)
		gradient:add(frame)
		local made: any = frame:FindFirstChildWhichIsA("UIGradient")

		roblox.step(1)
		-- red at 0.25, blue at 0.75, and halfway back to red at the ends
		expect(keys(made.Color)).toEqual({ { 0, "0.5 0 0.5" }, { 0.25, "1 0 0" }, { 0.75, "0 0 1" }, { 1, "0.5 0 0.5" } })

		-- offsets are rounded to 512 positions, and 0.125 is one of them
		gradient:set_offset(0.125)
		expect(keys(made.Color)).toEqual({ { 0, "0.75 0 0.25" }, { 0.125, "1 0 0" }, { 0.625, "0 0 1" }, { 1, "0.75 0 0.25" } })
		gradient:destroy()
	end)

	it("keeps a hard edge where the last keypoint differs from the first", function()
		local frame = Instance.new("Frame")
		local halves = ColorSequence.new({
			ColorSequenceKeypoint.new(0, RED),
			ColorSequenceKeypoint.new(0.5, RED),
			ColorSequenceKeypoint.new(0.5, BLUE),
			ColorSequenceKeypoint.new(1, BLUE),
		})
		local gradient = Gradient.new(halves):set_offset(0.25)
		gradient:add(frame)
		local made: any = frame:FindFirstChildWhichIsA("UIGradient")
		-- the last blue keypoint sits just before the first red one
		expect(keys(made.Color)).toEqual({
			{ 0, "0 0 1" },
			{ 0.25, "0 0 1" },
			{ 0.25, "1 0 0" },
			{ 0.75, "1 0 0" },
			{ 0.75, "0 0 1" },
			{ 1, "0 0 1" },
		})
	end)

	it("slides the transparency", function()
		local frame = Instance.new("Frame")
		local fade = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		local gradient = Gradient.new(ColorSequence.new(RED), fade):set_transparency_offset(0.5)
		gradient:add(frame)
		local made: any = frame:FindFirstChildWhichIsA("UIGradient")
		expect(keys(made.Transparency)).toEqual({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } })
	end)

	it("turns and sways the angle", function()
		local frame = Instance.new("Frame")
		local gradient = Gradient.new(red_to_blue()):set_rotation(350):set_rotation_speed(20)
		gradient:add(frame)
		local made: any = frame:FindFirstChildWhichIsA("UIGradient")
		roblox.step(1)
		expect(made.Rotation).toBe(10)

		-- two seconds played, an eighth of a swing a second: a quarter swing
		gradient:set_rotation_speed(0):set_rotation(0):set_sway(30, 0.125)
		roblox.step(1)
		expect(math.round(made.Rotation)).toBe(30)
		gradient:destroy()
	end)

	it("pulses the thickness of strokes and puts it back", function()
		local label = Instance.new("TextLabel")
		local gradient = Gradient.new(red_to_blue()):set_fill(false):set_pulse(1, 3, 0.25)
		gradient:add(label, 2)
		local stroke: any = label:FindFirstChildWhichIsA("UIStroke")
		roblox.step(1)
		expect(stroke.Thickness).toBe(6)

		gradient:set_pulse(1, 1, 0)
		expect(stroke.Thickness).toBe(2)
		gradient:destroy()
	end)

	it("pauses and plays, its stroke gradient too", function()
		local label = Instance.new("TextLabel")
		local stroke = Gradient.new(red_to_blue()):set_rotation_speed(10)
		local gradient = Gradient.new(red_to_blue()):set_rotation_speed(10):set_stroke(stroke)
		gradient:add(label, 1)
		local fill: any = label:FindFirstChildWhichIsA("UIGradient")
		local outline: any = (label:FindFirstChildWhichIsA("UIStroke") :: any):FindFirstChildWhichIsA("UIGradient")

		gradient:pause()
		expect(gradient:is_playing()).toBe(false)
		expect(stroke:is_playing()).toBe(false)
		expect(roblox.heartbeats()).toBe(0)
		roblox.step(1)
		expect(fill.Rotation).toBe(0)

		gradient:play()
		roblox.step(1)
		expect(fill.Rotation).toBe(10)
		expect(outline.Rotation).toBe(10)
		gradient:destroy()
	end)
end)

describe("speed", function()
	it("only steps every frame while something moves", function()
		local frame = Instance.new("Frame")
		local still = Gradient.new(red_to_blue())
		still:add(frame)
		expect(roblox.heartbeats()).toBe(0)

		local constant = Gradient.new(ColorSequence.new(RED)):set_speed(1)
		constant:add(Instance.new("Frame"))
		expect(roblox.heartbeats()).toBe(0)

		still:set_speed(1)
		expect(roblox.heartbeats()).toBe(1)
		still:destroy()
		constant:destroy()
		expect(roblox.heartbeats()).toBe(0)
	end)

	it("makes each sequence once per position, for every target", function()
		local gradient = Gradient.new(red_to_blue()):set_speed(0.5)
		local frames = {}
		for index = 1, 10 do
			frames[index] = Instance.new("Frame")
			gradient:add(frames[index])
		end

		local before = roblox.made.color
		for _ = 1, 8 do
			roblox.step(0.5)
		end
		-- 4 positions a loop, the first made on add, the others once over two
		-- loops for ten frames
		expect(roblox.made.color - before).toBe(3)
		gradient:destroy()
	end)
end)

describe("presets", function()
	it("builds every preset", function()
		for _, name in
			{
				"Bubblegum",
				"Chrome",
				"Death",
				"Electric",
				"Fire",
				"Galaxy",
				"Ghost",
				"Gold",
				"Ice",
				"Lava",
				"Matrix",
				"Neon",
				"Oceanic",
				"Rainbow",
				"Shine",
				"Silver",
				"Sunset",
				"Zebra",
				"GreenOutline",
				"RainbowOutline",
				"ShineOutline",
				"Wave",
			} :: { any }
		do
			local label = Instance.new("TextLabel")
			local gradient = Gradient.preset(name, { speed = 1, color = RED })
			gradient:add(label, 2)
			for _ = 1, 30 do
				roblox.step(1 / 7)
			end
			gradient:destroy()
			expect(#label:GetChildren()).toBe(0)
			expect(`{name} {roblox.heartbeats()}`).toBe(`{name} 0`)
		end
		expect(roblox.heartbeats()).toBe(0)
	end)

	it("errors on a name that is not a preset", function()
		expect(function()
			Gradient.preset("Nope" :: any)
		end).toThrow("no preset named Nope")
	end)

	it("tells gradients apart", function()
		expect(Gradient.is(Gradient.preset("Rainbow"))).toBe(true)
		expect(Gradient.is({})).toBe(false)
	end)
end)

return nil

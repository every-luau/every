-- The colors of the presets, taken from the gradient templates of ezVisualz
-- (https://github.com/arxkdev/ezVisualz), under its license:
--
-- MIT License
--
-- Copyright (c) 2026 Arxk
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- a ColorSequence from `{ time, r, g, b }` rows, the channels from 0 to 255
const function colors(rows: { { number } }): ColorSequence
	const keypoints: { ColorSequenceKeypoint } = table.create(#rows) :: { ColorSequenceKeypoint }
	for index, row in rows do
		keypoints[index] = ColorSequenceKeypoint.new(row[1], Color3.fromRGB(row[2], row[3], row[4]))
	end
	return ColorSequence.new(keypoints)
end

-- a NumberSequence from `{ time, value }` rows
const function numbers(rows: { { number } }): NumberSequence
	const keypoints: { NumberSequenceKeypoint } = table.create(#rows) :: { NumberSequenceKeypoint }
	for index, row in rows do
		keypoints[index] = NumberSequenceKeypoint.new(row[1], row[2])
	end
	return NumberSequence.new(keypoints)
end

-- fades the middle out, for Bubblegum and Ghost
const HOLLOW = numbers({ { 0, 0 }, { 0.099, 0 }, { 0.5, 1 }, { 0.9, 0 }, { 1, 0 } })

return table.freeze({
	Bubblegum = colors({ { 0, 243, 101, 177 }, { 0.5, 255, 167, 227 }, { 1, 243, 101, 177 } }),
	Chrome = colors({
		{ 0, 0, 16, 90 },
		{ 0.068, 175, 201, 213 },
		{ 0.172, 224, 240, 255 },
		{ 0.318, 255, 180, 255 },
		{ 0.467, 68, 0, 127 },
		{ 0.498, 5, 1, 9 },
		{ 0.503, 255, 255, 255 },
		{ 0.719, 180, 255, 243 },
		{ 0.941, 39, 159, 175 },
		{ 1, 0, 16, 90 },
	}),
	Death = colors({
		{ 0, 153, 0, 0 },
		{ 0.125, 255, 0, 0 },
		{ 0.255, 105, 0, 0 },
		{ 0.377, 77, 0, 0 },
		{ 0.5, 176, 0, 0 },
		{ 0.62, 77, 0, 0 },
		{ 0.738, 255, 0, 0 },
		{ 0.868, 77, 0, 0 },
		{ 1, 153, 0, 0 },
	}),
	Electric = colors({
		{ 0, 0, 150, 255 },
		{ 0.15, 255, 255, 255 },
		{ 0.3, 100, 200, 255 },
		{ 0.45, 255, 255, 255 },
		{ 0.6, 0, 200, 255 },
		{ 0.75, 255, 255, 255 },
		{ 0.9, 50, 150, 255 },
		{ 1, 0, 150, 255 },
	}),
	Fire = colors({
		{ 0, 255, 234, 0 },
		{ 0.151, 255, 234, 0 },
		{ 0.307, 255, 153, 0 },
		{ 0.497, 139, 94, 9 },
		{ 0.665, 255, 170, 0 },
		{ 0.839, 173, 125, 29 },
		{ 1, 255, 234, 0 },
	}),
	Galaxy = colors({
		{ 0, 75, 0, 130 },
		{ 0.25, 138, 43, 226 },
		{ 0.5, 25, 25, 112 },
		{ 0.75, 72, 61, 139 },
		{ 1, 75, 0, 130 },
	}),
	Ghost = colors({ { 0, 255, 255, 255 }, { 0.5, 181, 184, 188 }, { 1, 255, 255, 255 } }),
	Gold = colors({
		{ 0, 213, 174, 56 },
		{ 0.22, 213, 174, 56 },
		{ 0.368, 199, 152, 12 },
		{ 0.498, 217, 178, 3 },
		{ 0.503, 255, 236, 129 },
		{ 0.693, 213, 174, 56 },
		{ 0.792, 213, 174, 56 },
		{ 1, 213, 174, 56 },
	}),
	Green = colors({ { 0, 0, 255, 0 }, { 1, 0, 255, 0 } }),
	Ice = colors({
		{ 0, 109, 210, 212 },
		{ 0.172, 224, 240, 255 },
		{ 0.318, 140, 208, 209 },
		{ 0.467, 109, 210, 212 },
		{ 0.498, 109, 210, 212 },
		{ 0.503, 255, 255, 255 },
		{ 0.719, 180, 255, 243 },
		{ 1, 109, 210, 212 },
	}),
	Lava = colors({
		{ 0, 255, 0, 0 },
		{ 0.125, 255, 200, 0 },
		{ 0.255, 255, 0, 0 },
		{ 0.377, 255, 200, 0 },
		{ 0.5, 255, 0, 0 },
		{ 0.62, 255, 200, 0 },
		{ 0.738, 255, 0, 0 },
		{ 0.868, 255, 200, 0 },
		{ 1, 255, 0, 0 },
	}),
	Matrix = colors({ { 0, 62, 239, 2 }, { 0.497, 62, 239, 2 }, { 0.503, 0, 0, 0 }, { 1, 0, 0, 0 } }),
	Neon = colors({
		{ 0, 255, 0, 255 },
		{ 0.2, 0, 255, 255 },
		{ 0.4, 255, 0, 255 },
		{ 0.6, 255, 0, 150 },
		{ 0.8, 0, 255, 255 },
		{ 1, 255, 0, 255 },
	}),
	Oceanic = colors({
		{ 0, 0, 115, 255 },
		{ 0.125, 255, 0, 0 },
		{ 0.255, 0, 115, 255 },
		{ 0.377, 255, 0, 0 },
		{ 0.5, 0, 115, 255 },
		{ 0.62, 255, 0, 0 },
		{ 0.737, 0, 115, 255 },
		{ 0.868, 255, 0, 0 },
		{ 1, 0, 115, 255 },
	}),
	Rainbow = colors({
		{ 0, 255, 0, 0 },
		{ 0.151, 157, 0, 255 },
		{ 0.307, 17, 0, 255 },
		{ 0.497, 0, 255, 255 },
		{ 0.665, 4, 255, 0 },
		{ 0.839, 255, 255, 0 },
		{ 1, 255, 0, 0 },
	}),
	Silver = colors({
		{ 0, 213, 213, 213 },
		{ 0.285, 187, 200, 213 },
		{ 0.498, 85, 85, 112 },
		{ 0.503, 255, 255, 255 },
		{ 0.715, 187, 200, 213 },
		{ 1, 213, 213, 213 },
	}),
	Sunset = colors({
		{ 0, 255, 94, 77 },
		{ 0.25, 255, 154, 0 },
		{ 0.5, 255, 192, 203 },
		{ 0.75, 255, 20, 147 },
		{ 1, 255, 94, 77 },
	}),
	Zebra = colors({ { 0, 255, 255, 255 }, { 0.497, 255, 255, 255 }, { 0.503, 0, 0, 0 }, { 1, 0, 0, 0 } }),

	Hollow = HOLLOW,
	-- shows a third of the outline, for GreenOutline
	Arc = numbers({ { 0, 0 }, { 0.7, 1 }, { 1, 1 } }),
	-- a short bright band, for Wave
	Band = numbers({ { 0, 0 }, { 0.25, 1 }, { 0.75, 1 }, { 1, 0 } }),
})

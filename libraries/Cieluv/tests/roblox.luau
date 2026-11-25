--!strict
-- Minimal stand-in for the Roblox globals the library uses, since lest's native
-- backend has none: a Color3 that only holds its channels.

export type Color = { R: number, G: number, B: number }

local globals = _G :: any
globals.Color3 = {
	new = function(r: number, g: number, b: number): Color
		return { R = r, G = g, B = b }
	end,
}

return nil

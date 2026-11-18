--!nonstrict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

-- lest's native backend has no Roblox types: Vector3 is the native vector, and
-- CFrame only supports translations
local CFrameClass = {}
CFrameClass.__index = CFrameClass

function CFrameClass.PointToObjectSpace(self, point)
	return point - self.Position
end

function CFrameClass.PointToWorldSpace(self, point)
	return point + self.Position
end

local globals = _G :: any
globals.Vector3 = { new = vector.create, zero = vector.zero, one = vector.one }
globals.CFrame = {
	new = function(position)
		return setmetatable({ Position = position }, CFrameClass)
	end,
}

local Volume = require("../src")

local function cube(position: vector, size: number): any
	return Volume.new(CFrame.new(position), vector.create(size, size, size))
end

describe("Volume", function()
	it("keeps its CFrame and size", function()
		local cframe = CFrame.new(vector.zero)
		local volume = Volume.new(cframe, vector.one)
		expect(volume:get_cframe()).toBe(cframe)
		expect(volume:get_size()).toBe(vector.one)
	end)

	it("contains points inside it, edges included", function()
		local volume = cube(vector.create(10, 0, 0), 4)
		expect(volume:contains_point(vector.create(10, 0, 0))).toBe(true)
		expect(volume:contains_point(vector.create(12, 2, -2))).toBe(true)
		expect(volume:contains_point(vector.create(12.01, 0, 0))).toBe(false)
		expect(volume:contains_point(vector.zero)).toBe(false)
	end)

	it("returns its 8 corners", function()
		local corners = cube(vector.zero, 2):get_corners()
		expect(#corners).toBe(8)
		expect(table.find(corners, vector.create(1, -1, 1))).toNotBe(nil)
		expect(table.find(corners, vector.create(-1, -1, -1))).toNotBe(nil)
	end)

	it("contains volumes with every corner inside", function()
		local big = cube(vector.zero, 10)
		expect(big:contains_volume(cube(vector.create(2, 2, 2), 2))).toBe(true)
		expect(big:contains_volume(cube(vector.create(4.5, 0, 0), 2))).toBe(false)
	end)

	it("is built from a part", function()
		local part = { CFrame = CFrame.new(vector.create(1, 2, 3)), Size = vector.one }
		local volume = Volume.from_part(part :: any)
		expect(volume:get_size()).toBe(vector.one)
		expect(volume:contains_point(vector.create(1, 2, 3))).toBe(true)
	end)

	it("tells volumes apart", function()
		expect(Volume.is(cube(vector.zero, 1))).toBe(true)
		expect(Volume.is({})).toBe(false)
	end)
end)

return nil

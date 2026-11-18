--!nonstrict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Region = require("../src")

local function part(name: string, position: vector, parent: any?): any
	local instance = roblox.new("Part", name)
	instance.Position = position
	instance.CFrame = CFrame.new(position)
	instance.Size = vector.one
	instance.Parent = parent or roblox.workspace
	return instance
end

-- a 10 stud cube centered on the origin
local function box(): any
	return Region.new():set_size(vector.create(10, 10, 10))
end

local function record(region: any): { string }
	local events: { string } = {}
	region.entered:connect(function(value)
		table.insert(events, `+{value}`)
	end)
	region.left:connect(function(value)
		table.insert(events, `-{value}`)
	end)
	return events
end

describe("Region", function()
	it("reports parts entering and leaving", function()
		local region = box():build()
		local events = record(region)

		local ball = part("Ball", vector.create(20, 0, 0))
		roblox.step(0)
		expect(#events).toBe(0)

		ball.Position = vector.create(1, 1, 1)
		roblox.step(0)
		expect(region:has_part(ball)).toBe(true)

		ball.Position = vector.create(0, 50, 0)
		roblox.step(0)
		expect(events).toEqual({ "+Ball", "-Ball" })
		expect(region:has_part(ball)).toBe(false)

		region:destroy()
		ball.Parent = nil
	end)

	it("counts a removed part as leaving", function()
		local region = box():build()
		local events = record(region)

		local ball = part("Ball", vector.zero)
		roblox.step(0)
		ball.Parent = nil
		roblox.step(0)

		expect(events).toEqual({ "+Ball", "-Ball" })
		region:destroy()
	end)

	it("reports a value once while any of its parts is inside", function()
		local model = roblox.new("Model", "Bob", roblox.workspace)
		local head = part("Head", vector.zero, model)
		local arm = part("Arm", vector.zero, model)

		local region = box()
			:set_rule(function(instance)
				return instance.Parent
			end)
			:build()
		local events = record(region)

		roblox.step(0)
		head.Position = vector.create(50, 0, 0)
		roblox.step(0)
		expect(events).toEqual({ "+Bob" })
		expect(region:get_results()).toEqual({ model })

		arm.Position = vector.create(50, 0, 0)
		roblox.step(0)
		expect(events).toEqual({ "+Bob", "-Bob" })

		region:destroy()
		model.Parent = nil
	end)

	it("only tracks parts the predicate accepts", function()
		local region = box()
			:set_predicate(function(instance)
				return instance.Name == "Coin"
			end)
			:build()
		local events = record(region)

		local coin = part("Coin", vector.zero)
		local rock = part("Rock", vector.zero)
		roblox.step(0)
		expect(events).toEqual({ "+Coin" })

		region:set_predicate(nil)
		roblox.step(0)
		expect(events).toEqual({ "+Coin", "+Rock" })

		region:destroy()
		coin.Parent = nil
		rock.Parent = nil
	end)

	it("ignores values filtered out with where", function()
		local region = box():build():where(function(instance)
			return instance.Name ~= "Ghost"
		end)
		local events = record(region)

		local ghost = part("Ghost", vector.zero)
		roblox.step(0)
		expect(#events).toBe(0)

		region:destroy()
		ghost.Parent = nil
	end)

	it("follows the box when it moves", function()
		local region = box():build()
		local ball = part("Ball", vector.create(100, 0, 0))

		roblox.step(0)
		expect(region:has_part(ball)).toBe(false)

		region:set_cframe(CFrame.new(vector.create(100, 0, 0)))
		roblox.step(0)
		expect(region:has_part(ball)).toBe(true)

		region:destroy()
		ball.Parent = nil
	end)

	it("observes values with a void cleaned when they leave", function()
		local region = box():build()
		local ball = part("Ball", vector.zero)
		roblox.step(0)

		local events: { string } = {}
		region:observe(function(value, void)
			table.insert(events, `+{value}`)
			void:add(function()
				table.insert(events, `-{value}`)
			end)
		end)

		ball.Position = vector.create(50, 0, 0)
		roblox.step(0)
		ball.Position = vector.zero
		roblox.step(0)

		expect(events).toEqual({ "+Ball", "-Ball", "+Ball" })

		region:destroy()
		expect(events).toEqual({ "+Ball", "-Ball", "+Ball", "-Ball" })
		ball.Parent = nil
	end)

	it("stops checking while disabled", function()
		local region = box():build()
		local stepped = 0
		region.stepped:connect(function()
			stepped += 1
		end)

		roblox.step(0)
		region:disable()
		roblox.step(0)
		expect(stepped).toBe(1)
		expect(region:is_enabled()).toBe(false)

		region:toggle()
		roblox.step(0)
		expect(stepped).toBe(2)

		region:destroy()
		roblox.step(0)
		expect(stepped).toBe(2)
	end)

	it("checks containment", function()
		local region = box():build()
		local inside = part("Inside", vector.zero)
		local outside = part("Outside", vector.create(50, 0, 0))

		expect(region:contains_point(vector.create(5, 5, 5))).toBe(true)
		expect(region:contains_point(vector.create(5.1, 0, 0))).toBe(false)
		expect(region:contains_part(inside)).toBe(true)
		expect(region:contains_parts({ inside, outside }, "Any")).toBe(true)
		expect(region:contains_parts({ inside, outside }, "All")).toBe(false)
		expect(region:contains_volume(box():set_size(vector.create(2, 2, 2)):build())).toBe(true)

		region:destroy()
		inside.Parent = nil
		outside.Parent = nil
	end)

	it("moves the box with set_position and keeps it with set_orientation", function()
		local builder = box():set_position(vector.create(3, 0, 0)):set_orientation(CFrame.identity)
		local region = builder:build()

		expect(region:get_volume():get_cframe().Position).toBe(vector.create(3, 0, 0))
		region:destroy()
	end)

	it("tells regions apart", function()
		local region = box():build()
		expect(Region.is(region)).toBe(true)
		expect(Region.is(box())).toBe(false)
		region:destroy()
	end)
end)

return nil

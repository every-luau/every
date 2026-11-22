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
		local region = box()
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
		local region = box()
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
		local region = box():where(function(instance)
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
		local region = box()
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
		local region = box()
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
		local region = box()
		local stepped = 0
		region.stepped:connect(function()
			stepped += 1
		end)

		roblox.step(0)
		region:disable()
		roblox.step(0)
		expect(stepped).toBe(1)
		expect(region:is_enabled()).toBe(false)

		region:enable()
		expect(region:is_enabled()).toBe(true)
		region:disable()
		region:toggle()
		roblox.step(0)
		expect(stepped).toBe(2)

		region:destroy()
		roblox.step(0)
		expect(stepped).toBe(2)
	end)

	it("checks containment", function()
		local region = box()
		local inside = part("Inside", vector.zero)
		local outside = part("Outside", vector.create(50, 0, 0))

		expect(region:get_size()).toBe(vector.create(10, 10, 10))
		expect(region:contains_point(vector.create(5, 5, 5))).toBe(true)
		expect(region:contains_point(vector.create(5.1, 0, 0))).toBe(false)
		expect(region:contains_part(inside)).toBe(true)
		expect(region:contains_parts({ inside, outside }, "Any")).toBe(true)
		expect(region:contains_parts({ inside, outside }, "All")).toBe(false)
		expect(region:contains_region(box():set_size(vector.create(2, 2, 2)))).toBe(true)
		expect(region:contains_region(box():set_size(vector.create(12, 2, 2)))).toBe(false)

		region:destroy()
		inside.Parent = nil
		outside.Parent = nil
	end)

	it("moves the box with set_position and keeps it with set_orientation", function()
		local region = box():set_position(vector.create(3, 0, 0)):set_orientation(CFrame.identity)

		expect(region:get_cframe().Position).toBe(vector.create(3, 0, 0))
		region:destroy()
	end)

	it("counts a part as inside as soon as it touches the shape", function()
		local region = box()
		local plank = part("Plank", vector.create(7.1, 0, 0))
		plank.Size = vector.create(4, 1, 1)

		roblox.step(0)
		expect(region:has_part(plank)).toBe(false)

		-- its center is still outside the box, but its end touches it
		plank.Position = vector.create(6.9, 0, 0)
		roblox.step(0)
		expect(region:has_part(plank)).toBe(true)

		plank.Position = vector.create(8, 0, 0)
		roblox.step(0)
		expect(region:has_part(plank)).toBe(false)

		-- the part's shape follows its size
		plank.Size = vector.create(7, 1, 1)
		roblox.step(0)
		expect(region:has_part(plank)).toBe(true)

		region:destroy()
		plank.Parent = nil
	end)

	it("uses any Bolt shape", function()
		local sphere = Region.Bolt.create_sphere(5)
		local region = box():set_shape(sphere)

		expect(region:get_shape()).toBe(sphere)
		expect(region:get_size()).toBe(vector.create(10, 10, 10))
		expect(region:contains_point(vector.create(4, 0, 0))).toBe(true)
		expect(region:contains_point(vector.create(4, 4, 0))).toBe(false)

		region:destroy()
	end)

	it("takes the position, orientation and shape of a part", function()
		local plank = roblox.new("Part", "Plank")
		plank.Size = vector.create(10, 2, 2)
		plank.CFrame = CFrame.new(100, 0, 0) * CFrame.Angles(0, math.rad(90), 0)

		-- turned a quarter around Y, its length goes along Z
		local turned = Region.new():set_part(plank)
		expect(turned:contains_point(vector.create(100, 0, 4))).toBe(true)
		expect(turned:contains_point(vector.create(104, 0, 0))).toBe(false)
		turned:destroy()

		local ball = roblox.new("Part", "Ball")
		ball.Shape = Enum.PartType.Ball
		ball.Size = vector.create(10, 10, 10)
		local round = Region.new():set_part(ball)
		expect(round:contains_point(vector.create(4, 0, 0))).toBe(true)
		expect(round:contains_point(vector.create(4, 4, 0))).toBe(false)
		round:destroy()

		-- a mesh becomes its box
		local mesh = roblox.new("MeshPart", "Rock")
		mesh.Size = vector.create(10, 10, 10)
		local boxed = Region.new():set_part(mesh)
		expect(boxed:contains_point(vector.create(4, 4, 0))).toBe(true)
		boxed:destroy()
	end)

	it("tells whether two regions touch", function()
		local region = box()
		local long = box():set_size(vector.create(12, 2, 2))
		local far = box():set_position(vector.create(50, 0, 0))

		expect(region:intersects_region(long)).toBe(true)
		expect(region:contains_region(long)).toBe(false)
		expect(region:intersects_region(far)).toBe(false)

		region:destroy()
		long:destroy()
		far:destroy()
	end)

	it("checks right away with step, even while disabled", function()
		local ball = part("Ball", vector.zero)
		local region = box():disable()
		local events = record(region)

		region:step()
		expect(events).toEqual({ "+Ball" })
		expect(region:get_results()).toEqual({ ball })

		ball.Position = vector.create(50, 0, 0)
		roblox.step(0)
		expect(region:has_part(ball)).toBe(true)

		region:step()
		expect(events).toEqual({ "+Ball", "-Ball" })

		region:destroy()
		ball.Parent = nil
	end)

	it("checks every interval instead of every frame", function()
		local region = box():set_interval(1)
		local checks = 0
		region.stepped:connect(function()
			checks += 1
		end)

		roblox.step(0.6)
		expect(checks).toBe(0)
		roblox.step(0.6)
		expect(checks).toBe(1)

		region:set_interval(0)
		roblox.step(0)
		roblox.step(0)
		expect(checks).toBe(3)

		region:destroy()
	end)

	it("follows a part with an offset", function()
		local handle = part("Handle", vector.create(100, 0, 0))
		local ball = part("Ball", vector.create(100, 0, 20))
		local region = box():follow(handle, CFrame.new(0, 0, 20))

		region:step()
		expect(region:get_cframe().Position).toBe(vector.create(100, 0, 20))
		expect(region:has_part(ball)).toBe(true)

		handle.Position = vector.create(200, 0, 0)
		region:step()
		expect(region:has_part(ball)).toBe(false)

		region:follow(nil)
		handle.Position = vector.create(100, 0, 0)
		region:step()
		expect(region:get_cframe().Position).toBe(vector.create(200, 0, 20))

		region:destroy()
		handle.Parent = nil
		ball.Parent = nil
	end)

	it("only checks the parts in its root", function()
		local folder = roblox.new("Folder", "Characters", roblox.workspace)
		local inside = part("Inside", vector.zero, folder)
		local outside = part("Outside", vector.zero)

		local region = box():step()
		local events = record(region)
		region:set_root(folder):step()
		expect(events).toEqual({ "-Outside" })
		expect(region:has_part(inside)).toBe(true)

		region:destroy()
		folder.Parent = nil
		outside.Parent = nil
	end)

	it("tells regions apart", function()
		local region = box()
		expect(Region.is(region)).toBe(true)
		expect(Region.is({})).toBe(false)
		region:destroy()
	end)
end)

return nil

--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Atom = require("../../Atom/src")
local Stream = require("../../Stream/src")
local Mount = require("../src")

describe("Mount", function()
	it("mounts properties, streams, events and children", function()
		local hovered = Atom.new(false)
		local parent = roblox.new("Folder")
		local child = roblox.new("Part")
		local entered = 0

		local frame = roblox.new("Frame")
		local connection = Mount(frame, {
			Name = "Panel",
			BackgroundTransparency = hovered:map(function(is_hovered)
				return if is_hovered then 0 else 0.5
			end),
			MouseEnter = function()
				entered += 1
				hovered:set(true)
			end,
			child,
			Mount.create("TextLabel", { Text = "hi" }),
			{ Size = "1,1" },
			Parent = parent,
		})

		expect(frame.Name).toBe("Panel")
		expect(frame.BackgroundTransparency).toBe(0.5)
		expect(frame.Size).toBe("1,1")
		expect(frame.Parent).toBe(parent)
		expect(child.Parent).toBe(frame)
		expect(#frame:GetChildren()).toBe(2)

		frame.MouseEnter.fire()
		expect(entered).toBe(1)
		expect(frame.BackgroundTransparency).toBe(0)

		connection:disconnect()
		hovered:set(false)
		frame.MouseEnter.fire()
		expect(frame.BackgroundTransparency).toBe(0)
		expect(entered).toBe(1)
		expect(child.destroyed).toBe(true)
		expect(#frame:GetChildren()).toBe(0)
	end)

	it("applies props with Mount.apply like calling the module", function()
		local name = Atom.new("first")
		local frame = roblox.new("Frame")
		local connection = Mount.apply(frame, { Name = name })
		name:set("second")
		expect(frame.Name).toBe("second")
		connection:disconnect()
		name:set("third")
		expect(frame.Name).toBe("second")
	end)

	it("sets a ValueBase or a state from an event", function()
		local frame = roblox.new("TextButton")
		local presses = roblox.new("IntValue")
		local last = Atom.new(nil :: any)
		Mount(frame, { Activated = presses, MouseEnter = last })
		frame.Activated.fire(3)
		frame.MouseEnter.fire("entered")
		expect(presses.Value).toBe(3)
		expect(last:get()).toBe("entered")
	end)

	it("follows a parent given as a stream or an ObjectValue", function()
		local first, second = roblox.new("Folder"), roblox.new("Folder")
		local parent = Atom.new(first)
		local frame = roblox.new("Frame")
		Mount(frame, { Parent = parent })
		expect(frame.Parent).toBe(first)
		parent:set(second)
		expect(frame.Parent).toBe(second)

		local holder = roblox.new("ObjectValue")
		holder.Value = first
		local other = roblox.new("Frame")
		Mount(other, { Parent = holder })
		expect(other.Parent).toBe(first)
	end)

	it("handles the instance and cleanup keys, output keys and signal keys", function()
		local log = {}
		local signal = roblox.signal()
		local frame = roblox.new("Frame")
		local connection = Mount(frame, {
			instance = function(instance)
				table.insert(log, `instance {instance.Name}`)
				return function()
					table.insert(log, "instance cleaned")
				end
			end,
			cleanup = function()
				table.insert(log, "cleanup")
			end,
			[Mount.output("BackgroundTransparency")] = function(transparency)
				table.insert(log, `transparency {transparency}`)
			end,
			[signal] = function(value)
				table.insert(log, `signal {value}`)
			end,
		})
		signal.fire(1)
		frame.BackgroundTransparency = 1
		connection:disconnect()
		signal.fire(2)
		frame.BackgroundTransparency = 0

		table.sort(log)
		expect(log).toEqual({
			"cleanup",
			"instance Frame",
			"instance cleaned",
			"signal 1",
			"transparency 0",
			"transparency 1",
		})
	end)

	it("errors on a child or a handler it can't use", function()
		expect(function()
			Mount(roblox.new("Frame"), { 5 })
		end).toThrow("a child must be")
		expect(function()
			Mount(roblox.new("Frame"), { MouseEnter = 5 })
		end).toThrow("needs a function")
	end)

	it("creates an instance per listener and destroys it when the listener leaves", function()
		local parent = roblox.new("Folder")
		local made: any = nil
		local connection = Mount.create("TextLabel", { Text = "hello", Parent = parent }):listen(function(instance)
			made = instance
		end)
		expect(made.Text).toBe("hello")
		expect(made.Parent).toBe(parent)
		connection:disconnect()
		expect(made.destroyed).toBe(true)
	end)
end)

return nil

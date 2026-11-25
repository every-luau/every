--!strict
-- Building UI out of props, where any property can be a stream.

local Players = game:GetService("Players")

local Mount = require("../src")
local Stream = require("../../Stream/src")

local screen = Instance.new("ScreenGui")
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- States hold values, and a property given a stream follows it.
local clicks = Stream.state(0)
local hovered = Stream.state(false)

-- Calling the module applies props to an instance you already have, and
-- returns a Connection that undoes them.
local connection = Mount(Instance.new("TextButton"), {
	Size = UDim2.fromOffset(200, 50),
	BackgroundColor3 = hovered:map(function(is_hovered)
		return if is_hovered then Color3.fromRGB(80, 140, 255) else Color3.fromRGB(60, 60, 60)
	end),
	Text = clicks:map(function(count)
		return `clicked {count} times`
	end),

	-- events take a function, or a state or a ValueBase to set
	MouseEnter = function()
		hovered:set(true)
	end,
	MouseLeave = function()
		hovered:set(false)
	end,
	Activated = function()
		clicks:update(function(count)
			return count + 1
		end)
	end,

	-- children: Mount.create makes them along with the button
	Mount.create("UICorner", { CornerRadius = UDim.new(0, 8) }),

	-- an output key calls its value with every value of a property
	[Mount.output("AbsoluteSize")] = function(size: Vector2)
		print("size", size)
	end,

	-- set last, once everything else is in place
	Parent = screen,
})

-- Mount.create is a stream: the instance exists while something listens.
local label = Mount.create("TextLabel", {
	Text = "hello",
	Parent = screen,
}):listen(function(instance)
	print("created", instance)
end)

task.delay(10, function()
	connection:disconnect()
	label:disconnect()
end)

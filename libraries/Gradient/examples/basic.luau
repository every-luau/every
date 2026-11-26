--!strict
-- Animated text and outlines in a ScreenGui.

local Players = game:GetService("Players")

local Gradient = require("../src")

local screen = Instance.new("ScreenGui")
screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function label(text: string, y: number): TextLabel
	local made = Instance.new("TextLabel")
	made.Text = text
	made.TextScaled = true
	-- a UIGradient multiplies the color under it, so keep the text white
	made.TextColor3 = Color3.new(1, 1, 1)
	made.BackgroundTransparency = 1
	made.Size = UDim2.fromOffset(300, 60)
	made.Position = UDim2.fromOffset(20, y)
	made.Parent = screen
	return made
end

-- One gradient paints every target added to it.
local rainbow = Gradient.preset("Rainbow")
rainbow:add(label("Rainbow", 20))
rainbow:add(label("Same rainbow", 90))

-- A number makes a stroke that thick, painted with the stroke colors.
Gradient.preset("Electric", { speed = 0.75 }):add(label("Electric", 160), 3)

-- Outline presets only paint strokes.
Gradient.preset("ShineOutline", { color = Color3.fromRGB(255, 200, 0) }):add(label("Shine", 230), 2)

-- Your own colors, sliding and turning.
local custom = Gradient.new(ColorSequence.new(Color3.fromRGB(255, 0, 120), Color3.fromRGB(0, 200, 255)))
	:set_speed(0.25)
	:set_sway(20, 0.5)
custom:add(label("Custom", 300))

task.delay(10, function()
	-- removes what it made, and puts back the gradients that were there
	rainbow:destroy()
	custom:destroy()
end)

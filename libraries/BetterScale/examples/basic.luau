--!strict
-- Scaling a menu designed at 1920x1080 to any screen.

local Players = game:GetService("Players")

local BetterScale = require("../src")

local gui = Players.LocalPlayer.PlayerGui:WaitForChild("Menu")
local ui_scale = Instance.new("UIScale")
ui_scale:SetAttribute("Resolution", Vector2.new(1920, 1080))
ui_scale:SetAttribute("Range", NumberRange.new(0.5, 1.5))
ui_scale.Parent = gui.Frame

-- Tracks the gui's size from now on.
local scale = BetterScale.build(ui_scale)

-- Only follows the height.
ui_scale:SetAttribute("Direction", Enum.AutomaticSize.Y)

-- 25% bigger on phones.
ui_scale:SetAttribute("DisplayRatios", '{"Small": 1.25}')

print(scale:get_scale())

-- Keeps the current scale and stops updating it.
scale:untrack()

--!strict
-- A frame that fades in and out on hover, where the last fade always wins.

local AlphaTween = require("../src")

local frame = Instance.new("Frame")
local current: AlphaTween.AlphaTween? = nil

local function fade(goal: number)
	-- Cancels the fade still playing, so the new one starts from where it got to.
	if current then
		current:cancel()
	end
	current = AlphaTween.value(frame.BackgroundTransparency, goal, TweenInfo.new(0.25), function(transparency)
		frame.BackgroundTransparency = transparency
	end):play()
end

frame.MouseEnter:Connect(function()
	fade(0)
end)

frame.MouseLeave:Connect(function()
	fade(1)
end)

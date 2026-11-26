--!strict
-- A sliding door that opens on a pivot, can be paused halfway and closes on its own.

local AlphaTween = require("../src")

local door = Instance.new("Model")
local closed = door:GetPivot()
local open = closed * CFrame.new(0, 0, 6)

-- Opens, then closes by going back the same way.
local tween = AlphaTween.new(TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true, 0), function(alpha)
	door:PivotTo(closed:Lerp(open, alpha))
end)

tween:play()

-- Stops where it is, then goes on from there.
task.delay(0.5, function()
	tween:pause()
	task.wait(1)
	tween:play()
end)

local state = tween.completed:wait()
print(state) --> Enum.PlaybackState.Completed

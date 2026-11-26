--!strict
-- A camera that zooms while the player sprints, and a pulse that never ends until it is cancelled.

local AlphaTween = require("../src")

local camera = workspace.CurrentCamera
local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local zooming: AlphaTween.AlphaTween? = nil

local function zoom(fov: number)
	if zooming then
		zooming:cancel()
	end
	zooming = AlphaTween.value(camera.FieldOfView, fov, info, function(value)
		camera.FieldOfView = value
	end):play()
end

zoom(85) -- sprints
task.wait(0.1)
zoom(70) -- stops, from wherever the zoom got to

-- A repeat count of -1 plays forever, going back and forth.
local pulse = AlphaTween.new(TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), function(alpha)
	camera.FieldOfView = 70 + alpha * 2
end)

pulse:play()
task.wait(3)
pulse:cancel()

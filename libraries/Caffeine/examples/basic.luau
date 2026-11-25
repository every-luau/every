--!strict
-- Keeping slow parts awake, then letting them sleep again. Run it on the
-- server, and require Caffeine once on the client too so parts a player owns
-- stay awake.

local Caffeine = require("../src")

-- An AlignPosition moving a platform at 0.1 studs/s is under the sleep
-- threshold, so the platform would freeze without Caffeine. Calling the module
-- keeps it awake until the connection is disconnected.
local platform = workspace:FindFirstChild("Platform") :: BasePart
local connection = Caffeine(platform)

-- A model is followed: parts added to the car later are kept awake too.
local car = workspace:FindFirstChild("Car") :: Model
Caffeine(car)

-- Each pin is its own assembly, so they go in a list. A duration lets go on its
-- own once the ball has rolled past.
local pins: { BasePart } = {}
for _, child in workspace:GetChildren() do
	if child:IsA("BasePart") and child.Name == "Pin" then
		table.insert(pins, child)
	end
end
Caffeine.keep(pins, 3)

-- A tower of loose bricks drifts if kept awake, so wake it once right before
-- a projectile lands instead.
local tower = workspace:FindFirstChild("Tower") :: Model
Caffeine.wake(tower)

-- Disconnecting lets the platform sleep again.
task.delay(10, function()
	connection:disconnect()
end)

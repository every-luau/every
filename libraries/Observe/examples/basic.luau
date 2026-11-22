--!strict
-- Setting things up for what exists, and cleaning them when it's gone.

local Observe = require("../src")

-- Every part tagged Lava, now and later. the void is cleaned when the tag is
-- removed, which disconnects Touched.
Observe.tag("Lava", function(part, void)
	void:add((part :: BasePart).Touched:Connect(function(hit)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end))
end)

-- Every character of every player, cleaned on respawn and when they leave.
Observe.characters(function(player, character, void)
	local highlight = void:add(Instance.new("Highlight"))
	highlight.Parent = character
end, function(player)
	return player.Team ~= nil
end)

-- Every tool the local player has, kept while it moves between backpack and
-- hand. Observe.tools does the same for any player.
Observe.local_tools(function(tool, void)
	print(`you have {tool.Name}`)
	void:add(function()
		print(`you lost {tool.Name}`)
	end)
end)

-- Every instance named SpawnDoor anywhere in the game, and every Seat in the
-- workspace only, which listens to fewer instances.
Observe.instance("SpawnDoor", function(door, void)
	void:add((door :: BasePart).Touched:Connect(function()
		print("someone reached the door")
	end))
end)
Observe.class_name("Seat", function(seat, void)
	print(`{seat:GetFullName()} can be sat on`)
end, nil, workspace)

-- Every player on the red team, cleaned when they switch team or leave.
Observe.team(game:GetService("Teams"):WaitForChild("Red") :: Team, function(player, void)
	print(`{player.Name} is red`)
	void:add(function()
		print(`{player.Name} is not red anymore`)
	end)
end)

-- The input the player uses, cleaned when they switch, like from touch to a
-- gamepad. display_size works the same way for the screen size.
Observe.preferred_input(function(input, void)
	if input == Enum.PreferredInput.Touch then
		local buttons = void:add(Instance.new("ScreenGui"))
		buttons.Name = "MobileButtons"
	end
end)

-- A value, cleaned every time it changes.
local connection = Observe.attribute(workspace, "Night", function(night, void)
	if night then
		local light = void:add(Instance.new("PointLight"))
		light.Parent = workspace:WaitForChild("Lamp")
	end
end)

-- Stops observing and cleans every void.
connection:disconnect()

--!strict
-- Setting things up for what exists, and cleaning them when it's gone.

local Players = game:GetService("Players")

local Observe = require("../src")

-- Every part tagged Lava, now and later. The brio dies when the tag is
-- removed, which cleans its void and disconnects Touched.
Observe.tag("Lava"):subscribe(function(brio)
	local void, part = brio:to_void_and_value()
	void:add((part :: BasePart).Touched:Connect(function(hit)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end))
end)

-- Every character of a player on a team, killed on respawn and when they
-- leave. filter picks what gets a brio.
Observe.characters()
	:filter(function(character)
		local player = Players:GetPlayerFromCharacter(character)
		return player ~= nil and player.Team ~= nil
	end)
	:subscribe(function(brio)
		local void, character = brio:to_void_and_value()
		local highlight = void:add(Instance.new("Highlight"))
		highlight.Parent = character
	end)

-- Every tool the local player has, kept while it moves between backpack and
-- hand. Observe.tools does the same for any player.
Observe.local_tools():subscribe(function(brio)
	local void, tool = brio:to_void_and_value()
	print(`you have {tool.Name}`)
	void:add(function()
		print(`you lost {tool.Name}`)
	end)
end)

-- Every instance named SpawnDoor anywhere in the game, and every Seat in the
-- workspace only, which listens to fewer instances.
Observe.instance("SpawnDoor"):subscribe(function(brio)
	local void, door = brio:to_void_and_value()
	void:add((door :: BasePart).Touched:Connect(function()
		print("someone reached the door")
	end))
end)
Observe.class_name("Seat", workspace):subscribe(function(brio)
	local seat = brio:get_value()
	print(`{seat:GetFullName()} can be sat on`)
end)

-- Every player on the red team, killed when they switch team or leave.
Observe.team(game:GetService("Teams"):WaitForChild("Red") :: Team):subscribe(function(brio)
	local void, player = brio:to_void_and_value()
	print(`{player.Name} is red`)
	void:add(function()
		print(`{player.Name} is not red anymore`)
	end)
end)

-- The input the player uses, killed when they switch, like from touch to a
-- gamepad. display_size works the same way for the screen size.
Observe.preferred_input()
	:filter(function(input)
		return input == Enum.PreferredInput.Touch
	end)
	:subscribe(function(brio)
		local void = brio:to_void()
		local buttons = void:add(Instance.new("ScreenGui"))
		buttons.Name = "MobileButtons"
	end)

-- A value, killed every time it changes. Only a brio for the night here.
local connection = Observe.attribute(workspace, "Night")
	:filter(function(night)
		return night == true
	end)
	:subscribe(function(brio)
		local void = brio:to_void()
		local light = void:add(Instance.new("PointLight"))
		light.Parent = workspace:WaitForChild("Lamp")
	end)

-- Stops observing and kills every brio.
connection:disconnect()

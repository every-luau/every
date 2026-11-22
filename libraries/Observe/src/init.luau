--[=[
	@class Observe

	Observe runs a callback for every player, character, instance, tag or value, now and later

	each observer calls its callback for what already exists, then for what comes
	later. the callback's last argument is a [Void] cleaned once that thing is
	gone, so whatever it sets up for it ends with it. every observer returns a
	[Connection] that stops observing and cleans every void

	```lua
	local Observe = require(path.to.Observe)

	Observe.tag("Lava", function(part, void)
		void:add(part.Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 0
			end
		end))
	end)
	```

	:::info
	callbacks run on a recycled thread with [Thread], so they can yield. each
	observer is also its own module, so `require(path.to.Observe.tag)` only loads
	that one
	:::
]=]

return table.freeze({
	attribute = require("@self/attribute"),
	character = require("@self/character"),
	characters = require("@self/characters"),
	children = require("@self/children"),
	class_name = require("@self/class_name"),
	descendants = require("@self/descendants"),
	display_size = require("@self/display_size"),
	instance = require("@self/instance"),
	local_character = require("@self/local_character"),
	local_tools = require("@self/local_tools"),
	players = require("@self/players"),
	preferred_input = require("@self/preferred_input"),
	property = require("@self/property"),
	tag = require("@self/tag"),
	team = require("@self/team"),
	tools = require("@self/tools"),
})

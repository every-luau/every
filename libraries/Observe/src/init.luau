--[=[
	@class Observe

	Observe hands out a [Brio] for every player, character, instance, tag or value, now and later

	each observer returns an [Observable]. subscribing to it gives a [Brio] for
	what already exists, then for what comes later. [Brio:get_value] reads it,
	and [Brio:to_void] gives a [Void] cleaned once that thing is gone, so
	whatever was set up for it ends with it. subscribing returns a [Connection]
	that stops observing and kills every brio

	```lua
	local Observe = require(path.to.Observe)

	Observe.tag("Lava"):subscribe(function(brio)
		local void, part = brio:to_void_and_value()
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

	:::tip
	observables chain before subscribing: `filter` keeps what you need, `map`
	turns each item into another, and `flat_map` follows something for each
	item, like `Observe.players():flat_map(Observe.character)`
	:::
]=]

const Observable = require(script.Parent.Observable)

export type Brio<T> = Observable.Brio<T>
export type Connection = Observable.Connection
export type Observable<T> = Observable.Observable<T>

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

# Observe

Observe hands out a Brio for every player, character, instance, tag or value, now and later

each observer returns an [Observable](https://every-luau.github.io/docs/observable). subscribing to it gives a [Brio](https://every-luau.github.io/docs/brio) for what already exists, then for what comes later. `brio:get_value()` reads it, and `brio:to_void()` gives a [Void](https://every-luau.github.io/docs/void) cleaned once that thing is gone. subscribing returns a [Connection](https://every-luau.github.io/docs/connection) that stops observing

**[Documentation](https://every-luau.github.io/docs/observe)**

## Installation

```toml
[dependencies]
Observe = { name = "every/observe", version = "^0.0.1" }
```

```sh
embr install
```

installs [Observable](https://every-luau.github.io/docs/observable), [Stream](https://every-luau.github.io/docs/stream) and [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Observe = require(ReplicatedStorage.Packages.Observe)

Observe.tag("Lava"):subscribe(function(brio)
	local void, part = brio:to_void_and_value()
	void:add(part.Touched:Connect(kill))
end)

Observe.characters():subscribe(function(brio)
	local void, character = brio:to_void_and_value()
	local highlight = void:add(Instance.new("Highlight"))
	highlight.Parent = character
end)

-- only looks in workspace instead of the whole game
Observe.class_name("Seat", workspace):subscribe(function(brio)
	local void, seat = brio:to_void_and_value()
	void:add(seat:GetPropertyChangedSignal("Occupant"):Connect(update_seat))
end)

Observe.team(Teams.Red):subscribe(function(brio)
	local void, player = brio:to_void_and_value()
	void:add(give_red_tools(player))
end)

-- a brio only while the value passes the filter
Observe.preferred_input()
	:filter(function(input)
		return input == Enum.PreferredInput.Touch
	end)
	:subscribe(function(brio)
		local void = brio:to_void()
		void:add(show_mobile_buttons())
	end)

local connection = Observe.attribute(workspace, "Night")
	:filter(function(night)
		return night == true
	end)
	:subscribe(function(brio)
		local void = brio:to_void()
		void:add(start_music())
	end)

connection:disconnect()
```

## License

MIT

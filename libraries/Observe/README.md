# Observe

Observe runs a callback for every player, character, instance, tag or value, now and later

each observer calls its callback for what already exists, then for what comes later, with a [Void](https://every-luau.github.io/docs/void) cleaned once that thing is gone. it returns a [Connection](https://every-luau.github.io/docs/connection) that stops observing

**[Documentation](https://every-luau.github.io/docs/observe)**

## Installation

```toml
[dependencies]
Observe = { name = "every/observe", version = "^0.0.1" }
```

```sh
embr install
```

installs [Connection](https://every-luau.github.io/docs/connection), [Thread](https://every-luau.github.io/docs/thread) and [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Observe = require(ReplicatedStorage.Packages.Observe)

Observe.tag("Lava", function(part, void)
	void:add(part.Touched:Connect(kill))
end)

Observe.characters(function(player, character, void)
	local highlight = void:add(Instance.new("Highlight"))
	highlight.Parent = character
end)

-- only looks in workspace instead of the whole game
Observe.class_name("Seat", function(seat, void)
	void:add(seat:GetPropertyChangedSignal("Occupant"):Connect(update_seat))
end, nil, workspace)

Observe.team(Teams.Red, function(player, void)
	void:add(give_red_tools(player))
end)

Observe.preferred_input(function(input, void)
	if input == Enum.PreferredInput.Touch then
		void:add(show_mobile_buttons())
	end
end)

local connection = Observe.attribute(workspace, "Night", function(night, void)
	if night then
		void:add(start_music())
	end
end)

connection:disconnect()
```

## License

MIT

# Stream

Stream follows values over time and builds reactive code out of them

chain methods like `map`, `filter` or `switch` to make new streams, then `listen` or `each` to use the values. life streams follow sets of things that come and go, like players or tagged parts. to build UI out of streams, use [Mount](https://every-luau.github.io/docs/mount)

**[Documentation](https://every-luau.github.io/docs/stream)**

## Installation

```toml
[dependencies]
Stream = { name = "every/stream", version = "^0.0.1" }
```

```sh
embr install
```

installs [Connection](https://every-luau.github.io/docs/connection), [Thread](https://every-luau.github.io/docs/thread) and [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Stream = require(ReplicatedStorage.Packages.Stream)

-- the health of the local player's current character, nil while there is none
local connection = Stream.character(Players.LocalPlayer)
	:child("Humanoid")
	:property("Health")
	:listen(print)
connection:disconnect()

-- something for each player while they are in the game
Stream.players():each(function(player, void)
	print(`{player.Name} joined`)
	void:add(function()
		print(`{player.Name} left`)
	end)
end)

-- every part tagged Lava inside workspace
Stream.tagged("Lava", workspace):each(function(part, void)
	void:add(part.Touched:Connect(kill))
end)

-- the search box, once the player stopped typing
Stream.property(search_box, "Text"):debounce(0.3):changed():listen(search)
```

## License

MIT

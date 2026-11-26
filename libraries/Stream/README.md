# Stream

Stream follows values over time and builds reactive code out of them

chain methods like `map`, `filter` or `switch` to make new streams, then `listen` or `each` to use the values. to hold a value you set, use [Atom](https://every-luau.github.io/docs/atom), which is a stream too. to follow sets of things that come and go, like players or tagged parts, use [Observable](https://every-luau.github.io/docs/observable). to build UI out of streams, use [Mount](https://every-luau.github.io/docs/mount)

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

-- something while the humanoid sits, undone when it gets up
Stream.property(humanoid, "Sit"):each(function(sitting, void)
	if sitting then
		void:add(show_seat_menu())
	end
end)

-- the search box, once the player stopped typing
Stream.property(search_box, "Text"):debounce(0.3):changed():listen(search)
```

## License

MIT

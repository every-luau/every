# Observable

Observable hands out a Brio for every value or item of a Stream, alive while it lasts

wrap a [Stream](https://every-luau.github.io/docs/stream) with `Observable.new` and subscribe. each value or item comes as a [Brio](https://every-luau.github.io/docs/brio): `brio:get_value()` reads it, and `brio:to_void()` gives a Void cleaned once the value is replaced or the item leaves. chain `filter`, `map` and `changed` before subscribing. subscribing returns a [Connection](https://every-luau.github.io/docs/connection)

**[Documentation](https://every-luau.github.io/docs/observable)**

## Installation

```toml
[dependencies]
Observable = { name = "every/observable", version = "^0.0.1" }
```

```sh
embr install
```

installs [Brio](https://every-luau.github.io/docs/brio), [Connection](https://every-luau.github.io/docs/connection), [Stream](https://every-luau.github.io/docs/stream), [Thread](https://every-luau.github.io/docs/thread) and [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Observable = require(ReplicatedStorage.Packages.Observable)
local Stream = require(ReplicatedStorage.Packages.Stream)

-- a brio per player, killed when they leave
Observable.new(Stream.players()):subscribe(function(brio)
	local void, player = brio:to_void_and_value()
	local leaderstats = void:add(Instance.new("Folder"))
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
end)

-- a brio while the health is low, killed once it goes back up
local connection = Observable.new(Stream.property(humanoid, "Health"))
	:filter(function(health)
		return health < 20
	end)
	:subscribe(function(brio)
		local void = brio:to_void()
		void:add(show_low_health_warning())
	end)

connection:disconnect()
```

## License

MIT

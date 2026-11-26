# Atom

Atom is a value you set and follow like a stream

create one with a starting value, change it with `set` or `update`, and listen with `observe`. it only notifies when the value really changes, comparing tables deeply. an atom is a [Stream](https://every-luau.github.io/docs/stream), so `map`, `filter`, `Stream.combine` and [Mount](https://every-luau.github.io/docs/mount) props work with it

**[Documentation](https://every-luau.github.io/docs/atom)**

## Installation

```toml
[dependencies]
Atom = { name = "every/atom", version = "^0.0.1" }
```

```sh
embr install
```

installs [Connection](https://every-luau.github.io/docs/connection), [Stream](https://every-luau.github.io/docs/stream) and [Thread](https://every-luau.github.io/docs/thread) with it

## Usage

```lua
local Atom = require(ReplicatedStorage.Packages.Atom)

local coins = Atom.new(0)

coins:observe(function(new, old)
	label.Text = `{new} coins`
end)

coins:increment(10)

-- an atom is a stream, so the stream methods work on it
local shown = coins:debounce(0.5)

-- notifies once for both changes
Atom.batch({ coins, gems }, function()
	coins:decrement(100)
	gems:increment(1)
end)
```

## License

MIT

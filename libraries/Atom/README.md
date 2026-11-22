# Atom

Atom is a value that can be observed, derived and updated

create one with a starting value, change it with `set` or `update`, and listen with `observe`. it only notifies when the value really changes, comparing tables deeply, and `map`, `filter` and `throttle` derive new atoms that follow it

**[Documentation](https://every-luau.github.io/docs/atom)**

## Installation

```toml
[dependencies]
Atom = { name = "every/atom", version = "^0.0.1" }
```

```sh
embr install
```

installs [Signal](https://every-luau.github.io/docs/signal), [Thread](https://every-luau.github.io/docs/thread) and [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Atom = require(ReplicatedStorage.Packages.Atom)

local coins = Atom.new(0)

coins:observe(function(new, old)
	label.Text = `{new} coins`
end)

coins:increment(10)

-- Follows coins, holding changes for half a second
local shown = coins:throttle(0.5)

-- Notifies once for both changes
Atom.batch({ coins, gems }, function()
	coins:decrement(100)
	gems:increment(1)
end)
```

## License

MIT

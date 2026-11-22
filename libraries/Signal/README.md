# Signal

Signal is a yield-safe signal whose handlers run on a recycled thread

connect handlers, then fire values to all of them. each handler runs with [Thread](https://every-luau.github.io/docs/thread), so one that yields doesn't hold up the others, and connecting returns a [Connection](https://every-luau.github.io/docs/connection) that removes it

**[Documentation](https://every-luau.github.io/docs/signal)**

## Installation

```toml
[dependencies]
Signal = { name = "every/signal", version = "^0.0.1" }
```

```sh
embr install
```

installs [Thread](https://every-luau.github.io/docs/thread) and [Connection](https://every-luau.github.io/docs/connection) with it

## Usage

```lua
local Signal = require(ReplicatedStorage.Packages.Signal)

local damaged = Signal.new()

local connection = damaged:connect(function(name, damage)
	print(`{name} took {damage} damage`)
end)

damaged:once(function()
	print("first hit!")
end)

damaged:fire("Player1", 25)
connection:disconnect()

-- Follow an RBXScriptSignal until destroyed
local added = Signal.wrap(workspace.ChildAdded)
added:connect(print)
added:destroy()
```

## License

MIT

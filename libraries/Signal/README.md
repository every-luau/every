# 🔔 Signal

A yield-safe signal whose handlers run on a recycled thread.

Handlers are stored in a linked list, so connecting and disconnecting never walk it. A handler that yields doesn't hold up the others, and connections can be added to a [Void](https://every-luau.github.io/docs/void).

**[Documentation](https://every-luau.github.io/docs/signal)**

## Installation

```toml
[dependencies]
Signal = { name = "every/signal", version = "^0.1.0" }
```

```sh
embr install
```

Installs [Thread](https://every-luau.github.io/docs/thread) and [Connection](https://every-luau.github.io/docs/connection) with it.

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

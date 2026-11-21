# 🔌 Connection

A handle that runs its cleanup once, when disconnected.

It is what [Signal](https://every-luau.github.io/docs/signal) and [Observable](https://every-luau.github.io/docs/observable) return when connecting or subscribing. The cleanup is either a function, called on a recycled thread, or a [Void](https://every-luau.github.io/docs/void) to clean.

**[Documentation](https://every-luau.github.io/docs/connection)**

## Installation

```toml
[dependencies]
Connection = { name = "every/connection", version = "^0.0.1" }
```

```sh
embr install
```

Installs [Void](https://every-luau.github.io/docs/void) and [Thread](https://every-luau.github.io/docs/thread) with it.

## Usage

```lua
local Connection = require(ReplicatedStorage.Packages.Connection)

local function listen(part: BasePart, callback: (BasePart) -> ())
	local touched = part.Touched:Connect(callback)

	return Connection.new(function()
		touched:Disconnect()
	end)
end

local connection = listen(workspace.Door, print)
print(connection.connected) --> true

connection:disconnect()
print(connection.connected) --> false
```

## License

MIT

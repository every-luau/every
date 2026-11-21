# Connection

Connection is like Roblox's RBXScriptConnection, but for your own code

create it with a function, a [Void](https://every-luau.github.io/docs/void) or an RBXScriptConnection, then return it from anything that has to be undone later. disconnecting calls the function, cleans the Void or disconnects the RBXScriptConnection

**[Documentation](https://every-luau.github.io/docs/connection)**

## Installation

```toml
[dependencies]
Connection = { name = "every/connection", version = "^0.0.1" }
```

```sh
embr install
```

installs [Void](https://every-luau.github.io/docs/void) and [Thread](https://every-luau.github.io/docs/thread) with it

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

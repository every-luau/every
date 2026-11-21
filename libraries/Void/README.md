# Void

Void keeps track of things to clean up, and cleans them all at once

add what a feature creates as you go, then call `clean` when it ends. instances are destroyed, connections disconnected, threads cancelled, functions called with [Thread](https://every-luau.github.io/docs/thread), and objects have their `Destroy`, `Disconnect`, `destroy` or `disconnect` method called

**[Documentation](https://every-luau.github.io/docs/void)**

## Installation

```toml
[dependencies]
Void = { name = "every/void", version = "^0.0.1" }
```

```sh
embr install
```

installs [Thread](https://every-luau.github.io/docs/thread) with it

## Usage

```lua
local Void = require(ReplicatedStorage.Packages.Void)

local void = Void.new()

local part = void:add(Instance.new("Part"))
void:add(workspace.ChildAdded:Connect(print))
void:add(function()
	print("cleaned")
end)

-- Clean everything once the model leaves the game
void:attach_to_instance(model)

void:clean() --> cleaned
```

## License

MIT

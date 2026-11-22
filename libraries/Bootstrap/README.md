# Bootstrap

Bootstrap requires ModuleScripts and calls their hooks in order of priority

`load` requires each ModuleScript in parallel and sorts them by their `_priority`, then `call` runs a method like `init` or `start` on each one at once and waits for all of them

**[Documentation](https://every-luau.github.io/docs/bootstrap)**

## Installation

```toml
[dependencies]
Bootstrap = { name = "every/bootstrap", version = "^0.0.1" }
```

```sh
embr install
```

installs [Future](https://every-luau.github.io/docs/future) with it

## Usage

```lua
local Bootstrap = require(ReplicatedStorage.Packages.Bootstrap)

local services = Bootstrap.load(ServerScriptService.Services):await()

Bootstrap.call(services, "init"):await()
Bootstrap.call(services, "start"):await()
```

## License

MIT

# Thread

Thread runs callbacks on a recycled thread instead of creating a new one per call

use it like `task.spawn`, by calling the module or `Thread.spawn`. idle threads are reused, and a new one is only created when every idle thread is busy with a callback that yielded

**[Documentation](https://every-luau.github.io/docs/thread)**

## Installation

```toml
[dependencies]
Thread = { name = "every/thread", version = "^0.0.1" }
```

```sh
embr install
```

## Usage

```lua
local Thread = require(ReplicatedStorage.Packages.Thread)

-- The same as Thread.spawn, arguments are forwarded like task.spawn
Thread(print, "hello", "world")

Thread.spawn(function(name)
	task.wait(1) -- yielding is fine, the next call just gets another thread
	print(`hello {name}`)
end, "world")
```

## License

MIT

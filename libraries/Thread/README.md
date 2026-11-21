# 🧵 Thread

Runs callbacks on a recycled thread instead of creating a new one per call.

`task.spawn(callback)` allocates a coroutine every time. Thread keeps a pool of idle threads and hands callbacks to them; a new thread is only created when every idle one is busy because its callback yielded.

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

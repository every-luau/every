# Loop

Loop calls a callback every few seconds, driven by Heartbeat

call the module or `Loop.new` with an interval and a callback. the callback gets the time that passed since its last call, and the loop runs until the returned [Connection](https://every-luau.github.io/docs/connection) is disconnected

**[Documentation](https://every-luau.github.io/docs/loop)**

## Installation

```toml
[dependencies]
Loop = { name = "every/loop", version = "^0.0.1" }
```

```sh
embr install
```

installs [Connection](https://every-luau.github.io/docs/connection) with it

## Usage

```lua
local Loop = require(ReplicatedStorage.Packages.Loop)

-- Regenerate health every second
local connection = Loop(1, function(elapsed)
	humanoid.Health += 5 * elapsed
end)

-- An interval of 0 runs every frame
Loop(0, function(delta_time)
	part.CFrame *= CFrame.Angles(0, delta_time, 0)
end)

connection:disconnect()
```

## License

MIT

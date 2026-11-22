# Timer

Timer is a stopwatch or countdown with a speed, updated every frame

set its time and speed, then `start` it. its time moves by the frame's delta time times its speed, so a speed of -1 counts down, and `format_seconds` turns it into `mm:ss` text

**[Documentation](https://every-luau.github.io/docs/timer)**

## Installation

```toml
[dependencies]
Timer = { name = "every/timer", version = "^0.0.1" }
```

```sh
embr install
```

installs [Loop](https://every-luau.github.io/docs/loop), [Signal](https://every-luau.github.io/docs/signal) and [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Timer = require(ReplicatedStorage.Packages.Timer)

local countdown = Timer.new():set_time(60):set_speed(-1):start()

countdown:observe(function(time)
	label.Text = Timer.format_seconds(math.max(time, 0))

	if time <= 0 then
		countdown:stop()
	end
end)
```

## License

MIT

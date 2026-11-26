# Clock

Clock is a time in seconds that moves at a speed, the same on the server and every client

start a clock, set its speed or count down with a negative one, and call back at a time with `at`. on the server, `replicate` sends it to clients, who get their own copy with `Clock.get` that moves on its own. `Clock.synced_time` and `Clock.timestamp` give a time that is the same on every server, to save in data

**[Documentation](https://every-luau.github.io/clock)**

## Installation

```toml
[dependencies]
Clock = { name = "every/clock", version = "^0.0.1" }
```

```sh
embr install
```

installs [Atom](https://every-luau.github.io/atom), [Connection](https://every-luau.github.io/connection), [Future](https://every-luau.github.io/future), [Loop](https://every-luau.github.io/loop), [Lync](https://github.com/Axp3cter/Lync), [Signal](https://every-luau.github.io/signal) and [Void](https://every-luau.github.io/void) with it

## Usage

```lua
local Clock = require(ReplicatedStorage.Packages.Clock)

-- server
local round = Clock.new():set_time(120):set_speed(-1):start():replicate("Round")

round:at(0, function()
	round:stop()
end)

-- client
local round = Clock.get("Round"):await()

round:observe(function(time)
	label.Text = string.format("%d", math.max(time, 0))
end)
```

```lua
-- saved data, compared on any server later
if Clock.since(data.last_reward) >= Clock.DAY then
	data.last_reward = Clock.timestamp()
end
```

a running clock sends nothing: each side works its time out from `Clock.synced_time`, and only a start, a stop or a change is sent. Clock defines a Lync namespace, so require it before `Lync.start` runs

## License

MIT

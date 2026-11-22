# Ratelimit

Ratelimit limits how many times something can happen per key within an interval

call the module with a limit and an interval in seconds. it returns a function that takes a key, often a player, and returns whether that key can act now

**[Documentation](https://every-luau.github.io/docs/ratelimit)**

## Installation

```toml
[dependencies]
Ratelimit = { name = "every/ratelimit", version = "^0.0.1" }
```

```sh
embr install
```

## Usage

```lua
local Ratelimit = require(ReplicatedStorage.Packages.Ratelimit)

-- 3 purchases per player every 10 seconds
local can_buy = Ratelimit(3, 10)

remote.OnServerEvent:Connect(function(player, item)
	if can_buy(player) then
		buy(player, item)
	end
end)
```

## License

MIT

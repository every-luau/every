# Retryer

Retryer calls a function again until it stops erroring, with different waits

pick how long to wait between attempts: nothing with `zero_delay`, a fixed delay with `delay`, or a growing one with `exp`. each returns whether it worked and the results or the last error, and the `inf_` versions keep trying until it works

**[Documentation](https://every-luau.github.io/docs/retryer)**

## Installation

```toml
[dependencies]
Retryer = { name = "every/retryer", version = "^0.0.1" }
```

```sh
embr install
```

## Usage

```lua
local Retryer = require(ReplicatedStorage.Packages.Retryer)

-- 5 attempts, waiting 1 + 2 ^ attempt seconds between them
local ok, data = Retryer.exp(1, 2, 5, store.GetAsync, store, key)
if not ok then
	warn("couldn't load:", data)
end

-- Never gives up, waiting 2 seconds between attempts
local result = Retryer.inf_delay(2, store.SetAsync, store, key, value)
```

## License

MIT

# Future

Future is a value available later, with chaining, combinators and cancellation

create one with an executor that calls `pass` or `fail`, then `await` it, chain it with `and_then` and `catch`, or race it against a `timeout`. a future settles once: it's resolved, rejected or cancelled, and stays that way

**[Documentation](https://every-luau.github.io/docs/future)**

## Installation

```toml
[dependencies]
Future = { name = "every/future", version = "^0.0.1" }
```

```sh
embr install
```

installs [Thread](https://every-luau.github.io/docs/thread) with it

## Usage

```lua
local Future = require(ReplicatedStorage.Packages.Future)

local data = Future.new(function(pass, fail)
	local ok, result = pcall(store.GetAsync, store, key)
	if ok then
		pass(result)
	else
		fail(result)
	end
end)

-- Waits for the value, erroring if it takes more than 5 seconds
local value = data:timeout(5):await()

-- Runs both at once and waits for both
local results = Future.all({ load_profile(player), load_inventory(player) }):await()
```

## License

MIT

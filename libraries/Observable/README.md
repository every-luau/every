# 📡 Observable

A reactive stream of values to subscribe to, map, filter and dedupe.

Observables are cold: nothing runs until something subscribes, and each subscription runs its producer again. Subscribing returns a [Connection](https://every-luau.github.io/docs/connection).

**[Documentation](https://every-luau.github.io/docs/observable)**

## Installation

```toml
[dependencies]
Observable = { name = "every/observable", version = "^0.0.1" }
```

```sh
embr install
```

Installs [Connection](https://every-luau.github.io/docs/connection), [Signal](https://every-luau.github.io/docs/signal) and [Void](https://every-luau.github.io/docs/void) with it.

## Usage

```lua
local Observable = require(ReplicatedStorage.Packages.Observable)

local health = Observable.from_signal(humanoid.HealthChanged)

local connection = health
	:filter(function(value)
		return value < 20
	end)
	:changed()
	:subscribe(function(value)
		warn(`low health: {value}`)
	end)

connection:disconnect()
```

## License

MIT

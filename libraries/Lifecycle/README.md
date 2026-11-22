# Lifecycle

Lifecycle builds objects whose lifecycle hooks are registered with chainable calls

any `on_name` call registers the hook `name`, so a lifecycle has whatever hooks you give it. calling the hook then runs what was registered, and `extend` runs the hooks of a base first

**[Documentation](https://every-luau.github.io/docs/lifecycle)**

## Installation

```toml
[dependencies]
Lifecycle = { name = "every/lifecycle", version = "^0.0.1" }
```

```sh
embr install
```

## Usage

```lua
local Lifecycle = require(ReplicatedStorage.Packages.Lifecycle)

local CoinService = Lifecycle.new(10)
	:on_init(function(self)
		self.coins = {}
	end)
	:on_start(function(self)
		print("coins ready")
	end)

CoinService:init()
CoinService:start()
```

## License

MIT

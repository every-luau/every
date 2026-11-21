# Weight

Weight picks random keys from a table of weights, with an optional luck factor

give it a table of keys to weights, then call `generate`. a key with a weight of 10 comes up ten times as often as one with a weight of 1. rolls come from the CSPRNG of [rbx-cryptography](https://github.com/daily3014/rbx-cryptography), so they can't be predicted

**[Documentation](https://every-luau.github.io/docs/weight)**

## Installation

```toml
[dependencies]
Weight = { name = "every/weight", version = "^0.0.1" }
```

```sh
embr install
```

installs [rbx-cryptography](https://github.com/daily3014/rbx-cryptography) with it

## Usage

```lua
local Weight = require(ReplicatedStorage.Packages.Weight)

local loot = Weight.new({ common = 80, rare = 15, epic = 5 })

print(loot:generate()) --> common

-- Luck above 1 makes rare keys more likely
print(loot:generate(5))

-- The intensity sets how much luck does, the lower the stronger
loot:set_intensity(1)

-- `+` merges two weights, the right side winning
local event = loot + Weight.new({ legendary = 1 })
print(event) --> Weight { common = 80, epic = 5, legendary = 1, rare = 15 }
```

## License

MIT

# Caffeine

Caffeine keeps unanchored parts from falling asleep in Roblox physics

Roblox stops simulating a part once it moves slower than its sleep thresholds, so a door pushed slowly by a constraint or a bowling pin waiting for a ball can freeze in place. `Caffeine.wake` gives a part, a model or a list of parts one small shake to wake them. calling the module shakes them before every physics step, so they never fall asleep, until the returned [Connection](https://every-luau.github.io/docs/connection) is disconnected

**[Documentation](https://every-luau.github.io/docs/caffeine)**

## Installation

```toml
[dependencies]
Caffeine = { name = "every/caffeine", version = "^0.0.1" }
```

```sh
embr install
```

installs [Connection](https://every-luau.github.io/docs/connection) and [Observe](https://every-luau.github.io/docs/observe) with it

## Usage

```lua
local Caffeine = require(ReplicatedStorage.Packages.Caffeine)

-- Wake once, right before a projectile lands
Caffeine.wake(workspace.Tower)

-- Keep a slow platform awake until disconnected
local connection = Caffeine(workspace.Platform)

-- Every part of a model, including parts added later, for 5 seconds
Caffeine(workspace.Car, 5)

-- A list of parts
Caffeine({ pin_1, pin_2, pin_3 }, 3)

connection:disconnect()
```

only the side that simulates a part can wake it, and Roblox hands unanchored parts near a player to that player. parts kept on the server are tagged `Caffeine`, so require Caffeine once on the client too and they stay awake whoever owns them

```lua
-- in a LocalScript
require(ReplicatedStorage.Packages.Caffeine)
```

`Caffeine.wake` does not replicate, so call it where the part is simulated

an awake part picks up small movements from floating point errors, so a structure of loose parts kept awake can shift over time. wake structures right before something hits them instead of keeping them awake

## License

MIT

# Elo

Elo rates players from the matches they play against each other

build a config with `Elo.new` and its `set_` methods, then pass it to `Elo.rate` after each match. the winner takes points from the loser, more of them when the loser was rated higher. `Elo.percentile` and `Elo.rating_at_percentile` turn a rating into a rank and back

**[Documentation](https://every-luau.github.io/docs/elo)**

## Installation

```toml
[dependencies]
Elo = { name = "every/elo", version = "^0.0.1" }
```

```sh
embr install
```

## Usage

```lua
local Elo = require(ReplicatedStorage.Packages.Elo)

local config = Elo.new():set_k(24):set_initial(1000)

-- results are from the first player
local alice, bob = Elo.rate(config, 1000, 1200, Elo.WIN)
print(alice, bob) --> 1018.2, 1181.8

-- a series of games, from the same ratings
alice, bob = Elo.rate(config, alice, bob, { Elo.WIN, Elo.DRAW, Elo.LOSS })

-- what a win would bring, before the match
local reward = Elo.delta(config, alice, bob, Elo.WIN)

-- the share of players below, and the rating of the top 10%
print(Elo.percentile(config, alice), Elo.rating_at_percentile(config, 0.9))
```

## Credits

follows the elo package of [Nevermore](https://github.com/Quenty/NevermoreEngine) by Quenty

## License

MIT

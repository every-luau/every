# Kernel

Kernel adds roles, commands and a log on top of the Konsole command console

give roles to players by user id, group rank, game pass or your own check, then make commands that need one of them. [Konsole](https://github.com/KYRORBLX/Konsole) parses the arguments, checks the rank and shows the console, and Kernel resolves the roles, limits how fast a player sends commands and logs every command run on the server

**[Documentation](https://every-luau.github.io/docs/kernel)**

## Installation

```toml
[dependencies]
Kernel = { name = "every/kernel", version = "^0.0.1" }
```

```sh
embr install
```

installs Konsole, [Ratelimit](https://every-luau.github.io/docs/ratelimit) and [Signal](https://every-luau.github.io/docs/signal) with it

## Usage

```lua
local Kernel = require(ReplicatedStorage.Packages.Kernel)

Kernel.role("moderator", 50, { groups = { [1234] = 200 } })
Kernel.role("vip", 5, { passes = { 5678 } })

Kernel.command({
	name = "coins",
	description = "Gives coins to a player",
	rank = "moderator",
	args = {
		{ name = "target", type = "player" },
		{ name = "amount", type = "number" },
	},
	run = function(context, target, amount)
		give_coins(target, amount)
		return `gave {amount} coins to {target.Name}`
	end,
})

Kernel.executed:connect(function(entry)
	print(entry.player, entry.text, entry.ok)
end)

Kernel.start()
```

on clients, requiring Kernel or Konsole is enough to get the console

## License

MIT

# Schema

Schema describes the shape of a value once, to check it, repair it, and turn it into bytes with Lync

`check` tells whether a value fits and where it does not, `reconcile` repairs saved data with defaults, and `codec` is the [Lync](https://github.com/Axp3cter/Lync) codec of the same shape, for packets, queries and sets. `encode` and `decode` turn a value into bytes and back on their own

the type of the values follows from the schema, down to the names of an enum and the variants of a tagged union, so it is never written twice

**[Documentation](https://every-luau.github.io/docs/schema)**

## Installation

```toml
[dependencies]
Schema = { name = "every/schema", version = "^0.0.1" }
```

```sh
embr install
```

installs Lync with it

## Usage

```lua
local Schema = require(ReplicatedStorage.Packages.Schema)

local Profile = Schema.struct({
	name = Schema.string(1, 20):default("guest"),
	coins = Schema.int(0),
	music = Schema.boolean():default(true),
	pet = Schema.optional(Schema.enum<<"cat" | "dog">>({ "cat", "dog" })),
})

type Profile = Schema.Infer<typeof(Profile)>
--> { name: string, coins: number, music: boolean, pet: ("cat" | "dog")? }

print(Profile:check({ name = "", coins = 5, music = true }))
--> false name: expected a string of 1 to 20 bytes, got ""

local data = Profile:reconcile(saved_data) -- a Profile

local Action = Schema.tagged({
	kind = {
		buy = Schema.struct({ item = Schema.int(0) }),
		equip = Schema.struct({ slot = Schema.int(1, 8) }),
	},
})

local action = Action:assert(value)
if action.kind == "buy" then
	print(action.item) -- narrowed to the buy variant
end

local Net = Lync.define("game", {
	Profile = Lync.packet(Profile:codec()),
})
```

## License

MIT

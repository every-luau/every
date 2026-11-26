--!strict
-- One schema for saved data, a packet and a check.

local Schema = require("../src")

local Item = Schema.struct({
	id = Schema.int(0),
	amount = Schema.int(1, 99):default(1),
})

local Profile = Schema.struct({
	name = Schema.string(1, 20):default("guest"),
	coins = Schema.int(0),
	inventory = Schema.array(Item, 0, 50),
	settings = Schema.struct({
		music = Schema.boolean():default(true),
		volume = Schema.number(0, 1, 0.01):default(0.5),
	}),
	pet = Schema.optional(Schema.enum<<"cat" | "dog">>({ "cat", "dog" })),
})

-- The type of the data, worked out from the schema.
type Profile = Schema.Infer<typeof(Profile)>

-- One of several shapes, narrowed by its kind.
local Action = Schema.tagged({
	kind = {
		buy = Schema.struct({ item = Schema.int(0), amount = Schema.int(1, 99) }),
		equip = Schema.struct({ slot = Schema.int(1, 8) }),
	},
})

local function run(action: Schema.Infer<typeof(Action)>)
	if action.kind == "buy" then
		print(action.item, action.amount)
	else
		print(action.slot)
	end
end

run(Action:assert({ kind = "equip", slot = 2 }))

-- Data saved under an older shape, repaired with the defaults.
local saved = { coins = -3, inventory = { { id = 4 }, "broken" }, old_field = true }
local data: Profile = Profile:reconcile(saved)
--> { name = "guest", coins = 0, inventory = { { id = 4, amount = 1 } },
--    settings = { music = true, volume = 0.5 } }

-- Where a value does not fit.
local ok, reason = Profile:check({ name = "rex", coins = 5, inventory = {}, settings = {} })
print(ok, reason) --> false settings.music: expected a boolean, got nil

-- The same shape as bytes, through Lync.
local bytes = Profile:encode(data)
print(buffer.len(bytes))
print(Profile:decode(bytes).name) --> guest

-- Or as a Lync packet:
-- Lync.define("game", { Profile = Lync.packet(Profile:codec()) })

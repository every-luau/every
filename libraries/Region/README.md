# Region

Region is a shape that reports what enters and leaves it, every frame, without physics queries

create one with `new` and shape it with the `set_` methods. every frame it checks which parts of the workspace touch it with [Bolt](https://unityjaeger.github.io/Bolt/) and fires `entered` and `left`, and a rule can turn parts into what to report, like the player a limb belongs to

**[Documentation](https://every-luau.github.io/docs/region)**

## Installation

```toml
[dependencies]
Region = { name = "every/region", version = "^0.0.1" }
```

```sh
embr install
```

installs [Bolt](https://unityjaeger.github.io/Bolt/), [Connection](https://every-luau.github.io/docs/connection), [Loop](https://every-luau.github.io/docs/loop), [Observe](https://every-luau.github.io/docs/observe), [Signal](https://every-luau.github.io/docs/signal), [Thread](https://every-luau.github.io/docs/thread) and [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Region = require(ReplicatedStorage.Packages.Region)

-- takes the position and shape of a part, a block, a ball, a cylinder or a wedge
local shop = Region.new()
	:set_part(workspace.Shop)
	:set_rule(function(part)
		return Players:GetPlayerFromCharacter(part.Parent)
	end)

shop:observe(function(player, void)
	void:add(open_shop(player))
end)

-- a hitbox that follows a sword, checked only when swinging
local hitbox = Region.new()
	:set_size(Vector3.new(1, 1, 4))
	:follow(sword.Handle, CFrame.new(0, 0, -2))
	:set_root(workspace.Characters)
	:disable()

hitbox:step()

-- any Bolt shape works, without installing Bolt yourself, and step checks right away
local blast = Region.new()
	:set_position(explosion.Position)
	:set_shape(Region.Bolt.create_sphere(12))
	:step()

print(blast:get_results())
blast:destroy()
```

## License

MIT

# Brio

Brio holds a value while it is alive, and cleans what was made for it once it dies

`brio:get_value()` reads the value, and `brio:to_void()` gives a [Void](https://every-luau.github.io/docs/void) cleaned when the brio dies. the Void is only made the first time it is asked for, so a brio nobody adds anything to costs almost nothing. [Observable](https://every-luau.github.io/docs/observable) and [Observe](https://every-luau.github.io/docs/observe) hand out brios

**[Documentation](https://every-luau.github.io/docs/brio)**

## Installation

```toml
[dependencies]
Brio = { name = "every/brio", version = "^0.0.1" }
```

```sh
embr install
```

installs [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Brio = require(ReplicatedStorage.Packages.Brio)

local brio = Brio.new(player)

-- made now, since it is the first time it is asked for
local void, value = brio:to_void_and_value()
void:add(function()
	print(`{value.Name} is gone`)
end)

-- after a yield, check that the brio is still alive
task.wait(1)
if not brio:is_dead() then
	print(brio:get_value().Name)
end

-- cleans the void and drops the value
brio:destroy()
```

## License

MIT

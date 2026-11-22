# BetterScale

BetterScale scales a UIScale with the size of its gui, configured with attributes

give it a UIScale and it sets its `Scale` so a design made for one resolution fits the gui it is in, updating when the gui is resized or the attributes change

**[Documentation](https://every-luau.github.io/docs/betterscale)**

## Installation

```toml
[dependencies]
BetterScale = { name = "every/betterscale", version = "^0.0.1" }
```

```sh
embr install
```

installs [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local BetterScale = require(ReplicatedStorage.Packages.BetterScale)

local ui_scale = gui.UIScale
ui_scale:SetAttribute("Resolution", Vector2.new(1920, 1080))
ui_scale:SetAttribute("Range", NumberRange.new(0.5, 2))

-- Bigger on phones
ui_scale:SetAttribute("DisplayRatios", '{"Small": 1.25}')

local scale = BetterScale.build(ui_scale)
```

## License

MIT

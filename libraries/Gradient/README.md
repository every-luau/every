# Gradient

Gradient animates UIGradients, with ready presets for text, frames and strokes

a gradient paints every target you add to it: the UIGradient of a GuiObject, of a UIStroke, or a UIGradient itself. its colors and transparency slide, and its angle turns or sways. `Gradient.preset` builds a ready one, like `Rainbow`, `Gold` or `Electric`, and most presets paint strokes with their own colors too

**[Documentation](https://every-luau.github.io/docs/gradient)**

## Installation

```toml
[dependencies]
Gradient = { name = "every/gradient", version = "^0.0.1" }
```

```sh
embr install
```

## Usage

```lua
local Gradient = require(ReplicatedStorage.Packages.Gradient)

-- one gradient for every title, worked out once a frame for all of them
local rainbow = Gradient.preset("Rainbow")
rainbow:add(title)
rainbow:add(subtitle)

-- the text in gold, and a 3 pixel outline with the stroke colors
Gradient.preset("Gold"):add(label, 3)

-- an outline whose colors turn around it
Gradient.preset("RainbowOutline"):add(button, 2)

-- your own colors
local fade = Gradient.new(ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1)))
	:set_speed(0.25)
	:set_rotation(45)
fade:add(frame)

-- removes what it made, and puts back the gradients that were there
fade:destroy()
```

## Credits

the presets come from [ezVisualz](https://github.com/arxkdev/ezVisualz) by Arxk and RhodesDigital, under the MIT license

## License

MIT

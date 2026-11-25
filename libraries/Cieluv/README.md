# Cieluv

Cieluv converts Color3 to and from CIELUV, and blends colors through it

CIELUV is a color space where equal steps look equally different to the eye, so a blend through it keeps the brightness even and skips the muddy gray `Color3:Lerp` goes through between opposite colors

**[Documentation](https://every-luau.github.io/docs/cieluv)**

## Installation

```toml
[dependencies]
Cieluv = { name = "every/cieluv", version = "^0.0.1" }
```

```sh
embr install
```

## Usage

```lua
local Cieluv = require(ReplicatedStorage.Packages.Cieluv)

-- Color3 to CIELUV and back
local l, u, v = Cieluv.from_color3(Color3.new(1, 0, 0)) --> 53.24 175.01 37.76
local red = Cieluv.to_color3(l, u, v)

-- Blend once
local purple = Cieluv.lerp(Color3.new(1, 0, 0), Color3.new(0, 0, 1), 0.5)

-- Blend the same two colors every frame, converting them once
local blend = Cieluv.lerper(Color3.new(1, 0, 0), Color3.new(0, 0, 1))
RunService.Heartbeat:Connect(function()
	part.Color = blend(math.sin(os.clock()) / 2 + 0.5)
end)
```

## License

MIT

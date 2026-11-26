# AlphaTween

AlphaTween plays a tween that hands an eased alpha to a callback, to animate anything

it plays like a Roblox `Tween`, from a `TweenInfo` with its easing, repeats, reverses and delay, and pauses, resumes and cancels the same way, but calls back with an alpha from 0 to 1 so it moves models, the camera or any value

**[Documentation](https://every-luau.github.io/alpha-tween)**

## Installation

```toml
[dependencies]
AlphaTween = { name = "every/alpha-tween", version = "^0.0.1" }
```

```sh
embr install
```

installs [Loop](https://every-luau.github.io/loop), [Signal](https://every-luau.github.io/signal) and [Void](https://every-luau.github.io/void) with it

## Usage

```lua
local AlphaTween = require(ReplicatedStorage.Packages.AlphaTween)

local start = model:GetPivot()
local goal = start * CFrame.new(0, 10, 0)

local tween = AlphaTween.new(TweenInfo.new(1, Enum.EasingStyle.Back), function(alpha)
	model:PivotTo(start:Lerp(goal, alpha))
end)

tween:play()
tween:pause()
tween:play()
tween:cancel()
```

```lua
-- from one value to another, with their Lerp
AlphaTween.value(camera.FieldOfView, 85, TweenInfo.new(0.3), function(fov)
	camera.FieldOfView = fov
end):play()
```

## License

MIT

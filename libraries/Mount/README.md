# Mount

Mount builds instances out of props, where any property can be a stream

calling the module applies props to an instance, and `Mount.create` makes a new one. a property given a [Stream](https://every-luau.github.io/docs/stream) or a ValueBase follows it, events take functions, and children can be instances, streams or `Mount.create`. disconnecting the returned [Connection](https://every-luau.github.io/docs/connection) undoes everything

**[Documentation](https://every-luau.github.io/docs/mount)**

## Installation

```toml
[dependencies]
Mount = { name = "every/mount", version = "^0.0.1" }
Stream = { name = "every/stream", version = "^0.0.1" }
```

```sh
embr install
```

installs [Connection](https://every-luau.github.io/docs/connection), [Stream](https://every-luau.github.io/docs/stream) and [Void](https://every-luau.github.io/docs/void) with it. add `Stream` to your own dependencies to make states and other streams for the props

## Usage

```lua
local Mount = require(ReplicatedStorage.Packages.Mount)
local Stream = require(ReplicatedStorage.Packages.Stream)

-- a button that counts its clicks and turns blue while hovered
local count = Stream.state(0)
local hovered = Stream.state(false)

local connection = Mount(Instance.new("TextButton"), {
	Size = UDim2.fromOffset(200, 50),
	Text = count:map(function(count)
		return `clicked {count} times`
	end),
	BackgroundColor3 = hovered:map(function(is_hovered)
		return if is_hovered then Color3.fromRGB(80, 140, 255) else Color3.fromRGB(60, 60, 60)
	end),
	MouseEnter = function()
		hovered:set(true)
	end,
	MouseLeave = function()
		hovered:set(false)
	end,
	Activated = function()
		count:update(function(n)
			return n + 1
		end)
	end,

	-- children are created with the button and destroyed with it
	Mount.create("UICorner", { CornerRadius = UDim.new(0, 8) }),

	Parent = screen_gui,
})

-- undoes the props and destroys the children
connection:disconnect()
```

## License

MIT

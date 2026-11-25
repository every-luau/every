# Observable

Observable follows a set of things that come and go, and hands out a Brio for each while it is there

an observable announces when an item joins and when it leaves, like the players in the game or the parts with a tag. subscribing gives a [Brio](https://every-luau.github.io/docs/brio) for every item: `brio:get_value()` reads it, and `brio:to_void()` gives a Void cleaned once the item leaves. `Observable.from_stream` turns a [Stream](https://every-luau.github.io/docs/stream) into an observable whose only item is its latest value. chain `filter`, `map` and `flat_map` before subscribing, which returns a [Connection](https://every-luau.github.io/docs/connection)

**[Documentation](https://every-luau.github.io/docs/observable)**

## Installation

```toml
[dependencies]
Observable = { name = "every/observable", version = "^0.0.1" }
```

```sh
embr install
```

installs [Brio](https://every-luau.github.io/docs/brio), [Connection](https://every-luau.github.io/docs/connection), [Stream](https://every-luau.github.io/docs/stream), [Thread](https://every-luau.github.io/docs/thread) and [Void](https://every-luau.github.io/docs/void) with it

## Usage

```lua
local Observable = require(ReplicatedStorage.Packages.Observable)

-- the children of a folder, now and later
local doors = Observable.new(function(emit, void)
	void:add(folder.ChildAdded:Connect(function(child)
		emit(child, true)
	end))
	void:add(folder.ChildRemoved:Connect(function(child)
		emit(child, false)
	end))
	for _, child in folder:GetChildren() do
		emit(child, true)
	end
end)

-- a brio per door, killed when it is removed
local connection = doors:subscribe(function(brio)
	local void, door = brio:to_void_and_value()
	void:add(door.Touched:Connect(open))
end)

-- how many there are
doors:count():listen(print)

connection:disconnect()
```

[Observe](https://every-luau.github.io/docs/observe) has observables ready for players, characters, children, tags and more

## License

MIT

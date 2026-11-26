--[=[
	@class Stream

	Stream follows values over time and builds reactive code out of them

	a stream emits values to whatever listens to it. chain methods like
	[Stream:map], [Stream:filter] or [Stream:switch] to make new streams, then
	[Stream:listen] or [Stream:each] to use the values. nothing runs until
	something listens, and each listener runs the stream again from the start

	```lua
	local Stream = require(path.to.Stream)

	local health = Stream.character(player):child("Humanoid"):property("Health")
	local connection = health:listen(print)
	connection:disconnect()
	```

	to hold a value you set, use [Atom], which is a stream too. to follow a
	set of things that come and go, like the players in the game or the parts
	with a tag, use [Observable]. to build instances whose properties are
	streams, use [Mount]

	:::info
	methods that change the type of the values, like [Stream:map], return an
	untyped stream since Luau can't type them yet. annotate the result to get
	the types back: `local name: Stream<string> = stream:map(get_name)`
	:::

	Credits: [Serokai](https://github.com/serokai)
]=]

const core = require("@self/core")
require("@self/operators")
const sources = require("@self/sources")
const instances = require("@self/instances")
const stream_types = require("@self/types")

export type Connection = stream_types.Connection
export type Void = stream_types.Void
export type SignalLike = stream_types.SignalLike
export type Stream<T> = stream_types.Stream<T>

table.freeze(core.methods)

return table.freeze({
	new = core.new,
	is = core.is,
	of = sources.of,
	never = sources.never,
	from = sources.from,
	signal = sources.signal,
	property = sources.property,
	attribute = sources.attribute,
	merge = sources.merge,
	race = sources.race,
	combine = sources.combine,
	combine_table = sources.combine_table,
	character = instances.character,
	child = instances.child,
	descendant = instances.descendant,
})

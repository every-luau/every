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

	a [LifeStream] follows a set of things that come and go, like the players in
	the game or the parts with a tag, and [LifeStream:each] runs something for
	each while it is there

	```lua
	Stream.tagged("Lava"):each(function(part, void)
		void:add(part.Touched:Connect(kill))
	end)
	```

	to build instances whose properties are streams, use [Mount]

	:::info
	methods that change the type of the values, like [Stream:map], return an
	untyped stream since Luau can't type them yet. annotate the result to get
	the types back: `local name: Stream<string> = stream:map(get_name)`
	:::
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
export type LifeStream<T> = stream_types.LifeStream<T>
export type State<T> = stream_types.State<T>
export type Subject<T> = stream_types.Subject<T>

table.freeze(core.methods)
table.freeze(core.life_methods)

return table.freeze({
	new = core.new,
	life = core.new_life,
	is = core.is,
	is_life = core.is_life,

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
	state = sources.state,
	subject = sources.subject,

	character = instances.character,
	child = instances.child,
	descendant = instances.descendant,
	players = instances.players,
	characters = instances.characters,
	children = instances.children,
	descendants = instances.descendants,
	tagged = instances.tagged,
})

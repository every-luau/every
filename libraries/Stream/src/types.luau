-- The public types. A method that changes the type of the values returns `any`,
-- since Luau can't refer to `Stream<U>` inside the definition of `Stream<T>`:
-- annotate the result to get the types back, like
-- `local names: Stream<string> = players:map(get_name)`.

const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

export type Connection = Connection.Connection
export type Void = Void.Void

--[=[
	@within Stream
	@type SignalLike RBXScriptSignal | { Connect: (self, (...any) -> ()) -> any } | { connect: (self, (...any) -> ()) -> any }

	what [Stream.signal] can follow: an RBXScriptSignal, a [Signal], or a table
	whose `Connect` or `connect` method returns something with a `Disconnect`,
	`disconnect`, `Destroy` or `destroy` method
]=]
export type SignalLike = RBXScriptSignal | { Connect: (any, (...any) -> ()) -> any } | { connect: (any, (...any) -> ()) -> any }

export type Stream<T> = {
	listen: (self: Stream<T>, listener: (value: T) -> ()) -> Connection,
	each: (self: Stream<T>, callback: (value: T, void: Void) -> (), predicate: ((value: T) -> boolean)?) -> Connection,
	wait: (self: Stream<T>) -> T,
	use: (self: Stream<T>, operator: (stream: Stream<T>) -> any) -> any,
	destroy: (self: Stream<T>) -> (),

	map: (self: Stream<T>, transform: (value: T) -> any) -> any,
	filter: (self: Stream<T>, predicate: (value: T) -> boolean) -> Stream<T>,
	tap: (self: Stream<T>, callback: (value: T) -> ()) -> Stream<T>,
	changed: (self: Stream<T>, equals: ((last: T, new: T) -> boolean)?) -> Stream<T>,
	switch: (self: Stream<T>, project: (value: T) -> any) -> any,
	default: (self: Stream<T>, fallback: T) -> Stream<T>,
	skip_nil: (self: Stream<T>) -> Stream<T>,
	take: (self: Stream<T>, count: number) -> Stream<T>,
	skip: (self: Stream<T>, count: number) -> Stream<T>,
	take_while: (self: Stream<T>, predicate: (value: T) -> boolean) -> Stream<T>,
	skip_while: (self: Stream<T>, predicate: (value: T) -> boolean) -> Stream<T>,
	scan: (self: Stream<T>, reducer: (accumulator: any, value: T) -> any, seed: any) -> any,
	start_with: (self: Stream<T>, first: T) -> Stream<T>,
	end_with: (self: Stream<T>, last: T) -> Stream<T>,
	with: (self: Stream<T>, other: any, combine: (value: T, other: any) -> any) -> any,
	after: (self: Stream<T>, seconds: number) -> Stream<T>,
	debounce: (self: Stream<T>, seconds: number) -> Stream<T>,
	throttle: (self: Stream<T>, seconds: number) -> Stream<T>,
	buffer: (self: Stream<T>, count: number) -> any,
	buffer_time: (self: Stream<T>, seconds: number) -> any,
	catch: (self: Stream<T>, label: string) -> Stream<T>,

	property: (self: Stream<T>, name: string) -> any,
	attribute: (self: Stream<T>, name: string) -> any,
	child: (self: Stream<T>, name: string, class_name: string?) -> any,
	descendant: (self: Stream<T>, name: string, class_name: string?) -> any,
}

return nil

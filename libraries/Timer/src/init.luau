--[=[
	@class Timer

	Timer is a stopwatch or countdown with a speed, updated every frame

	create one with [Timer.new], set its time and speed, then start it. its time
	moves by the frame's delta time times its speed, so a speed of -1 counts down,
	and [Timer.updated] fires on every frame it moves

	```lua
	local Timer = require(path.to.Timer)

	local countdown = Timer.new():set_time(60):set_speed(-1):start()

	countdown:observe(function(time)
		label.Text = Timer.format_seconds(math.max(time, 0))
	end)
	```

	:::info
	a timer only listens to Heartbeat with [Loop] while it plays. it doesn't stop
	on its own at 0, so check the time in [Timer:observe] to end a countdown
	:::
]=]

const Loop = require(script.Parent.Loop)
const Signal = require(script.Parent.Signal)
const Void = require(script.Parent.Void)

export type Connection = Signal.Connection
export type Signal<T...> = Signal.Signal<T...>

export type Timer = setmetatable<{
	_time: number,
	_speed: number,
	_loop: Connection | false,
	_void: Void.Void,
	updated: Signal<number, number>,
	start: (self: Timer) -> Timer,
	stop: (self: Timer) -> Timer,
	reset: (self: Timer) -> Timer,
	is_playing: (self: Timer) -> boolean,
	get_time: (self: Timer) -> number,
	set_time: (self: Timer, time: number) -> Timer,
	get_speed: (self: Timer) -> number,
	set_speed: (self: Timer, speed: number) -> Timer,
	format: (self: Timer, milliseconds: boolean?) -> string,
	observe: (self: Timer, callback: (time: number, elapsed: number) -> ()) -> Connection,
	destroy: (self: Timer) -> (),
}, { __index: Timer }>

const Timer = {}
Timer.__index = Timer

--[=[
	@within Timer
	@prop updated Signal<number, number>
	@readonly

	fires with the time and the seconds that passed every frame the timer moves
]=]

--[=[
	@within Timer
	@function new
	@return Timer

	creates a stopped Timer at 0 with a speed of 1
]=]
function Timer.new(): Timer
	const void = Void.new()

	return setmetatable(
		{
			_time = 0,
			_speed = 1,
			_loop = false,
			_void = void,
			updated = void:add(Signal.new()),
		},
		Timer
	) :: any
end

--[=[
	@within Timer
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Timer
]=]
function Timer.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Timer
end

--[=[
	@within Timer
	@function format_seconds
	@param seconds number
	@param milliseconds boolean?
	@return string

	formats `seconds` as `ss`, `mm:ss` or `hh:mm:ss`, with `.mmm` milliseconds
	after it when `milliseconds` is true. negative durations start with `-`

	```lua
	print(Timer.format_seconds(65)) --> 01:05
	print(Timer.format_seconds(65.5, true)) --> 01:05.500
	```
]=]
function Timer.format_seconds(seconds: number, milliseconds: boolean?): string
	const sign = if seconds < 0 then "-" else ""
	local rest = math.abs(seconds)

	const hours = math.floor(rest / 3600)
	rest -= hours * 3600
	const minutes = math.floor(rest / 60)
	rest -= minutes * 60
	const whole = math.floor(rest)

	local text = if hours > 0
		then string.format("%02d:%02d:%02d", hours, minutes, whole)
		elseif minutes > 0 then string.format("%02d:%02d", minutes, whole)
		else string.format("%02d", whole)

	if milliseconds then
		text ..= string.format(".%03d", math.floor((rest - whole) * 1000 + 0.5))
	end

	return sign .. text
end

--[=[
	@within Timer
	@method start
	@return Timer

	starts or resumes the timer. does nothing if it is already playing
]=]
function Timer.start(self: Timer): Timer
	if self._loop then
		return self
	end

	const loop = Loop(0, function(elapsed: number)
		self._time += elapsed * self._speed
		self.updated:fire(self._time, elapsed)
	end)
	self._loop = self._void:add(loop)

	return self
end

--[=[
	@within Timer
	@method stop
	@return Timer

	pauses the timer, keeping its time
]=]
function Timer.stop(self: Timer): Timer
	const loop = self._loop
	if loop then
		self._loop = false
		self._void:clean_item(loop :: any)
	end

	return self
end

--[=[
	@within Timer
	@method reset
	@return Timer

	stops the timer and sets its time back to 0
]=]
function Timer.reset(self: Timer): Timer
	self:stop()
	self._time = 0
	return self
end

--[=[
	@within Timer
	@method is_playing
	@return boolean

	returns whether the timer is started
]=]
function Timer.is_playing(self: Timer): boolean
	return self._loop ~= false
end

--[=[
	@within Timer
	@method get_time
	@return number

	returns the time in seconds
]=]
function Timer.get_time(self: Timer): number
	return self._time
end

--[=[
	@within Timer
	@method set_time
	@param time number
	@return Timer

	sets the time in seconds
]=]
function Timer.set_time(self: Timer, time: number): Timer
	self._time = time
	return self
end

--[=[
	@within Timer
	@method get_speed
	@return number

	returns the speed, see [Timer:set_speed]
]=]
function Timer.get_speed(self: Timer): number
	return self._speed
end

--[=[
	@within Timer
	@method set_speed
	@param speed number
	@return Timer

	sets how many seconds the time moves per second. 1 is real time, 2 is twice
	as fast, and a negative speed counts down
]=]
function Timer.set_speed(self: Timer, speed: number): Timer
	self._speed = speed
	return self
end

--[=[
	@within Timer
	@method format
	@param milliseconds boolean?
	@return string

	formats the time with [Timer.format_seconds]
]=]
function Timer.format(self: Timer, milliseconds: boolean?): string
	return Timer.format_seconds(self._time, milliseconds)
end

--[=[
	@within Timer
	@method observe
	@param callback (time: number, elapsed: number) -> ()
	@return Connection

	calls `callback` right away with the time and 0, then on every update like
	[Timer.updated]
]=]
function Timer.observe(self: Timer, callback: (time: number, elapsed: number) -> ()): Connection
	callback(self._time, 0)
	return self.updated:connect(callback)
end

--[=[
	@within Timer
	@method destroy

	stops the timer and disconnects everything connected to [Timer.updated]
]=]
function Timer.destroy(self: Timer)
	self._loop = false
	self._void:clean()
end

return table.freeze({
	new = Timer.new,
	is = Timer.is,
	format_seconds = Timer.format_seconds,
})

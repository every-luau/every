--[=[
	@class AlphaTween

	AlphaTween plays a tween that hands an eased alpha to a callback, to animate anything

	it plays like a Roblox `Tween`, from a `TweenInfo` with its easing, repeats,
	reverses and delay, but calls back with an alpha from 0 to 1 instead of
	setting properties, so it moves models, the camera, a number or a color
	alike. [AlphaTween.value] goes from one value to another with their `Lerp`

	```lua
	local AlphaTween = require(path.to.AlphaTween)

	local start = model:GetPivot()
	local goal = start * CFrame.new(0, 10, 0)

	AlphaTween.new(TweenInfo.new(1, Enum.EasingStyle.Back), function(alpha)
		model:PivotTo(start:Lerp(goal, alpha))
	end):play()
	```
]=]

const TweenService = game:GetService("TweenService")

const Loop = require(script.Parent.Loop)
const Signal = require(script.Parent.Signal)
const Void = require(script.Parent.Void)

export type Connection = Signal.Connection
export type Signal<T...> = Signal.Signal<T...>

export type AlphaTween = setmetatable<{
	_info: TweenInfo,
	_callback: (alpha: number) -> (),
	_elapsed: number,
	_alpha: number,
	_state: Enum.PlaybackState,
	_loop: Connection | false,
	_void: Void.Void,
	completed: Signal<Enum.PlaybackState>,
	play: (self: AlphaTween) -> AlphaTween,
	pause: (self: AlphaTween) -> AlphaTween,
	cancel: (self: AlphaTween) -> AlphaTween,
	get_alpha: (self: AlphaTween) -> number,
	get_state: (self: AlphaTween) -> Enum.PlaybackState,
	is_playing: (self: AlphaTween) -> boolean,
	get_info: (self: AlphaTween) -> TweenInfo,
	destroy: (self: AlphaTween) -> (),
}, { __index: AlphaTween }>

const AlphaTween = {}
AlphaTween.__index = AlphaTween

-- where a tween is after `elapsed` seconds: the alpha before easing, or nil
-- while it waits out its delay, and whether it is done. every repeat waits
-- the delay, then goes forward, then back when it reverses
const function progress(info: TweenInfo, elapsed: number): (number?, boolean)
	const duration = math.max(info.Time, 0)
	const delay = math.max(info.DelayTime, 0)
	const reverses = info.Reverses
	const finish = if reverses then 0 else 1
	const cycle = delay + duration * (if reverses then 2 else 1)
	const cycles = if info.RepeatCount < 0 then math.huge else info.RepeatCount + 1

	if cycle <= 0 then
		return finish, true
	end

	const index = math.floor(elapsed / cycle)
	if index >= cycles then
		return finish, true
	end

	const within = elapsed - index * cycle - delay
	if within < 0 then
		return nil, false
	elseif duration <= 0 then
		return finish, false
	elseif within < duration then
		return within / duration, false
	end
	return math.max(1 - (within - duration) / duration, 0), false
end

const function stop_loop(self: AlphaTween)
	const loop = self._loop
	if loop then
		self._loop = false
		self._void:clean_item(loop :: any)
	end
end

const function set_alpha(self: AlphaTween, raw: number)
	const alpha = TweenService:GetValue(raw, self._info.EasingStyle, self._info.EasingDirection)
	self._alpha = alpha
	self._callback(alpha)
end

-- moves the tween to its elapsed time, calling back and completing it
const function step(self: AlphaTween)
	const raw, done = progress(self._info, self._elapsed)

	if raw == nil then
		self._state = Enum.PlaybackState.Delayed
		return
	end

	self._state = Enum.PlaybackState.Playing
	set_alpha(self, raw)

	if done then
		stop_loop(self)
		self._elapsed = 0
		self._state = Enum.PlaybackState.Completed
		self.completed:fire(Enum.PlaybackState.Completed)
	end
end

--[=[
	@within AlphaTween
	@prop completed Signal<Enum.PlaybackState>
	@readonly

	fires with `Completed` when the tween finishes, or `Cancelled` when it is
	cancelled, like `Tween.Completed`. pausing does not fire it

	```lua
	tween:play()
	tween.completed:wait()
	```
]=]

--[=[
	@within AlphaTween
	@function new
	@param info TweenInfo?
	@param callback (alpha: number) -> ()
	@return AlphaTween

	makes a tween that is not playing yet. once played, it calls `callback`
	every frame with the alpha eased by the style and direction of `info`, which
	is `TweenInfo.new()` when not given

	```lua
	local fade = AlphaTween.new(TweenInfo.new(0.5), function(alpha)
		frame.BackgroundTransparency = alpha
	end)
	```
]=]
function AlphaTween.new(info: TweenInfo?, callback: (alpha: number) -> ()): AlphaTween
	if type(callback) ~= "function" then
		error("AlphaTween.new needs a callback", 2)
	end

	const void = Void.new()

	return setmetatable(
		{
			_info = info or TweenInfo.new(),
			_callback = callback,
			_elapsed = 0,
			_alpha = 0,
			_state = Enum.PlaybackState.Begin,
			_loop = false,
			_void = void,
			completed = void:add(Signal.new()),
		},
		AlphaTween
	) :: any
end

--[=[
	@within AlphaTween
	@function lerp
	@param from T
	@param to T
	@param alpha number
	@return T
	@error "AlphaTween cannot lerp ..." -- `from` is not a number and has no `Lerp`

	returns the value `alpha` of the way from `from` to `to`. numbers and `UDim`
	are lerped here, and anything else with its own `Lerp`, like `Vector3`,
	`CFrame`, `Color3` and `UDim2`

	```lua
	print(AlphaTween.lerp(0, 10, 0.25)) --> 2.5
	```
]=]
function AlphaTween.lerp<T>(from: T, to: T, alpha: number): T
	const kind = typeof(from)

	if kind == "number" then
		const start, goal = from :: any, to :: any
		return (start + (goal - start) * alpha) :: any
	elseif kind == "UDim" then
		const start, goal = from :: any, to :: any
		return UDim.new(
			start.Scale + (goal.Scale - start.Scale) * alpha,
			start.Offset + (goal.Offset - start.Offset) * alpha
		) :: any
	end

	const lerp = if type(from) == "table" or type(from) == "userdata" then (from :: any).Lerp else nil
	if lerp == nil then
		error(`AlphaTween cannot lerp a {kind}`, 2)
	end
	return (lerp :: any)(from, to, alpha)
end

--[=[
	@within AlphaTween
	@function value
	@param from T
	@param to T
	@param info TweenInfo?
	@param callback (value: T) -> ()
	@return AlphaTween
	@error "AlphaTween cannot lerp ..." -- `from` is not a number and has no `Lerp`

	makes a tween that calls `callback` with the value between `from` and `to`
	at its alpha, lerped with [AlphaTween.lerp]

	```lua
	local camera = workspace.CurrentCamera

	AlphaTween.value(camera.FieldOfView, 50, TweenInfo.new(0.3), function(fov)
		camera.FieldOfView = fov
	end):play()
	```
]=]
function AlphaTween.value<T>(from: T, to: T, info: TweenInfo?, callback: (value: T) -> ()): AlphaTween
	-- checked now, so a value that cannot be lerped errors here rather than every frame
	AlphaTween.lerp(from, to, 0)

	return AlphaTween.new(info, function(alpha)
		callback(AlphaTween.lerp(from, to, alpha))
	end)
end

--[=[
	@within AlphaTween
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is an AlphaTween
]=]
function AlphaTween.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == AlphaTween
end

--[=[
	@within AlphaTween
	@method play
	@return AlphaTween

	starts the tween, resumes it once paused, or plays it again from the start
	once it completed or was cancelled. does nothing while it plays
]=]
function AlphaTween.play(self: AlphaTween): AlphaTween
	if self._loop then
		return self
	end

	const state = self._state
	if state == Enum.PlaybackState.Completed or state == Enum.PlaybackState.Cancelled then
		self._elapsed = 0
	end

	self._loop = self._void:add(Loop(0, function(elapsed: number)
		self._elapsed += elapsed
		step(self)
	end))
	step(self)

	return self
end

--[=[
	@within AlphaTween
	@method pause
	@return AlphaTween

	stops the tween where it is, so [AlphaTween:play] resumes it from there
]=]
function AlphaTween.pause(self: AlphaTween): AlphaTween
	if self._loop then
		stop_loop(self)
		self._state = Enum.PlaybackState.Paused
	end
	return self
end

--[=[
	@within AlphaTween
	@method cancel
	@return AlphaTween

	stops the tween and sets its progress back to the start, so playing it again
	takes the full time. what the callback set stays as it is, like `Tween:Cancel`.
	fires [AlphaTween.completed] with `Cancelled`. does nothing when it is not
	playing or paused
]=]
function AlphaTween.cancel(self: AlphaTween): AlphaTween
	const state = self._state
	if
		state ~= Enum.PlaybackState.Playing
		and state ~= Enum.PlaybackState.Delayed
		and state ~= Enum.PlaybackState.Paused
	then
		return self
	end

	stop_loop(self)
	self._elapsed = 0
	self._state = Enum.PlaybackState.Cancelled
	self.completed:fire(Enum.PlaybackState.Cancelled)
	return self
end

--[=[
	@within AlphaTween
	@method get_alpha
	@return number

	returns the alpha the callback was last called with, eased, or 0 before
	that. some easing styles, like `Back` and `Elastic`, go past 0 and 1
]=]
function AlphaTween.get_alpha(self: AlphaTween): number
	return self._alpha
end

--[=[
	@within AlphaTween
	@method get_state
	@return Enum.PlaybackState

	returns where the tween is, like `Tween.PlaybackState`: `Begin` before it
	first plays, `Delayed` while it waits out the delay of `TweenInfo`, then
	`Playing`, `Paused`, `Completed` or `Cancelled`
]=]
function AlphaTween.get_state(self: AlphaTween): Enum.PlaybackState
	return self._state
end

--[=[
	@within AlphaTween
	@method is_playing
	@return boolean

	returns whether the tween is playing or waiting out its delay
]=]
function AlphaTween.is_playing(self: AlphaTween): boolean
	return self._loop ~= false
end

--[=[
	@within AlphaTween
	@method get_info
	@return TweenInfo

	returns the `TweenInfo` the tween plays with
]=]
function AlphaTween.get_info(self: AlphaTween): TweenInfo
	return self._info
end

--[=[
	@within AlphaTween
	@method destroy

	stops the tween without firing [AlphaTween.completed] and disconnects
	everything connected to it
]=]
function AlphaTween.destroy(self: AlphaTween)
	self._loop = false
	self._void:clean()
end

return table.freeze({
	new = AlphaTween.new,
	value = AlphaTween.value,
	lerp = AlphaTween.lerp,
	is = AlphaTween.is,
})

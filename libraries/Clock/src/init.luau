--[=[
	@class Clock

	Clock is a time in seconds that moves at a speed, the same on the server and every client

	start a clock, set its speed or count down with a negative one, and call
	back at a time with [Clock:at]. on the server, [Clock:replicate] sends it to
	clients, who get their own copy with [Clock.get] that moves on its own.
	[Clock.synced_time] and [Clock.timestamp] give a time that is the same on
	every server, to save in data

	```lua
	local Clock = require(path.to.Clock)

	-- server
	local round = Clock.new():set_time(120):set_speed(-1):start():replicate("Round")

	-- client
	local round = Clock.get("Round"):await()
	round:observe(function(time)
		print(math.ceil(time))
	end)
	```

	:::info
	a running clock sends nothing. each side works its time out from
	[Clock.synced_time], and only a start, a stop or a change is sent
	:::
]=]

const RunService = game:GetService("RunService")

const Atom = require(script.Parent.Atom)
const Connection = require(script.Parent.Connection)
const Future = require(script.Parent.Future)
const Loop = require(script.Parent.Loop)
const Lync = require(script.Parent.Lync)
const Signal = require(script.Parent.Signal)
const Void = require(script.Parent.Void)

export type Atom<T> = Atom.Atom<T>
export type Connection = Connection.Connection
export type Future<T...> = Future.Future<T...>
export type Signal<T...> = Signal.Signal<T...>

-- one record a replicated clock, split by `key` so each clock has its own
-- audience. a change only sends the fields that moved
const Net = Lync.define("Clock", {
	clocks = Lync.replicate(Lync.struct({
		key = Lync.vlq(),
		name = Lync.str(1, 100),
		time = Lync.f64(),
		at = Lync.f64(),
		speed = Lync.f64(),
		playing = Lync.bool(),
	})):keyBy("key"),
})
const clocks: any = Net.clocks

export type Clock = setmetatable<{
	_name: string?,
	_id: number?,
	_players: { [Player]: true }?,
	_group: Lync.Group?,
	_time: number,
	_at: number,
	_speed: number,
	_playing: boolean,
	_readonly: boolean,
	_atom: Atom<number>?,
	_void: Void.Void,
	changed: Signal<>,
	get_name: (self: Clock) -> string?,
	replicate: (self: Clock, name: string, players: (Player | { Player })?) -> Clock,
	add_players: (self: Clock, players: Player | { Player }) -> Clock,
	remove_players: (self: Clock, players: Player | { Player }) -> Clock,
	is_replicated_to: (self: Clock, player: Player) -> boolean,
	unreplicate: (self: Clock) -> Clock,
	get_time: (self: Clock) -> number,
	set_time: (self: Clock, time: number) -> Clock,
	get_speed: (self: Clock) -> number,
	set_speed: (self: Clock, speed: number) -> Clock,
	is_playing: (self: Clock) -> boolean,
	start: (self: Clock) -> Clock,
	stop: (self: Clock) -> Clock,
	reset: (self: Clock) -> Clock,
	at: (self: Clock, time: number, callback: () -> ()) -> Connection,
	observe: (self: Clock, callback: (time: number) -> ()) -> Connection,
	atom: (self: Clock) -> Atom<number>,
	destroy: (self: Clock) -> (),
}, { __index: Clock }>

const Clock = {}
Clock.__index = Clock

-- on the server, the clocks replicated under each name. a name holds several
-- when each goes to other players
const replicated: { [string]: { Clock } } = {}
-- on a client, the copies the server sent, by name and by record id
const copies: { [string]: Clock } = {}
const copies_by_id: { [number]: Clock } = {}
-- on a client, the futures from `Clock.get` waiting for a clock under each name
const waiting: { [string]: { (Clock) -> () } } = {}

local next_id = 1
local flushing = false

const function now(): number
	return workspace:GetServerTimeNow()
end

const function make(name: string?, readonly: boolean): Clock
	const void = Void.new()

	return setmetatable(
		{
			_name = name,
			_id = nil,
			_players = nil,
			_group = nil,
			_time = 0,
			_at = now(),
			_speed = 1,
			_playing = false,
			_readonly = readonly,
			_atom = nil,
			_void = void,
			changed = void:add(Signal.new()),
		},
		Clock
	) :: any
end

const function state(self: Clock): { [string]: any }
	return { time = self._time, at = self._at, speed = self._speed, playing = self._playing }
end

-- moves the time to now before the speed or the playing state changes, so the
-- time already passed is kept
const function settle(self: Clock)
	if self._readonly then
		error("this clock is read from the server, only the server can change it", 3)
	end

	self._time = self:get_time()
	self._at = now()
end

const function publish(self: Clock)
	const id = self._id
	if id then
		clocks:update(id, state(self))
	end

	self.changed:fire()
end

-- whether `player` gets the clock, where no player means every player
const function sees(self: Clock, player: Player?): boolean
	const players = self._players
	if players == nil then
		return true
	end
	return player ~= nil and players[player] == true
end

const function list_of(players: Player | { Player }): { Player }
	return if typeof(players) == "Instance" then { players :: Player } else players :: { Player }
end

-- the clock already replicated as `name` that one of `players` gets, where no
-- players means every player
const function taken(name: string, players: { [Player]: true }?, except: Clock?): Clock?
	for _, other in replicated[name] or {} do
		if other == except then
			continue
		end
		if players == nil or other._players == nil then
			return other
		end
		for player in players do
			if sees(other, player) then
				return other
			end
		end
	end
	return nil
end

-- on a client, resolves the futures waiting for the copy under its name
const function resolve(copy: Clock, name: string)
	const list = waiting[name]
	if not list then
		return
	end

	waiting[name] = nil
	for _, pass in list do
		pass(copy)
	end
end

const function client_only(said: string, name: string)
	if RunService:IsServer() then
		error(`{said} is for clients, the server keeps the clock it replicated as "{name}"`, 3)
	end
end

-- the server sends the Clock namespace every frame once a clock is replicated,
-- which is also when a player who joined gets the clocks they can see
const function ensure_flushing()
	if flushing then
		return
	end
	flushing = true
	RunService.Heartbeat:Connect(function()
		Lync.flush("Clock")
	end)
end

-- a client follows the records the server sends, as read only copies
const function apply(copy: Clock, record: any)
	copy._time = record.time
	copy._at = record.at
	copy._speed = record.speed
	copy._playing = record.playing
end

clocks:onAdded(function(id: number, record: any)
	if RunService:IsServer() then
		return
	end

	const name = record.name
	const copy = make(name, true)
	copy._id = id
	apply(copy, record)
	copies[name] = copy
	copies_by_id[id] = copy
	resolve(copy, name)
end)

clocks:onChanged(function(id: number, record: any)
	const copy = copies_by_id[id]
	if RunService:IsServer() or not copy then
		return
	end

	apply(copy, record)
	copy.changed:fire()
end)

clocks:onRemoved(function(id: number)
	const copy = copies_by_id[id]
	if RunService:IsServer() or not copy then
		return
	end

	copy:destroy()
end)

--[=[
	@within Clock
	@prop changed Signal<>
	@readonly

	fires when the clock starts, stops, or its time or speed is set. it does not
	fire while the time moves, use [Clock:observe] for that. on a client, the
	copy of a replicated clock fires it when the server changes the clock
]=]

--[=[
	@within Clock
	@function new
	@return Clock

	makes a clock stopped at 0 with a speed of 1. it only exists on the side
	that made it, until the server replicates it with [Clock:replicate]

	```lua
	local stopwatch = Clock.new():start()
	```
]=]
function Clock.new(): Clock
	return make(nil, false)
end

--[=[
	@within Clock
	@function find
	@param name string
	@return Clock?
	@client
	@error "Clock.find is for clients, the server keeps the clock it replicated" -- called on the server

	returns the copy of the clock the server replicated as `name` to this
	client, without yielding, or nil if it is not there yet. errors on the
	server, which keeps the clock it replicated
]=]
function Clock.find(name: string): Clock?
	client_only("Clock.find", name)
	return copies[name]
end

--[=[
	@within Clock
	@function get
	@param name string
	@return Future<Clock>
	@client
	@error "Clock.get is for clients, the server keeps the clock it replicated" -- called on the server

	returns a `Future` of the copy of the clock the server replicated as `name`
	to this client, resolved once it arrives, or right away if it already has.
	use `Future:timeout` to stop waiting after some seconds. errors on the
	server, which keeps the clock it replicated

	```lua
	-- yields until the clock is there
	local round = Clock.get("Round"):await()

	-- or without yielding
	Clock.get("Round"):after(function(round)
		print(round:get_time())
	end)

	-- errors if the server takes more than 10 seconds
	local round = Clock.get("Round"):timeout(10):await()
	```
]=]
function Clock.get(name: string): Future<Clock>
	client_only("Clock.get", name)

	const found = copies[name]
	if found then
		return Future.resolve(found)
	end

	return Future.new(function(pass: (Clock) -> ())
		const list = waiting[name] or {}
		waiting[name] = list
		table.insert(list, pass)
	end)
end

--[=[
	@within Clock
	@function synced_time
	@return number

	returns the synced time, the Unix time in seconds with a fraction. a client
	gets the time of its server rather than of its own device, and servers keep
	their clocks on UTC, so it is the same on the server, every client and every
	other server, within a few milliseconds. every clock moves with it

	```lua
	print(Clock.synced_time()) --> 1795000000.25
	```
]=]
function Clock.synced_time(): number
	return now()
end

--[=[
	@within Clock
	@function timestamp
	@return number

	returns the synced time in whole seconds, to save in data and compare on any
	server later, with [Clock.since] and [Clock.left]

	```lua
	data.last_login = Clock.timestamp()
	```
]=]
function Clock.timestamp(): number
	return math.floor(now())
end

--[=[
	@within Clock
	@function since
	@param timestamp number
	@return number

	returns how many seconds went by since `timestamp`, a time from
	[Clock.timestamp] or [Clock.synced_time], saved on this server or
	another one

	```lua
	if Clock.since(data.last_reward) >= Clock.DAY then
		give_reward(player)
		data.last_reward = Clock.timestamp()
	end
	```
]=]
function Clock.since(timestamp: number): number
	return now() - timestamp
end

--[=[
	@within Clock
	@function left
	@param timestamp number
	@return number

	returns how many seconds are left until `timestamp`, a Unix time, and 0 once it
	is past

	```lua
	data.boost_ends = Clock.timestamp() + 30 * Clock.MINUTE
	print(Clock.left(data.boost_ends)) --> 1800
	```
]=]
function Clock.left(timestamp: number): number
	return math.max(timestamp - now(), 0)
end

const function check_period(length: number, offset: number?, level: number)
	if type(length) ~= "number" or length <= 0 or length ~= length then
		error("Clock needs a period length in seconds above 0", level + 1)
	elseif offset ~= nil and (type(offset) ~= "number" or offset ~= offset) then
		error("Clock needs a period offset in seconds", level + 1)
	end
end

--[=[
	@within Clock
	@function period
	@param length number
	@param offset number?
	@return number
	@error "Clock needs a period length in seconds above 0" -- `length` is not a number above 0

	returns the number of the period of `length` seconds that is going on,
	counted from the Unix epoch. every server and client gets the same number at
	the same moment, so it works for daily resets, shop rotations and seeds that
	match everywhere without sending anything. periods start `offset` seconds
	after a multiple of `length`, so a day that starts at 5:00 UTC is
	`Clock.period(Clock.DAY, 5 * Clock.HOUR)`. the epoch was a Thursday, so a
	week that starts on Monday at 0:00 UTC has an offset of `4 * Clock.DAY`

	```lua
	-- the same shop on every server, changing every hour
	local random = Random.new(Clock.period(Clock.HOUR))
	```
]=]
function Clock.period(length: number, offset: number?): number
	check_period(length, offset, 2)
	return math.floor((now() - (offset or 0)) / length)
end

--[=[
	@within Clock
	@function next
	@param length number
	@param offset number?
	@return number
	@error "Clock needs a period length in seconds above 0" -- `length` is not a number above 0

	returns the Unix time when the next period of [Clock.period] starts

	```lua
	-- seconds until the daily reset
	print(Clock.left(Clock.next(Clock.DAY)))
	```
]=]
function Clock.next(length: number, offset: number?): number
	check_period(length, offset, 2)
	const shift = offset or 0
	return (math.floor((now() - shift) / length) + 1) * length + shift
end

--[=[
	@within Clock
	@function every
	@param length number
	@param callback (period: number) -> ()
	@param offset number?
	@return Connection
	@error "Clock needs a period length in seconds above 0" -- `length` is not a number above 0

	calls `callback` with the number of the new period each time one of
	[Clock.period] starts, until the returned connection is disconnected. it
	runs at the same moment on every server and client

	```lua
	Clock.every(Clock.HOUR, function(period)
		restock_shop(Random.new(period))
	end)
	```
]=]
function Clock.every(length: number, callback: (period: number) -> (), offset: number?): Connection
	check_period(length, offset, 2)
	const shift = offset or 0
	local thread: thread? = nil

	const connection = Connection.new(function()
		if thread then
			task.cancel(thread)
			thread = nil
		end
	end)

	const function schedule(period: number)
		-- the period to wait for is known up front, so a delay that wakes up a
		-- little early still reports the right one
		const start = period * length + shift
		thread = task.delay(math.max(start - now(), 0), function()
			thread = nil
			schedule(period + 1)
			callback(period)
		end)
	end

	schedule(math.floor((now() - shift) / length) + 1)
	return connection
end

--[=[
	@within Clock
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Clock
]=]
function Clock.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Clock
end

--[=[
	@within Clock
	@method get_name
	@return string?

	returns the name the clock is replicated as, or nil
]=]
function Clock.get_name(self: Clock): string?
	return self._name
end

--[=[
	@within Clock
	@method replicate
	@param name string
	@param players (Player | { Player })?
	@return Clock
	@server
	@error "only the server can replicate a clock" -- called on a client
	@error "this clock is already replicated" -- the clock was replicated before
	@error "a clock is already replicated to the same players" -- a player would get two clocks under `name`

	gives the clock a name and sends it through Lync to `players`, or to every
	player, now and later, when no `players` are given. they get their own copy
	with [Clock.get], at the same time, and the copy moves on its own

	```lua
	-- for everyone
	local round = Clock.new():set_time(120):set_speed(-1):start():replicate("Round")

	-- for one player
	local run = Clock.new():start():replicate("Run", player)
	```

	the clock is sent once: its time, the moment that time was set, its speed
	and whether it plays. each side then works the time out by itself, as
	`time + (synced_time - moment) * speed`. after that, only the fields that
	change are sent, by the methods tagged `Replicates`, so a clock that runs for
	an hour sends nothing for an hour. a player who joins later gets the clock as
	it is when they join

	a name can hold several clocks as long as no player gets two of them, like
	one speedrun timer per player. change who gets the clock with
	[Clock:add_players] and [Clock:remove_players]

	:::caution
	Clock defines a Lync namespace named `Clock`, so require it before
	`Lync.start` runs, on the server and on every client. once a clock is
	replicated, the server flushes that namespace every frame by itself
	:::
]=]
function Clock.replicate(self: Clock, name: string, players: (Player | { Player })?): Clock
	if not RunService:IsServer() then
		error(`only the server can replicate a clock, get "{name}" with Clock.get`, 2)
	elseif self._name then
		error(`this clock is already replicated as "{self._name}"`, 2)
	end

	local audience: { [Player]: true }? = nil
	if players ~= nil then
		const set: { [Player]: true } = {}
		for _, player in list_of(players) do
			set[player] = true
		end
		audience = set
	end

	if taken(name, audience) then
		error(`a clock is already replicated as "{name}" to the same players`, 2)
	end

	const id = next_id
	next_id += 1

	if audience then
		const group = Lync.group()
		for player in audience do
			group:add(player)
		end
		self._group = group
		clocks:audience(id, group)
	else
		clocks:audience(id, Lync.all)
	end

	const record = state(self)
	record.key = id
	record.name = name
	clocks:add(id, record)
	ensure_flushing()

	self._name = name
	self._id = id
	self._players = audience
	const list = replicated[name] or {}
	replicated[name] = list
	table.insert(list, self)

	return self
end

--[=[
	@within Clock
	@method add_players
	@param players Player | { Player }
	@return Clock
	@server
	@error "add_players is for a clock replicated to some players" -- the clock goes to every player, or is not replicated
	@error "one of these players already gets a clock" -- a player already gets another clock under the same name

	sends a clock replicated to some players to `players` too. errors when the
	clock goes to every player, or when one of `players` already gets another
	clock under the same name
]=]
function Clock.add_players(self: Clock, players: Player | { Player }): Clock
	const name, audience, group = self._name, self._players, self._group
	if not name or not audience or not group then
		error("add_players is for a clock replicated to some players", 2)
	end

	const added: { [Player]: true } = {}
	for _, player in list_of(players) do
		added[player] = true
	end
	if taken(name, added, self) then
		error(`one of these players already gets a clock replicated as "{name}"`, 2)
	end

	for player in added do
		audience[player] = true
		group:add(player)
	end

	return self
end

--[=[
	@within Clock
	@method remove_players
	@param players Player | { Player }
	@return Clock
	@server
	@error "remove_players is for a clock replicated to some players" -- the clock goes to every player, or is not replicated

	stops sending a clock replicated to some players to `players`, whose copy
	is destroyed
]=]
function Clock.remove_players(self: Clock, players: Player | { Player }): Clock
	const audience, group = self._players, self._group
	if not audience or not group then
		error("remove_players is for a clock replicated to some players", 2)
	end

	for _, player in list_of(players) do
		audience[player] = nil
		group:remove(player)
	end

	return self
end

--[=[
	@within Clock
	@method is_replicated_to
	@param player Player
	@return boolean
	@server

	returns whether `player` gets the clock
]=]
function Clock.is_replicated_to(self: Clock, player: Player): boolean
	return self._id ~= nil and sees(self, player)
end

--[=[
	@within Clock
	@method unreplicate
	@return Clock
	@server

	stops sending the clock, so every copy of it is destroyed and its name is
	free again. the clock keeps going on the server
]=]
function Clock.unreplicate(self: Clock): Clock
	const id, name = self._id, self._name
	if self._readonly or not id or not name then
		return self
	end

	clocks:remove(id)
	const group = self._group
	if group then
		group:destroy()
	end

	const list = replicated[name]
	if list then
		const index = table.find(list, self)
		if index then
			table.remove(list, index)
		end
		if #list == 0 then
			replicated[name] = nil
		end
	end

	self._id = nil
	self._name = nil
	self._players = nil
	self._group = nil
	return self
end

--[=[
	@within Clock
	@method get_time
	@return number

	returns the time in seconds
]=]
function Clock.get_time(self: Clock): number
	if self._playing then
		return self._time + (now() - self._at) * self._speed
	end

	return self._time
end

--[=[
	@within Clock
	@method set_time
	@param time number
	@return Clock
	@tag Replicates
	@error "this clock is read from the server, only the server can change it" -- called on the copy a client got

	sets the time in seconds
]=]
function Clock.set_time(self: Clock, time: number): Clock
	settle(self)
	self._time = time
	publish(self)
	return self
end

--[=[
	@within Clock
	@method get_speed
	@return number

	returns the speed, see [Clock:set_speed]
]=]
function Clock.get_speed(self: Clock): number
	return self._speed
end

--[=[
	@within Clock
	@method set_speed
	@param speed number
	@return Clock
	@tag Replicates
	@error "this clock is read from the server, only the server can change it" -- called on the copy a client got

	sets how many seconds the time moves per second. 1 is real time, 2 is twice
	as fast, and a negative speed counts down
]=]
function Clock.set_speed(self: Clock, speed: number): Clock
	settle(self)
	self._speed = speed
	publish(self)
	return self
end

--[=[
	@within Clock
	@method is_playing
	@return boolean

	returns whether the clock is started
]=]
function Clock.is_playing(self: Clock): boolean
	return self._playing
end

--[=[
	@within Clock
	@method start
	@return Clock
	@tag Replicates
	@error "this clock is read from the server, only the server can change it" -- called on the copy a client got

	starts or resumes the clock. does nothing if it is already playing
]=]
function Clock.start(self: Clock): Clock
	if self._playing and not self._readonly then
		return self
	end

	settle(self)
	self._playing = true
	publish(self)
	return self
end

--[=[
	@within Clock
	@method stop
	@return Clock
	@tag Replicates
	@error "this clock is read from the server, only the server can change it" -- called on the copy a client got

	pauses the clock, keeping its time
]=]
function Clock.stop(self: Clock): Clock
	if not self._playing and not self._readonly then
		return self
	end

	settle(self)
	self._playing = false
	publish(self)
	return self
end

--[=[
	@within Clock
	@method reset
	@return Clock
	@tag Replicates
	@error "this clock is read from the server, only the server can change it" -- called on the copy a client got

	stops the clock and sets its time back to 0
]=]
function Clock.reset(self: Clock): Clock
	settle(self)
	self._playing = false
	self._time = 0
	publish(self)
	return self
end

--[=[
	@within Clock
	@method at
	@param time number
	@param callback () -> ()
	@return Connection

	calls `callback` once, when the clock reaches `time` moving at its speed. it
	waits while the clock is stopped or moving away from `time`, and follows every
	change to it, so the callback runs at the same moment on every side

	```lua
	local round = Clock.new():set_time(60):set_speed(-1):start()

	round:at(10, function()
		print("10 seconds left")
	end)
	```
]=]
function Clock.at(self: Clock, time: number, callback: () -> ()): Connection
	const void = Void.new()
	const connection = Connection.new(void)
	local thread: thread? = nil

	const function cancel()
		if thread then
			task.cancel(thread)
			thread = nil
		end
	end

	const function fire()
		thread = nil
		connection:disconnect()
		callback()
	end

	const function schedule()
		cancel()

		const current = self:get_time()
		if current == time then
			fire()
			return
		end

		if not self._playing or self._speed == 0 then
			return
		end

		const delay = (time - current) / self._speed
		if delay >= 0 then
			thread = task.delay(delay, fire)
		end
	end

	void:add(cancel)
	void:add(self.changed:connect(schedule))
	self._void:add(connection)
	void:add(function()
		self._void:remove(connection)
	end)

	schedule()
	return connection
end

--[=[
	@within Clock
	@method observe
	@param callback (time: number) -> ()
	@return Connection

	calls `callback` with the time right away, then every frame while the clock
	plays and on every change, until the returned connection is disconnected
]=]
function Clock.observe(self: Clock, callback: (time: number) -> ()): Connection
	const void = Void.new()
	const connection = Connection.new(void)
	local loop: Connection | false = false

	const function update()
		callback(self:get_time())

		if self._playing and not loop then
			loop = void:add(Loop(0, function()
				callback(self:get_time())
			end))
		elseif not self._playing and loop then
			void:clean_item(loop)
			loop = false
		end
	end

	void:add(self.changed:connect(update))
	self._void:add(connection)
	void:add(function()
		self._void:remove(connection)
	end)

	update()
	return connection
end

--[=[
	@within Clock
	@method atom
	@return Atom<number>

	returns an `Atom` that holds the time of the clock, set every frame while it
	plays and on every change, like [Clock:observe]. the same atom is returned
	each time, and it is destroyed with the clock. derive from it rather than
	setting it, since the clock sets it again on the next frame

	```lua
	local round = Clock.get("Round"):await()

	-- notifies once a second rather than every frame
	local seconds = round:atom():map(function(time)
		return math.max(math.ceil(time), 0)
	end)

	seconds:observe(function(value)
		label.Text = `{value}`
	end)
	```
]=]
function Clock.atom(self: Clock): Atom<number>
	const existing = self._atom
	if existing then
		return existing
	end

	const atom = Atom.new(self:get_time())
	self._atom = atom
	self:observe(function(time)
		atom:set(time)
	end)
	self._void:add(atom)

	return atom
end

--[=[
	@within Clock
	@method destroy

	stops the clock and disconnects everything connected to it. on the server, a
	replicated clock is removed from every client too
]=]
function Clock.destroy(self: Clock)
	if self._readonly then
		const name, id = self._name, self._id
		if name and copies[name] == self then
			copies[name] = nil
		end
		if id and copies_by_id[id] == self then
			copies_by_id[id] = nil
		end
	else
		self:unreplicate()
	end

	self._playing = false
	self._void:clean()
end

--[=[
	@within Clock
	@prop MINUTE number
	@readonly

	60, the seconds in a minute
]=]

--[=[
	@within Clock
	@prop HOUR number
	@readonly

	3600, the seconds in an hour
]=]

--[=[
	@within Clock
	@prop DAY number
	@readonly

	86400, the seconds in a day
]=]

--[=[
	@within Clock
	@prop WEEK number
	@readonly

	604800, the seconds in a week
]=]

return table.freeze({
	new = Clock.new,
	find = Clock.find,
	get = Clock.get,
	synced_time = Clock.synced_time,
	timestamp = Clock.timestamp,
	since = Clock.since,
	left = Clock.left,
	period = Clock.period,
	next = Clock.next,
	every = Clock.every,
	is = Clock.is,

	MINUTE = 60,
	HOUR = 3600,
	DAY = 86400,
	WEEK = 604800,
})

--[=[
	@class Region

	Region is a shape that reports what enters and leaves it, every frame, without physics queries

	create one with [Region.new] and shape it with the `set_` methods. every
	frame, it checks which parts of the workspace touch it with
	[Bolt](https://unityjaeger.github.io/Bolt/) and fires [Region.entered] and
	[Region.left]. a rule can turn parts into the values to report, like the
	player a limb belongs to

	```lua
	local Region = require(path.to.Region)

	local shop = Region.new()
		:set_part(workspace.Shop)
		:set_rule(function(part)
			return Players:GetPlayerFromCharacter(part.Parent)
		end)

	shop:observe(function(player, void)
		void:add(open_shop(player))
	end)
	```

	:::info
	a part is inside as soon as it touches the shape, and every part keeps its
	own shape, so a ball or a wedge is checked as one. a value stays inside while
	any of its parts is, and a part removed from the workspace leaves on the next
	check. the first check runs on the next frame, so the `set_` methods chained
	after [Region.new] all apply before it, and [Region:step] checks right away
	instead of waiting
	:::
]=]

const Bolt = require(script.Parent.Bolt)
const Connection = require(script.Parent.Connection)
const Loop = require(script.Parent.Loop)
const Observe = require(script.Parent.Observe)
const Signal = require(script.Parent.Signal)
const Thread = require(script.Parent.Thread)
const Void = require(script.Parent.Void)

export type Connection = Connection.Connection
export type Shape = Bolt.Shape
export type Signal<T...> = Signal.Signal<T...>

--[=[
	@within Region
	@type Rule (part: BasePart) -> any

	returns the value a part counts for, or nil to ignore it
]=]
export type Rule = (part: BasePart) -> any

--[=[
	@within Region
	@type Predicate (part: BasePart) -> boolean

	returns whether a part is checked at all
]=]
export type Predicate = (part: BasePart) -> boolean

-- the shape of a part, kept until its size or shape changes
type PartShape = {
	size: Vector3,
	kind: any,
	shape: Shape,
}

export type Region = setmetatable<{
	_cframe: CFrame,
	_shape: Shape,
	_radius: number,
	_predicate: Predicate | false,
	_rule: Rule | false,
	_filters: { (value: any) -> boolean },
	_enabled: boolean,
	-- the part the region follows, and its offset from it
	_target: BasePart | false,
	_offset: CFrame,
	_checked_at: number,
	-- the connections that track the parts of the root and check on their own
	_tracking: Connection,
	_loop: Connection,
	-- every part in the root
	_parts: { [BasePart]: true },
	-- the parts inside and the value each one counts for
	_inside: { [BasePart]: any },
	-- the values inside and how many of their parts are
	_counts: { [any]: number },
	_shapes: { [BasePart]: PartShape },
	_void: Void.Void,
	entered: Signal<any>,
	left: Signal<any>,
	stepped: Signal<number>,
	set_cframe: (self: Region, cframe: CFrame) -> Region,
	set_position: (self: Region, position: Vector3) -> Region,
	set_orientation: (self: Region, orientation: CFrame) -> Region,
	set_size: (self: Region, size: Vector3) -> Region,
	set_shape: (self: Region, shape: Shape) -> Region,
	set_part: (self: Region, part: BasePart) -> Region,
	set_predicate: (self: Region, predicate: Predicate?) -> Region,
	set_rule: (self: Region, rule: Rule?) -> Region,
	set_root: (self: Region, root: Instance) -> Region,
	set_interval: (self: Region, seconds: number) -> Region,
	follow: (self: Region, part: BasePart?, offset: CFrame?) -> Region,
	step: (self: Region) -> Region,
	get_cframe: (self: Region) -> CFrame,
	get_size: (self: Region) -> Vector3,
	get_shape: (self: Region) -> Shape,
	where: (self: Region, filter: (value: any) -> boolean) -> Region,
	get_results: (self: Region) -> { any },
	has_part: (self: Region, part: BasePart) -> boolean,
	contains_point: (self: Region, point: Vector3) -> boolean,
	contains_part: (self: Region, part: BasePart) -> boolean,
	contains_parts: (self: Region, parts: { BasePart }, mode: ("Any" | "All")?) -> boolean,
	contains_region: (self: Region, other: Region) -> boolean,
	intersects_region: (self: Region, other: Region) -> boolean,
	observe: (self: Region, callback: (value: any, void: Void.Void) -> ()) -> Connection,
	enable: (self: Region) -> Region,
	disable: (self: Region) -> Region,
	toggle: (self: Region) -> Region,
	is_enabled: (self: Region) -> boolean,
	destroy: (self: Region) -> (),
}, { __index: Region }>

-- how close counts as touching, in studs
const TOLERANCE = 1e-4
-- a point, for contains_point
const POINT = Bolt.create_sphere(0)

const Region = {}
Region.__index = Region

--[=[
	@within Region
	@prop entered Signal<any>
	@readonly

	fires with a value when its first part enters the shape
]=]

--[=[
	@within Region
	@prop left Signal<any>
	@readonly

	fires with a value when its last part leaves the shape
]=]

--[=[
	@within Region
	@prop stepped Signal<number>
	@readonly

	fires after every check with the seconds since the previous one
]=]

--[=[
	@within Region
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Region
]=]
function Region.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Region
end


--[=[
	@within Region
	@method set_cframe
	@param cframe CFrame
	@return Region

	sets the position and orientation of the shape's center
]=]
function Region.set_cframe(self: Region, cframe: CFrame): Region
	self._cframe = cframe
	return self
end

--[=[
	@within Region
	@method set_position
	@param position Vector3
	@return Region

	moves the shape's center, keeping its orientation
]=]
function Region.set_position(self: Region, position: Vector3): Region
	self._cframe = self._cframe.Rotation + position
	return self
end

--[=[
	@within Region
	@method set_orientation
	@param orientation CFrame
	@return Region

	rotates the shape like `orientation`, keeping its position
]=]
function Region.set_orientation(self: Region, orientation: CFrame): Region
	self._cframe = orientation.Rotation + self._cframe.Position
	return self
end

--[=[
	@within Region
	@method set_shape
	@param shape Shape
	@return Region

	sets the shape, any [Bolt](https://unityjaeger.github.io/Bolt/guides/shapes/)
	shape, like a sphere or a capsule. [Region.Bolt] makes them

	```lua
	region:set_shape(Region.Bolt.create_sphere(10))
	```
]=]
function Region.set_shape(self: Region, shape: Shape): Region
	self._shape = shape
	self._radius = Bolt.circumradius(shape)
	return self
end

--[=[
	@within Region
	@method set_size
	@param size Vector3
	@return Region

	makes the shape a box of `size` studs
]=]
function Region.set_size(self: Region, size: Vector3): Region
	return self:set_shape(Bolt.create_box(size))
end

-- the Bolt shape of `part`. meshes and unions are checked as their box
const function shape_of(part: BasePart): Shape
	if part:IsA("Part") then
		const ok, shape = pcall(Bolt.create_from_part, part :: Part)
		if ok then
			return shape
		end
	elseif part:IsA("WedgePart") then
		return Bolt.create_wedge(part.Size)
	elseif part:IsA("CornerWedgePart") then
		return Bolt.create_corner_wedge(part.Size)
	end
	return Bolt.create_box(part.Size)
end

--[=[
	@within Region
	@method set_part
	@param part BasePart
	@return Region

	takes the position, orientation and shape of `part`, so a block, a ball, a
	cylinder or a wedge in the workspace can be the region. meshes and unions
	become their box. the region doesn't follow `part` when it moves afterwards
]=]
function Region.set_part(self: Region, part: BasePart): Region
	self._cframe = part.CFrame
	return self:set_shape(shape_of(part))
end

--[=[
	@within Region
	@method set_predicate
	@param predicate Predicate?
	@return Region

	only checks the parts `predicate` returns true for. nil checks every part
]=]
function Region.set_predicate(self: Region, predicate: Predicate?): Region
	self._predicate = predicate or false
	return self
end

--[=[
	@within Region
	@method set_rule
	@param rule Rule?
	@return Region

	reports what `rule` returns for a part instead of the part itself. nil
	reports the parts

	```lua
	region:set_rule(function(part)
		return part.Parent:FindFirstChildOfClass("Humanoid") and part.Parent
	end)
	```
]=]
function Region.set_rule(self: Region, rule: Rule?): Region
	self._rule = rule or false
	return self
end

-- the shape of `part`, made again when its size or shape changes
const function part_shape(self: Region, part: BasePart): Shape
	const size = part.Size
	const kind = if part:IsA("Part") then (part :: Part).Shape else false

	local cached = self._shapes[part]
	if cached == nil or cached.size ~= size or cached.kind ~= kind then
		cached = { size = size, kind = kind, shape = shape_of(part) }
		self._shapes[part] = cached
	end

	return cached.shape
end

-- whether `part` touches the shape right now
const function touches(self: Region, part: BasePart): boolean
	const cframe = part.CFrame

	-- when the spheres around both shapes don't touch, the shapes can't either,
	-- which skips most parts before the narrow check
	const distance = vector.magnitude((cframe.Position - self._cframe.Position) :: any)
	if distance > self._radius + vector.magnitude(part.Size :: any) / 2 + TOLERANCE then
		return false
	end

	return Bolt.dispatch.gjk.intersects(self._cframe, self._shape, cframe, part_shape(self, part), TOLERANCE)
end

-- the value `part` counts for right now, or nil when it is outside or ignored
const function value_of(self: Region, part: BasePart): any
	const predicate = self._predicate
	if (predicate and not predicate(part)) or not touches(self, part) then
		return nil
	end

	const rule = self._rule
	const value = if rule then rule(part) else part
	if value == nil then
		return nil
	end

	for _, filter in self._filters do
		if not filter(value) then
			return nil
		end
	end

	return value
end

const function check(self: Region)
	const target = self._target
	if target then
		self._cframe = target.CFrame * self._offset
	end

	const inside: { [BasePart]: any } = {}
	const counts: { [any]: number } = {}
	for part in self._parts do
		const value = value_of(self, part)
		if value ~= nil then
			inside[part] = value
			counts[value] = (counts[value] or 0) + 1
		end
	end

	const old = self._counts
	self._inside = inside
	self._counts = counts

	for value in old do
		if not counts[value] then
			self.left:fire(value)
		end
	end
	for value in counts do
		if not old[value] then
			self.entered:fire(value)
		end
	end

	const now = os.clock()
	const delta_time = now - self._checked_at
	self._checked_at = now
	self.stepped:fire(delta_time)
end

-- tracks the parts in `root`
const function track(self: Region, root: Instance)
	const tracking = Observe.descendants(root)
		:filter(function(descendant)
			return descendant:IsA("BasePart")
		end)
		:subscribe(function(brio)
			const part_void, part = brio:to_void_and_value()
			self._parts[part :: BasePart] = true
			part_void:add(function()
				self._parts[part :: BasePart] = nil
				self._shapes[part :: BasePart] = nil
			end)
		end)
	self._tracking = self._void:add(tracking)
end

-- checks every `interval` seconds while enabled
const function schedule(self: Region, interval: number)
	const loop = Loop(interval, function()
		if self._enabled then
			check(self)
		end
	end)
	self._loop = self._void:add(loop)
end

--[=[
	@within Region
	@function new
	@return Region

	creates a Region, a 1 stud box at the origin, that checks the parts of the
	workspace every frame, starting on the next one. shape it with the `set_`
	methods

	```lua
	local blast = Region.new()
		:set_position(explosion.Position)
		:set_shape(Region.Bolt.create_sphere(12))
	```
]=]
function Region.new(): Region
	const void = Void.new()
	const shape = Bolt.create_box(Vector3.one)
	const region: Region = setmetatable({
		_cframe = CFrame.identity,
		_shape = shape,
		_radius = Bolt.circumradius(shape),
		_predicate = false,
		_rule = false,
		_filters = {},
		_enabled = true,
		_target = false,
		_offset = CFrame.identity,
		_checked_at = os.clock(),
		_tracking = nil :: any,
		_loop = nil :: any,
		_parts = {},
		_inside = {},
		_counts = {},
		_shapes = {},
		_void = void,
		entered = void:add(Signal.new()),
		left = void:add(Signal.new()),
		stepped = void:add(Signal.new()),
	}, Region) :: any

	track(region, workspace)
	schedule(region, 0)

	return region
end

--[=[
	@within Region
	@method set_root
	@param root Instance
	@return Region

	only checks the parts in `root` instead of the whole workspace, like a folder
	of characters, which is faster when the workspace has many parts. the parts
	outside `root` that were inside leave on the next check
]=]
function Region.set_root(self: Region, root: Instance): Region
	self._void:clean_item(self._tracking :: any)
	track(self, root)
	return self
end

--[=[
	@within Region
	@method set_interval
	@param seconds number
	@return Region

	checks every `seconds` instead of every frame, which is cheaper when the
	region doesn't need to react right away. 0 checks every frame

	```lua
	-- a zone that gives coins doesn't need to check 60 times a second
	coin_zone:set_interval(0.5)
	```
]=]
function Region.set_interval(self: Region, seconds: number): Region
	self._void:clean_item(self._loop :: any)
	schedule(self, seconds)
	return self
end

--[=[
	@within Region
	@method follow
	@param part BasePart?
	@param offset CFrame?
	@return Region

	moves the region with `part` before every check, `offset` away from it in
	its space, like a hitbox on a sword. nil stops following and leaves the
	region where it is

	```lua
	local hitbox = Region.new()
		:set_size(Vector3.new(1, 1, 4))
		:follow(sword.Handle, CFrame.new(0, 0, -2))
	```
]=]
function Region.follow(self: Region, part: BasePart?, offset: CFrame?): Region
	self._target = part or false
	self._offset = offset or CFrame.identity
	return self
end

--[=[
	@within Region
	@method step
	@return Region

	checks right away instead of waiting for the next check, firing
	[Region.entered] and [Region.left] before it returns. it works even while the
	region is disabled, so a disabled region only checks when it is told to

	```lua
	local blast = Region.new()
		:set_position(explosion.Position)
		:set_shape(Region.Bolt.create_sphere(12))
		:step()

	for _, part in blast:get_results() do
		part:BreakJoints()
	end
	blast:destroy()
	```
]=]
function Region.step(self: Region): Region
	check(self)
	return self
end

--[=[
	@within Region
	@method get_cframe
	@return CFrame

	returns the position and orientation of the shape's center
]=]
function Region.get_cframe(self: Region): CFrame
	return self._cframe
end

--[=[
	@within Region
	@method get_size
	@return Vector3

	returns the size of the box around the shape, in its own space. for a box,
	it is the box's size
]=]
function Region.get_size(self: Region): Vector3
	const min, max = Bolt.shape_aabb(CFrame.identity, self._shape)
	return (max - min) :: any
end

--[=[
	@within Region
	@method get_shape
	@return Shape

	returns the Bolt shape of the region
]=]
function Region.get_shape(self: Region): Shape
	return self._shape
end

--[=[
	@within Region
	@method where
	@param filter (value: any) -> boolean
	@return Region

	ignores the values `filter` returns false for, after the rule. each call
	adds a filter, and a value has to pass all of them
]=]
function Region.where(self: Region, filter: (value: any) -> boolean): Region
	table.insert(self._filters, filter)
	return self
end

--[=[
	@within Region
	@method get_results
	@return { any }

	returns the values inside, as of the last check
]=]
function Region.get_results(self: Region): { any }
	const results = {}
	for value in self._counts do
		table.insert(results, value)
	end
	return results
end

--[=[
	@within Region
	@method has_part
	@param part BasePart
	@return boolean

	returns whether `part` was inside and counted on the last check
]=]
function Region.has_part(self: Region, part: BasePart): boolean
	return self._inside[part] ~= nil
end

--[=[
	@within Region
	@method contains_point
	@param point Vector3
	@return boolean

	returns whether `point` is in the shape right now, edges included
]=]
function Region.contains_point(self: Region, point: Vector3): boolean
	return Bolt.dispatch.gjk.intersects(self._cframe, self._shape, CFrame.new(point), POINT, TOLERANCE)
end

--[=[
	@within Region
	@method contains_part
	@param part BasePart
	@return boolean

	returns whether `part` touches the shape right now, ignoring the predicate
	and the rule
]=]
function Region.contains_part(self: Region, part: BasePart): boolean
	return touches(self, part)
end

--[=[
	@within Region
	@method contains_parts
	@param parts { BasePart }
	@param mode ("Any" | "All")?
	@return boolean

	returns whether all of `parts` touch the shape right now, or any of them
	with the mode `"Any"`. the mode defaults to `"All"`
]=]
function Region.contains_parts(self: Region, parts: { BasePart }, mode: ("Any" | "All")?): boolean
	const any = mode == "Any"
	for _, part in parts do
		if self:contains_part(part) == any then
			return any
		end
	end
	return not any
end

--[=[
	@within Region
	@method contains_region
	@param other Region
	@return boolean

	returns whether the shape of `other` is entirely in this one. it checks the
	corners of the box around `other`, so it is exact for boxes, and can say no
	for a round shape that only just fits
]=]
function Region.contains_region(self: Region, other: Region): boolean
	const min, max = Bolt.shape_aabb(CFrame.identity, other._shape)
	for _, x in { min.x, max.x } do
		for _, y in { min.y, max.y } do
			for _, z in { min.z, max.z } do
				if not self:contains_point(other._cframe * Vector3.new(x, y, z)) then
					return false
				end
			end
		end
	end
	return true
end

--[=[
	@within Region
	@method intersects_region
	@param other Region
	@return boolean

	returns whether the shapes of both regions touch right now
]=]
function Region.intersects_region(self: Region, other: Region): boolean
	return Bolt.dispatch.gjk.intersects(self._cframe, self._shape, other._cframe, other._shape, TOLERANCE)
end

--[=[
	@within Region
	@method observe
	@param callback (value: any, void: Void) -> ()
	@return Connection

	calls `callback` for every value inside, now and when it enters. the void is
	cleaned when the value leaves, when the connection is disconnected or when
	the region is destroyed
]=]
function Region.observe(self: Region, callback: (value: any, void: Void.Void) -> ()): Connection
	const void = self._void:extend()
	const voids: { [any]: Void.Void } = {}

	const function add(value: any)
		if voids[value] then
			return
		end

		const value_void = void:extend()
		voids[value] = value_void
		Thread(callback, value, value_void)
	end

	void:add(self.entered:connect(add))
	const left = self.left:connect(function(value)
		const value_void = voids[value]
		if value_void then
			voids[value] = nil
			void:clean_item(value_void)
		end
	end)
	void:add(left)

	for value in self._counts do
		add(value)
	end

	return Connection.new(void)
end

--[=[
	@within Region
	@method enable
	@return Region

	checks every frame again after [Region:disable]
]=]
function Region.enable(self: Region): Region
	self._enabled = true
	return self
end

--[=[
	@within Region
	@method disable
	@return Region

	stops checking on its own. what was inside stays inside until it is enabled
	again, and [Region:step] still checks
]=]
function Region.disable(self: Region): Region
	self._enabled = false
	return self
end

--[=[
	@within Region
	@method toggle
	@return Region

	enables the region if it is disabled, and disables it otherwise
]=]
function Region.toggle(self: Region): Region
	self._enabled = not self._enabled
	return self
end

--[=[
	@within Region
	@method is_enabled
	@return boolean

	returns whether the region checks every frame
]=]
function Region.is_enabled(self: Region): boolean
	return self._enabled
end

--[=[
	@within Region
	@method destroy

	stops checking, cleans the voids of [Region:observe] and disconnects
	everything connected to the signals
]=]
function Region.destroy(self: Region)
	self._enabled = false
	self._void:clean()
end

--[=[
	@within Region
	@prop Bolt Bolt
	@readonly

	the [Bolt](https://unityjaeger.github.io/Bolt/) Region checks with, to make
	shapes for [Region:set_shape] without installing it yourself
]=]

return table.freeze({
	new = Region.new,
	is = Region.is,
	Bolt = Bolt,
})

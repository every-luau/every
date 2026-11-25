--[=[
	@class Caffeine

	Caffeine keeps unanchored parts from falling asleep in Roblox physics

	Roblox stops simulating an assembly once it moves slower than its sleep
	thresholds (0.33 studs/s and 0.24 studs/s² for linear motion). a part pushed
	slowly by a constraint, a bowling pin waiting for a ball or a crate on a
	moving platform can freeze in place

	[Caffeine.wake] gives a part, a model or a list of parts one small shake to
	wake them. calling the module or [Caffeine.keep] shakes them before every
	physics step, so they never fall asleep, until the returned [Connection] is
	disconnected

	```lua
	local Caffeine = require(path.to.Caffeine)

	-- once, right before a projectile lands
	Caffeine.wake(workspace.Tower)

	-- until disconnected
	local connection = Caffeine(workspace.Platform)
	connection:disconnect()

	-- every part of the car, for 5 seconds
	Caffeine(workspace.Car, 5)
	```

	:::info
	a shake is a `BasePart:ApplyImpulse` on the assembly's root that changes its
	speed by 0.0001 studs/s, too little to see but never rounded to zero, even
	for heavy assemblies. any non-zero impulse wakes an assembly, and changes no
	property of the part. [Caffeine.keep] alternates up and down each step, so
	what it kept awake never drifts
	:::

	:::info
	only the side that simulates a part can wake it, and Roblox hands unanchored
	parts near a player to that player. so parts kept on the server are tagged
	`Caffeine`, and every client that requires Caffeine keeps them awake too.
	require it once on the client, for example from a LocalScript, and
	[Caffeine.keep] works whoever owns the part. [Caffeine.wake] does not
	replicate, so call it where the part is simulated
	:::

	:::caution
	an awake assembly is simulated again, so it picks up small movements from
	floating point errors. a part on solid ground barely moves, but a structure of
	unanchored parts kept awake can shift and collapse over time. wake structures
	right before something hits them, for example when a projectile is about to
	land, rather than keeping them awake
	:::
]=]

const RunService = game:GetService("RunService")

const Connection = require(script.Parent.Connection)
const Observe = require(script.Parent.Observe)

export type Connection = Connection.Connection

--[=[
	@within Caffeine
	@type Target BasePart | Model | { BasePart }

	what Caffeine wakes: a part and everything welded to it, every part in a
	model, or every part in a list
]=]
export type Target = BasePart | Model | { BasePart }

-- the tag the server puts on kept parts for clients to keep too
const TAG = "Caffeine"

-- the speed a shake adds, far under the 0.33 studs/s sleep threshold but big
-- enough that impulse / mass never rounds to zero
const UP = Vector3.new(0, 1e-4, 0)
const DOWN = -UP

const SERVER = RunService:IsServer()
const CLIENT = RunService:IsClient() and not SERVER

-- how many keeps hold each part, and the Destroying connection that drops it
const held: { [BasePart]: number } = {}
const destroying: { [BasePart]: RBXScriptConnection } = {}
local count = 0
local stepping: RBXScriptConnection? = nil
local up = false

-- the assemblies already shaken by this call, so a welded model gets one shake
const shaken: { [BasePart]: true } = {}

const function shake(part: BasePart, direction: Vector3)
	const root = part.AssemblyRootPart
	if root == nil or root.Anchored or shaken[root] then
		return
	end

	shaken[root] = true
	root:ApplyImpulse(direction * root.AssemblyMass)
end

const function step()
	up = not up

	const direction = if up then UP else DOWN
	for part in held do
		shake(part, direction)
	end

	table.clear(shaken)
end

const function drop(part: BasePart)
	held[part] = nil
	destroying[part]:Disconnect()
	destroying[part] = nil
	count -= 1

	if SERVER then
		part:RemoveTag(TAG)
	end

	if count == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

const function hold(part: BasePart)
	const holds = held[part]
	if holds then
		held[part] = holds + 1
		return
	end

	held[part] = 1
	destroying[part] = part.Destroying:Connect(function()
		if held[part] then
			drop(part)
		end
	end)

	count += 1
	if SERVER then
		part:AddTag(TAG)
	end

	if stepping == nil then
		stepping = RunService.PreSimulation:Connect(step)
	end
end

const function release(part: BasePart)
	const holds = held[part]
	if holds == nil then
		return -- the part was destroyed while held
	elseif holds > 1 then
		held[part] = holds - 1
	else
		drop(part)
	end
end

const function is_part(value: any): boolean
	return typeof(value) == "Instance" and (value :: Instance):IsA("BasePart")
end

const function is_model(value: any): boolean
	return typeof(value) == "Instance" and (value :: Instance):IsA("Model")
end

-- the parts `target` holds right now, erroring on anything that is not a Target
const function parts_of(target: Target, name: string): { BasePart }
	if is_part(target) then
		return { target :: BasePart }
	end

	const parts = {}
	if is_model(target) then
		for _, descendant in (target :: Model):GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end

		return parts
	end

	assert(
		typeof(target) == "table",
		`Caffeine.{name} needs a BasePart, a Model or a list of BaseParts, got {typeof(target)}`
	)

	for index, part in target :: { BasePart } do
		assert(is_part(part), `Caffeine.{name} needs a list of BaseParts, got {typeof(part)} at {index}`)
		table.insert(parts, part)
	end

	return parts
end

--[=[
	@within Caffeine
	@function wake
	@param target Target

	shakes `target` once to wake it. it can fall asleep again if it stays still,
	so use [Caffeine.keep] to hold it awake. errors when `target` is not a
	[Caffeine.Target]

	```lua
	-- a door that was asleep reacts to its new target right away
	hinge.TargetAngle = 90
	Caffeine.wake(door)

	-- wake a tower of loose bricks just before a projectile hits it
	Caffeine.wake(tower)
	```
]=]
const function wake(target: Target)
	for _, part in parts_of(target, "wake") do
		shake(part, DOWN)
	end

	table.clear(shaken)
end

--[=[
	@within Caffeine
	@function keep
	@param target Target
	@param duration number?
	@return Connection

	shakes `target` before every physics step so it never falls asleep, until
	the returned [Connection] is disconnected or for `duration` seconds when
	given. calling the module does the same

	```lua
	-- an AlignPosition moving at 0.1 studs/s would fall asleep without it
	local connection = Caffeine.keep(platform)

	-- keep the pins awake while the ball rolls
	Caffeine.keep(pins, 3)
	```

	a model is followed: parts added to it later are kept too, and parts that
	leave it are let go. sleep is per assembly, so a single part of a welded
	model is enough, while loose parts each need to be in the target. keeping a
	part twice holds it until both keeps are disconnected, and a destroyed part
	is let go on its own. errors when `target` is not a [Caffeine.Target] or
	`duration` is not positive
]=]
const function keep(target: Target, duration: number?): Connection
	assert(
		duration == nil or (type(duration) == "number" and duration > 0),
		`Caffeine.keep needs a positive duration or nil, got {duration}`
	)

	local connection: Connection
	if is_model(target) then
		connection = Observe.descendants(target :: Model):filter(is_part):subscribe(function(brio)
			const void, part = brio:to_void_and_value()
			hold(part :: BasePart)
			void:add(function()
				release(part :: BasePart)
			end)
		end)
	else
		-- a set, so a part listed twice is held and released once
		const parts: { [BasePart]: true } = {}
		for _, part in parts_of(target, "keep") do
			if not parts[part] then
				parts[part] = true
				hold(part)
			end
		end

		connection = Connection.new(function()
			for part in parts do
				release(part)
			end
			table.clear(parts)
		end)
	end

	if duration then
		task.delay(duration, connection.disconnect, connection)
	end

	return connection
end

-- on a client, keep what the server keeps, since the client may own those parts
if CLIENT then
	Observe.tag(TAG):filter(is_part):subscribe(function(brio)
		const void, part = brio:to_void_and_value()
		hold(part :: BasePart)
		void:add(function()
			release(part :: BasePart)
		end)
	end)
end

return table.freeze(
	setmetatable(
		{
			keep = keep,
			wake = wake,
		},
		{
			__call = function(_, target: Target, duration: number?): Connection
				return keep(target, duration)
			end,
		}
	)
)

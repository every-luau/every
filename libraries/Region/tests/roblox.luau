--!nonstrict
-- Minimal stand-in for the Roblox engine the library and its dependencies use,
-- since lest's native backend has none: a tiny instance tree with the signals
-- Observe listens to, the Players, CollectionService and RunService services,
-- and the CFrames, Vector3s and part shapes Bolt needs.
--
-- `script.Parent.Name`, and `script.Parent.Parent.Name` from a module inside a
-- library, resolve to the path of the `Name` library next to this one, the same
-- way package managers put dependencies next to each other. Bolt is the real
-- one, installed in `Packages` by `embr install`.

-- Vector3 is the native vector. a CFrame is a position and the right, up and
-- back vectors of its rotation, the columns of its rotation matrix

local CFrame = {}
local CFrameMeta = {}

local function make(position, x, y, z)
	return setmetatable({ _p = position, _x = x, _y = y, _z = z }, CFrameMeta)
end

local function to_world(self, point)
	return self._p + self._x * point.x + self._y * point.y + self._z * point.z
end

local function rotate(self, direction)
	return self._x * direction.x + self._y * direction.y + self._z * direction.z
end

local function to_object(self, direction)
	return vector.create(vector.dot(direction, self._x), vector.dot(direction, self._y), vector.dot(direction, self._z))
end

local function map(transform)
	return function(self, ...)
		local results = table.pack(...)
		for index = 1, results.n do
			results[index] = transform(self, results[index])
		end
		return table.unpack(results, 1, results.n)
	end
end

function CFrame.new(x, y, z)
	local position = if type(x) == "number" then vector.create(x, y, z) else x or vector.zero
	return make(position, vector.create(1, 0, 0), vector.create(0, 1, 0), vector.create(0, 0, 1))
end

-- rotates around X, then Y, then Z, like Roblox
function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local around_x = make(vector.zero, vector.create(1, 0, 0), vector.create(0, cx, sx), vector.create(0, -sx, cx))
	local around_y = make(vector.zero, vector.create(cy, 0, -sy), vector.create(0, 1, 0), vector.create(sy, 0, cy))
	local around_z = make(vector.zero, vector.create(cz, sz, 0), vector.create(-sz, cz, 0), vector.create(0, 0, 1))
	return around_x * around_y * around_z
end

CFrame.PointToWorldSpace = map(to_world)
CFrame.VectorToWorldSpace = map(rotate)
CFrame.PointToObjectSpace = map(function(self, point)
	return to_object(self, point - self._p)
end)
CFrame.VectorToObjectSpace = map(to_object)

function CFrame.Inverse(self)
	local x, y, z = self._x, self._y, self._z
	local inverse = make(vector.zero, vector.create(x.x, y.x, z.x), vector.create(x.y, y.y, z.y), vector.create(x.z, y.z, z.z))
	inverse._p = -rotate(inverse, self._p)
	return inverse
end

function CFrame.ToObjectSpace(self, other)
	return self:Inverse() * other
end

function CFrame.ToWorldSpace(self, other)
	return self * other
end

local PROPERTIES = {
	Position = function(self)
		return self._p
	end,
	Rotation = function(self)
		return make(vector.zero, self._x, self._y, self._z)
	end,
	RightVector = function(self)
		return self._x
	end,
	UpVector = function(self)
		return self._y
	end,
	LookVector = function(self)
		return -self._z
	end,
	XVector = function(self)
		return self._x
	end,
	YVector = function(self)
		return self._y
	end,
	ZVector = function(self)
		return self._z
	end,
}

function CFrameMeta.__index(self, key)
	local property = PROPERTIES[key]
	if property then
		return property(self)
	end
	return CFrame[key]
end

function CFrameMeta.__mul(self, other)
	if type(other) == "vector" then
		return to_world(self, other)
	end
	return make(to_world(self, other._p), rotate(self, other._x), rotate(self, other._y), rotate(self, other._z))
end

function CFrameMeta.__add(self, offset)
	return make(self._p + offset, self._x, self._y, self._z)
end

function CFrameMeta.__sub(self, offset)
	return make(self._p - offset, self._x, self._y, self._z)
end

CFrame.identity = CFrame.new()

local Enum = {
	PartType = {
		Block = "Block",
		Ball = "Ball",
		Cylinder = "Cylinder",
		Wedge = "Wedge",
		CornerWedge = "CornerWedge",
	},
}

local function spawn(callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	local ok, message = coroutine.resume(thread, ...)
	if not ok then
		error(message, 0)
	end
	return thread
end

-- the connections Connect returns, so `typeof` can call them RBXScriptConnections
local rbx_connections = setmetatable({}, { __mode = "k" })

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _listeners = {} }, Signal)
end

function Signal:Connect(listener)
	local listeners = self._listeners
	local connection = {}
	function connection.Disconnect()
		listeners[connection] = nil
	end
	listeners[connection] = listener
	rbx_connections[connection] = true
	return connection
end

function Signal:Fire(...)
	for connection, listener in table.clone(self._listeners) do
		if self._listeners[connection] then
			listener(...)
		end
	end
end

local SUPERCLASSES = {
	Part = { "BasePart" },
	MeshPart = { "BasePart" },
	Tool = {},
	Backpack = {},
	Model = {},
	Folder = {},
	Humanoid = {},
	Player = {},
}

local Instance = {}

local function new(class_name: string, name: string?, parent: any?)
	local self
	local properties = { ClassName = class_name, Name = name or class_name, Parent = nil }
	if class_name == "Part" or class_name == "MeshPart" then
		properties.Size = vector.one
		properties.CFrame = CFrame.identity
		properties.Position = vector.zero
	end
	if class_name == "Part" then
		properties.Shape = Enum.PartType.Block
	end
	local changed = {}
	local attributes = {}
	local attribute_changed = {}
	local children = {}

	self = setmetatable({
		ChildAdded = Signal.new(),
		ChildRemoved = Signal.new(),
		DescendantAdded = Signal.new(),
		DescendantRemoving = Signal.new(),
		AncestryChanged = Signal.new(),
		_children = children,
	}, {
		__index = function(_, key)
			if properties[key] ~= nil or key == "Parent" then
				return properties[key]
			end
			if Instance[key] then
				return Instance[key]
			end
			for _, child in children do
				if child.Name == key then
					return child
				end
			end
			return nil
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				Instance._setParent(self, value)
				return
			end
			-- a part's position and CFrame move together
			if key == "Position" and properties.CFrame then
				properties.CFrame = properties.CFrame.Rotation + value
			elseif key == "CFrame" and properties.Position then
				properties.Position = value.Position
			end
			properties[key] = value
			local signal = changed[key]
			if signal then
				signal:Fire()
			end
		end,
		__tostring = function()
			return properties.Name
		end,
	})

	function self._setParentRaw(value)
		properties.Parent = value
	end

	function self.GetPropertyChangedSignal(_, property)
		changed[property] = changed[property] or Signal.new()
		return changed[property]
	end

	function self.GetAttribute(_, attribute)
		return attributes[attribute]
	end

	function self.SetAttribute(_, attribute, value)
		attributes[attribute] = value
		local signal = attribute_changed[attribute]
		if signal then
			signal:Fire()
		end
	end

	function self.GetAttributeChangedSignal(_, attribute)
		attribute_changed[attribute] = attribute_changed[attribute] or Signal.new()
		return attribute_changed[attribute]
	end

	if parent then
		self.Parent = parent
	end

	return self
end

function Instance.IsA(self, class_name)
	if self.ClassName == class_name then
		return true
	end
	return table.find(SUPERCLASSES[self.ClassName] or {}, class_name) ~= nil
end

function Instance.GetChildren(self)
	return table.clone(self._children)
end

function Instance.GetDescendants(self)
	local descendants = {}
	local function collect(instance)
		for _, child in instance._children do
			table.insert(descendants, child)
			collect(child)
		end
	end
	collect(self)
	return descendants
end

function Instance.FindFirstChildOfClass(self, class_name)
	for _, child in self._children do
		if child.ClassName == class_name then
			return child
		end
	end
	return nil
end

function Instance.Destroy(self)
	self.Parent = nil
end

function Instance._setParent(self, parent)
	local old = self.Parent
	if old == parent then
		return
	end

	local moved = { self }
	for _, descendant in self:GetDescendants() do
		table.insert(moved, descendant)
	end

	if old then
		local ancestor = old
		while ancestor do
			for _, instance in moved do
				ancestor.DescendantRemoving:Fire(instance)
			end
			ancestor = ancestor.Parent
		end
		table.remove(old._children, table.find(old._children, self))
	end

	self._setParentRaw(parent)

	if old then
		old.ChildRemoved:Fire(self)
	end

	for _, instance in moved do
		instance.AncestryChanged:Fire(self, parent)
	end

	if parent then
		table.insert(parent._children, self)
		parent.ChildAdded:Fire(self)
		local ancestor = parent
		while ancestor do
			for _, instance in moved do
				ancestor.DescendantAdded:Fire(instance)
			end
			ancestor = ancestor.Parent
		end
	end
end

-- the services

local game = new("DataModel", "Game")
local workspace = new("Folder", "Workspace", game)

local Players = new("Folder", "Players", game)
Players.PlayerAdded = Signal.new()
Players.PlayerRemoving = Signal.new()
Players.LocalPlayer = nil
function Players.GetPlayers(self)
	return self:GetChildren()
end

local tagged: { [string]: { any } } = {}
local tag_added: { [string]: any } = {}
local tag_removed: { [string]: any } = {}

local CollectionService = {}
function CollectionService.GetTagged(_, tag)
	return table.clone(tagged[tag] or {})
end
function CollectionService.GetInstanceAddedSignal(_, tag)
	tag_added[tag] = tag_added[tag] or Signal.new()
	return tag_added[tag]
end
function CollectionService.GetInstanceRemovedSignal(_, tag)
	tag_removed[tag] = tag_removed[tag] or Signal.new()
	return tag_removed[tag]
end

local services = {
	Players = Players,
	CollectionService = CollectionService,
	GuiService = new("Folder", "GuiService"),
	UserInputService = new("Folder", "UserInputService"),
}

function game.GetService(_, name)
	return services[name]
end

-- helpers for the tests

local function add_player(name: string)
	local player = new("Player", name)
	player.CharacterAdded = Signal.new()
	player.CharacterRemoving = Signal.new()
	player.Character = nil
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	return player
end

local function remove_player(player)
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
end

local function spawn_character(player)
	local old = player.Character
	if old then
		player.CharacterRemoving:Fire(old)
		old.Parent = nil
	end

	local character = new("Model", player.Name)
	new("Humanoid", "Humanoid", character)
	player.Character = character
	character.Parent = workspace

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack.Parent = nil
	end
	new("Backpack", "Backpack", player)

	player.CharacterAdded:Fire(character)
	return character
end

local function add_tag(instance, tag: string)
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], instance)
	CollectionService:GetInstanceAddedSignal(tag):Fire(instance)
end

local function remove_tag(instance, tag: string)
	table.remove(tagged[tag], table.find(tagged[tag], instance))
	CollectionService:GetInstanceRemovedSignal(tag):Fire(instance)
end


-- RunService.Heartbeat only fires on `step`

local Heartbeat = Signal.new()
services.RunService = { Heartbeat = Heartbeat }

local function step(delta_time: number)
	Heartbeat:Fire(delta_time)
end

local globals = _G :: any
globals.task = {
	spawn = spawn,
	defer = spawn,
	cancel = function(thread)
		if coroutine.status(thread) ~= "dead" then
			coroutine.close(thread)
		end
	end,
}
globals.warn = function() end
local builtin_typeof = typeof
globals.typeof = function(value: any): string
	return if rbx_connections[value] then "RBXScriptConnection" else builtin_typeof(value)
end
globals.game = game
globals.CFrame = CFrame
globals.Enum = Enum
globals.Vector3 = {
	new = vector.create,
	zero = vector.zero,
	one = vector.one,
	xAxis = vector.create(1, 0, 0),
	yAxis = vector.create(0, 1, 0),
	zAxis = vector.create(0, 0, 1),
}
globals.workspace = workspace
-- `script.Parent.Parent` is `script.Parent`, since every source file is one
-- folder away from the libraries, whether it is the library or one of the
-- modules inside it like Observe's
local parent = setmetatable({
	Bolt = "../Packages/Bolt",
}, {
	__index = function(_, name: string)
		return `../../{name}/src`
	end,
})
parent.Parent = parent
globals.script = { Parent = parent }

return {
	step = step,
	new = new,
	workspace = workspace,
	Players = Players,
	add_player = add_player,
	remove_player = remove_player,
	spawn_character = spawn_character,
	add_tag = add_tag,
	remove_tag = remove_tag,
}

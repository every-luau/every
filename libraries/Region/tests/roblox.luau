--!nonstrict
-- Minimal stand-in for the Roblox engine the library and its dependencies use,
-- since lest's native backend has none: a tiny instance tree with the signals
-- Observe listens to, the Players, CollectionService and RunService services,
-- and CFrames that only translate.
--
-- `script.Parent.Name`, and `script.Parent.Parent.Name` from a module inside a
-- library, resolve to the path of the `Name` library next to this one, the same
-- way package managers put dependencies next to each other.

local function spawn(callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	local ok, message = coroutine.resume(thread, ...)
	if not ok then
		error(message, 0)
	end
	return thread
end

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
	Tool = {},
	Backpack = {},
	Model = {},
	Folder = {},
	Humanoid = {},
	Player = {},
}

local Instance = {}

local function new(className: string, name: string?, parent: any?)
	local self
	local properties = { ClassName = className, Name = name or className, Parent = nil }
	local changed = {}
	local attributes = {}
	local attributeChanged = {}
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
		local signal = attributeChanged[attribute]
		if signal then
			signal:Fire()
		end
	end

	function self.GetAttributeChangedSignal(_, attribute)
		attributeChanged[attribute] = attributeChanged[attribute] or Signal.new()
		return attributeChanged[attribute]
	end

	if parent then
		self.Parent = parent
	end

	return self
end

function Instance.IsA(self, className)
	if self.ClassName == className then
		return true
	end
	return table.find(SUPERCLASSES[self.ClassName] or {}, className) ~= nil
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

function Instance.FindFirstChildOfClass(self, className)
	for _, child in self._children do
		if child.ClassName == className then
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
local tagAdded: { [string]: any } = {}
local tagRemoved: { [string]: any } = {}

local CollectionService = {}
function CollectionService.GetTagged(_, tag)
	return table.clone(tagged[tag] or {})
end
function CollectionService.GetInstanceAddedSignal(_, tag)
	tagAdded[tag] = tagAdded[tag] or Signal.new()
	return tagAdded[tag]
end
function CollectionService.GetInstanceRemovedSignal(_, tag)
	tagRemoved[tag] = tagRemoved[tag] or Signal.new()
	return tagRemoved[tag]
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

local function addPlayer(name: string)
	local player = new("Player", name)
	player.CharacterAdded = Signal.new()
	player.CharacterRemoving = Signal.new()
	player.Character = nil
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	return player
end

local function removePlayer(player)
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
end

local function spawnCharacter(player)
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

local function addTag(instance, tag: string)
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], instance)
	CollectionService:GetInstanceAddedSignal(tag):Fire(instance)
end

local function removeTag(instance, tag: string)
	table.remove(tagged[tag], table.find(tagged[tag], instance))
	CollectionService:GetInstanceRemovedSignal(tag):Fire(instance)
end


-- RunService.Heartbeat only fires on `step`

local Heartbeat = Signal.new()
services.RunService = { Heartbeat = Heartbeat }

local function step(deltaTime: number)
	Heartbeat:Fire(deltaTime)
end

-- Vector3 is the native vector, and CFrame only supports translations

local CFrame = {}
CFrame.__index = CFrame

function CFrame.new(position)
	return setmetatable({ Position = position or vector.zero }, CFrame)
end

CFrame.identity = CFrame.new(vector.zero)

function CFrame.__index(self, key)
	if key == "Rotation" then
		return CFrame.identity
	end
	return CFrame[key]
end

function CFrame.__add(self, offset)
	return CFrame.new(self.Position + offset)
end

function CFrame.PointToObjectSpace(self, point)
	return point - self.Position
end

function CFrame.PointToWorldSpace(self, point)
	return point + self.Position
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
globals.game = game
globals.CFrame = CFrame
globals.Vector3 = { new = vector.create, zero = vector.zero, one = vector.one }
globals.workspace = workspace
-- `script.Parent.Parent` is `script.Parent`, since every source file is one
-- folder away from the libraries, whether it is the library or one of the
-- modules inside it like Observe's
local parent = setmetatable({}, {
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
	addPlayer = addPlayer,
	removePlayer = removePlayer,
	spawnCharacter = spawnCharacter,
	addTag = addTag,
	removeTag = removeTag,
}

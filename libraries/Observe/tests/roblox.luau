--!nonstrict
-- Minimal stand-in for the Roblox engine the library and its dependencies use,
-- since lest's native backend has none: a tiny instance tree with the signals
-- Observe listens to, plus the Players and CollectionService services.
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

local function new(class_name: string, name: string?, parent: any?)
	local self
	local properties = { ClassName = class_name, Name = name or class_name, Parent = nil }
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
	new = new,
	workspace = workspace,
	Players = Players,
	add_player = add_player,
	remove_player = remove_player,
	spawn_character = spawn_character,
	add_tag = add_tag,
	remove_tag = remove_tag,
}

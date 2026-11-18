--!nonstrict
-- Minimal stand-in for the Roblox engine the library and its dependencies use,
-- since lest's native backend has none: instances with attributes and property
-- signals, the datatypes BetterScale reads, and the GuiService, HttpService and
-- RunService services. `RunService.RenderStepped` only fires on `render`.
--
-- `script.Parent.Name` resolves to the path of the `Name` library next to this
-- one, the same way package managers put dependencies next to each other.

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

function Signal:Once(listener)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		listener(...)
	end)
	return connection
end

function Signal:Fire(...)
	for connection, listener in table.clone(self._listeners) do
		if self._listeners[connection] then
			listener(...)
		end
	end
end

-- a userdata the patched `typeof` below reports as `typeName`
local function datatype(typeName: string, fields: { [string]: any })
	local proxy = newproxy(true)
	local metatable = getmetatable(proxy)
	metatable.__type = typeName
	metatable.__index = fields
	return proxy
end

local function enum(names: { string })
	local enumType = {}
	for _, name in names do
		enumType[name] = datatype("EnumItem", { Name = name, EnumType = enumType })
	end
	return enumType
end

local Enum = {
	AutomaticSize = enum({ "None", "X", "Y", "XY" }),
	DisplaySize = enum({ "Small", "Medium", "Large" }),
}

local NumberRange = {
	new = function(min: number, max: number?)
		return datatype("NumberRange", { Min = min, Max = max or min })
	end,
}

local Vector2 = {
	new = function(x: number, y: number)
		return datatype("Vector2", { X = x, Y = y })
	end,
}

local SUPERCLASSES = {
	ScreenGui = { "LayerCollector" },
	SurfaceGui = { "LayerCollector" },
	BillboardGui = { "LayerCollector" },
}

local Instance = {}

local function new(className: string, parent: any?)
	local self
	local properties = { ClassName = className, Name = className, Parent = nil }
	local changed = {}
	local attributes = {}

	self = setmetatable({
		AncestryChanged = Signal.new(),
		AttributeChanged = Signal.new(),
		_children = {},
	}, {
		__index = function(_, key)
			if properties[key] ~= nil or key == "Parent" then
				return properties[key]
			end
			return Instance[key]
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				Instance._setParent(self, properties, value)
				return
			end
			properties[key] = value
			if changed[key] then
				changed[key]:Fire()
			end
		end,
		__tostring = function()
			return properties.Name
		end,
	})

	function self.GetPropertyChangedSignal(_, property)
		changed[property] = changed[property] or Signal.new()
		return changed[property]
	end

	function self.GetAttribute(_, attribute)
		return attributes[attribute]
	end

	function self.SetAttribute(_, attribute, value)
		attributes[attribute] = value
		self.AttributeChanged:Fire(attribute)
	end

	if parent then
		self.Parent = parent
	end

	return self
end

function Instance.IsA(self, className)
	return self.ClassName == className or table.find(SUPERCLASSES[self.ClassName] or {}, className) ~= nil
end

function Instance.FindFirstAncestorWhichIsA(self, className)
	local ancestor = self.Parent
	while ancestor and not ancestor:IsA(className) do
		ancestor = ancestor.Parent
	end
	return ancestor
end

function Instance.Destroy(self)
	self.Parent = nil
end

function Instance._setParent(self, properties, parent)
	local old = properties.Parent
	if old == parent then
		return
	end

	if old then
		table.remove(old._children, table.find(old._children, self))
	end
	properties.Parent = parent
	if parent then
		table.insert(parent._children, self)
	end

	local function notify(instance)
		instance.AncestryChanged:Fire(self, parent)
		for _, child in instance._children do
			notify(child)
		end
	end
	notify(self)
end

-- the services

local GuiService = new("GuiService")
GuiService.ViewportDisplaySize = Enum.DisplaySize.Medium

-- only decodes flat objects of numbers, which is all DisplayRatios holds
local HttpService = {}
function HttpService.JSONDecode(_, source: string)
	local body = string.match(source, "^%s*{(.*)}%s*$")
	if not body then
		error("Can't parse JSON")
	end

	local decoded = {}
	for key, value in string.gmatch(body, '"([^"]*)"%s*:%s*([%d%.%-]+)') do
		decoded[key] = tonumber(value)
	end
	return decoded
end

local RenderStepped = Signal.new()

local services = {
	GuiService = GuiService,
	HttpService = HttpService,
	RunService = { RenderStepped = RenderStepped },
}

-- fires RenderStepped once
local function render()
	RenderStepped:Fire(1 / 60)
end

-- a ScreenGui of `width` by `height` with a UIScale in a frame inside it
local function screen(width: number, height: number)
	local gui = new("ScreenGui")
	gui.AbsoluteSize = Vector2.new(width, height)
	local frame = new("Frame", gui)
	local uiScale = new("UIScale", frame)
	uiScale.Scale = 1
	return uiScale, gui
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
globals.game = {
	Destroy = function(instance)
		instance:Destroy()
	end,
	GetService = function(_, name)
		return services[name]
	end,
}
-- instances here are tables and datatypes plain userdata, so `typeof` is taught
-- their names
local builtinTypeof = typeof
globals.typeof = function(value)
	if type(value) == "table" and rawget(value, "_children") then
		return "Instance"
	elseif type(value) == "userdata" then
		local metatable = getmetatable(value)
		if type(metatable) == "table" and metatable.__type then
			return metatable.__type
		end
	end
	return builtinTypeof(value)
end
globals.Enum = Enum
globals.NumberRange = NumberRange
globals.Vector2 = Vector2
globals.script = {
	Parent = setmetatable({}, {
		__index = function(_, name: string)
			return `../../{name}/src`
		end,
	}),
}

return {
	new = new,
	screen = screen,
	render = render,
	GuiService = GuiService,
	Enum = Enum,
	NumberRange = NumberRange,
	Vector2 = Vector2,
}

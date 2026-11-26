--!strict
-- Minimal stand-in for the Roblox globals Gradient uses, since lest's native
-- backend has none: Color3, the sequences and their keypoints, a few
-- instances and `RunService.Heartbeat`, which only fires on `step`.

local globals = _G :: any

-- Color3

local Color3 = {}
Color3.__index = Color3
Color3.__eq = function(a: any, b: any)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
Color3.__tostring = function(color: any)
	return `{color.R}, {color.G}, {color.B}`
end

function Color3.new(r: number?, g: number?, b: number?)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end

function Color3.fromRGB(r: number, g: number, b: number)
	return Color3.new(r / 255, g / 255, b / 255)
end

function Color3.Lerp(self: any, goal: any, alpha: number)
	return Color3.new(
		self.R + (goal.R - self.R) * alpha,
		self.G + (goal.G - self.G) * alpha,
		self.B + (goal.B - self.B) * alpha
	)
end

-- sequences, which check their keypoints like Roblox does

local Keypoint = {}
local function keypoint(time: number, value: any)
	return setmetatable({ Time = time, Value = value }, Keypoint)
end

-- how many sequences were made, to check what is cached
local made = { color = 0, number = 0 }

local function check(keypoints: { any }, kind: string)
	assert(#keypoints >= 2 and #keypoints <= 20, `{kind} needs 2 to 20 keypoints, got {#keypoints}`)
	assert(keypoints[1].Time == 0, `{kind} must start at 0, got {keypoints[1].Time}`)
	assert(keypoints[#keypoints].Time == 1, `{kind} must end at 1, got {keypoints[#keypoints].Time}`)
	for index = 2, #keypoints do
		assert(keypoints[index].Time >= keypoints[index - 1].Time, `{kind} keypoints must be in order`)
	end
end

local ColorSequence = {}
ColorSequence.__index = ColorSequence
local NumberSequence = {}
NumberSequence.__index = NumberSequence

globals.Color3 = Color3
globals.ColorSequenceKeypoint = { new = keypoint }
globals.NumberSequenceKeypoint = { new = keypoint }
globals.ColorSequence = {
	new = function(first: any, last: any?)
		local keypoints = if getmetatable(first) == Color3
			then { keypoint(0, first), keypoint(1, last or first) }
			else first
		check(keypoints, "ColorSequence")
		made.color += 1
		return setmetatable({ Keypoints = keypoints }, ColorSequence)
	end,
}
globals.NumberSequence = {
	new = function(first: any, last: number?)
		local keypoints = if type(first) == "number" then { keypoint(0, first), keypoint(1, last or first) } else first
		check(keypoints, "NumberSequence")
		made.number += 1
		return setmetatable({ Keypoints = keypoints }, NumberSequence)
	end,
}

-- a signal with Connect, whose connections Disconnect

local function signal()
	local listeners: { [any]: true } = {}
	local self = {}
	function self.Connect(_, listener: (...any) -> ())
		local entry = { listener }
		listeners[entry] = true
		return {
			Disconnect = function()
				listeners[entry] = nil
			end,
		}
	end
	function self.fire(...: any)
		for entry in table.clone(listeners) do
			if listeners[entry] then
				entry[1](...)
			end
		end
	end
	function self.count(): number
		local count = 0
		for _ in listeners do
			count += 1
		end
		return count
	end
	return self
end

-- instances

local CLASSES: { [string]: { string } } = {
	Frame = { "Frame", "GuiObject", "GuiBase2d", "Instance" },
	TextLabel = { "TextLabel", "GuiObject", "GuiBase2d", "Instance" },
	UIStroke = { "UIStroke", "UIComponent", "Instance" },
	UIGradient = { "UIGradient", "UIComponent", "Instance" },
	Folder = { "Folder", "Instance" },
}

local Instance = {}

local function is_a(self: any, class_name: string): boolean
	return table.find(CLASSES[self.ClassName], class_name) ~= nil
end

local function set_parent(self: any, parent: any)
	local old = rawget(self, "_parent")
	if old then
		local index = table.find(old._children, self)
		if index then
			table.remove(old._children, index)
		end
	end
	rawset(self, "_parent", parent)
	if parent then
		table.insert(parent._children, self)
	end
end

local function destroy(self: any)
	if rawget(self, "_destroyed") then
		return
	end
	rawset(self, "_destroyed", true)
	for _, child in table.clone(self._children) do
		destroy(child)
	end
	self.Destroying.fire()
	set_parent(self, nil)
end

Instance.__index = function(self: any, key: string)
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	return nil
end
Instance.__newindex = function(self: any, key: string, value: any)
	if key == "Parent" then
		set_parent(self, value)
	else
		rawset(self, key, value)
	end
end

globals.Instance = {
	new = function(class_name: string)
		assert(CLASSES[class_name], `the fake Instance has no {class_name}`)
		local self = {
			ClassName = class_name,
			Name = class_name,
			_children = {},
			Destroying = signal(),
			IsA = is_a,
			Destroy = destroy,
			GetChildren = function(this: any)
				return table.clone(this._children)
			end,
			FindFirstChildWhichIsA = function(this: any, name: string)
				for _, child in this._children do
					if is_a(child, name) then
						return child
					end
				end
				return nil
			end,
		}
		if class_name == "UIGradient" then
			self.Color = globals.ColorSequence.new(Color3.new(1, 1, 1))
			self.Transparency = globals.NumberSequence.new(0)
			self.Rotation = 0
		elseif class_name == "UIStroke" then
			self.Color = Color3.new(0, 0, 0)
			self.Thickness = 1
		end
		return setmetatable(self, Instance)
	end,
}

local builtin_typeof = typeof
globals.typeof = function(value: any): string
	local metatable = type(value) == "table" and getmetatable(value)
	if metatable == Instance then
		return "Instance"
	elseif metatable == ColorSequence then
		return "ColorSequence"
	elseif metatable == NumberSequence then
		return "NumberSequence"
	elseif metatable == Color3 then
		return "Color3"
	end
	return builtin_typeof(value)
end

-- RunService

local Heartbeat = signal()
globals.game = {
	GetService = function(_, name: string)
		assert(name == "RunService", `the fake game has no {name}`)
		return { Heartbeat = Heartbeat }
	end,
}

return {
	made = made,
	-- fires Heartbeat once with `dt`
	step = function(dt: number)
		Heartbeat.fire(dt)
	end,
	heartbeats = function(): number
		return Heartbeat.count()
	end,
}

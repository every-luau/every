--!nonstrict
-- A stand-in for Lync, which needs the Roblox engine. its codecs only remember
-- how they were built, so tests can check which Lync codec a schema makes, and
-- `encode` keeps a copy of the value behind an id that `decode` gives back,
-- running the codec's validates like Lync does.

local Codec = {}
Codec.__index = Codec

local function make(kind, ...)
	return setmetatable({ kind = kind, args = table.pack(...), validates = {} }, Codec)
end

function Codec:validate(check)
	local copy = setmetatable(table.clone(self), Codec)
	copy.validates = table.clone(self.validates)
	table.insert(copy.validates, check)
	return copy
end

local function constructor(kind)
	return function(...)
		return make(kind, ...)
	end
end

local function deep_clone(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = deep_clone(item)
	end
	return copy
end

local stored = {}

local Lync = {
	bool = constructor("bool"),
	int = constructor("int"),
	quant = constructor("quant"),
	f64 = constructor("f64"),
	vlq = constructor("vlq"),
	vli = constructor("vli"),
	str = constructor("str"),
	buffer = constructor("buffer"),
	enum = constructor("enum"),
	struct = constructor("struct"),
	array = constructor("array"),
	map = constructor("map"),
	optional = constructor("optional"),
	tagged = constructor("tagged"),
	vec2 = constructor("vec2"),
	vec3 = constructor("vec3"),
	cframe = constructor("cframe"),
	color3 = constructor("color3"),
	inst = constructor("inst"),
	rotation = { quat = constructor("quat") },
}

function Lync.encode(_codec, value)
	table.insert(stored, deep_clone(value))
	local bytes = buffer.create(4)
	buffer.writeu32(bytes, 0, #stored)
	return bytes, nil
end

function Lync.decode(codec, bytes)
	local value = deep_clone(stored[buffer.readu32(bytes, 0)])
	for _, check in codec.validates do
		local reason = check(value, { player = nil, now = 0, last = nil })
		if reason then
			error(`decode refused the bytes: {reason}`, 2)
		end
	end
	return value
end

return Lync

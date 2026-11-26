--!nonstrict
-- A stand-in for Lync, which needs the Roblox engine. a replicated set keeps
-- the records the server writes, and `deliver` hands what changed to the
-- listeners, as the client `player` would see it, like a frame arriving

local Lync = {}

-- the client the records are delivered to
Lync.player = nil
Lync.all = table.freeze({ _all = true })

local function codec()
	return {}
end

Lync.vlq = codec
Lync.str = codec
Lync.f64 = codec
Lync.bool = codec
Lync.struct = codec

function Lync.define(_name, defs)
	return defs
end

Lync.flushes = 0
function Lync.flush()
	Lync.flushes += 1
end

local Group = {}
Group.__index = Group

function Group:add(player)
	self.members[player] = true
end

function Group:remove(player)
	self.members[player] = nil
end

function Group:has(player)
	return self.members[player] == true
end

function Group:destroy()
	table.clear(self.members)
	self.destroyed = true
end

function Lync.group()
	return setmetatable({ _group = true, members = {}, destroyed = false }, Group)
end

local function sees(to, player)
	if to == nil or player == nil then
		return false
	elseif to._all then
		return true
	elseif to._group then
		return to.members[player] == true
	end
	return to == player
end

local function same(a, b)
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end
	return true
end

local Set = {}
Set.__index = Set

local sets = {}

function Lync.replicate(_codec)
	local self = setmetatable({
		key_field = nil,
		records = {},
		audiences = {},
		view = {},
		added = {},
		changed = {},
		removed = {},
	}, Set)
	table.insert(sets, self)
	return self
end

function Set:keyBy(field)
	self.key_field = field
	return self
end

function Set:add(id, record)
	assert(self.records[id] == nil, "the id is already held")
	self.records[id] = table.clone(record)
end

function Set:update(id, fields)
	local record = assert(self.records[id], "no record under the id")
	for key, value in fields do
		record[key] = value
	end
end

function Set:remove(id)
	self.records[id] = nil
end

function Set:audience(key, to)
	self.audiences[key] = to
end

function Set:onAdded(fn)
	table.insert(self.added, fn)
end

function Set:onChanged(fn)
	table.insert(self.changed, fn)
end

function Set:onRemoved(fn)
	table.insert(self.removed, fn)
end

-- what the client sees now, compared with what it saw at the last delivery
function Lync.deliver()
	for _, set in sets do
		local visible = {}
		for id, record in set.records do
			if sees(set.audiences[record[set.key_field]], Lync.player) then
				visible[id] = record
			end
		end

		for id in set.view do
			if visible[id] == nil then
				set.view[id] = nil
				for _, fn in set.removed do
					fn(id, "removed")
				end
			end
		end

		for id, record in visible do
			local seen = set.view[id]
			if seen == nil then
				set.view[id] = table.clone(record)
				for _, fn in set.added do
					fn(id, table.clone(record))
				end
			elseif not same(record, seen) then
				set.view[id] = table.clone(record)
				for _, fn in set.changed do
					fn(id, table.clone(record), seen)
				end
			end
		end
	end
end

return Lync

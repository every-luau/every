--!nonstrict
-- A stand-in for Konsole, which needs the Roblox engine. it keeps the parts
-- Kernel uses: ranks with a resolver, commands defined and implemented by name,
-- a host that returns its RemoteFunction, and a dispatch that checks the rank,
-- converts arguments with `Arguments.types` and runs the implementation.

local ranks = {}
local labels = {}
local assignments = {}
local resolver = nil

local Ranks = {}

function Ranks.define(id, name, aliases)
	ranks[id] = { id = id, name = name }
	labels[string.lower(name)] = id
	for _, alias in aliases or {} do
		labels[string.lower(alias)] = id
	end
	return ranks[id]
end

function Ranks.resolve(value)
	if type(value) == "number" then
		return value
	end
	return tonumber(value) or labels[string.lower(tostring(value))]
end

function Ranks.get(entity)
	if entity == nil then
		return 0
	end
	if resolver then
		local ok, level = pcall(resolver, entity)
		if ok and type(level) == "number" then
			return level
		end
	end
	return assignments[entity.UserId] or 0
end

function Ranks.allows(entity, required)
	local id = Ranks.resolve(required)
	return id == nil or id <= 0 or Ranks.get(entity) >= id
end

function Ranks.set(user_id, rank)
	assignments[user_id] = Ranks.resolve(rank)
end

for _, rank in { { 0, "player" }, { 10, "helper" }, { 50, "moderator", { "mod" } }, { 100, "admin" } } do
	Ranks.define(rank[1], rank[2], rank[3])
end

local definitions = {}
local implementations = {}

local Kommand = {}

function Kommand.find(name)
	return definitions[string.lower(name)]
end

local Arguments = {
	types = {
		string = function(token)
			return true, token
		end,
		number = function(token)
			local value = tonumber(token)
			if value == nil then
				return false, `expected a number, got "{token}"`
			end
			return true, value
		end,
	},
}

local function fail(code, message)
	return { ok = false, code = code, message = message }
end

local Dispatch = {}

function Dispatch.execute(text, entity)
	local tokens = string.split(text, " ")
	local name = table.remove(tokens, 1)
	local command = definitions[string.lower(name or "")]

	if not command then
		return fail("unknown-command", `unknown command "{name}"`)
	end

	if not Ranks.allows(entity, command.rank) then
		return fail("not-authorized", `"{command.name}" requires rank {command.rank}+`)
	end

	local values = {}
	for index, argument in command.args or {} do
		local convert = Arguments.types[argument.type or "string"]
		local ok, value = convert(tokens[index], entity)
		if not ok then
			return fail("bad-argument", value)
		end
		values[index] = value
	end

	local run = if command.server then implementations[command.server] else command.run
	local context = {
		entity = entity,
		reply = function(message)
			return { ok = true, message = message }
		end,
		err = fail,
	}

	local ok, result = pcall(run, context, table.unpack(values))
	if not ok then
		return fail("command-error", tostring(result))
	end
	if type(result) == "table" then
		return result
	end
	return { ok = true, message = tostring(result or "Command completed.") }
end

local remote = { OnServerInvoke = nil }

local Konsole = {
	Ranks = Ranks,
	Kommand = Kommand,
	Arguments = Arguments,
	Dispatch = Dispatch,
}

function Konsole.define(definition)
	local command = table.clone(definition)
	command.name = string.lower(definition.name)
	command.rank = Ranks.resolve(definition.rank or 0)
	definitions[command.name] = command
	return command
end

function Konsole.implement(name, callback)
	implementations[name] = callback
end

function Konsole.host()
	return remote
end

function Konsole.bindRanks(fn)
	resolver = fn
end

function Konsole.getRank(entity)
	return Ranks.get(entity)
end

function Konsole.run(text)
	return Dispatch.execute(text, nil)
end

-- for tests: what a client sends through the remote
function Konsole.invoke(player, text)
	return remote.OnServerInvoke(player, text)
end

return Konsole

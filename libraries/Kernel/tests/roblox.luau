--!nonstrict
-- Minimal stand-in for the Roblox globals the library and its dependencies use,
-- since lest's native backend has none: players with group ranks, game passes,
-- the signals Kernel listens to, and tasks where delays only run on `flush`.
--
-- `script.Parent.Konsole` is the stand-in in `tests/konsole.luau`, and any other
-- `script.Parent.Name` resolves to the `Name` library next to this one, the same
-- way package managers put dependencies next to each other.

local queued = {}

local function spawn(callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	local ok, message = coroutine.resume(thread, ...)
	if not ok then
		error(message, 0)
	end
	return thread
end

local function queue(callback, ...)
	local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
	table.insert(queued, { thread = thread, args = table.pack(...) })
	return thread
end

local function flush()
	local entries = table.clone(queued)
	table.clear(queued)
	for _, entry in entries do
		spawn(entry.thread, table.unpack(entry.args, 1, entry.args.n))
	end
end

local function signal()
	local listeners = {}
	return {
		Connect = function(_, listener)
			listeners[listener] = true
			return {
				Disconnect = function()
					listeners[listener] = nil
				end,
			}
		end,
		fire = function(_, ...)
			for listener in table.clone(listeners) do
				listener(...)
			end
		end,
	}
end

local Player = {}
Player.__index = Player

function Player:IsA(class_name)
	return class_name == "Player" or class_name == "Instance"
end

function Player:GetRankInGroupAsync(group)
	local calls = self._group_calls
	calls[group] = (calls[group] or 0) + 1
	if self._groups_fail then
		error("HTTP 500")
	end
	return self._groups[group] or 0
end

local function new_player(user_id, options)
	options = options or {}
	return setmetatable({
		UserId = user_id,
		Name = `Player{user_id}`,
		_groups = options.groups or {},
		_passes = options.passes or {},
		_groups_fail = options.groups_fail or false,
		_group_calls = {},
	}, Player)
end

local Players = { PlayerRemoving = signal() }

local MarketplaceService = { PromptGamePassPurchaseFinished = signal() }

function MarketplaceService:UserOwnsGamePassAsync(_user_id, _pass)
	error("replaced per player below")
end

local players_by_id = {}

local function add_player(user_id, options)
	local player = new_player(user_id, options)
	players_by_id[user_id] = player
	return player
end

MarketplaceService.UserOwnsGamePassAsync = function(_, user_id, pass)
	local player = players_by_id[user_id]
	return player ~= nil and table.find(player._passes, pass) ~= nil
end

local services = {
	Players = Players,
	MarketplaceService = MarketplaceService,
	RunService = {
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
	},
}

local globals = _G :: any
local builtin_typeof = typeof
globals.typeof = function(value)
	if type(value) == "table" and getmetatable(value) == Player then
		return "Instance"
	end
	return builtin_typeof(value)
end
globals.task = {
	spawn = spawn,
	defer = queue,
	delay = function(_seconds, callback, ...)
		return queue(callback, ...)
	end,
	cancel = function() end,
	wait = function()
		return 0
	end,
}
globals.game = {
	Destroy = function(instance)
		instance:Destroy()
	end,
	GetService = function(_, name)
		return services[name]
	end,
}
globals.script = {
	Parent = setmetatable({ Konsole = "../tests/konsole" }, {
		__index = function(_, name: string)
			return `../../{name}/src`
		end,
	}),
}

return {
	flush = flush,
	add_player = add_player,
	Players = Players,
	MarketplaceService = MarketplaceService,
}

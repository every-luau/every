--[=[
	@class Kernel

	Kernel adds roles, commands and a log on top of the [Konsole](https://github.com/KYRORBLX/Konsole) command console

	give roles to players by user id, group rank, game pass or your own check,
	then make commands that need one of them. Konsole parses, checks the rank and
	shows the console, and Kernel resolves the roles, limits how fast a player
	sends commands and logs every command run on the server

	```lua
	local Kernel = require(path.to.Kernel)

	Kernel.role("moderator", 50, { groups = { [1234] = 200 } })
	Kernel.role("vip", 5, { passes = { 5678 } })

	Kernel.command({
		name = "coins",
		description = "Gives coins to a player",
		rank = "moderator",
		args = {
			{ name = "target", type = "player" },
			{ name = "amount", type = "number" },
		},
		run = function(context, target, amount)
			give_coins(target, amount)
			return `gave {amount} coins to {target.Name}`
		end,
	})

	Kernel.executed:connect(function(entry)
		print(entry.player, entry.text, entry.ok)
	end)

	Kernel.start()
	```

	:::info
	Konsole ranks are numbers, and a command runs for a player whose rank is at
	least its own. Konsole already has the ranks player (0), helper (10),
	moderator (50), admin (100) and creator (1000), and a [Kernel.role] with the
	same level replaces one. players without a role fall back to
	`Konsole.setRank`, and the game creator and Studio get every rank
	:::
]=]

const MarketplaceService = game:GetService("MarketplaceService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Konsole = require(script.Parent.Konsole)
const Ratelimit = require(script.Parent.Ratelimit)
const Signal = require(script.Parent.Signal)

export type Context = Konsole.Context
export type Outcome = Konsole.Outcome
export type Signal<T...> = Signal.Signal<T...>

--[=[
	@within Kernel
	@interface Rules
	.users { number }? -- user ids that have the role
	.groups { [number]: number }? -- group ids, each with the lowest rank in it that has the role
	.passes { number }? -- game pass ids whose owners have the role
	.check ((player: Player) -> boolean)? -- your own check, which can yield
	.aliases { string }? -- other names the role can be written with

	who has a role. a player has it when any rule matches
]=]
export type Rules = {
	users: { number }?,
	groups: { [number]: number }?,
	passes: { number }?,
	check: ((player: Player) -> boolean)?,
	aliases: { string }?,
}

--[=[
	@within Kernel
	@interface Argument
	.name string? -- shown in the console hints
	.type string? -- string, number, boolean, player, players, or one added with Kernel.type
	.required boolean? -- false to make it optional
	.default any? -- used when it is left out
	.suggestions ({ string } | string)? -- what the console suggests for it

	one argument of a command, the same as in Konsole
]=]
export type Argument = {
	name: string?,
	type: string?,
	required: boolean?,
	default: any,
	suggestions: ({ string } | string)?,
}

--[=[
	@within Kernel
	@interface Command
	.name string
	.run (context: Context, ...any) -> any -- gets the parsed arguments after the context
	.description string?
	.aliases { string }?
	.rank (number | string)? -- the lowest level or role name that can run it, 0 when not given
	.cooldown number? -- seconds between two runs by the same player
	.args { Argument }?

	a command. `run` returns nil for a plain success, a string to reply with, or
	`context.reply(message)` and `context.err(code, message)`
]=]
export type Command = {
	name: string,
	run: (context: Context, ...any) -> any,
	description: string?,
	aliases: { string }?,
	rank: (number | string)?,
	cooldown: number?,
	args: { Argument }?,
}

--[=[
	@within Kernel
	@interface Entry
	.player Player? -- who ran it, nil when the server did
	.text string -- what was typed
	.command string? -- the name of the command, nil when none matched
	.ok boolean
	.code string? -- why it failed, like not-authorized, bad-argument, cooldown or ratelimit
	.message string
	.time number -- os.time() when it ran

	one command run on the server, see [Kernel.executed]
]=]
export type Entry = {
	player: Player?,
	text: string,
	command: string?,
	ok: boolean,
	code: string?,
	message: string,
	time: number,
}

--[=[
	@within Kernel
	@interface Options
	.limit number? -- commands a player can send per interval, 10 when not given
	.interval number? -- seconds, 10 when not given

	how [Kernel.start] limits players
]=]
export type Options = {
	limit: number?,
	interval: number?,
}

type Role = {
	name: string,
	level: number,
	rules: Rules,
}

const Kernel = {}

const roles: { [string]: Role } = {}

-- the level each player resolved to, or false when no role matched
const levels: { [Player]: number | false } = setmetatable({}, { __mode = "k" }) :: any

local started = false

--[=[
	@within Kernel
	@prop executed Signal<Entry>
	@readonly

	fires on the server after every command a player or [Kernel.run] runs, even
	the ones refused
]=]
const executed: Signal<Entry> = Signal.new()
Kernel.executed = executed

--[=[
	@within Kernel
	@prop Konsole Konsole
	@readonly

	the Konsole module Kernel runs on, to show the console, change its keys or
	read its ranks
]=]
Kernel.Konsole = Konsole

-- whether `player` matches `rules`, and whether a check failed to answer
const function matches(player: Player, rules: Rules): (boolean, boolean)
	if rules.users and table.find(rules.users, player.UserId) then
		return true, false
	end

	local failed = false

	for group, lowest in rules.groups or {} do
		const ok, rank = pcall(player.GetRankInGroupAsync, player, group)
		if not ok then
			failed = true
		elseif rank >= lowest then
			return true, false
		end
	end

	for _, pass in rules.passes or {} do
		const ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass)
		if not ok then
			failed = true
		elseif owns then
			return true, false
		end
	end

	const check = rules.check
	if check then
		const ok, allowed = pcall(check, player)
		if not ok then
			failed = true
		elseif allowed then
			return true, false
		end
	end

	return false, failed
end

-- the highest level among the roles of `player`, or nil when none matched
const function resolve(entity: any): number?
	if typeof(entity) ~= "Instance" or not (entity :: Instance):IsA("Player") then
		return nil
	end

	const player = entity :: Player
	const cached = levels[player]
	if cached ~= nil then
		return cached or nil
	end

	local best: number? = nil
	local failed = false

	for _, role in roles do
		if best == nil or role.level > best then
			const matched, role_failed = matches(player, role.rules)
			failed = failed or role_failed
			if matched then
				best = role.level
			end
		end
	end

	-- a failed web call is asked again next time instead of being remembered
	if not failed then
		levels[player] = best or false
	end

	return best
end

const function first_word(text: string): string?
	return string.match(text, "^%s*(%S+)")
end

const function execute(text: string, player: Player?): Outcome
	const outcome = Konsole.Dispatch.execute(text, player)
	const word = first_word(text)
	const command = if word then Konsole.Kommand.find(word) else nil

	executed:fire({
		player = player,
		text = text,
		command = if command then command.name else nil,
		ok = outcome.ok ~= false,
		code = outcome.code,
		message = tostring(outcome.message or ""),
		time = os.time(),
	})

	return outcome
end

--[=[
	@within Kernel
	@function role
	@param name string
	@param level number
	@param rules Rules?

	gives the players matching `rules` the rank `level`, which commands can ask
	for by its number or by `name`. a player with several roles gets the highest.
	define roles before the commands that name them

	```lua
	Kernel.role("admin", 100, { users = { 1, 2 } })
	Kernel.role("moderator", 50, { groups = { [1234] = 200 }, aliases = { "mod" } })
	Kernel.role("tester", 20, {
		check = function(player)
			return player:GetAttribute("Tester") == true
		end,
	})
	```
]=]
function Kernel.role(name: string, level: number, rules: Rules?)
	const given: Rules = rules or {}
	Konsole.Ranks.define(level, name, given.aliases)
	roles[string.lower(name)] = { name = name, level = level, rules = given }
	table.clear(levels)
end

--[=[
	@within Kernel
	@function command
	@param command Command
	@return Konsole.Command

	makes a command. made on the server, it runs on the server and every client
	can type it. made on a client, it only runs on that client
]=]
function Kernel.command(command: Command): Konsole.Command
	assert(type(command.run) == "function", `the command "{command.name}" needs a run function`)

	const definition: Konsole.Definition = {
		name = command.name,
		aliases = command.aliases,
		description = command.description,
		rank = command.rank,
		cooldown = command.cooldown,
		args = command.args :: any,
	}

	if RunService:IsServer() then
		const server = `kernel:{string.lower(command.name)}`
		Konsole.implement(server, command.run)
		definition.server = server
	else
		definition.run = command.run
	end

	return Konsole.define(definition)
end

--[=[
	@within Kernel
	@function type
	@param name string
	@param convert (token: string, caller: Player?) -> (boolean, any)

	adds an argument type commands can use. `convert` returns true and the value,
	or false and why the text does not fit. add it on the side the command runs on

	```lua
	Kernel.type("team", function(token)
		local team = Teams:FindFirstChild(token)
		if team then
			return true, team
		end
		return false, `no team named "{token}"`
	end)
	```
]=]
function Kernel.type(name: string, convert: (token: string, caller: Player?) -> (boolean, any))
	Konsole.Arguments.types[string.lower(name)] = convert
end

--[=[
	@within Kernel
	@function level
	@param player Player
	@return number

	returns the rank of `player`
]=]
function Kernel.level(player: Player): number
	return Konsole.getRank(player)
end

--[=[
	@within Kernel
	@function allows
	@param player Player
	@param rank number | string
	@return boolean

	returns whether `player` has at least `rank`, a level or a role name
]=]
function Kernel.allows(player: Player, rank: number | string): boolean
	return Konsole.Ranks.allows(player, rank)
end

--[=[
	@within Kernel
	@function refresh
	@param player Player

	forgets the roles of `player`, so they are resolved again on their next
	command. Kernel does it on its own when they buy a game pass
]=]
function Kernel.refresh(player: Player)
	levels[player] = nil
end

--[=[
	@within Kernel
	@function run
	@param text string
	@param player Player?
	@return Outcome

	runs a command as if `player` typed it. without a player Konsole gives rank 0,
	so only commands of rank 0 run. on the server it is logged in
	[Kernel.executed]
]=]
function Kernel.run(text: string, player: Player?): Outcome
	if RunService:IsServer() then
		return execute(text, player)
	end
	return Konsole.run(text)
end

--[=[
	@within Kernel
	@function start
	@param options Options?

	starts Konsole on the server with the roles, the rate limit and the log.
	call it once, after making the commands. clients only need to require Kernel
	or Konsole to get the console
]=]
function Kernel.start(options: Options?)
	assert(RunService:IsServer(), "Kernel.start can only be called on the server")
	assert(not started, "Kernel.start was already called")
	started = true

	const given: Options = options or {}
	const allow = Ratelimit(given.limit or 10, given.interval or 10)

	Konsole.bindRanks(resolve)

	const bridge = Konsole.host()
	if bridge then
		bridge.OnServerInvoke = function(player: Player, text: unknown): any
			if type(text) ~= "string" then
				return { ok = false, code = "bad-request", message = "expected the command as text" }
			end

			if not allow(player) then
				const outcome = { ok = false, code = "ratelimit", message = "too many commands, slow down" }
				executed:fire({
					player = player,
					text = text,
					command = nil,
					ok = false,
					code = outcome.code,
					message = outcome.message,
					time = os.time(),
				})
				return outcome
			end

			return execute(text, player)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		levels[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, _pass: number, purchased: boolean)
		if purchased then
			levels[player] = nil
		end
	end)
end

return table.freeze(Kernel)

--!strict
-- Roles, a few commands and a log, in a server script.

local Teams = game:GetService("Teams")

local Kernel = require("../src")

-- Who has which rank.
Kernel.role("admin", 100, { users = { 1, 2 } })
Kernel.role("moderator", 50, { groups = { [1234] = 200 }, aliases = { "mod" } })
Kernel.role("vip", 5, { passes = { 5678 } })

-- An argument type of your own.
Kernel.type("team", function(token)
	local team = Teams:FindFirstChild(token)
	if team then
		return true, team
	end
	return false, `no team named "{token}"`
end)

Kernel.command({
	name = "team",
	description = "Moves a player to a team",
	rank = "mod",
	args = {
		{ name = "target", type = "player" },
		{ name = "team", type = "team" },
	},
	run = function(_context, target: Player, team: Team)
		target.Team = team
		return `moved {target.Name} to {team.Name}`
	end,
})

Kernel.command({
	name = "fly",
	description = "Lets a VIP fly for a minute",
	rank = "vip",
	cooldown = 300,
	run = function(context)
		local player = context.entity :: Player
		player:SetAttribute("Flying", true)
		task.delay(60, player.SetAttribute, player, "Flying", false)
		return nil
	end,
})

-- Every command run on the server, refused or not.
Kernel.executed:connect(function(entry)
	local who = if entry.player then entry.player.Name else "server"
	print(`[{who}] {entry.text} -> {if entry.ok then "ok" else entry.code}`)
end)

Kernel.start({ limit = 10, interval = 10 })

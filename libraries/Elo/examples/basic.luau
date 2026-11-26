--!strict
-- Rating the players of a duel game, saved in their attributes.

local Players = game:GetService("Players")

local Elo = require("../src")

local config = Elo.new():set_k(24):set_initial(1000):set_floor(0)

local function rating(player: Player): number
	local saved: number? = player:GetAttribute("Rating") :: any
	return saved or config:get_initial()
end

-- Results are from the first player: here the winner.
local function on_duel_won(winner: Player, loser: Player)
	local won, lost = Elo.rate(config, rating(winner), rating(loser), Elo.WIN)
	print(`{winner.Name} +{math.round(won - rating(winner))}, {loser.Name} {math.round(lost - rating(loser))}`)
	winner:SetAttribute("Rating", won)
	loser:SetAttribute("Rating", lost)
end

-- What a win would bring, shown before the duel.
local function preview(player: Player, opponent: Player)
	local reward = Elo.change(config, rating(player), rating(opponent), Elo.WIN)
	local chance = Elo.expected(config, rating(player), rating(opponent))
	print(`{math.round(chance * 100)}% to win, +{math.round(reward)} if you do`)
end

-- A rank from the rating: the share of players below it.
Players.PlayerAdded:Connect(function(player)
	print(`{player.Name} is above {math.round(Elo.percentile(config, rating(player)) * 100)}% of players`)
end)

local players = Players:GetPlayers()
if #players >= 2 then
	preview(players[1], players[2])
	on_duel_won(players[1], players[2])
end

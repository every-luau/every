--!strict
-- A speedrun timer for each player, sent only to them under the same name: it starts on the start
-- line, stops on the finish line, and goes back to 0 when they die.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Clock = require("../src")

if RunService:IsServer() then
	local timers: { [Player]: Clock.Clock } = {}

	local function player_of(hit: BasePart): Player?
		local character = hit:FindFirstAncestorOfClass("Model")
		return if character then Players:GetPlayerFromCharacter(character) else nil
	end

	Players.PlayerAdded:Connect(function(player)
		local timer = Clock.new():replicate("Run", player)
		timers[player] = timer

		player.CharacterAdded:Connect(function()
			timer:reset()
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local timer = timers[player]
		if timer then
			timer:destroy()
			timers[player] = nil
		end
	end)

	local start = workspace:WaitForChild("Start") :: BasePart
	local finish = workspace:WaitForChild("Finish") :: BasePart

	start.Touched:Connect(function(hit)
		local player = player_of(hit)
		local timer = player and timers[player]
		if timer and not timer:is_playing() then
			timer:set_time(0):start()
		end
	end)

	finish.Touched:Connect(function(hit)
		local player = player_of(hit)
		local timer = player and timers[player]
		if player and timer and timer:is_playing() then
			timer:stop()
			print(`{player.Name} finished in {string.format("%.2f", timer:get_time())} seconds`)
		end
	end)
else
	-- Each client only sees its own, and it runs smoothly without the server sending anything.
	local timer = Clock.get("Run"):await()

	timer:observe(function(time)
		print(string.format("%.2f", time))
	end)
end

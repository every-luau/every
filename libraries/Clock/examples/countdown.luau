--!strict
-- A round that counts down from 120 for every player, sent once and followed on each client.

local RunService = game:GetService("RunService")

local Clock = require("../src")

if RunService:IsServer() then
	local round = Clock.new():set_time(120):set_speed(-1):start():replicate("Round")

	round:at(30, function()
		print("30 seconds left")
	end)

	round:at(0, function()
		round:stop()
		print("round over")
	end)

	-- Slow motion for everyone, sent as one change.
	task.delay(10, function()
		round:set_speed(-0.5)
	end)
else
	local round = Clock.get("Round"):await()

	-- Every frame while it runs.
	round:observe(function(time)
		print(string.format("%.1f", math.max(time, 0)))
	end)

	-- Or once a second, through an Atom.
	round:atom():map(math.ceil):changed():listen(function(seconds)
		print(`{seconds} seconds left`)
	end)
end

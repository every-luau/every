--!strict
-- Limiting how often players can use a remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ratelimit = require("../src")

-- 3 calls per player every 10 seconds.
local can_buy = Ratelimit(3, 10)

ReplicatedStorage.Buy.OnServerEvent:Connect(function(player, item)
	if not can_buy(player) then
		return
	end
	print(`{player.Name} bought {item}`)
end)

-- Without a key, every call counts for the same shared key.
local can_announce = Ratelimit.new(1, 60)
print(can_announce()) --> true
print(can_announce()) --> false

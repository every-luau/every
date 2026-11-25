--!strict
-- Wrapping streams in observables, and using the brio of each value or item.

local Players = game:GetService("Players")

local Observable = require("../src")
local Stream = require("../../Stream/src")

-- A life stream gives a brio per item: here one per player, killed when they
-- leave. The Void of a brio is only made when asked for.
Observable.new(Stream.players()):subscribe(function(brio)
	local void, player = brio:to_void_and_value()
	print(`{player.Name} joined`)
	void:add(function()
		print(`{player.Name} left`)
	end)
end)

-- A stream gives a brio per value, killed when the next one comes.
local gravity = Observable.new(Stream.property(workspace, "Gravity"))
gravity:subscribe(function(brio)
	local value = brio:get_value()
	print("gravity is", value)
end)

-- filter still kills the brio of the value before, so this warning only lasts
-- while the health is low.
local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

local connection = Observable.new(Stream.property(humanoid, "Health"))
	:filter(function(health: number)
		return health < 20
	end)
	:map(function(health: number)
		return math.floor(health)
	end)
	:changed()
	:subscribe(function(brio)
		local void, health = brio:to_void_and_value()
		warn(`low health: {health}`)
		void:add(function()
			print("health is fine again, or changed")
		end)
	end)

-- Disconnecting kills every brio it gave.
task.delay(30, function()
	connection:disconnect()
	gravity:destroy()
end)

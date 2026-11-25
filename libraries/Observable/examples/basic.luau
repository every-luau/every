--!strict
-- Following sets of things that come and go, with a brio for each item.

local Players = game:GetService("Players")

local Observable = require("../src")
local Stream = require("../../Stream/src")

-- A producer emits (item, true) when an item joins and (item, false) when it
-- leaves. Here, every player in the game.
local players = Observable.new(function(emit, void)
	void:add(Players.PlayerAdded:Connect(function(player)
		emit(player, true)
	end))
	void:add(Players.PlayerRemoving:Connect(function(player)
		emit(player, false)
	end))
	for _, player in Players:GetPlayers() do
		emit(player, true)
	end
end)

-- A brio per player, killed when they leave. Its Void is only made when
-- asked for.
players:subscribe(function(brio)
	local void, player = brio:to_void_and_value()
	print(`{player.Name} joined`)
	void:add(function()
		print(`{player.Name} left`)
	end)
end)

-- flat_map follows something for each item: here the character of each
-- player, from a Stream of their current character.
local characters = players:flat_map(function(player: Player)
	return Observable.from_stream(Stream.character(player))
end)
characters:subscribe(function(brio)
	local character = brio:get_value()
	print(`{character.Name} spawned`)
end)

-- count gives a Stream of how many items there are.
local connection = players:count():listen(function(count: number)
	print(`{count} players`)
end)

-- A Stream's latest value is the only item of from_stream, so the brio lives
-- until the value changes. filter still replaces the value before.
Observable.from_stream(Stream.property(workspace, "Gravity"))
	:filter(function(gravity: number)
		return gravity < 100
	end)
	:subscribe(function(brio)
		local void, gravity = brio:to_void_and_value()
		print(`low gravity: {gravity}`)
		void:add(function()
			print("gravity changed")
		end)
	end)

-- Disconnecting stops, and destroy disconnects every subscription.
task.delay(30, function()
	connection:disconnect()
	players:destroy()
end)

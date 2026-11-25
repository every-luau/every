--!strict
-- Following values over time with streams.

local Players = game:GetService("Players")

local Stream = require("../src")

-- Chain methods to make new streams, then listen. Listening returns a
-- Connection that stops it.
local connection = Stream.of(1, 2, 3, 4)
	:filter(function(n)
		return n % 2 == 0
	end)
	:map(function(n)
		return n * 10
	end)
	:listen(print) --> 20, 40
connection:disconnect()

-- A state holds a value: listening emits it, and setting it emits again.
local hovered = Stream.state(false)
hovered:listen(function(is_hovered)
	print("hovered", is_hovered)
end)
hovered:set(true)

-- child and property follow "the current" instance: here the Health of each
-- new character's Humanoid, dropping the old one when the character changes.
-- methods that change the type return an untyped stream, so annotate it.
local health: Stream.Stream<number?> = Stream.character(Players.LocalPlayer):child("Humanoid"):property("Health")
health:listen(print)

-- each calls back with a Void cleaned when the value is replaced.
Stream.property(workspace, "Gravity"):each(function(gravity, void)
	print("gravity is", gravity)
	void:add(function()
		print("gravity was", gravity)
	end)
end)

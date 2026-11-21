--!nonstrict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local Observe = require("../src")

-- lest only resolves requires while the spec loads, so every module is
-- required here
local modules = {}
for name in Observe do
	modules[name] = require(`../src/{name}`)
end

-- observes with `observe`, recording "+name" when the callback runs and "-name"
-- when its void is cleaned
local function journal(observe: (callback: (...any) -> ()) -> any): ({ string }, any)
	local events: { string } = {}
	local connection = observe(function(...)
		local args = { ... }
		local void = args[#args]
		local name = tostring(args[#args - 1])
		table.insert(events, `+{name}`)
		void:add(function()
			table.insert(events, `-{name}`)
		end)
	end)
	return events, connection
end

describe("Observe", function()
	it("observes current and future children until removed", function()
		local folder = roblox.new("Folder", "Folder")
		roblox.new("Part", "A", folder)

		local events, connection = journal(function(callback)
			return Observe.children(folder, callback)
		end)

		local b = roblox.new("Part", "B", folder)
		b.Parent = nil
		expect(events).toEqual({ "+A", "+B", "-B" })

		connection:disconnect()
		expect(events).toEqual({ "+A", "+B", "-B", "-A" })
		roblox.new("Part", "C", folder)
		expect(#events).toBe(4)
	end)

	it("filters with the predicate", function()
		local folder = roblox.new("Folder", "Folder")
		roblox.new("Part", "Keep", folder)
		roblox.new("Folder", "Skip", folder)

		local events = journal(function(callback)
			return Observe.children(folder, callback, function(child)
				return child:IsA("BasePart")
			end)
		end)

		expect(events).toEqual({ "+Keep" })
	end)

	it("observes descendants", function()
		local root = roblox.new("Folder", "Root")
		local inner = roblox.new("Folder", "Inner", root)
		local events = journal(function(callback)
			return Observe.descendants(root, callback)
		end)

		roblox.new("Part", "Deep", inner)
		inner.Parent = nil
		expect(events).toEqual({ "+Inner", "+Deep", "-Inner", "-Deep" })
	end)

	it("observes properties, cleaning the previous value", function()
		local part = roblox.new("Part", "Part")
		part.Color = "red"

		local events = journal(function(callback)
			return Observe.property(part, "Color", callback)
		end)

		part.Color = "blue"
		expect(events).toEqual({ "+red", "-red", "+blue" })
	end)

	it("cleans the previous value even when the new one is filtered out", function()
		local part = roblox.new("Part", "Part")
		part:SetAttribute("Level", 1)

		local events = journal(function(callback)
			return Observe.attribute(part, "Level", callback, function(value)
				return value ~= nil
			end)
		end)

		part:SetAttribute("Level", nil)
		part:SetAttribute("Level", 2)
		expect(events).toEqual({ "+1", "-1", "+2" })
	end)

	it("observes tags", function()
		local part = roblox.new("Part", "Lava")
		local events = journal(function(callback)
			return Observe.tag("Lava", callback)
		end)

		roblox.add_tag(part, "Lava")
		roblox.remove_tag(part, "Lava")
		expect(events).toEqual({ "+Lava", "-Lava" })
	end)

	it("observes players and characters", function()
		local players = journal(function(callback)
			return Observe.players(callback)
		end)
		local characters = journal(function(callback)
			return Observe.characters(callback)
		end)

		local player = roblox.add_player("Bob")
		roblox.spawn_character(player)
		roblox.spawn_character(player)
		roblox.remove_player(player)

		expect(players).toEqual({ "+Bob", "-Bob" })
		expect(characters).toEqual({ "+Bob", "-Bob", "+Bob", "-Bob" })
	end)

	it("passes the player to the characters predicate", function()
		local seen: { string } = {}
		Observe.characters(function(player)
			table.insert(seen, player.Name)
		end, function(player)
			return player.Name == "Kept"
		end)

		roblox.spawn_character(roblox.add_player("Kept"))
		roblox.spawn_character(roblox.add_player("Skipped"))
		expect(seen).toEqual({ "Kept" })
	end)

	it("keeps a tool while it moves between the backpack and the character", function()
		local player = roblox.add_player("Alice")
		local character = roblox.spawn_character(player)

		local events = journal(function(callback)
			return Observe.tools(player, callback)
		end)

		local sword = roblox.new("Tool", "Sword", player:FindFirstChildOfClass("Backpack"))
		sword.Parent = character
		sword.Parent = player:FindFirstChildOfClass("Backpack")
		expect(events).toEqual({ "+Sword" })

		sword.Parent = roblox.workspace
		expect(events).toEqual({ "+Sword", "-Sword" })
	end)

	it("follows the new backpack after a respawn", function()
		local player = roblox.add_player("Carl")
		roblox.spawn_character(player)

		local events = journal(function(callback)
			return Observe.tools(player, callback)
		end)

		roblox.new("Tool", "Old", player:FindFirstChildOfClass("Backpack"))
		roblox.spawn_character(player)
		roblox.new("Tool", "New", player:FindFirstChildOfClass("Backpack"))

		expect(events).toEqual({ "+Old", "-Old", "+New" })
	end)

	it("exposes every observer as its own module", function()
		for name, observer in Observe do
			expect(modules[name]).toBe(observer)
		end
	end)

	it("errors for the local player on the server", function()
		expect(function()
			Observe.local_character(print)
		end).toThrow("only exists on the client")
	end)
end)

return nil

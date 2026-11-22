--!strict
-- A shop zone that opens a menu for the players inside it.

local Players = game:GetService("Players")

local Region = require("../src")

local zone = workspace:WaitForChild("ShopZone") :: BasePart

-- Takes the position, orientation and shape of the zone part.
local shop = Region.new()
	:set_part(zone)
	-- Reports players instead of their body parts.
	:set_rule(function(part)
		return Players:GetPlayerFromCharacter(part.Parent :: Model)
	end)

shop.entered:connect(function(player)
	print(`{player.Name} entered the shop`)
end)

-- The void is cleaned when the player leaves the zone.
shop:observe(function(player, void)
	local menu = void:add(Instance.new("ScreenGui"))
	menu.Parent = player.PlayerGui
end)

-- Ignores players who are not on a team.
shop:where(function(player)
	return player.Team ~= nil
end)

print(shop:contains_point(zone.Position)) --> true

-- Any Bolt shape works, like a sphere around the shop.
local nearby = Region.new()
	:set_position(zone.Position)
	:set_shape(Region.Bolt.create_sphere(30))

print(nearby:contains_region(shop)) --> true when the zone fits in the sphere

-- A zone like this doesn't need to check every frame.
shop:set_interval(0.25)

-- Stops checking on its own without losing who is inside, until it is enabled
-- again. step still checks right away.
shop:disable()
shop:step()
shop:enable()

-- A hitbox in front of a part that moves, only checking characters.
local handle = workspace:WaitForChild("SwordHandle") :: BasePart
local hitbox = Region.new()
	:set_size(Vector3.new(1, 1, 4))
	:follow(handle, CFrame.new(0, 0, -2))
	:set_root(workspace:WaitForChild("Characters"))
hitbox.entered:connect(function(part)
	print(`hit {part:GetFullName()}`)
end)
hitbox:destroy()

shop:destroy()
nearby:destroy()

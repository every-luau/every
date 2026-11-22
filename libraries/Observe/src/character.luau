const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

--[=[
	@within Observe
	@function character
	@param player Player
	@param callback (character: Model, void: Void) -> ()
	@param predicate ((character: Model) -> boolean)?
	@return Connection

	calls `callback` for the character of `player`, now and on every spawn, if
	`predicate` accepts it. the void is cleaned when the character is removed,
	on respawn or when observing stops
]=]
return function(
	player: Player,
	callback: (character: Model, void: Void.Void) -> (),
	predicate: ((character: Model) -> boolean)?
): Connection.Connection
	const void = Void.new()
	local character_void: Void.Void? = nil

	const function removed()
		const removed_void = character_void
		if removed_void then
			character_void = nil
			void:clean_item(removed_void)
		end
	end

	const function added(character: Model)
		removed()
		if predicate and not predicate(character) then
			return
		end

		const added_void = void:extend()
		character_void = added_void
		Thread(callback, character, added_void)
	end

	void:add(player.CharacterAdded:Connect(added))
	void:add(player.CharacterRemoving:Connect(removed))

	if player.Character then
		added(player.Character)
	end

	return Connection.new(void)
end

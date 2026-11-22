const Players = game:GetService("Players")

const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

--[=[
	@within Observe
	@function players
	@param callback (player: Player, void: Void) -> ()
	@param predicate ((player: Player) -> boolean)?
	@return Connection

	calls `callback` for every player in the game, now and later, that
	`predicate` accepts. the void is cleaned when the player leaves

	```lua
	Observe.players(function(player, void)
		local leaderstats = void:add(Instance.new("Folder"))
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end)
	```
]=]
return function(
	callback: (player: Player, void: Void.Void) -> (),
	predicate: ((player: Player) -> boolean)?
): Connection.Connection
	const void = Void.new()
	const voids: { [Player]: Void.Void } = {}

	const function add(player: Player)
		if voids[player] or (predicate and not predicate(player)) then
			return
		end

		const player_void = void:extend()
		voids[player] = player_void
		Thread(callback, player, player_void)
	end

	void:add(Players.PlayerAdded:Connect(add))
	void:add(Players.PlayerRemoving:Connect(function(player)
		const player_void = voids[player]
		if player_void then
			voids[player] = nil
			void:clean_item(player_void)
		end
	end))

	for _, player in Players:GetPlayers() do
		add(player)
	end

	return Connection.new(void)
end

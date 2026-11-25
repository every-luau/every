const Players = game:GetService("Players")

const Observable = require(script.Parent.Parent.Observable)

const character = require("./character")

--[=[
	@within Observe
	@function local_character
	@return Observable<Model>
	@error "Observe.local_character only exists on the client"

	[Observe.character] for the local player, on the client
]=]
return function(): Observable.Observable<Model>
	const player = Players.LocalPlayer
	if not player then
		error("Observe.local_character only exists on the client", 2)
	end

	return character(player)
end

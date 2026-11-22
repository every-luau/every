const UserInputService = game:GetService("UserInputService")

const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

const property = require("./property")

--[=[
	@within Observe
	@function preferred_input
	@param callback (preferred_input: Enum.PreferredInput, void: Void) -> ()
	@param predicate ((preferred_input: Enum.PreferredInput) -> boolean)?
	@return Connection

	[Observe.property] for `UserInputService.PreferredInput`, the input the
	player is using, like a gamepad or touch

	```lua
	Observe.preferred_input(function(input, void)
		if input == Enum.PreferredInput.Touch then
			void:add(show_mobile_buttons())
		end
	end)
	```
]=]
return function(
	callback: (preferred_input: Enum.PreferredInput, void: Void.Void) -> (),
	predicate: ((preferred_input: Enum.PreferredInput) -> boolean)?
): Connection.Connection
	return property(UserInputService, "PreferredInput", callback, predicate)
end

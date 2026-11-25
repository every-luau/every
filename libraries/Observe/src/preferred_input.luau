const UserInputService = game:GetService("UserInputService")

const Observable = require(script.Parent.Parent.Observable)

const property = require("./property")

--[=[
	@within Observe
	@function preferred_input
	@return Observable<Enum.PreferredInput>

	[Observe.property] for `UserInputService.PreferredInput`, the input the
	player is using, like a gamepad or touch

	```lua
	Observe.preferred_input():subscribe(function(brio)
		local void, input = brio:to_void_and_value()
		if input == Enum.PreferredInput.Touch then
			void:add(show_mobile_buttons())
		end
	end)
	```
]=]
return function(): Observable.Observable<Enum.PreferredInput>
	return property(UserInputService, "PreferredInput")
end

const GuiService = game:GetService("GuiService")

const Connection = require(script.Parent.Parent.Connection)
const Void = require(script.Parent.Parent.Void)

const property = require("./property")

--[=[
	@within Observe
	@function display_size
	@param callback (display_size: Enum.DisplaySize, void: Void) -> ()
	@param predicate ((display_size: Enum.DisplaySize) -> boolean)?
	@return Connection

	[Observe.property] for `GuiService.ViewportDisplaySize`, whether the screen
	is small, medium or large

	```lua
	Observe.display_size(function(size, void)
		if size == Enum.DisplaySize.Small then
			void:add(use_compact_layout())
		end
	end)
	```
]=]
return function(
	callback: (display_size: Enum.DisplaySize, void: Void.Void) -> (),
	predicate: ((display_size: Enum.DisplaySize) -> boolean)?
): Connection.Connection
	return property(GuiService, "ViewportDisplaySize", callback, predicate)
end

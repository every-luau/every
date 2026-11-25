const GuiService = game:GetService("GuiService")

const Observable = require(script.Parent.Parent.Observable)

const property = require("./property")

--[=[
	@within Observe
	@function display_size
	@return Observable<Enum.DisplaySize>

	[Observe.property] for `GuiService.ViewportDisplaySize`, whether the screen
	is small, medium or large

	```lua
	Observe.display_size():subscribe(function(brio)
		local void, size = brio:to_void_and_value()
		if size == Enum.DisplaySize.Small then
			void:add(use_compact_layout())
		end
	end)
	```
]=]
return function(): Observable.Observable<Enum.DisplaySize>
	return property(GuiService, "ViewportDisplaySize")
end

const Connection = require(script.Parent.Parent.Connection)
const Thread = require(script.Parent.Parent.Thread)
const Void = require(script.Parent.Parent.Void)

--[=[
	@within Observe
	@function attribute
	@param instance Instance
	@param name string
	@param callback (value: any, void: Void) -> ()
	@param predicate ((value: any) -> boolean)?
	@return Connection

	calls `callback` with the attribute `name` of `instance`, now and every time
	it changes, if `predicate` accepts it. a missing attribute is nil. the void
	of a value is cleaned when the attribute changes, even when `predicate`
	rejects the new one

	```lua
	Observe.attribute(player, "Team", function(team, void)
		void:add(show_team_badge(team))
	end, function(team)
		return team ~= nil
	end)
	```
]=]
return function(
	instance: Instance,
	name: string,
	callback: (value: any, void: Void.Void) -> (),
	predicate: ((value: any) -> boolean)?
): Connection.Connection
	const void = Void.new()
	const value_void = void:extend()

	const function changed()
		value_void:clean()

		const value = instance:GetAttribute(name)
		if predicate and not predicate(value) then
			return
		end

		Thread(callback, value, value_void)
	end

	void:add(instance:GetAttributeChangedSignal(name):Connect(changed))
	changed()

	return Connection.new(void)
end

const Observable = require(script.Parent.Parent.Observable)
const Stream = require(script.Parent.Parent.Stream)

--[=[
	@within Observe
	@function attribute
	@param instance Instance
	@param name string
	@return Observable<any>

	observes the attribute `name` of `instance`: a brio for its value now and
	every time it changes, killed by the next one. a missing attribute is nil

	```lua
	Observe.attribute(player, "Team")
		:filter(function(team)
			return team ~= nil
		end)
		:subscribe(function(brio)
			local void, team = brio:to_void_and_value()
			void:add(show_team_badge(team))
		end)
	```
]=]
return function(instance: Instance, name: string): Observable.Observable<any>
	return Observable.new(Stream.attribute(instance, name))
end

const Observable = require(script.Parent.Parent.Observable)
const Stream = require(script.Parent.Parent.Stream)

--[=[
	@within Observe
	@function property
	@param instance Instance
	@param name string
	@return Observable<any>

	observes the property `name` of `instance`: a brio for its value now and
	every time it changes, killed by the next one

	```lua
	Observe.property(humanoid, "Sit")
		:filter(function(sitting)
			return sitting
		end)
		:subscribe(function(brio)
			local void = brio:to_void()
			void:add(show_seat_menu())
		end)
	```
]=]
return function(instance: Instance, name: string): Observable.Observable<any>
	return Observable.new(Stream.property(instance, name))
end

const Observable = require(script.Parent.Parent.Observable)
const Stream = require(script.Parent.Parent.Stream)

--[=[
	@within Observe
	@function children
	@param parent Instance
	@return Observable<Instance>

	observes the children of `parent`: a brio for each one now and later,
	killed when the child is removed

	```lua
	Observe.children(workspace.Doors):subscribe(function(brio)
		local void, door = brio:to_void_and_value()
		void:add(door.Touched:Connect(open))
	end)
	```
]=]
return function(parent: Instance): Observable.Observable<Instance>
	return Observable.new(Stream.children(parent))
end

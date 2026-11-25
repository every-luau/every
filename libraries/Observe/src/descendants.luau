const Observable = require(script.Parent.Parent.Observable)

const signals = require("./signals")

--[=[
	@within Observe
	@function descendants
	@param root Instance
	@return Observable<Instance>

	observes the descendants of `root`: a brio for each one now and later,
	killed when it leaves `root`, so removing a folder kills the brios of
	everything in it too

	```lua
	Observe.descendants(workspace.Map)
		:filter(function(descendant)
			return descendant:IsA("BasePart")
		end)
		:subscribe(function(brio)
			local part = brio:get_value()
			print(part.Name)
		end)
	```
]=]
return function(root: Instance): Observable.Observable<Instance>
	return signals(function()
		return root:GetDescendants()
	end, root.DescendantAdded, root.DescendantRemoving)
end

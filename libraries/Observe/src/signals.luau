-- An observable of what `list` returns when subscribed, then of what `added`
-- and `removed` fire with. Not an observer itself: the observers of sets of
-- instances are built on it.

const Observable = require(script.Parent.Parent.Observable)

return function<T>(list: () -> { T }, added: RBXScriptSignal, removed: RBXScriptSignal): Observable.Observable<T>
	return Observable.new(function(emit: (T, boolean) -> (), void: Observable.Void)
		-- connected first, so what changes while the current items are emitted
		-- isn't missed
		void:add(added:Connect(function(item: T)
			emit(item, true)
		end))
		void:add(removed:Connect(function(item: T)
			emit(item, false)
		end))
		for _, item in list() do
			emit(item, true)
		end
	end)
end

--[=[
	@class Bootstrap

	Bootstrap requires ModuleScripts and calls their hooks in order of priority

	load every ModuleScript in a folder with [Bootstrap.load], then call a method
	on all of them with [Bootstrap.call]. both return a [Future], so you can wait
	for one step before starting the next

	```lua
	local Bootstrap = require(path.to.Bootstrap)

	Bootstrap.load(ServerScriptService.Services, function(module)
		return module.Name:match("Service$") ~= nil
	end):and_then(function(services)
		Bootstrap.call(services, "init"):await()
		Bootstrap.call(services, "start"):await()
	end)
	```

	:::info
	a module with a `_priority` number is loaded before the ones with a lower one,
	and modules without it have a priority of 0. modules with the same priority
	keep the order they were found in
	:::
]=]

const Future = require(script.Parent.Future)

export type Future<T...> = Future.Future<T...>

--[=[
	@within Bootstrap
	@type Module { [any]: any }

	what a ModuleScript returned. Bootstrap only keeps modules that return a table
]=]
export type Module = { [any]: any }

-- a required module and where it was found, to keep that order on ties
type Loaded = { module: Module, index: number }

--[=[
	@within Bootstrap
	@function load
	@param containers Instance | { Instance }
	@param predicate ((module: ModuleScript) -> boolean)?
	@return Future<{ Module }>

	requires every ModuleScript under `containers`, or only the ones `predicate`
	returns true for, and resolves with the tables they return, sorted by
	priority. each table gets an `_instance` field set to its ModuleScript, unless
	it is frozen. rejects if a module errors when required
]=]
const function load(
	containers: Instance | { Instance },
	predicate: ((module: ModuleScript) -> boolean)?
): Future<{ Module }>
	const roots: { Instance } = if typeof(containers) == "Instance" then { containers } else containers

	const scripts: { ModuleScript } = {}
	for _, root in roots do
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("ModuleScript") and (not predicate or predicate(descendant)) then
				table.insert(scripts, descendant)
			end
		end
	end

	-- every module is required on its own thread, so one that yields doesn't hold
	-- up the others
	const requiring = {}
	for _, module_script in scripts do
		table.insert(
			requiring,
			Future.new(function(pass)
				pass(require(module_script) :: any)
			end)
		)
	end

	return Future.all(requiring):and_then(function(results: { any })
		const loaded: { Loaded } = {}
		for index, module in results do
			if type(module) ~= "table" then
				continue
			end

			if not table.isfrozen(module) then
				module._instance = scripts[index]
			end
			table.insert(loaded, { module = module, index = index })
		end

		table.sort(loaded, function(a: Loaded, b: Loaded)
			const priority_a, priority_b = a.module._priority or 0, b.module._priority or 0
			if priority_a ~= priority_b then
				return priority_a > priority_b
			end
			return a.index < b.index
		end)

		const modules = {}
		for index, entry in loaded do
			modules[index] = entry.module
		end
		return modules
	end)
end

--[=[
	@within Bootstrap
	@function call
	@param modules { Module }
	@param method string
	@param ... any
	@return Future<{ Module }>

	calls `module:method(...)` on every module that has that method, each on its
	own thread, and resolves with `modules` once they all returned. rejects if one
	of them errors

	```lua
	Bootstrap.call(services, "init"):await()
	```
]=]
const function call(modules: { Module }, method: string, ...: any): Future<{ Module }>
	const calls: { any } = {}
	for _, module in modules do
		const callback: any = module[method]
		if type(callback) == "function" then
			table.insert(
				calls,
				Future.new(function(pass: any, _: any, ...: any)
					(callback :: any)(module, ...)
					pass()
				end, ...)
			)
		end
	end

	return Future.all(calls):and_then(function()
		return modules
	end)
end

return table.freeze({
	load = load,
	call = call,
})

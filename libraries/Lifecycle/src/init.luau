--[=[
	@class Lifecycle

	Lifecycle builds objects whose lifecycle hooks are registered with chainable calls

	any `OnName` call registers the hook `Name`, and `on_name` registers `name`,
	so a lifecycle has whatever hooks you give it. calling the hook then runs what
	was registered, with the lifecycle as `self`. it has a `_priority`, the field
	[Bootstrap] sorts modules by

	```lua
	local Lifecycle = require(path.to.Lifecycle)

	local CoinService = Lifecycle.new(10)
		:on_init(function(self)
			self.coins = {}
		end)
		:on_start(function(self)
			print("coins ready")
		end)

	CoinService:init()
	CoinService:start()

	return CoinService
	```

	:::info
	registering a hook again replaces it. a key that is neither a hook nor a value
	you set is nil, so `lifecycle.start` is nil until `on_start` was called
	:::
]=]

--[=[
	@within Lifecycle
	@type Hook (self: Lifecycle, ...any) -> ...any

	a function registered with an `On` or `on_` call
]=]
export type Hook = (self: Lifecycle, ...any) -> ...any

export type Lifecycle = {
	_priority: number,
	[string]: any,
}

-- what isn't stored on the lifecycle itself, so it never clashes with a field
type State = {
	hooks: { [string]: Hook },
	base: Lifecycle?,
}

const states: { [Lifecycle]: State } = setmetatable({}, { __mode = "k" }) :: any

-- the name of the hook `key` registers, if it is an `OnName` or `on_name` key
const function registered_hook(key: string): string?
	return string.match(key, "^On(%u.*)$") or string.match(key, "^on_(%l.*)$")
end

-- every function registered as `name` in `lifecycle` and the lifecycles it
-- extends, the deepest base first
const function collect(lifecycle: Lifecycle, name: string, into: { Hook })
	const state = states[lifecycle]
	if state.base then
		collect(state.base, name, into)
	end

	const hook = state.hooks[name]
	if hook then
		table.insert(into, hook)
	end
end

const metatable = {}

metatable.__index = function(self: Lifecycle, key: any): any
	if type(key) ~= "string" then
		return nil
	end

	const name = registered_hook(key)
	if name then
		return function(lifecycle: Lifecycle, hook: Hook): Lifecycle
			states[lifecycle].hooks[name] = hook
			return lifecycle
		end
	end

	const hooks: { Hook } = {}
	collect(self, key, hooks)
	if #hooks == 0 then
		return nil
	elseif #hooks == 1 then
		return hooks[1]
	end

	return function(lifecycle: Lifecycle, ...: any)
		for _, hook in hooks do
			hook(lifecycle, ...)
		end
	end
end

const function create(priority: number, state: State): Lifecycle
	const lifecycle = setmetatable({ _priority = priority }, metatable) :: any
	states[lifecycle] = state
	return lifecycle
end

--[=[
	@within Lifecycle
	@function new
	@param priority number?
	@return Lifecycle

	creates a Lifecycle without hooks. `priority` defaults to 0
]=]
const function new(priority: number?): Lifecycle
	return create(priority or 0, { hooks = {} })
end

--[=[
	@within Lifecycle
	@function extend
	@param base Lifecycle
	@return Lifecycle

	creates a Lifecycle that runs the hooks of `base` first, then its own. it
	starts with the priority of `base`, and `base` doesn't change

	```lua
	local Shop = Lifecycle.extend(BaseService):on_init(function(self)
		self.items = {}
	end)
	```
]=]
const function extend(base: Lifecycle): Lifecycle
	return create(base._priority, { hooks = {}, base = base })
end

--[=[
	@within Lifecycle
	@function clone
	@param template Lifecycle
	@param priority number?
	@return Lifecycle

	creates a Lifecycle with a copy of the hooks of `template`, which can then be
	replaced without changing `template`. `priority` defaults to the one of
	`template`
]=]
const function clone(template: Lifecycle, priority: number?): Lifecycle
	const state = states[template]
	return create(priority or template._priority, { hooks = table.clone(state.hooks), base = state.base })
end

--[=[
	@within Lifecycle
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Lifecycle
]=]
const function is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == metatable
end

return table.freeze({
	new = new,
	extend = extend,
	clone = clone,
	is = is,
})

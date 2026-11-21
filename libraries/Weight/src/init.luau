--!native
--!optimize 2

--[=[
	@class Weight

	Weight picks random keys from a table of weights, with an optional luck factor

	give it a table of keys to weights, then call `Weight:generate(...)`. a key with a
	weight of 10 comes up ten times as often as one with a weight of 1. rolls come
	from the CSPRNG of [rbx-cryptography](https://github.com/daily3014/rbx-cryptography),
	so they can't be predicted

	```lua
	local Weight = require(path.to.Weight)

	local loot = Weight.new({ common = 80, rare = 15, epic = 5 })

	print(loot:generate()) --> common
	print(loot:generate(5)) -- rare and epic come up more often
	```
    
	:::info
	luck above 1 makes rare keys more likely by flattening the weights, and the
	intensity sets how much luck does. keys with a weight of 0 or less never come up
	:::
]=]

const Cryptography = require(script.Parent.Cryptography)

const DEFAULT_LUCK = 1
const DEFAULT_INTENSITY = 10 -- the higher it is, the less luck changes the weights

export type Weight<K> = setmetatable<{
	_weights: { [K]: number },
	_intensity: number,
	set_intensity: (self: Weight<K>, intensity: number?) -> Weight<K>,
	get_intensity: (self: Weight<K>) -> number,
	get_total_weight: (self: Weight<K>, luck: number?) -> number,
	get_values: (self: Weight<K>, luck: number?) -> { [K]: number },
	generate: (self: Weight<K>, luck: number?) -> K,
}, {
	__index: Weight<K>,
	__add: (self: Weight<K>, other: Weight<K>) -> Weight<K>,
	__tostring: (self: Weight<K>) -> string,
}>

-- raising the weight to 1 / scaled luck brings big and small weights closer together
const function adjust(weight: number, luck: number?, intensity: number): number
	const scaled = 1 + ((luck or DEFAULT_LUCK) - 1) * 0.8 ^ (intensity - 1)
	return weight ^ (1 / scaled)
end

const Weight = {}
Weight.__index = Weight

--[=[
	@within Weight
	@function new
	@param weights { [K]: number }
	@param intensity number?
	@return Weight<K>

	creates a Weight from a copy of `weights`. `intensity` defaults to 10, see
	[Weight:set_intensity]
]=]
function Weight.new<K>(weights: { [K]: number }, intensity: number?): Weight<K>
	return setmetatable(
		{
			_weights = table.clone(weights),
			_intensity = intensity or DEFAULT_INTENSITY,
		},
		Weight
	) :: any
end

--[=[
	@within Weight
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Weight
]=]
function Weight.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Weight
end

--[=[
	@within Weight
	@method set_intensity
	@param intensity number?
	@return Weight<K>

	sets how much luck changes the weights: the higher it is, the less luck does.
	no `intensity` resets it to 10. returns the Weight, so calls can be chained

	```lua
	loot:set_intensity(1):generate(5)
	```
]=]
function Weight.set_intensity<K>(self: Weight<K>, intensity: number?): Weight<K>
	self._intensity = intensity or DEFAULT_INTENSITY
	return self
end

--[=[
	@within Weight
	@method get_intensity
	@return number

	returns the intensity, see [Weight:set_intensity]
]=]
function Weight.get_intensity<K>(self: Weight<K>): number
	return self._intensity
end

--[=[
	@within Weight
	@method get_total_weight
	@param luck number?
	@return number

	returns the sum of every positive weight, adjusted for `luck`
]=]
function Weight.get_total_weight<K>(self: Weight<K>, luck: number?): number
	local total = 0

	for _, weight in self._weights do
		if weight > 0 then
			total += adjust(weight, luck, self._intensity)
		end
	end

	return total
end

--[=[
	@within Weight
	@method get_values
	@param luck number?
	@return { [K]: number }

	returns a copy of the positive weights, adjusted for `luck`. these are the
	weights [Weight:generate] picks from

	```lua
	print(Weight.new({ common = 100, rare = 1 }, 1):get_values(2))
	--> { common = 10, rare = 1 }
	```
]=]
function Weight.get_values<K>(self: Weight<K>, luck: number?): { [K]: number }
	const values = {}

	for key, weight in self._weights do
		if weight > 0 then
			values[key] = adjust(weight, luck, self._intensity)
		end
	end

	return values
end

--[=[
	@within Weight
	@method generate
	@param luck number?
	@return K

	picks a random key. a key's odds are its weight adjusted for `luck`, over the
	total. errors when no key has a positive weight
]=]
function Weight.generate<K>(self: Weight<K>, luck: number?): K
	const total = self:get_total_weight(luck)
	if total <= 0 then
		error("Weight can't generate a key, there is no positive weight", 2)
	end

	const roll = Cryptography.Utilities.CSPRNG.Random() * total
	local current = 0
	local last: K? = nil

	for key, weight in self._weights do
		if weight > 0 then
			current += adjust(weight, luck, self._intensity)
			last = key
			if roll <= current then
				return key
			end
		end
	end

	-- floating point can leave the roll just above the last sum
	return last :: K
end

-- `a + b` merges two weights into a new one, `b` winning on keys and intensity
Weight.__add = function<K>(self: Weight<K>, other: Weight<K>): Weight<K>
	const weights = table.clone(self._weights)
	for key, weight in other._weights do
		weights[key] = weight
	end

	return Weight.new(weights, other._intensity)
end

-- prints like `Weight { a = 1, b = 2 }`, keys sorted
Weight.__tostring = function<K>(self: Weight<K>): string
	const entries = {}
	for key, weight in self._weights do
		table.insert(entries, `{key} = {weight}`)
	end
	table.sort(entries)

	if #entries == 0 then
		return "Weight {}"
	end
	return `Weight \{ {table.concat(entries, ", ")} }`
end

return table.freeze({
	new = Weight.new,
	is = Weight.is,
})

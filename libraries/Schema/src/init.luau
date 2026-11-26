--[=[
	@class Schema

	Schema describes the shape of a value once, to check it, repair it, and turn it into bytes with [Lync](https://github.com/Axp3cter/Lync)

	build a schema out of the constructors below. [Schema:check] tells whether a
	value fits and where it does not, [Schema:reconcile] repairs saved data with
	defaults, and [Schema:codec] is the Lync codec of the same shape, for packets,
	queries and sets, or [Schema:encode] and [Schema:decode] on their own

	the type of the values follows from the constructors, so nothing has to be
	written twice: `data` below is a `{ name: string, coins: number, settings: {
	music: boolean }, pet: ("cat" | "dog")? }`, and `Schema.Infer` names it

	```lua
	local Schema = require(path.to.Schema)

	local Profile = Schema.struct({
		name = Schema.string(1, 20),
		coins = Schema.int(0),
		settings = Schema.struct({
			music = Schema.boolean():default(true),
		}),
		pet = Schema.optional(Schema.enum<<"cat" | "dog">>({ "cat", "dog" })),
	})

	type Profile = Schema.Infer<typeof(Profile)>

	print(Profile:check({ name = "", coins = 5, settings = { music = true } }))
	--> false name: expected a string of 1 to 20 bytes, got ""

	local data = Profile:reconcile(saved_data)

	local bytes = Profile:encode(data)
	local copy = Profile:decode(bytes)
	```

	:::info
	a schema never changes once built: [Schema:default] and [Schema:refine]
	return a new one. a refined schema cannot go in a Lync set record, since Lync
	refuses validation there
	:::
]=]

const Lync = require(script.Parent.Lync)

-- the longest string, buffer, array or map a schema accepts when no maximum is given
const DEFAULT_MAX = 1000

-- the rotation precision of a CFrame codec, in degrees
const ROTATION_PRECISION = 0.01

--[=[
	@within Schema
	@type Schema<T> { check: ..., assert: ..., reconcile: ..., default: ..., refine: ..., codec: ..., encode: ..., decode: ... }

	a schema of values of type `T`. `T` follows from the constructors, so
	`Schema.struct({ coins = Schema.int() })` is a `Schema<{ coins: number }>`
	and [Schema:assert], [Schema:reconcile] and [Schema:decode] return a
	`{ coins: number }`. `_T` only exists for the type checker, like in Lync
]=]
export type Schema<T> = {
	read _T: T,

	check: (self: Schema<T>, value: unknown) -> (boolean, string?),
	assert: (self: Schema<T>, value: unknown) -> T,
	reconcile: (self: Schema<T>, value: unknown) -> T,
	default: (self: Schema<T>, value: T) -> Schema<T>,
	refine: (self: Schema<T>, check: (value: T) -> string?) -> Schema<T>,
	codec: (self: Schema<T>) -> Codec<T>,
	encode: (self: Schema<T>, value: T) -> (buffer, { Instance }?),
	decode: (self: Schema<T>, bytes: buffer, refs: { Instance }?) -> T,
}

--[=[
	@within Schema
	@type Codec<T> { validate: ..., as: any, newest: ... }

	the Lync codec of a `Schema<T>`, which Lync takes wherever it takes its own
	`Lync.Codec<T>`. Lync declares `as` with a generic that Luau turns into an
	error type, so this one leaves `as` untyped to keep `T` readable
]=]
export type Codec<T> = {
	read _T: T,
	read validate: (self: Codec<T>, check: (value: T, ctx: Lync.ValidateContext) -> string?) -> Codec<T>,
	read as: any,
	read newest: (self: Codec<T>, hz: number?) -> Codec<T>,
}

--[=[
	@within Schema
	@type Infer<S> T

	the type of the values a schema describes

	```lua
	local Profile = Schema.struct({
		name = Schema.string(1, 20),
		pet = Schema.optional(Schema.enum<<"cat" | "dog">>({ "cat", "dog" })),
	})

	type Profile = Schema.Infer<typeof(Profile)>
	--> { name: string, pet: ("cat" | "dog")? }
	```
]=]
export type Infer<S> = index<S, "_T">

-- the record a table of schemas describes, for `Schema.struct`
type function Struct(fields: any): any
	-- the type a schema holds in its `_T`, or nil when it is not a schema
	local function value_of(schema: any): any
		if schema == nil or not schema:is("table") then
			return nil
		end
		return schema:readproperty(types.singleton("_T"))
	end

	if not fields:is("table") then
		error("Schema.struct expects a table of schemas")
	end

	local record: any = types.newtable()
	for key: any, property: any in fields:properties() do
		local value = value_of(property.read or property.write)
		if value == nil then
			error(`Schema.struct expects a schema for the field {key:value()}`)
		end
		record:setproperty(key, value)
	end

	-- a table of schemas built at run time, whose fields are not known
	if fields:indexer() then
		record:setindexer(types.string, types.unknown)
	end

	return record
end

-- the union a `{ [field] = { [name] = struct } }` table describes, for `Schema.tagged`
type function Tagged(shape: any): any
	local function value_of(schema: any): any
		if schema == nil or not schema:is("table") then
			return nil
		end
		return schema:readproperty(types.singleton("_T"))
	end

	local usage = "Schema.tagged expects a table like { kind = { name = Schema.struct(...) } }"
	if not shape:is("table") then
		error(usage)
	end

	local field: any = nil
	local variants: any = nil
	for key: any, property: any in shape:properties() do
		if field ~= nil then
			error("Schema.tagged expects one field, the one that names the variant")
		end
		field = key
		variants = property.read or property.write
	end
	if field == nil or variants == nil or not variants:is("table") then
		error(usage)
	end

	local options: { any } = {}
	for name: any, property: any in variants:properties() do
		local value = value_of(property.read or property.write)
		if value == nil or not value:is("table") then
			error(`Schema.tagged expects a struct for the variant {name:value()}`)
		end

		local record: any = types.newtable()
		for key: any, part: any in value:properties() do
			record:setproperty(key, part.read or part.write)
		end
		record:setproperty(field, name)
		table.insert(options, record)
	end

	if #options == 0 then
		error("Schema.tagged expects at least one variant")
	elseif #options == 1 then
		return options[1]
	end
	return types.unionof(table.unpack(options))
end

-- what a schema holds at run time, behind the `Schema<T>` the constructors return
type Node = {
	_kind: string,
	_expect: string,
	_test: (value: any) -> (string?, string?),
	_build: () -> any,
	_fallback: () -> any,
	_repair: ((value: any) -> any)?,
	_refines: { (value: any) -> string? },
	_fields: { [string]: Node }?,
	_has_default: boolean,
	_default: any,
	_codec: any,
}

const Schema = {}
Schema.__index = Schema

-- the run time side of a schema
const function node(schema: any): Node
	return schema
end

const function deep_clone<T>(value: T): T
	if type(value) ~= "table" then
		return value :: any
	end

	const out = {}
	for key, item in value :: any do
		out[deep_clone(key)] = deep_clone(item)
	end

	return out :: any
end

const function show(value: any): string
	const kind = typeof(value)

	if kind == "string" then
		if #value > 24 then
			return `"{string.sub(value, 1, 24)}..."`
		end
		return `"{value}"`
	elseif kind == "number" or kind == "boolean" or kind == "nil" then
		return tostring(value)
	end

	return kind
end

-- the path to `key` followed by `rest`, like `items[2].name`
const function join(key: any, rest: string?): string
	const part = if type(key) == "string" and string.match(key, "^[%a_][%w_]*$") then key else `[{show(key)}]`

	if rest == nil or rest == "" then
		return part
	end

	return if string.sub(rest, 1, 1) == "[" then part .. rest else `{part}.{rest}`
end

const function bounds(min: number?, max: number?): string
	if min and max then
		return if min == max then ` of {min}` else ` of {min} to {max}`
	elseif min then
		return ` of at least {min}`
	elseif max then
		return ` of at most {max}`
	end
	return ""
end

const function count(value: { [any]: any }): number
	local total = 0
	for _ in value do
		total += 1
	end
	return total
end

-- builds a schema. `test` returns why a value does not fit and the path to the
-- part that failed, or nil when it fits
const function make(
	kind: string,
	expect: string,
	test: (value: any) -> (string?, string?),
	build: () -> any,
	fallback: () -> any,
	repair: ((value: any) -> any)?
): any
	const schema: Node = {
		_kind = kind,
		_expect = expect,
		_test = test,
		_build = build,
		_fallback = fallback,
		_repair = repair,
		_refines = {},
		_fields = nil,
		_has_default = false,
		_default = nil,
		_codec = nil,
	}
	return setmetatable(schema, Schema)
end

-- a leaf test, which only checks `fits` and explains with `expect`
const function leaf(expect: string, fits: (value: any) -> boolean): (value: any) -> (string?, string?)
	return function(value)
		if fits(value) then
			return nil, nil
		end
		return `expected {expect}, got {show(value)}`, ""
	end
end

const function copy(self: Node): Node
	const new = table.clone(self)
	new._codec = nil
	return setmetatable(new, Schema) :: any
end

-- why `value` does not fit `self`, and the path to the part that failed
const function test(self: Node, value: any): (string?, string?)
	const reason, path = self._test(value)
	if reason then
		return reason, path
	end

	for _, refine in self._refines do
		const refused = refine(value)
		if refused then
			return refused, ""
		end
	end

	return nil, nil
end

const function fits(self: Node, value: any): boolean
	return (test(self, value)) == nil
end

const function explain(self: Node, value: any): string?
	const reason, path = test(self, value)
	if reason == nil then
		return nil
	end
	return if path == nil or path == "" then reason else `{path}: {reason}`
end

const function fallback_of(self: Node): any
	if self._has_default then
		return deep_clone(self._default)
	end
	return self._fallback()
end

const function reconcile(self: Node, value: any): any
	if fits(self, value) then
		return deep_clone(value)
	end

	const repair = self._repair
	if repair then
		const repaired = repair(value)
		if fits(self, repaired) then
			return repaired
		end
	end

	return fallback_of(self)
end

-- the Lync codec of `self`, built once
const function codec_of(self: Node): any
	local codec = self._codec
	if codec then
		return codec
	end

	codec = self._build()
	for _, refine in self._refines do
		codec = codec:validate(function(value)
			return refine(value)
		end)
	end

	self._codec = codec
	return codec
end

const function cannot(what: string): () -> any
	return function()
		error(`Schema: {what} has no default value, give it one with :default(value)`, 0)
	end
end

const function is_integer(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and math.abs(value) < 2 ^ 53
end

const function clamp(value: number, min: number?, max: number?): number
	return math.clamp(value, min or -math.huge, max or math.huge)
end

--[=[
	@within Schema
	@function boolean
	@return Schema<boolean>

	true or false. its default is false
]=]
function Schema.boolean(): Schema<boolean>
	return make("boolean", "a boolean", leaf("a boolean", function(value)
		return type(value) == "boolean"
	end), function()
		return Lync.bool()
	end, function()
		return false
	end)
end

--[=[
	@within Schema
	@function int
	@param min number?
	@param max number?
	@return Schema<number>

	a whole number from `min` to `max`. with both bounds it is sent in the fewest
	bits, otherwise as a variable length integer. its default is the value closest
	to 0 in its bounds
]=]
function Schema.int(min: number?, max: number?): Schema<number>
	const expect = `an integer{bounds(min, max)}`

	return make("int", expect, leaf(expect, function(value)
		return is_integer(value) and not (min and value < min) and not (max and value > max)
	end), function()
		if min and max then
			return Lync.int(min, max)
		elseif min and min >= 0 then
			return Lync.vlq()
		end
		return Lync.vli()
	end, function()
		return clamp(0, min, max)
	end, function(value)
		return if type(value) == "number" and value == value then clamp(math.round(value), min, max) else value
	end)
end

--[=[
	@within Schema
	@function number
	@param min number?
	@param max number?
	@param step number?
	@return Schema<number>

	a number from `min` to `max`, never NaN. with a `step` it is rounded to it and
	sent in the fewest bits, which needs both bounds, otherwise it is sent as a 64
	bit float. its default is the value closest to 0 in its bounds
]=]
function Schema.number(min: number?, max: number?, step: number?): Schema<number>
	if step and not (min and max) then
		error("Schema.number needs a min and a max to take a step", 2)
	end

	const expect = `a number{bounds(min, max)}`

	return make("number", expect, leaf(expect, function(value)
		return type(value) == "number" and value == value and not (min and value < min) and not (max and value > max)
	end), function()
		if step then
			return Lync.quant(min :: number, max :: number, step)
		end
		return Lync.f64()
	end, function()
		return clamp(0, min, max)
	end, function(value)
		return if type(value) == "number" and value == value then clamp(value, min, max) else value
	end)
end

--[=[
	@within Schema
	@function string
	@param min number?
	@param max number?
	@return Schema<string>

	a string from `min` to `max` bytes long, 0 to 1000 when not given. its
	default is the empty string, so one with a minimum length needs
	[Schema:default]
]=]
function Schema.string(min: number?, max: number?): Schema<string>
	const low, high = min or 0, max or DEFAULT_MAX
	const expect = `a string{bounds(low, high)} bytes`

	return make("string", expect, leaf(expect, function(value)
		return type(value) == "string" and #value >= low and #value <= high
	end), function()
		return Lync.str(low, high)
	end, if low == 0
		then function()
			return ""
		end
		else cannot("a string with a minimum length"), function(value)
		return if type(value) == "string" and #value > high then string.sub(value, 1, high) else value
	end)
end

--[=[
	@within Schema
	@function enum
	@param names { T }
	@return Schema<T>

	one of `names`. its default is the first one. a Schema<string> on its own,
	since Luau widens the names to `string`. give the names as a type to get
	them back as a union, and the type checker makes sure every name is one of
	them

	```lua
	local Pet = Schema.enum<<"cat" | "dog">>({ "cat", "dog" }) -- Schema<"cat" | "dog">
	```
]=]
function Schema.enum<T>(names: { T }): Schema<T>
	assert(#names > 0, "Schema.enum needs at least one name")

	const allowed = {}
	const quoted = {}
	for index, name in names :: { any } do
		if type(name) ~= "string" then
			error(`Schema.enum needs strings, got {show(name)} at {index}`, 2)
		end
		allowed[name] = true
		quoted[index] = `"{name}"`
	end

	const expect = `one of {table.concat(quoted, ", ")}`
	const frozen = table.freeze(table.clone(names))

	return make("enum", expect, leaf(expect, function(value)
		return allowed[value] == true
	end), function()
		return Lync.enum(table.clone(frozen))
	end, function()
		return frozen[1]
	end)
end

const function datatype(kind: string, type_name: string, build: () -> any, fallback: () -> any): any
	const expect = `a {type_name}`
	return make(kind, expect, leaf(expect, function(value)
		return typeof(value) == type_name
	end), build, fallback)
end

--[=[
	@within Schema
	@function vector2
	@return Schema<Vector2>

	a Vector2, sent as two 32 bit floats. its default is `Vector2.zero`
]=]
function Schema.vector2(): Schema<Vector2>
	return datatype("vector2", "Vector2", function()
		return Lync.vec2()
	end, function()
		return Vector2.zero
	end)
end

--[=[
	@within Schema
	@function vector3
	@return Schema<Vector3>

	a Vector3, sent as three 32 bit floats. its default is `Vector3.zero`
]=]
function Schema.vector3(): Schema<Vector3>
	return datatype("vector3", "Vector3", function()
		return Lync.vec3()
	end, function()
		return Vector3.zero
	end)
end

--[=[
	@within Schema
	@function cframe
	@return Schema<CFrame>

	a CFrame, sent as three 32 bit floats and a rotation to 0.01 degrees. its
	default is `CFrame.identity`
]=]
function Schema.cframe(): Schema<CFrame>
	return datatype("cframe", "CFrame", function()
		return Lync.cframe(Lync.vec3(), Lync.rotation.quat(ROTATION_PRECISION))
	end, function()
		return CFrame.identity
	end)
end

--[=[
	@within Schema
	@function color3
	@return Schema<Color3>

	a Color3, sent as three 32 bit floats. its default is black
]=]
function Schema.color3(): Schema<Color3>
	return datatype("color3", "Color3", function()
		return Lync.color3()
	end, function()
		return Color3.new(0, 0, 0)
	end)
end

--[=[
	@within Schema
	@function instance
	@param class string?
	@return Schema<Instance>

	an Instance that `:IsA(class)` when a class is given. Lync sends instances
	beside the bytes, and one the receiver cannot see arrives as nil. it has no
	default, so wrap it in [Schema.optional] for saved data. it is a
	Schema<Instance>, cast it to narrow the class

	```lua
	local Door = Schema.instance("BasePart") :: Schema.Schema<BasePart>
	```
]=]
function Schema.instance(class: string?): Schema<Instance>
	const expect = if class then `an Instance of class {class}` else "an Instance"

	return make("instance", expect, leaf(expect, function(value)
		return typeof(value) == "Instance" and (class == nil or (value :: Instance):IsA(class))
	end), function()
		return Lync.inst(class)
	end, cannot("an instance"))
end

--[=[
	@within Schema
	@function buffer
	@param min number?
	@param max number?
	@return Schema<buffer>

	a buffer from `min` to `max` bytes long, 0 to 1000 when not given. its
	default is a buffer of `min` zeros
]=]
function Schema.buffer(min: number?, max: number?): Schema<buffer>
	const low, high = min or 0, max or DEFAULT_MAX
	const expect = `a buffer{bounds(low, high)} bytes`

	return make("buffer", expect, leaf(expect, function(value)
		return type(value) == "buffer" and buffer.len(value) >= low and buffer.len(value) <= high
	end), function()
		return Lync.buffer(low, high)
	end, function()
		return buffer.create(low)
	end)
end

--[=[
	@within Schema
	@function optional
	@param schema Schema<T>
	@return Schema<T?>

	`schema` or nil. its default is nil
]=]
function Schema.optional<S>(schema: S): Schema<index<S, "_T">?>
	const inner = node(schema)

	return make("optional", `{inner._expect} or nil`, function(value)
		if value == nil then
			return nil, nil
		end
		return test(inner, value)
	end, function()
		return Lync.optional(codec_of(inner))
	end, function()
		return nil
	end, function(value)
		-- a part that cannot be repaired becomes nil rather than the default of `schema`
		const repair = inner._repair
		if repair then
			const repaired = repair(value)
			if fits(inner, repaired) then
				return repaired
			end
		end
		return nil
	end)
end

-- why the fields of `value` do not fit, skipping the field `skip`
const function test_fields(fields: { [string]: Node }, value: { [any]: any }, skip: string?): (string?, string?)
	for key in value do
		if key ~= skip and (type(key) ~= "string" or fields[key] == nil) then
			return "is not a field", join(key)
		end
	end

	-- in a stable order, so the same value always reports the same field
	const keys = {}
	for key in fields do
		table.insert(keys, key)
	end
	table.sort(keys)

	for _, key in keys do
		const reason, path = test(fields[key], value[key])
		if reason then
			return reason, join(key, path)
		end
	end

	return nil, nil
end

const function repair_fields(fields: { [string]: Node }, value: any): { [string]: any }
	const source = if type(value) == "table" then value else {}
	const out = {}

	for key, schema in fields do
		out[key] = reconcile(schema, source[key])
	end

	return out
end

--[=[
	@within Schema
	@function struct
	@param fields { [string]: Schema<any> }
	@return Schema<{ ... }>

	a table with these fields, where a missing field is nil, so it only fits an
	optional one. a field that is not declared does not fit. its default has the
	default of every field. its type is the record of the types of its fields

	```lua
	local Item = Schema.struct({
		id = Schema.int(0),
		note = Schema.optional(Schema.string()),
	}) -- Schema<{ id: number, note: string? }>
	```
]=]
function Schema.struct<T>(fields: T): Schema<Struct<T>>
	if type(fields) ~= "table" then
		error("Schema.struct needs a table of schemas", 2)
	end

	const frozen: { [string]: Node } = {}
	for key, field in fields :: { [any]: any } do
		if type(key) ~= "string" or not Schema.is(field) then
			error(`Schema.struct needs a schema for every string key, got {show(field)} at {show(key)}`, 2)
		end
		frozen[key] = node(field)
	end
	table.freeze(frozen)

	const schema = make("struct", "a table", function(value)
		if type(value) ~= "table" then
			return `expected a table, got {show(value)}`, ""
		end
		return test_fields(frozen, value, nil)
	end, function()
		const codecs = {}
		for key, field in frozen do
			codecs[key] = codec_of(field)
		end
		return Lync.struct(codecs)
	end, function()
		return repair_fields(frozen, nil)
	end, function(value)
		return if type(value) == "table" then repair_fields(frozen, value) else value
	end)

	const built = node(schema)
	built._fields = frozen
	return schema
end

--[=[
	@within Schema
	@function array
	@param item Schema<T>
	@param min number?
	@param max number?
	@return Schema<{ T }>

	an array of `min` to `max` items, 0 to 1000 when not given, each fitting
	`item`. its default is empty, so one with a minimum count needs
	[Schema:default]
]=]
function Schema.array<S>(item: S, min: number?, max: number?): Schema<{ index<S, "_T"> }>
	const inner = node(item)
	const low, high = min or 0, max or DEFAULT_MAX
	const expect = `an array{bounds(low, high)} items`

	return make("array", expect, function(value)
		if type(value) ~= "table" then
			return `expected {expect}, got {show(value)}`, ""
		end

		const length = #value
		if count(value) ~= length then
			return `expected {expect}, got a table with keys that are not 1 to {length}`, ""
		elseif length < low or length > high then
			return `expected {expect}, got {length} items`, ""
		end

		for index, element in value do
			const reason, path = test(inner, element)
			if reason then
				return reason, join(index, path)
			end
		end

		return nil, nil
	end, function()
		return Lync.array(codec_of(inner), low, high)
	end, if low == 0
		then function()
			return {}
		end
		else cannot("an array with a minimum count"), function(value)
		if type(value) ~= "table" then
			return value
		end

		-- keeps the items that fit or can be repaired, in order, up to the maximum
		const out = {}
		for _, element in ipairs(value) do
			if #out >= high then
				break
			end

			local repaired = element
			const repair = inner._repair
			if not fits(inner, repaired) and repair then
				repaired = repair(repaired)
			end
			if fits(inner, repaired) then
				table.insert(out, deep_clone(repaired))
			end
		end
		return out
	end)
end

--[=[
	@within Schema
	@function map
	@param key Schema<K>
	@param value Schema<V>
	@param min number?
	@param max number?
	@return Schema<{ [K]: V }>

	a table of `min` to `max` pairs, 0 to 1000 when not given, where every key
	fits `key` and every value fits `value`. its default is empty
]=]
function Schema.map<K, V>(
	key: K,
	value: V,
	min: number?,
	max: number?
): Schema<{ [index<K, "_T">]: index<V, "_T"> }>
	const key_node, value_node = node(key), node(value)
	const low, high = min or 0, max or DEFAULT_MAX
	const expect = `a map{bounds(low, high)} pairs`

	return make("map", expect, function(map)
		if type(map) ~= "table" then
			return `expected {expect}, got {show(map)}`, ""
		end

		const total = count(map)
		if total < low or total > high then
			return `expected {expect}, got {total} pairs`, ""
		end

		for entry_key, entry_value in map do
			const key_reason = test(key_node, entry_key)
			if key_reason then
				return `is not a valid key, {key_reason}`, join(entry_key)
			end

			const reason, path = test(value_node, entry_value)
			if reason then
				return reason, join(entry_key, path)
			end
		end

		return nil, nil
	end, function()
		return Lync.map(codec_of(key_node), codec_of(value_node), low, high)
	end, if low == 0
		then function()
			return {}
		end
		else cannot("a map with a minimum count"), function(map)
		if type(map) ~= "table" then
			return map
		end

		-- drops the pairs whose key does not fit, and repairs their values
		const out = {}
		local total = 0
		for entry_key, entry_value in map do
			if total >= high then
				break
			end
			if fits(key_node, entry_key) then
				out[entry_key] = reconcile(value_node, entry_value)
				total += 1
			end
		end
		return out
	end)
end

--[=[
	@within Schema
	@function tagged
	@param shape { [string]: { [string]: Schema<{ ... }> } }
	@return Schema<A | B | ...>

	one of several structs, told apart by a field that names the variant.
	`shape` has a single key, that field, holding the variants by name. each
	variant is a [Schema.struct] without that field. it has no default. its type
	is the union of the variants, each with the field set to its name, so
	checking the field narrows the value

	```lua
	local Outcome = Schema.tagged({
		kind = {
			hit = Schema.struct({ target = Schema.int(0, 255) }),
			miss = Schema.struct({ at = Schema.vector3() }),
		},
	}) -- Schema<{ kind: "hit", target: number } | { kind: "miss", at: Vector3 }>

	local outcome = Outcome:assert(value)
	if outcome.kind == "hit" then
		print(outcome.target)
	end
	```
]=]
function Schema.tagged<T>(shape: T): Schema<Tagged<T>>
	if type(shape) ~= "table" then
		error("Schema.tagged needs a table like { kind = { name = Schema.struct(...) } }", 2)
	end

	local field: string? = nil
	local given: any = nil
	for key, variants in shape :: { [any]: any } do
		if field ~= nil or type(key) ~= "string" or type(variants) ~= "table" then
			error("Schema.tagged needs a table like { kind = { name = Schema.struct(...) } }", 2)
		end
		field, given = key, variants
	end
	if field == nil then
		error("Schema.tagged needs a table like { kind = { name = Schema.struct(...) } }", 2)
	end
	const tag: string = field

	const names = {}
	const frozen: { [string]: Node } = {}
	for name, variant in given :: { [any]: any } do
		if type(name) ~= "string" or not Schema.is(variant) or node(variant)._fields == nil then
			error(`Schema.tagged needs a struct for the variant {show(name)}`, 2)
		end
		frozen[name] = node(variant)
		table.insert(names, `"{name}"`)
	end
	if #names == 0 then
		error("Schema.tagged needs at least one variant", 2)
	end
	table.sort(names)
	table.freeze(frozen)

	const expect = `a table with {tag} set to one of {table.concat(names, ", ")}`

	return make("tagged", expect, function(value)
		if type(value) ~= "table" then
			return `expected {expect}, got {show(value)}`, ""
		end

		const variant = frozen[value[tag]]
		if not variant then
			return `expected one of {table.concat(names, ", ")}, got {show(value[tag])}`, join(tag)
		end

		return test_fields(variant._fields :: any, value, tag)
	end, function()
		const codecs = {}
		for name, variant in frozen do
			codecs[name] = codec_of(variant)
		end
		return Lync.tagged(tag, codecs)
	end, cannot("a tagged union"), function(value)
		if type(value) ~= "table" then
			return value
		end

		const name = value[tag]
		const variant = frozen[name]
		if not variant then
			return value
		end

		const out = repair_fields(variant._fields :: any, value)
		out[tag] = name
		return out
	end)
end

--[=[
	@within Schema
	@method check
	@param value unknown
	@return boolean
	@return string?

	returns whether `value` fits, and when it does not, why, starting with the
	path to the part that failed

	```lua
	local ok, reason = Profile:check(data)
	if not ok then
		warn(reason) --> settings.music: expected a boolean, got nil
	end
	```
]=]
function Schema.check(self: Node, value: unknown): (boolean, string?)
	const reason = explain(self, value)
	return reason == nil, reason
end

--[=[
	@within Schema
	@method assert
	@param value unknown
	@return T

	returns `value` when it fits, and errors with the reason otherwise
]=]
function Schema.assert(self: Node, value: unknown): any
	const reason = explain(self, value)
	if reason then
		error(reason, 2)
	end
	return value :: any
end

--[=[
	@within Schema
	@method reconcile
	@param value unknown
	@return T

	returns a copy of `value` that fits, for data saved under an older shape.
	missing or wrong fields get their default, fields that are not declared are
	dropped, numbers are clamped into their bounds, strings and arrays are cut to
	their maximum, and array items that do not fit are dropped. errors when a part
	has to be replaced and has no default

	```lua
	local Data = Schema.struct({
		coins = Schema.int(0),
		music = Schema.boolean():default(true),
	})

	print(Data:reconcile({ coins = -5, old = 1 })) --> { coins = 0, music = true }
	```
]=]
function Schema.reconcile(self: Node, value: unknown): any
	return reconcile(self, value)
end

--[=[
	@within Schema
	@method default
	@param value T
	@return Schema<T>

	returns a copy of the schema whose default is `value`, used by
	[Schema:reconcile]. errors when `value` does not fit
]=]
function Schema.default(self: Node, value: unknown): Node
	const reason = explain(self, value)
	if reason then
		error(`Schema: the default does not fit, {reason}`, 2)
	end

	const new = copy(self)
	new._has_default = true
	new._default = deep_clone(value)
	return new
end

--[=[
	@within Schema
	@method refine
	@param check (value: T) -> string?
	@return Schema<T>

	returns a copy of the schema that also runs `check` once the value fits the
	rest. `check` returns nil to accept, or why it refuses. the codec runs it
	with Lync's `validate` when a value arrives

	```lua
	local Even = Schema.int(0, 100):refine(function(value)
		return if value % 2 == 0 then nil else "expected an even number"
	end)
	```
]=]
function Schema.refine(self: Node, check: (value: any) -> string?): Node
	const new = copy(self)
	const refines = table.clone(self._refines)
	table.insert(refines, check)
	new._refines = refines
	return new
end

--[=[
	@within Schema
	@method codec
	@return Codec<T>

	returns the Lync codec of the schema, built once. use it in Lync packets,
	queries and sets
]=]
function Schema.codec(self: Node): any
	return codec_of(self)
end

--[=[
	@within Schema
	@method encode
	@param value T
	@return buffer
	@return { Instance }?

	turns `value` into bytes with Lync, and the instances it holds when it holds
	any. errors when `value` does not fit. the bytes are not a storage format
	across Lync versions
]=]
function Schema.encode(self: Node, value: unknown): (buffer, { Instance }?)
	const reason = explain(self, value)
	if reason then
		error(reason, 2)
	end
	return Lync.encode(codec_of(self), value)
end

--[=[
	@within Schema
	@method decode
	@param bytes buffer
	@param refs { Instance }?
	@return T

	turns bytes from [Schema:encode] back into the value. errors when they do not
	hold one value of the schema
]=]
function Schema.decode(self: Node, bytes: buffer, refs: { Instance }?): any
	return Lync.decode(codec_of(self), bytes, refs)
end

--[=[
	@within Schema
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a Schema
]=]
function Schema.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == Schema
end

return table.freeze({
	boolean = Schema.boolean,
	int = Schema.int,
	number = Schema.number,
	string = Schema.string,
	enum = Schema.enum,
	vector2 = Schema.vector2,
	vector3 = Schema.vector3,
	cframe = Schema.cframe,
	color3 = Schema.color3,
	instance = Schema.instance,
	buffer = Schema.buffer,
	optional = Schema.optional,
	struct = Schema.struct,
	array = Schema.array,
	map = Schema.map,
	tagged = Schema.tagged,
	is = Schema.is,
})

--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

require("./roblox")
local Schema = require("../src")

local function reason(schema: any, value: any): string?
	local _, why = schema:check(value)
	return why
end

describe("Schema", function()
	describe("check", function()
		it("checks scalars", function()
			expect(Schema.boolean():check(true)).toBe(true)
			expect(reason(Schema.boolean(), 1)).toBe("expected a boolean, got 1")

			expect(Schema.int(1, 10):check(5)).toBe(true)
			expect(Schema.int(1, 10):check(5.5)).toBe(false)
			expect(reason(Schema.int(1, 10), 11)).toBe("expected an integer of 1 to 10, got 11")
			expect(Schema.int(0):check(-1)).toBe(false)

			expect(Schema.number():check(0 / 0)).toBe(false)
			expect(Schema.number(0, 1):check(0.5)).toBe(true)

			expect(Schema.string(1, 3):check("")).toBe(false)
			expect(Schema.string():check(string.rep("a", 1001))).toBe(false)

			expect(Schema.enum({ "a", "b" }):check("b")).toBe(true)
			expect(reason(Schema.enum({ "a", "b" }), "c")).toBe('expected one of "a", "b", got "c"')
		end)

		it("reports the path to the part that failed", function()
			local Profile = Schema.struct({
				name = Schema.string(1, 20),
				items = Schema.array(Schema.struct({ id = Schema.int(0) })),
				stats = Schema.map(Schema.string(), Schema.number()),
			})

			expect(Profile:check({ name = "a", items = {}, stats = {} })).toBe(true)
			expect(reason(Profile, { name = "a", items = { { id = 1 }, { id = -1 } }, stats = {} })).toBe(
				"items[2].id: expected an integer of at least 0, got -1"
			)
			expect(reason(Profile, { name = "a", items = {}, stats = { speed = "fast" } })).toBe(
				'stats.speed: expected a number, got "fast"'
			)
			expect(reason(Profile, { name = "a", items = {}, stats = {}, extra = 1 })).toBe("extra: is not a field")
			expect(reason(Profile, { items = {}, stats = {} })).toBe("name: expected a string of 1 to 20 bytes, got nil")
		end)

		it("lets optional fields be missing", function()
			local Pet = Schema.struct({ name = Schema.optional(Schema.string()) })
			expect(Pet:check({})).toBe(true)
			expect(Pet:check({ name = "rex" })).toBe(true)
			expect(Pet:check({ name = 1 })).toBe(false)
		end)

		it("refuses arrays with holes or too many items", function()
			local List = Schema.array(Schema.int(), 1, 2)
			expect(List:check({ 1, 2 })).toBe(true)
			expect(List:check({})).toBe(false)
			expect(List:check({ 1, 2, 3 })).toBe(false)
			expect(List:check({ [1] = 1, [3] = 3 })).toBe(false)
		end)

		it("tells tagged variants apart", function()
			local Outcome = Schema.tagged({
				kind = {
					hit = Schema.struct({ target = Schema.int(0, 255) }),
					miss = Schema.struct({}),
				},
			})

			expect(Outcome:check({ kind = "hit", target = 4 })).toBe(true)
			expect(Outcome:check({ kind = "miss" })).toBe(true)
			expect(reason(Outcome, { kind = "hit" })).toBe("target: expected an integer of 0 to 255, got nil")
			expect(reason(Outcome, { kind = "crit" })).toBe('kind: expected one of "hit", "miss", got "crit"')
			expect(function()
				Schema.tagged({ kind = { hit = Schema.int() } } :: any)
			end).toThrow("struct")
			expect(function()
				Schema.tagged({ kind = {}, type = {} } :: any)
			end).toThrow("kind = {")
		end)

		it("refuses what is not a schema or a name", function()
			expect(function()
				Schema.struct({ coins = 5 } :: any)
			end).toThrow("schema")
			expect(function()
				Schema.enum({ 1, 2 })
			end).toThrow("strings")
		end)

		it("runs refines after the rest fits", function()
			local Even = Schema.int(0, 10):refine(function(value)
				return if value % 2 == 0 then nil else "expected an even number"
			end)

			expect(Even:check(4)).toBe(true)
			expect(reason(Even, 3)).toBe("expected an even number")
			expect(reason(Even, 12)).toBe("expected an integer of 0 to 10, got 12")
		end)

		it("asserts", function()
			expect(Schema.int():assert(3)).toBe(3)
			expect(function()
				Schema.int():assert("3")
			end).toThrow("expected an integer")
		end)
	end)

	describe("reconcile", function()
		it("fills missing fields and drops unknown ones", function()
			local Data = Schema.struct({
				coins = Schema.int(0),
				music = Schema.boolean():default(true),
				pet = Schema.optional(Schema.enum({ "cat", "dog" })),
				name = Schema.string(),
			})

			expect(Data:reconcile({ coins = 5, old = 1 })).toEqual({ coins = 5, music = true, name = "" })
			expect(Data:reconcile(nil)).toEqual({ coins = 0, music = true, name = "" })
			expect(Data:reconcile({ coins = -5, music = false, pet = "fish" })).toEqual({ coins = 0, music = false, name = "" })
		end)

		it("clamps numbers and cuts strings", function()
			expect(Schema.int(0, 10):reconcile(12.4)).toBe(10)
			expect(Schema.int(0, 10):reconcile(3.6)).toBe(4)
			expect(Schema.number(-1, 1):reconcile(-5)).toBe(-1)
			expect(Schema.string(0, 3):reconcile("abcdef")).toBe("abc")
		end)

		it("keeps the array items that fit or can be repaired", function()
			local List = Schema.array(Schema.struct({ id = Schema.int(0), tag = Schema.string() }), 0, 2)
			expect(List:reconcile({ { id = 1 }, "bad", { id = 2, tag = "x" }, { id = 3 } })).toEqual({
				{ id = 1, tag = "" },
				{ id = 2, tag = "x" },
			})
		end)

		it("drops map pairs whose key does not fit", function()
			local Scores = Schema.map(Schema.string(), Schema.int(0))
			expect(Scores:reconcile({ a = 1, [2] = 3, b = -1 })).toEqual({ a = 1, b = 0 })
		end)

		it("returns a copy, never the value itself", function()
			local List = Schema.array(Schema.int())
			local value = { 1, 2 }
			local result = List:reconcile(value)
			expect(result).toEqual(value)
			expect(result).toNotBe(value)
		end)

		it("needs a default where none can be made", function()
			expect(function()
				Schema.string(1):reconcile(nil)
			end).toThrow("default")
			expect(Schema.string(1):default("guest"):reconcile(nil)).toBe("guest")
			expect(function()
				Schema.string(1):default("")
			end).toThrow("does not fit")
		end)

		it("leaves the schema it came from unchanged", function()
			local base = Schema.boolean()
			local on = base:default(true)
			expect(base:reconcile(nil)).toBe(false)
			expect(on:reconcile(nil)).toBe(true)
		end)
	end)

	describe("codec", function()
		it("builds the matching Lync codec", function()
			expect(Schema.int(0, 10):codec().kind).toBe("int")
			expect(Schema.int(0):codec().kind).toBe("vlq")
			expect(Schema.int():codec().kind).toBe("vli")
			expect(Schema.number():codec().kind).toBe("f64")
			expect(Schema.number(0, 1, 0.1):codec().kind).toBe("quant")
			expect(Schema.string():codec().args[2]).toBe(1000)

			local codec = Schema.struct({
				hp = Schema.int(0, 100),
				tags = Schema.array(Schema.string(0, 8), 0, 4),
				pet = Schema.optional(Schema.enum({ "cat" })),
			}):codec()

			expect(codec.kind).toBe("struct")
			local fields = codec.args[1]
			expect(fields.hp.kind).toBe("int")
			expect(fields.tags.kind).toBe("array")
			expect(fields.tags.args[1].kind).toBe("str")
			expect(fields.pet.kind).toBe("optional")
			expect(fields.pet.args[1].kind).toBe("enum")

			local tagged: any = Schema.tagged({
				kind = { hit = Schema.struct({ target = Schema.int(0, 255) }) },
			}):codec()

			expect(tagged.kind).toBe("tagged")
			expect(tagged.args[1]).toBe("kind")
			expect(tagged.args[2].hit.kind).toBe("struct")
		end)

		it("builds a codec once", function()
			local schema = Schema.int(0, 10)
			expect(schema:codec()).toBe(schema:codec())
		end)

		it("turns refines into validates", function()
			local Even = Schema.int(0, 10):refine(function(value)
				return if value % 2 == 0 then nil else "odd"
			end)
			expect(#Even:codec().validates).toBe(1)
		end)

		it("encodes and decodes through Lync", function()
			local Point = Schema.struct({ x = Schema.int(), y = Schema.int() })
			local bytes = Point:encode({ x = 1, y = 2 })
			expect(Point:decode(bytes)).toEqual({ x = 1, y = 2 })
			expect(function()
				Point:encode({ x = 1 } :: any)
			end).toThrow("y: expected an integer")
		end)
	end)

	it("tells schemas apart", function()
		expect(Schema.is(Schema.int())).toBe(true)
		expect(Schema.is({})).toBe(false)
	end)
end)

return nil

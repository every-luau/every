--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

require("./roblox")
local Void = require("../src")

-- a table cleaned through `method`, with a count of how many times it was
local function cleanable(method: string): (any, () -> number)
	local count = 0
	local item = {
		[method] = function()
			count += 1
		end,
	}

	return item, function(): number
		return count
	end
end

describe("Void", function()
	it("returns what it adds", function()
		local void = Void.new()
		local item = cleanable("destroy")
		expect(void:add(item)).toBe(item)
	end)

	it("cleans functions and tables with a cleanup method", function()
		local void = Void.new()
		local called = 0
		void:add(function()
			called += 1
		end)

		local counts = {}
		for _, method in { "Destroy", "Disconnect", "destroy", "disconnect" } do
			local item, count = cleanable(method)
			void:add(item)
			table.insert(counts, count)
		end

		void:clean()

		expect(called).toBe(1)
		for _, count in counts do
			expect(count()).toBe(1)
		end
		expect(void:is_empty()).toBe(true)
	end)

	it("closes threads", function()
		local void = Void.new()
		local thread = coroutine.create(function()
			coroutine.yield()
		end)
		coroutine.resume(thread)

		void:add(thread)
		void:clean()

		expect(coroutine.status(thread)).toBe("dead")
	end)

	it("refuses what it can't clean", function()
		local void = Void.new()
		expect(function()
			void:add(5 :: any)
		end).toThrow()
		expect(function()
			void:add({} :: any)
		end).toThrow()
	end)

	it("keeps a single entry for an item added twice", function()
		local void = Void.new()
		local item, count = cleanable("destroy")
		void:add(item)
		void:add(item)

		expect(#void:get_items()).toBe(1)
		void:clean()
		expect(count()).toBe(1)
	end)

	it("forgets removed items without cleaning them", function()
		local void = Void.new()
		local item, count = cleanable("destroy")
		void:add(item)

		expect(void:remove(item)).toBe(item)
		void:clean()
		expect(count()).toBe(0)

		void:add(item)
		void:remove_all()
		void:clean()
		expect(count()).toBe(0)
	end)

	it("cleans a single item with clean_item", function()
		local void = Void.new()
		local first, first_count = cleanable("destroy")
		local second, second_count = cleanable("destroy")
		void:add(first)
		void:add(second)

		void:clean_item(first)
		void:clean_item(first)

		expect(first_count()).toBe(1)
		expect(second_count()).toBe(0)
		expect(#void:get_items()).toBe(1)
	end)

	it("cleans extended voids with their parent", function()
		local void = Void.new()
		local child = void:extend()
		local item, count = cleanable("destroy")
		child:add(item)

		void:clean()

		expect(count()).toBe(1)
		expect(child:is_empty()).toBe(true)
	end)

	it("constructs and adds objects", function()
		local void = Void.new()
		local made = void:construct(function(method: string)
			return (cleanable(method))
		end, "destroy")
		local from_class = void:construct({
			new = function()
				return (cleanable("disconnect"))
			end,
		})

		expect(type(made.destroy)).toBe("function")
		expect(type(from_class.disconnect)).toBe("function")
		expect(#void:get_items()).toBe(2)
	end)

	it("cleans through wrap_clean and destroy, and can be used again", function()
		local void = Void.new()
		local item, count = cleanable("destroy")

		void:add(item)
		void:wrap_clean()()
		void:add(item)
		void:destroy()

		expect(count()).toBe(2)
	end)

	it("tells voids apart", function()
		expect(Void.is(Void.new())).toBe(true)
		expect(Void.is({})).toBe(false)
	end)
end)

return nil

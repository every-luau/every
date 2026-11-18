--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

require("./roblox")

-- fake instances are tables marked with `instance`, a ModuleScript holding what
-- requiring it returns
local originalTypeof = typeof
;(_G :: any).typeof = function(value: any): string
	if type(value) == "table" and rawget(value, "instance") then
		return "Instance"
	end
	return originalTypeof(value)
end

local Bootstrap = require("../src")

local function moduleScript(name: string, returns: any): any
	return {
		instance = true,
		Name = name,
		returns = returns,
		IsA = function(_, className: string)
			return className == "ModuleScript"
		end,
	}
end

local function folder(children: { any }): any
	return {
		instance = true,
		GetDescendants = function()
			return children
		end,
		IsA = function()
			return false
		end,
	}
end

-- `Bootstrap.load` requires the fake ModuleScripts through the global `require`
local originalRequire = require
;(_G :: any).require = function(target: any, ...: any): any
	if type(target) == "table" then
		if target.returns == "error" then
			error(`{target.Name} errored`, 0)
		end
		return target.returns
	end
	return originalRequire(target, ...)
end

describe("Bootstrap", function()
	describe("load", function()
		it("requires module scripts sorted by priority, in found order on ties", function()
			local low = { _priority = -1 }
			local first = {}
			local high = { _priority = 10 }
			local second = {}

			local container = folder({
				moduleScript("Low", low),
				moduleScript("First", first),
				folder({}),
				moduleScript("High", high),
				moduleScript("Second", second),
			})

			local modules = Bootstrap.load(container):unwrap()
			expect(modules).toEqual({ high, first, second, low })
		end)

		it("only keeps tables, giving them their instance", function()
			local service = {}
			local script = moduleScript("Service", service)
			local frozen = table.freeze({})

			local modules = Bootstrap.load({
				folder({ script, moduleScript("Number", 5) }),
				folder({ moduleScript("Frozen", frozen) }),
			}):unwrap()

			expect(#modules).toBe(2)
			expect(service._instance).toBe(script)
			expect(rawget(frozen, "_instance")).toBeNil()
		end)

		it("filters module scripts with the predicate", function()
			local kept = {}
			local modules = Bootstrap.load(folder({ moduleScript("KeptService", kept), moduleScript("Other", {}) }), function(module)
				return module.Name:match("Service$") ~= nil
			end):unwrap()

			expect(modules).toEqual({ kept })
		end)

		it("rejects when a module errors", function()
			local future = Bootstrap.load(folder({ moduleScript("Broken", "error") }))
			expect(future:get_status()).toBe("rejected")
			expect(function()
				future:unwrap()
			end).toThrow("Broken errored")
		end)
	end)

	describe("call", function()
		it("calls the method on every module that has it, with the arguments", function()
			local calls: { any } = {}
			local a = {
				Init = function(self, value)
					table.insert(calls, { self, value })
				end,
			}
			local b = {}
			local c = {
				Init = function(self, value)
					table.insert(calls, { self, value })
				end,
			}

			local modules = { a, b, c }
			local result = Bootstrap.call(modules, "Init", 42):unwrap()

			expect(result).toBe(modules)
			expect(calls).toEqual({ { a, 42 }, { c, 42 } })
		end)

		it("waits for yielding methods before resolving", function()
			local resume: thread? = nil
			local future = Bootstrap.call({
				{
					Start = function()
						resume = coroutine.running()
						coroutine.yield()
					end,
				},
			}, "Start")

			expect(future:is_pending()).toBe(true)
			task.spawn(resume :: thread)
			expect(future:get_status()).toBe("resolved")
		end)

		it("rejects when a method errors", function()
			local future = Bootstrap.call({
				{
					Init = function()
						error("init failed", 0)
					end,
				},
			}, "Init")

			expect(future:get_status()).toBe("rejected")
		end)
	end)
end)

return nil

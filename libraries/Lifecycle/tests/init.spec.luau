--!strict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local Lifecycle = require("../src")

describe("Lifecycle", function()
	it("registers hooks with chainable On calls", function()
		local calls: { string } = {}
		local service = Lifecycle.new()
			:OnInit(function(_self, value)
				table.insert(calls, `init {value}`)
			end)
			:OnStart(function()
				table.insert(calls, "start")
			end)

		service:Init(1)
		service:Start()
		expect(calls).toEqual({ "init 1", "start" })
	end)

	it("passes the lifecycle as self", function()
		local received: any = nil
		local service = Lifecycle.new():OnInit(function(self)
			received = self
		end)

		service:Init()
		expect(received).toBe(service)
	end)

	it("registers snake_case hooks with on_", function()
		local called = false
		local service = Lifecycle.new():on_init(function()
			called = true
		end)

		service:init()
		expect(called).toBe(true)
	end)

	it("replaces a hook registered again", function()
		local calls: { string } = {}
		local service = Lifecycle.new()
		service:OnInit(function()
			table.insert(calls, "first")
		end)
		service:OnInit(function()
			table.insert(calls, "second")
		end)

		service:Init()
		expect(calls).toEqual({ "second" })
	end)

	it("returns nil for keys that are not hooks", function()
		local service = Lifecycle.new()
		expect(service.Init).toBeNil()
		expect(service.whatever).toBeNil()
	end)

	it("keeps plain values", function()
		local service = Lifecycle.new()
		service.Name = "Service"
		expect(service.Name).toBe("Service")
	end)

	it("defaults the priority to 0", function()
		expect(Lifecycle.new()._priority).toBe(0)
		expect(Lifecycle.new(5)._priority).toBe(5)
	end)

	it("runs base hooks before extended ones", function()
		local calls: { string } = {}
		local base = Lifecycle.new(3)
			:OnInit(function()
				table.insert(calls, "base")
			end)
			:OnStart(function()
				table.insert(calls, "base start")
			end)

		local derived = Lifecycle.extend(base):OnInit(function()
			table.insert(calls, "derived")
		end)

		derived:Init()
		derived:Start()
		expect(calls).toEqual({ "base", "derived", "base start" })
		expect(derived._priority).toBe(3)
	end)

	it("does not change the base when extended", function()
		local calls: { string } = {}
		local base = Lifecycle.new():OnInit(function()
			table.insert(calls, "base")
		end)

		Lifecycle.extend(base):OnInit(function()
			table.insert(calls, "derived")
		end)

		base:Init()
		expect(calls).toEqual({ "base" })
	end)

	it("clones hooks, replacing them when registered again", function()
		local calls: { string } = {}
		local template = Lifecycle.new(2):OnInit(function()
			table.insert(calls, "template")
		end)

		local copy = Lifecycle.clone(template, 7)
		copy:Init()
		copy:OnInit(function()
			table.insert(calls, "copy")
		end)
		copy:Init()

		expect(calls).toEqual({ "template", "copy" })
		expect(copy._priority).toBe(7)
	end)

	it("tells lifecycles apart", function()
		expect(Lifecycle.is(Lifecycle.new())).toBe(true)
		expect(Lifecycle.is(Lifecycle.extend(Lifecycle.new()))).toBe(true)
		expect(Lifecycle.is({ _priority = 0 })).toBe(false)
	end)
end)

return nil

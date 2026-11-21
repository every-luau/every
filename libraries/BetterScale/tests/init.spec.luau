--!nonstrict
local Lest = require("@lest")
local describe, it, expect = Lest.describe, Lest.it, Lest.expect

local roblox = require("./roblox")
local BetterScale = require("../src")

local Enum, NumberRange, Vector2 = roblox.Enum, roblox.NumberRange, roblox.Vector2

describe("BetterScale", function()
	it("fits the resolution in the gui on both axes by default", function()
		expect(BetterScale.new((roblox.screen(1920, 1080))):get_scale()).toBe(1.5)
		expect(BetterScale.new((roblox.screen(2560, 720))):get_scale()).toBe(1)
		expect(BetterScale.new((roblox.screen(640, 1440))):get_scale()).toBe(0.5)
	end)

	it("follows a single axis", function()
		local ui_scale = roblox.screen(2560, 360)

		ui_scale:SetAttribute("Direction", Enum.AutomaticSize.X)
		expect(BetterScale.new(ui_scale):get_scale()).toBe(2)

		ui_scale:SetAttribute("Direction", Enum.AutomaticSize.Y)
		expect(BetterScale.new(ui_scale):get_scale()).toBe(0.5)
	end)

	it("only uses the ratio without a direction", function()
		local ui_scale = roblox.screen(2560, 1440)
		ui_scale:SetAttribute("Direction", Enum.AutomaticSize.None)
		ui_scale:SetAttribute("Ratio", 3)
		ui_scale:SetAttribute("Range", NumberRange.new(0, 2))
		expect(BetterScale.new(ui_scale):get_scale()).toBe(2)
	end)

	it("clamps to the range, then multiplies by the ratio", function()
		local ui_scale = roblox.screen(3840, 2160)
		ui_scale:SetAttribute("Range", NumberRange.new(0.5, 2))
		ui_scale:SetAttribute("Ratio", 1.5)
		ui_scale:SetAttribute("Resolution", Vector2.new(960, 540))
		expect(BetterScale.new(ui_scale):get_scale()).toBe(3)
	end)

	it("multiplies the ratio for the display size", function()
		local ui_scale = roblox.screen(1280, 720)
		ui_scale:SetAttribute("DisplayRatios", '{"Small": 1.5, "Large": 0.5}')
		local scale = BetterScale.new(ui_scale)

		roblox.GuiService.ViewportDisplaySize = Enum.DisplaySize.Small
		expect(scale:get_scale()).toBe(1.5)

		roblox.GuiService.ViewportDisplaySize = Enum.DisplaySize.Medium
		expect(scale:get_scale()).toBe(1)

		ui_scale:SetAttribute("DisplayRatios", "not json")
		roblox.GuiService.ViewportDisplaySize = Enum.DisplaySize.Small
		expect(scale:get_scale()).toBe(1)

		roblox.GuiService.ViewportDisplaySize = Enum.DisplaySize.Medium
	end)

	it("ignores attributes of the wrong type", function()
		local ui_scale = roblox.screen(1280, 720)
		ui_scale:SetAttribute("Ratio", "big")
		ui_scale:SetAttribute("Range", 5)
		ui_scale:SetAttribute("Resolution", Enum.AutomaticSize.X)
		ui_scale:SetAttribute("Direction", Enum.DisplaySize.Small)

		local attributes = BetterScale.new(ui_scale):get_attributes()
		expect(attributes.Ratio).toBe(1)
		expect(attributes.Range.Max).toBe(math.huge)
		expect(attributes.Resolution.X).toBe(1280)
		expect(attributes.Direction).toBe(Enum.AutomaticSize.XY)
	end)

	it("does nothing outside of a gui", function()
		local ui_scale = roblox.new("UIScale")
		ui_scale.Scale = 1
		local scale = BetterScale.new(ui_scale)

		expect(scale:get_scale()).toBeNil()
		scale:update()
		expect(ui_scale.Scale).toBe(1)
	end)

	it("tracks the next frame, resizes, attributes and display sizes", function()
		local ui_scale, gui = roblox.screen(1920, 1080)
		ui_scale:SetAttribute("DisplayRatios", '{"Small": 2}')
		local scale = BetterScale.build(ui_scale)

		expect(ui_scale.Scale).toBe(1)
		roblox.render()
		expect(ui_scale.Scale).toBe(1.5)

		gui.AbsoluteSize = Vector2.new(640, 360)
		expect(ui_scale.Scale).toBe(0.5)

		ui_scale:SetAttribute("Ratio", 2)
		expect(ui_scale.Scale).toBe(1)

		roblox.GuiService.ViewportDisplaySize = Enum.DisplaySize.Small
		expect(ui_scale.Scale).toBe(2)
		roblox.GuiService.ViewportDisplaySize = Enum.DisplaySize.Medium

		scale:untrack()
		expect(scale:is_tracking()).toBe(false)
		gui.AbsoluteSize = Vector2.new(1280, 720)
		expect(ui_scale.Scale).toBe(1)
	end)

	it("follows the UIScale into another gui", function()
		local ui_scale, first = roblox.screen(1280, 720)
		local _, second = roblox.screen(2560, 1440)
		BetterScale.build(ui_scale)

		ui_scale.Parent = second
		expect(ui_scale.Scale).toBe(2)

		first.AbsoluteSize = Vector2.new(640, 360)
		expect(ui_scale.Scale).toBe(2)

		second.AbsoluteSize = Vector2.new(1920, 1080)
		expect(ui_scale.Scale).toBe(1.5)
	end)

	it("uses the closest gui", function()
		local ui_scale, gui = roblox.screen(1280, 720)
		local surface = roblox.new("SurfaceGui", gui)
		surface.AbsoluteSize = Vector2.new(2560, 1440)
		ui_scale.Parent = surface

		expect(BetterScale.new(ui_scale):get_container()).toBe(surface)
	end)

	it("is destroyed once the UIScale is removed", function()
		local ui_scale, gui = roblox.screen(1280, 720)
		local scale = BetterScale.build(ui_scale)

		ui_scale.Parent = nil
		expect(scale:is_tracking()).toBe(false)

		ui_scale.Parent = gui
		gui.AbsoluteSize = Vector2.new(2560, 1440)
		expect(ui_scale.Scale).toBe(1)

		scale:track()
		gui.AbsoluteSize = Vector2.new(1920, 1080)
		expect(ui_scale.Scale).toBe(1.5)
	end)

	it("errors without a UIScale", function()
		expect(function()
			BetterScale.new(roblox.new("Frame"))
		end).toThrow("expected a UIScale")
	end)

	it("tells BetterScales apart", function()
		expect(BetterScale.is(BetterScale.new((roblox.screen(1, 1))))).toBe(true)
		expect(BetterScale.is({})).toBe(false)
	end)
end)

return nil

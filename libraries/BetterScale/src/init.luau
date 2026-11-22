--[=[
	@class BetterScale

	BetterScale scales a UIScale with the size of its gui, configured with attributes

	give it a UIScale, then call [BetterScale:track] or create it with
	[BetterScale.build]. it sets the UIScale's `Scale` so that a design made for
	one resolution fits the gui the UIScale is in, and updates it when the gui is
	resized or the attributes change

	```lua
	local BetterScale = require(path.to.BetterScale)

	ui_scale:SetAttribute("Resolution", Vector2.new(1920, 1080))
	ui_scale:SetAttribute("Range", NumberRange.new(0.5, 2))

	local scale = BetterScale.build(ui_scale)
	```

	:::info
	the attributes are all optional: `Resolution` (Vector2, 1280x720), `Direction`
	(an `Enum.AutomaticSize`, XY), `Range` (NumberRange, 0 to infinity), `Ratio`
	(number, 1) and `DisplayRatios`, a JSON object of `Enum.DisplaySize` names to
	numbers that multiply the ratio on those screens. an attribute of the wrong
	type is ignored
	:::
]=]

const GuiService = game:GetService("GuiService")
const HttpService = game:GetService("HttpService")
const RunService = game:GetService("RunService")

const Void = require(script.Parent.Void)

const DEFAULT_RATIO = 1
const DEFAULT_RANGE = NumberRange.new(0, math.huge)
const DEFAULT_RESOLUTION = Vector2.new(1280, 720)
const DEFAULT_DIRECTION = Enum.AutomaticSize.XY

--[=[
	@within BetterScale
	@interface Attributes
	.Ratio number -- multiplies the scale, after it is clamped to `Range`
	.Range NumberRange -- the scale before `Ratio` stays in it
	.Resolution Vector2 -- the size the gui was designed for
	.Direction Enum.AutomaticSize -- the axes to follow: X, Y, XY for the smallest fit, or None to only use `Ratio`

	the attributes of a UIScale, with defaults for the missing ones
]=]
export type Attributes = {
	Ratio: number,
	Range: NumberRange,
	Resolution: Vector2,
	Direction: Enum.AutomaticSize,
}

export type BetterScale = setmetatable<{
	_ui_scale: UIScale,
	_tracking: Void.Void | false,
	-- the AbsoluteSize connection of the gui, while tracking
	_resized: RBXScriptConnection | false,
	-- the last DisplayRatios string and what it decoded to
	_display_ratios: { source: string, ratios: { [string]: number } } | false,
	get_attributes: (self: BetterScale) -> Attributes,
	get_container: (self: BetterScale) -> LayerCollector?,
	get_scale: (self: BetterScale) -> number?,
	update: (self: BetterScale) -> (),
	track: (self: BetterScale) -> BetterScale,
	untrack: (self: BetterScale) -> BetterScale,
	is_tracking: (self: BetterScale) -> boolean,
	destroy: (self: BetterScale) -> (),
}, { __index: BetterScale }>

-- `value` if it is of the Roblox type `type_name`, `default` otherwise
const function typed<T>(value: any, type_name: string, default: T): T
	return if typeof(value) == type_name then value else default
end

const BetterScale = {}
BetterScale.__index = BetterScale

--[=[
	@within BetterScale
	@function new
	@param ui_scale UIScale
	@return BetterScale

	creates a BetterScale for `ui_scale`, without tracking it yet. errors when
	`ui_scale` isn't a UIScale
]=]
function BetterScale.new(ui_scale: UIScale): BetterScale
	if typeof(ui_scale) ~= "Instance" or not ui_scale:IsA("UIScale") then
		error(`BetterScale expected a UIScale, got {ui_scale}`, 2)
	end

	return setmetatable(
		{
			_ui_scale = ui_scale,
			_tracking = false,
			_resized = false,
			_display_ratios = false,
		},
		BetterScale
	) :: any
end

--[=[
	@within BetterScale
	@function build
	@param ui_scale UIScale
	@return BetterScale

	creates a BetterScale for `ui_scale` and tracks it right away
]=]
function BetterScale.build(ui_scale: UIScale): BetterScale
	return BetterScale.new(ui_scale):track()
end

--[=[
	@within BetterScale
	@function is
	@param obj any
	@return boolean

	returns whether `obj` is a BetterScale
]=]
function BetterScale.is(obj: any): boolean
	return type(obj) == "table" and getmetatable(obj) == BetterScale
end

-- the number DisplayRatios gives the current display size, 1 without one
const function display_ratio(self: BetterScale): number
	const source = self._ui_scale:GetAttribute("DisplayRatios")
	if type(source) ~= "string" then
		return 1
	end

	local cached = self._display_ratios
	if not cached or cached.source ~= source then
		const ok, decoded = pcall(HttpService.JSONDecode, HttpService, source)
		cached = { source = source, ratios = if ok and type(decoded) == "table" then decoded else {} }
		self._display_ratios = cached
	end

	const ratio = (cached :: any).ratios[GuiService.ViewportDisplaySize.Name]
	return if type(ratio) == "number" then ratio else 1
end

--[=[
	@within BetterScale
	@method get_attributes
	@return Attributes

	returns the attributes of the UIScale, with the defaults for the ones that are
	missing or of the wrong type. `DisplayRatios` is not applied to `Ratio` here
]=]
function BetterScale.get_attributes(self: BetterScale): Attributes
	const ui_scale = self._ui_scale
	const direction = ui_scale:GetAttribute("Direction")

	return {
		Ratio = typed(ui_scale:GetAttribute("Ratio"), "number", DEFAULT_RATIO),
		Range = typed(ui_scale:GetAttribute("Range"), "NumberRange", DEFAULT_RANGE),
		Resolution = typed(ui_scale:GetAttribute("Resolution"), "Vector2", DEFAULT_RESOLUTION),
		Direction = if typeof(direction) == "EnumItem" and direction.EnumType == Enum.AutomaticSize
			then direction :: any
			else DEFAULT_DIRECTION,
	}
end

--[=[
	@within BetterScale
	@method get_container
	@return LayerCollector?

	returns the closest gui the UIScale is in: a ScreenGui, SurfaceGui,
	BillboardGui or plugin widget
]=]
function BetterScale.get_container(self: BetterScale): LayerCollector?
	return self._ui_scale:FindFirstAncestorWhichIsA("LayerCollector") :: LayerCollector?
end

--[=[
	@within BetterScale
	@method get_scale
	@return number?

	returns the scale the UIScale should have, or nil when it isn't in a gui
]=]
function BetterScale.get_scale(self: BetterScale): number?
	const container = self:get_container()
	if not container then
		return nil
	end

	const attributes = self:get_attributes()
	const range = attributes.Range
	const ratio = attributes.Ratio * display_ratio(self)
	const direction = attributes.Direction

	if direction == Enum.AutomaticSize.None then
		return math.clamp(ratio, range.Min, range.Max)
	end

	const size = container.AbsoluteSize
	const resolution = attributes.Resolution
	const x, y = size.X / resolution.X, size.Y / resolution.Y
	const fit = if direction == Enum.AutomaticSize.X then x elseif direction == Enum.AutomaticSize.Y then y else math.min(x, y)

	return math.clamp(fit, range.Min, range.Max) * ratio
end

--[=[
	@within BetterScale
	@method update

	sets the UIScale's `Scale` right away. does nothing when it isn't in a gui
]=]
function BetterScale.update(self: BetterScale)
	const scale = self:get_scale()
	if scale then
		self._ui_scale.Scale = scale
	end
end

-- listens to the AbsoluteSize of the current gui, and stops listening to the
-- previous one
const function follow_container(self: BetterScale)
	const tracking = self._tracking
	if not tracking then
		return
	end

	const resized = self._resized
	if resized then
		self._resized = false
		tracking:clean_item(resized)
	end

	const container = self:get_container()
	if container then
		self._resized = tracking:add(container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:update()
		end))
	end
end

--[=[
	@within BetterScale
	@method track
	@return BetterScale

	updates on the next frame, then whenever the gui is resized, an attribute
	changes, the display size changes or the UIScale moves to another gui. removing
	the UIScale from its parent stops tracking
]=]
function BetterScale.track(self: BetterScale): BetterScale
	if self._tracking then
		return self
	end

	const ui_scale = self._ui_scale
	const tracking = Void.new()
	self._tracking = tracking

	const function update()
		self:update()
	end

	tracking:add(RunService.RenderStepped:Once(update))
	tracking:add(ui_scale.AttributeChanged:Connect(update))
	tracking:add(GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(update))
	tracking:add(ui_scale.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			self:untrack()
			return
		end

		follow_container(self)
		self:update()
	end))
	follow_container(self)

	return self
end

--[=[
	@within BetterScale
	@method untrack
	@return BetterScale

	stops updating the UIScale. it keeps its current `Scale`
]=]
function BetterScale.untrack(self: BetterScale): BetterScale
	const tracking = self._tracking
	if tracking then
		self._tracking = false
		self._resized = false
		tracking:clean()
	end

	return self
end

--[=[
	@within BetterScale
	@method is_tracking
	@return boolean

	returns whether the UIScale is tracked
]=]
function BetterScale.is_tracking(self: BetterScale): boolean
	return self._tracking ~= false
end

--[=[
	@within BetterScale
	@method destroy

	the same as [BetterScale:untrack], so a BetterScale can be added to a [Void]
]=]
function BetterScale.destroy(self: BetterScale)
	self:untrack()
end

return table.freeze({
	new = BetterScale.new,
	build = BetterScale.build,
	is = BetterScale.is,
})

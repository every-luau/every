--!strict
-- Tracking everything a feature creates, then cleaning it all at once.

local Void = require("../src")

local void = Void.new()

-- `add` returns the item, so it can be created and tracked on one line.
local part = void:add(Instance.new("Part"))
part.Parent = workspace

-- Connections are disconnected, threads cancelled and functions called.
void:add(workspace.ChildAdded:Connect(print))
void:add(task.delay(10, print, "never printed"))
void:add(function()
	print("cleaned")
end)

-- `clone` tracks the clone, and `construct` builds and tracks an object.
local copy = void:clone(part)
local folder = void:construct(Instance, "Folder")

-- `extend` creates a Void cleaned along with this one, but that can be cleaned on its own.
local round = void:extend()
round:add(Instance.new("Part"))
round:clean() -- only the round's part is destroyed

-- `clean_item` cleans one item right away, `remove` stops tracking it without cleaning it.
void:clean_item(copy)
void:remove(folder)

void:clean() --> cleaned
print(void:is_empty()) --> true

-- A Void can be reused after cleaning, and tied to an instance: it is cleaned once the
-- instance leaves the game, destroyed or not.
local model = Instance.new("Model")
model.Parent = workspace

local owned = Void.new()
owned:add(Instance.new("Part"))
owned:attach_to_instance(model)

model:Destroy() -- cleans `owned`

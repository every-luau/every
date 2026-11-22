--!strict
-- Starting every service of a game from one script.

local ServerScriptService = game:GetService("ServerScriptService")

local Bootstrap = require("../src")

-- Requires every ModuleScript under Services, the highest `_priority` first.
local services = Bootstrap.load(ServerScriptService.Services, function(module)
	return not module.Name:match("%.spec$")
end):await()

-- Calls `init` on every service at once, waits for all of them, then does the
-- same with `start`. a module without the method is skipped.
Bootstrap.call(services, "init"):await()
Bootstrap.call(services, "start"):await()

print(`started {#services} services`)

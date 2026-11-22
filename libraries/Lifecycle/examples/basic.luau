--!strict
-- Services sharing a base lifecycle.

local Lifecycle = require("../src")

-- Hooks are named after the call that registers them.
local BaseService = Lifecycle.new():on_init(function(self)
	self.ready = false
end)

-- Runs the base's `init` first, then its own.
local CoinService = Lifecycle.extend(BaseService)
	:on_init(function(self)
		self.coins = {}
	end)
	:on_start(function(self)
		self.ready = true
	end)

CoinService:init()
CoinService:start()
print(CoinService.ready) --> true

-- A copy whose hooks can be replaced without changing the template.
local GemService = Lifecycle.clone(CoinService, 5):on_start(function(self)
	print("gems ready")
end)
print(GemService._priority) --> 5

-- A hook that was never registered is nil.
print(CoinService.stop) --> nil

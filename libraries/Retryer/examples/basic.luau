--!strict
-- Saving to a DataStore that sometimes fails.

local DataStoreService = game:GetService("DataStoreService")

local Retryer = require("../src")

local store = DataStoreService:GetDataStore("Coins")

-- Tries 3 times right away.
local ok, coins = Retryer.zero_delay(3, store.GetAsync, store, "player_1")

-- Tries 5 times, waiting 2 seconds between attempts.
ok = Retryer.delay(2, 5, store.SetAsync, store, "player_1", 100)

-- Tries 5 times, waiting 1 + 2 ^ attempt seconds: 3, 5, 9 then 17 seconds.
ok, coins = Retryer.exp(1, 2, 5, store.GetAsync, store, "player_1")
if not ok then
	-- `coins` is the last error here.
	warn("couldn't load coins:", coins)
end

-- Never gives up, so it only returns what the function returns.
coins = Retryer.inf_exp(1, 2, store.GetAsync, store, "player_1")
print(coins)

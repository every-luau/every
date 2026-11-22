--!strict
-- Loading data that might fail, with a timeout and a fallback.

local Future = require("../src")

local function load(key: string)
	return Future.new(function(pass, fail)
		task.wait(1)
		if key == "" then
			fail("no key")
		else
			pass(`data for {key}`)
		end
	end)
end

-- `await` yields until the future settles, and errors if it was rejected.
print(load("coins"):await()) --> data for coins

-- `timeout` rejects when it takes too long, and `catch` turns that into a value.
local fallback = load("slow"):timeout(0.5):catch(function(err)
	return `fallback because {err}`
end)
print(fallback:await())

-- `and_then` transforms the value, `finally` runs however it ends.
load("profile")
	:and_then(function(data)
		return string.upper(data)
	end)
	:finally(function()
		print("done loading")
	end)

-- `all` waits for every future, in order.
print(Future.all({ load("a"), load("b") }):await()) --> { "data for a", "data for b" }

-- A future can be cancelled while it is pending.
local slow = load("never")
slow:cancel()
print(slow:get_status()) --> cancelled

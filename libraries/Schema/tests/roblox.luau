--!strict
-- Points `script.Parent.Lync` at the stand-in in `tests/lync.luau`, since the
-- real Lync needs the Roblox engine that lest's native backend does not have.

local globals = _G :: any
globals.script = {
	Parent = {
		Lync = "../tests/lync",
	},
}

return nil

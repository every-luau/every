--!strict
-- Minimal stand-in for the Roblox globals the library uses, since lest's native
-- backend has none.
--
-- `script.Parent.Cryptography` resolves to `./cryptography`, a stand-in for
-- daily3014/cryptography that installs nothing.

local globals = _G :: any
globals.script = {
	Parent = {
		Cryptography = "../tests/cryptography",
	},
}

return nil

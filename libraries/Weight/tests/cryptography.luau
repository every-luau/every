--!strict
-- Stand-in for daily3014/cryptography with only what Weight uses. Tests can swap
-- `Utilities.CSPRNG.Random` to control the rolls.

return {
	Utilities = {
		CSPRNG = {
			Random = math.random :: () -> number,
		},
	},
}

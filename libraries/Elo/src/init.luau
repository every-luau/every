--[=[
	@class Elo

	Elo rates players from the matches they play against each other

	build a config with [Elo.new] and its `set_` methods, then pass it to
	[Elo.rate] after each match. the winner takes points from the loser, more
	of them when the loser was rated higher

	```lua
	local Elo = require(path.to.Elo)

	local config = Elo.new():set_k(24):set_initial(1000)

	local alice, bob = 1000, 1200
	alice, bob = Elo.rate(config, alice, bob, Elo.WIN)
	print(alice, bob) --> 1018.2, 1181.8

	print(Elo.expected(config, alice, bob)) --> 0.28, the chance alice wins
	```

	:::info
	results are always from the first player: [Elo.WIN] means the first player
	won. a result can be any score from 0 to 1, a draw being 0.5
	:::

	Credits: [Nevermore](https://github.com/Quenty/NevermoreEngine) by Quenty,
	whose elo package this one follows
]=]

--[=[
	@within Elo
	@prop WIN number

	the first player won, a score of 1
]=]
--[=[
	@within Elo
	@prop DRAW number

	nobody won, a score of 0.5
]=]
--[=[
	@within Elo
	@prop LOSS number

	the first player lost, a score of 0
]=]
const WIN = 1
const DRAW = 0.5
const LOSS = 0

-- the standard deviation of a normal law is its scale over this
const SQRT2 = math.sqrt(2)

--[=[
	@within Elo
	@type K number | (rating: number) -> number

	how many points a match moves a rating: a number, or a function of the
	rating, like [Elo.fide]
]=]
export type K = number | (rating: number) -> number

export type Config = {
	set_k: (self: Config, k: K) -> Config,
	set_factor: (self: Config, factor: number) -> Config,
	set_initial: (self: Config, initial: number) -> Config,
	set_floor: (self: Config, floor: number) -> Config,
	set_group: (self: Config, group: boolean) -> Config,
	get_initial: (self: Config) -> number,
}

type Fields = {
	_k: K,
	_factor: number,
	_initial: number,
	_floor: number,
	_group: boolean,
}

const Config = {}
Config.__index = Config

--[=[
	@within Elo
	@function fide
	@param rating number
	@return number

	the K of the chess federation: 32 under 2100, 24 under 2400, then 16, so
	the best players move slower. it is the K of a new config
]=]
const function fide(rating: number): number
	if rating >= 2400 then
		return 16
	elseif rating >= 2100 then
		return 24
	end
	return 32
end

--[=[
	@within Elo
	@function new
	@return Config

	creates a config with the usual values, changed with its `set_` methods:

	| setting | default | method |
	| --- | --- | --- |
	| K | [Elo.fide] | `set_k` |
	| factor | 400 | `set_factor` |
	| initial rating | 1400 | `set_initial` |
	| lowest rating | 100 | `set_floor` |
	| series as one match | false | `set_group` |

	```lua
	local config = Elo.new():set_k(20):set_floor(0)
	```
]=]
const function new(): Config
	const fields: Fields = {
		_k = fide,
		_factor = 400,
		_initial = 1400,
		_floor = 100,
		_group = false,
	}
	return setmetatable(fields, Config) :: any
end

--[=[
	@within Elo
	@function is
	@param value any
	@return boolean

	returns whether `value` is a config from [Elo.new]
]=]
const function is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Config
end

--[=[
	@within Elo
	@method set_k
	@param k_factor K
	@return Config

	sets how many points a match moves a rating at most: a number, or a
	function of the rating
]=]
function Config.set_k(self: Config, k_factor: K): Config
	assert(
		type(k_factor) == "number" or type(k_factor) == "function",
		`[Elo] set_k needs a number or a function, got a {typeof(k_factor)}`
	)
	const fields: any = self
	fields._k = k_factor
	return self
end

--[=[
	@within Elo
	@method set_factor
	@param factor number
	@return Config

	sets the rating gap at which the stronger player is 10 times more likely
	to win
]=]
function Config.set_factor(self: Config, factor: number): Config
	assert(type(factor) == "number" and factor > 0, "[Elo] set_factor needs a number above 0")
	const fields: any = self
	fields._factor = factor
	return self
end

--[=[
	@within Elo
	@method set_initial
	@param initial number
	@return Config

	sets the rating of a new player, also the middle of [Elo.percentile]
]=]
function Config.set_initial(self: Config, initial: number): Config
	assert(type(initial) == "number", "[Elo] set_initial needs a number")
	const fields: any = self
	fields._initial = initial
	return self
end

--[=[
	@within Elo
	@method set_floor
	@param floor number
	@return Config

	sets the lowest rating a player can fall to, `-math.huge` for none
]=]
function Config.set_floor(self: Config, floor: number): Config
	assert(type(floor) == "number", "[Elo] set_floor needs a number")
	const fields: any = self
	fields._floor = floor
	return self
end

--[=[
	@within Elo
	@method set_group
	@param group boolean
	@return Config

	whether [Elo.rate] counts a series as one match, won by whoever won more
	games and worth as many matches as they won. otherwise each game counts
]=]
function Config.set_group(self: Config, group: boolean): Config
	assert(type(group) == "boolean", "[Elo] set_group needs a boolean")
	const fields: any = self
	fields._group = group
	return self
end

--[=[
	@within Elo
	@method get_initial
	@return number

	returns the rating of a new player
]=]
function Config.get_initial(self: Config): number
	return (self :: any)._initial
end

const function check(config: Config, rating_a: number, rating_b: number)
	assert(is(config), "[Elo] needs a config from Elo.new")
	assert(type(rating_a) == "number" and type(rating_b) == "number", "[Elo] needs two ratings")
end

--[=[
	@within Elo
	@function expected
	@param config Config
	@param rating_a number -- the rating of the first player
	@param rating_b number -- the rating of the second player
	@return number

	returns the score the first player should get against the second, from 0
	to 1: their chance of winning plus half their chance of a draw

	```lua
	Elo.expected(Elo.new(), 1400, 1400) --> 0.5
	Elo.expected(Elo.new(), 1800, 1400) --> 0.91
	```
]=]
const function expected(config: Config, rating_a: number, rating_b: number): number
	check(config, rating_a, rating_b)
	return 1 / (1 + 10 ^ ((rating_b - rating_a) / (config :: any)._factor))
end

-- the K of `config` for `rating`
const function k_of(config: any, rating: number): number
	const k_factor: K = config._k
	if type(k_factor) == "number" then
		return k_factor
	end
	return (k_factor :: (rating: number) -> number)(rating)
end

-- how far the first player did above what was expected, over every game
const function surprise(config: any, results: number | { number }, expectation: number): number
	if type(results) == "number" then
		assert(results >= 0 and results <= 1, "[Elo] a result is a score from 0 to 1")
		return results - expectation
	end

	if config._group then
		local wins, losses = 0, 0
		for _, score in results do
			assert(type(score) == "number" and score >= 0 and score <= 1, "[Elo] rating_a result is rating_a score from 0 to 1")
			if score == WIN then
				wins += 1
			elseif score == LOSS then
				losses += 1
			end
		end
		const score = if wins > losses then WIN elseif wins < losses then LOSS else DRAW
		return math.max(wins, losses, 1) * (score - expectation)
	end

	local total = 0
	for _, score in results do
		assert(type(score) == "number" and score >= 0 and score <= 1, "[Elo] rating_a result is rating_a score from 0 to 1")
		total += score - expectation
	end
	return total
end

--[=[
	@within Elo
	@function rate
	@param config Config
	@param rating_a number -- the rating of the first player
	@param rating_b number -- the rating of the second player
	@param results number | { number } -- the score of the first player, or of each game of a series
	@return number -- the new rating of the first player
	@return number -- the new rating of the second player
	@error "a result is a score from 0 to 1" -- a result is outside 0 to 1

	returns the ratings of both players after a match, or a series of games
	played from the same ratings. each player moves by their own K, and never
	below the floor

	```lua
	local config = Elo.new()
	local rating_a, rating_b = Elo.rate(config, 1400, 1800, Elo.WIN) --> 1429.1, 1770.9
	rating_a, rating_b = Elo.rate(config, rating_a, rating_b, { Elo.WIN, Elo.DRAW, Elo.LOSS })
	```
]=]
const function rate(config: Config, rating_a: number, rating_b: number, results: number | { number }): (number, number)
	const chance = expected(config, rating_a, rating_b)
	const gap = surprise(config, results, chance)
	const fields = config :: any
	const new_rating_a = math.max(fields._floor, rating_a + k_of(fields, rating_a) * gap)
	const new_rating_b = math.max(fields._floor, rating_b - k_of(fields, rating_b) * gap)
	return new_rating_a, new_rating_b
end

--[=[
	@within Elo
	@function change
	@param config Config
	@param rating_a number -- the rating of the first player
	@param rating_b number -- the rating of the second player
	@param results number | { number } -- the score of the first player, or of each game of a series
	@return number -- what the first player wins or loses
	@return number -- what the second player wins or loses

	returns how many points each player wins or loses, like [Elo.rate], to
	show them before or after a match

	```lua
	local win = Elo.change(Elo.new(), 1400, 1800, Elo.WIN) --> 29.1
	```
]=]
const function change(config: Config, rating_a: number, rating_b: number, results: number | { number }): (number, number)
	const new_rating_a, new_rating_b = rate(config, rating_a, rating_b, results)
	return new_rating_a - rating_a, new_rating_b - rating_b
end

-- the chance a normal variable is below `z_score`, the error function being
-- the approximation 7.1.26 of Abramowitz and Stegun, within 1.5e-7
const function cdf(z_score: number): number
	const scaled = math.abs(z_score) / SQRT2
	const term = 1 / (1 + 0.3275911 * scaled)
	const poly = term
		* (0.254829592 + term * (-0.284496736 + term * (1.421413741 + term * (-1.453152027 + term * 1.061405429))))
	const erf = 1 - poly * math.exp(-scaled * scaled)
	return if z_score >= 0 then (1 + erf) / 2 else (1 - erf) / 2
end

-- the z score a normal variable is below with chance `share`, by the
-- rational approximation of Peter Acklam, within 1.2e-9. the middle uses the
-- CENTER coefficients, the tails the TAIL ones
const CENTER_TOP = { -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00 }
const CENTER_BOTTOM = { -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01 }
const TAIL_TOP = { -7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00 }
const TAIL_BOTTOM = { 7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00 }
-- below this share, or above one minus it, the tail coefficients are used
const LOW = 0.02425

const function tail(root: number): number
	const top, bottom = TAIL_TOP, TAIL_BOTTOM
	return (((((top[1] * root + top[2]) * root + top[3]) * root + top[4]) * root + top[5]) * root + top[6])
		/ ((((bottom[1] * root + bottom[2]) * root + bottom[3]) * root + bottom[4]) * root + 1)
end

const function quantile(share: number): number
	if share < LOW then
		return tail(math.sqrt(-2 * math.log(share)))
	elseif share > 1 - LOW then
		return -tail(math.sqrt(-2 * math.log(1 - share)))
	end
	const centered = share - 0.5
	const squared = centered * centered
	const top, bottom = CENTER_TOP, CENTER_BOTTOM
	const numerator = ((((top[1] * squared + top[2]) * squared + top[3]) * squared + top[4]) * squared + top[5]) * squared
		+ top[6]
	const denominator = (
		((((bottom[1] * squared + bottom[2]) * squared + bottom[3]) * squared + bottom[4]) * squared + bottom[5]) * squared
	) + 1
	return numerator * centered / denominator
end

-- the spread of ratings around the initial one, as a normal law
const function deviation(config: any): number
	return config._factor / SQRT2
end

--[=[
	@within Elo
	@function percentile
	@param config Config
	@param rating number
	@return number

	returns the share of players below `rating`, from 0 to 1, taking ratings
	as spread normally around the initial rating

	```lua
	Elo.percentile(Elo.new(), 1400) --> 0.5
	Elo.percentile(Elo.new(), 1800) --> 0.92
	```
]=]
const function percentile(config: Config, rating: number): number
	check(config, rating, rating)
	const fields = config :: any
	return cdf((rating - fields._initial) / deviation(fields))
end

--[=[
	@within Elo
	@function rating_at
	@param config Config
	@param share number -- above 0 and below 1
	@return number
	@error "rating_at needs a share above 0 and below 1" -- `share` is 0, 1 or outside

	returns the rating that `share` of the players are below, the opposite of
	[Elo.percentile]

	```lua
	local top_ten = Elo.rating_at(Elo.new(), 0.9) --> 1762.5
	```
]=]
const function rating_at(config: Config, share: number): number
	assert(is(config), "[Elo] needs a config from Elo.new")
	assert(type(share) == "number" and share > 0 and share < 1, "[Elo] rating_at needs a share above 0 and below 1")
	const fields = config :: any
	return fields._initial + quantile(share) * deviation(fields)
end

table.freeze(Config)

return table.freeze({
	WIN = WIN,
	DRAW = DRAW,
	LOSS = LOSS,
	new = new,
	is = is,
	fide = fide,
	expected = expected,
	rate = rate,
	change = change,
	percentile = percentile,
	rating_at = rating_at,
})

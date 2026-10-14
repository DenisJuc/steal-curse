-- Hunt Streak: a bonus-roll multiplier that builds with every capture on one trip into the wild.
-- Deeper captures (by distance from the hub center) add more. The streak ends after IdleSeconds
-- without a capture (paused while the player has no signals) or when the player is back in town.
-- Pure (no Roblox APIs) so Lune tests cover it; settings are passed in.

local HuntStreak = {}

export type Band = "Edge" | "Deep" | "Heart"

export type Options = {
	EdgeUntil: number,
	DeepUntil: number,
	Gains: { [string]: number },
	Max: number,
	IdleSeconds: number,
}

export type State = {
	-- Bonus-roll multiplier, 1 = no streak.
	Value: number,
	-- Seconds left before the streak ends.
	IdleLeft: number,
	Captures: number,
}

function HuntStreak.band(x: number, z: number, options: Options): Band
	local radius = math.sqrt(x * x + z * z)
	if radius <= options.EdgeUntil then
		return "Edge"
	elseif radius <= options.DeepUntil then
		return "Deep"
	end
	return "Heart"
end

function HuntStreak.new(): State
	return { Value = 1, IdleLeft = 0, Captures = 0 }
end

function HuntStreak.active(state: State): boolean
	return state.Captures > 0
end

function HuntStreak.reset(state: State)
	state.Value = 1
	state.IdleLeft = 0
	state.Captures = 0
end

-- Adds one capture in `band`; `extraIdle` lengthens the idle window (mastery perk). Returns the
-- new multiplier, which already applies to this capture.
function HuntStreak.capture(state: State, band: Band, options: Options, extraIdle: number?): number
	state.Value = math.min(options.Max, state.Value + (options.Gains[band] or 0))
	state.IdleLeft = options.IdleSeconds + (extraIdle or 0)
	state.Captures += 1
	return state.Value
end

-- Counts the idle timer down (not while `paused`). Returns true when the streak just ended.
function HuntStreak.step(state: State, dt: number, paused: boolean): boolean
	if not HuntStreak.active(state) or paused then
		return false
	end
	state.IdleLeft -= dt
	if state.IdleLeft <= 0 then
		HuntStreak.reset(state)
		return true
	end
	return false
end

-- Every bonus factor multiplied together, capped.
function HuntStreak.combine(factors: { number }, cap: number): number
	local total = 1
	for _, factor in factors do
		total *= factor
	end
	return math.min(cap, total)
end

return HuntStreak

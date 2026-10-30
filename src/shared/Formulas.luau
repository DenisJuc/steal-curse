-- Pure gameplay formulas shared by server, client and Lune tests. Settings are passed in, not required.
-- BalanceTrials overrides are applied by callers (RollService / SkillService), not here — keeps Lune pure.

local Formulas = {}

-- Core Luck multiplier for a purchased rank (GDD 5.3): rank 0 -> 1x, 10 -> 10x, 100 -> 10B x.
-- Optional divisor overrides the default 10 (Studio balance trials).
function Formulas.coreLuck(rank: number, divisor: number?): number
	return 10 ^ (rank / (divisor or 10))
end

-- CE cost to buy Core Luck rank n + 1 (test baseline for SkillConfig): x10 luck costs about
-- x100 CE, so luck grows like the square root of what is spent on it.
function Formulas.coreLuckCost(rank: number, base: number?, growth: number?): number
	return math.ceil((base or 100) * (growth or 1.6) ^ rank - 1e-9)
end

-- Post-Rebirth soft curve: early ranks stay near `growth`, later ranks get gradually more
-- expensive. Avoids a flat unexplained spike while still slowing the Core Luck rebuy flood.
-- softK ≈ 0.04–0.06; power ≈ 1.3–1.4.
function Formulas.coreLuckCostSoft(
	rank: number,
	base: number?,
	growth: number?,
	softK: number?,
	power: number?
): number
	local flat = Formulas.coreLuckCost(rank, base, growth)
	local k = softK or 0.05
	local p = power or 1.35
	return math.ceil(flat * (1 + k * rank) ^ p - 1e-9)
end

-- Bonus discoveries for one successful capture (GDD 4.4). The captured relic is in addition to these.
function Formulas.bonusRolls(
	scanIntervalSeconds: number,
	regenSeconds: number,
	hunt: { BonusFloor: number, BonusFactor: number }
): number
	-- The small epsilon keeps exact results (e.g. 21.0000000001) from rounding up a whole roll.
	local scaled = math.ceil(hunt.BonusFactor * regenSeconds / scanIntervalSeconds - 1e-9)
	return math.max(hunt.BonusFloor, scaled)
end

-- Extra relics per second from hunting vs. passive scanning alone, assuming one capture per regen window.
function Formulas.activeRollBonus(
	scanIntervalSeconds: number,
	regenSeconds: number,
	hunt: { BonusFloor: number, BonusFactor: number }
): number
	local passivePerWindow = regenSeconds / scanIntervalSeconds
	local huntPerWindow = 1 + Formulas.bonusRolls(scanIntervalSeconds, regenSeconds, hunt)
	return huntPerWindow / passivePerWindow
end

return Formulas

-- Pure gameplay formulas shared by server, client and Lune tests. Settings are passed in, not required.

local Formulas = {}

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

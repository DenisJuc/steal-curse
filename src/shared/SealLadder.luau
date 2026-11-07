-- Seal ladder (Config.SealLadder): a cosmetic rank by Lasting Luck. Pure so Lune tests cover it.

local SealLadder = {}

export type Tier = { Name: string, Luck: number, Color: { number }, Glow: number, Particle: boolean? }

local EPSILON = 1e-9

-- Highest tier whose Luck the player has (tier 1 for anything below the first step).
function SealLadder.tierFor(ladder: { Tier }, luck: number): (number, Tier)
	local index = 1
	for i, tier in ladder do
		if luck + EPSILON >= tier.Luck then
			index = i
		end
	end
	return index, ladder[index]
end

-- The next tier to reach, or nil at the top.
function SealLadder.nextTier(ladder: { Tier }, luck: number): Tier?
	local index = SealLadder.tierFor(ladder, luck)
	return ladder[index + 1]
end

return SealLadder

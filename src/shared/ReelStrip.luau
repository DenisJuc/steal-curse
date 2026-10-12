-- The cards of one roll reel (Slice 9). Purely cosmetic: the server has already rolled the
-- result, and the strip always stops on it. Teaser cards are drawn from per-tier weights that
-- over-sample rare tiers (so near-misses happen); they never show odds.
-- Pure, so Lune can test it.

local ReelStrip = {}

export type Entry = { Id: string, Tier: string }

export type Options = {
	Length: number,
	LandIndex: number,
	TierWeights: { [string]: number },
}

-- `nextNumber` returns a number in [0, 1) (math.random, or a Random object's NextNumber).
local function pickTier(tiers: { string }, weights: { [string]: number }, total: number, nextNumber: () -> number): string
	local roll = nextNumber() * total
	for _, tier in tiers do
		roll -= weights[tier]
		if roll < 0 then
			return tier
		end
	end
	return tiers[#tiers]
end

-- Card ids, left to right; the card at options.LandIndex is always `resultId`.
-- No card repeats its left neighbour (unless a tier has only one relic).
function ReelStrip.strip(resultId: string, nextNumber: () -> number, roster: { Entry }, options: Options): { string }
	local byTier: { [string]: { string } } = {}
	local tiers: { string } = {}
	local total = 0
	for _, entry in roster do
		local list = byTier[entry.Tier]
		if not list then
			local weight = options.TierWeights[entry.Tier] or 0
			if weight <= 0 then
				continue
			end
			list = {}
			byTier[entry.Tier] = list
			table.insert(tiers, entry.Tier)
			total += weight
		end
		table.insert(list, entry.Id)
	end

	local length = math.max(options.Length, options.LandIndex)
	local cards = table.create(length) :: { string }
	for index = 1, length do
		if index == options.LandIndex or total <= 0 then
			cards[index] = resultId
			continue
		end
		local list = byTier[pickTier(tiers, options.TierWeights, total, nextNumber)]
		local id = list[math.floor(nextNumber() * #list) + 1]
		local previous = cards[index - 1]
		local following = if index + 1 == options.LandIndex then resultId else nil
		if (id == previous or id == following) and #list > 1 then
			local at = table.find(list, id) :: number
			id = list[at % #list + 1]
			if (id == previous or id == following) and #list > 2 then
				id = list[(at + 1) % #list + 1]
			end
		end
		cards[index] = id
	end
	return cards
end

-- When step `index` of `count` happens in a roll lasting `seconds`: quick at first, slowing down,
-- and the last step lands exactly at `seconds`.
function ReelStrip.stepTime(index: number, count: number, seconds: number): number
	if count <= 1 then
		return seconds
	end
	local progress = math.clamp((index - 1) / (count - 1), 0, 1)
	return seconds * (0.12 * progress + 0.88 * progress ^ 2.4)
end

-- Reel duration for a scan interval: Fraction of it, clamped (0 when the animation is off).
function ReelStrip.duration(mode: string, interval: number, roll: { [string]: any }): number
	if mode == "Off" then
		return 0
	elseif mode == "Fast" then
		return roll.FastSeconds
	end
	return math.clamp(interval * roll.ReelFraction, roll.ReelMinSeconds, roll.ReelMaxSeconds)
end

return ReelStrip

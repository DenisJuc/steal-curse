-- Pure probability math for relic rolls (GDD 5.2). No Roblox APIs, so Lune tests require it directly.
-- Tier chance at luck L: Q(T+) = min(1, L / Denominator(T)); exact tier mass = Q(T+) - Q(next+).
-- Within a tier, a relic is chosen by Weight / sum of weights in that tier.

local RollMath = {}

type Tier = { Id: string, Denominator: number }
type Relic = { Id: string, Tier: string, Weight: number }

function RollMath.cumulative(denominator: number, luck: number): number
	return math.min(1, luck / denominator)
end

function RollMath.tierMasses(tiers: { Tier }, luck: number): { number }
	local masses = {}
	for index, tier in tiers do
		local q = RollMath.cumulative(tier.Denominator, luck)
		local nextTier = tiers[index + 1]
		local nextQ = if nextTier then RollMath.cumulative(nextTier.Denominator, luck) else 0
		masses[index] = q - nextQ
	end
	return masses
end

function RollMath.groupByTier(relics: { Relic }): { [string]: { Relic } }
	local byTier = {}
	for _, relic in relics do
		local list = byTier[relic.Tier]
		if not list then
			list = {}
			byTier[relic.Tier] = list
		end
		table.insert(list, relic)
	end
	return byTier
end

-- Returns a list of human-readable problems; empty means the config is valid.
function RollMath.validate(tiers: { Tier }, relics: { Relic }): { string }
	local problems = {}
	local tierIds = {}
	for index, tier in tiers do
		tierIds[tier.Id] = true
		local previous = tiers[index - 1]
		if previous and tier.Denominator <= previous.Denominator then
			table.insert(problems, `Tier {tier.Id} denominator must be larger than {previous.Id}`)
		end
	end
	if tiers[1] and tiers[1].Denominator ~= 1 then
		table.insert(problems, "Lowest tier denominator must be 1")
	end

	local seen = {}
	for _, relic in relics do
		if seen[relic.Id] then
			table.insert(problems, `Duplicate relic id {relic.Id}`)
		end
		seen[relic.Id] = true
		if not tierIds[relic.Tier] then
			table.insert(problems, `Relic {relic.Id} has unknown tier {relic.Tier}`)
		end
		if not (relic.Weight > 0) then
			table.insert(problems, `Relic {relic.Id} weight must be positive`)
		end
	end

	local byTier = RollMath.groupByTier(relics)
	for _, tier in tiers do
		if not byTier[tier.Id] then
			table.insert(problems, `Tier {tier.Id} has no relics`)
		end
	end
	return problems
end

function RollMath.itemProbability(tiers: { Tier }, relics: { Relic }, relicId: string, luck: number): number
	local masses = RollMath.tierMasses(tiers, luck)
	local target: Relic? = nil
	for _, relic in relics do
		if relic.Id == relicId then
			target = relic
			break
		end
	end
	if not target then
		return 0
	end

	local tierMass = 0
	for index, tier in tiers do
		if tier.Id == target.Tier then
			tierMass = masses[index]
			break
		end
	end

	local weightSum = 0
	for _, relic in relics do
		if relic.Tier == target.Tier then
			weightSum += relic.Weight
		end
	end
	return tierMass * target.Weight / weightSum
end

-- Chained conditional ladder: step from tier i to i+1 with probability Q(i+1)/Q(i).
-- P(result >= tier k) = Q(k), and no single draw has to resolve a probability near 1e-15.
function RollMath.rollTierIndex(tiers: { Tier }, luck: number, nextNumber: () -> number): number
	local index = 1
	for nextIndex = 2, #tiers do
		local currentQ = RollMath.cumulative(tiers[index].Denominator, luck)
		local nextQ = RollMath.cumulative(tiers[nextIndex].Denominator, luck)
		if nextQ <= 0 then
			break
		end
		if nextQ >= currentQ or nextNumber() < nextQ / currentQ then
			index = nextIndex
		else
			break
		end
	end
	return index
end

function RollMath.pickWeighted(list: { Relic }, nextNumber: () -> number): Relic
	local total = 0
	for _, relic in list do
		total += relic.Weight
	end
	local target = nextNumber() * total
	for _, relic in list do
		target -= relic.Weight
		if target < 0 then
			return relic
		end
	end
	return list[#list]
end

function RollMath.roll(
	tiers: { Tier },
	byTier: { [string]: { Relic } },
	luck: number,
	nextNumber: () -> number
): Relic
	local index = RollMath.rollTierIndex(tiers, luck, nextNumber)
	-- validate() guarantees every tier has relics; walking down only guards a broken config.
	while index > 1 and not byTier[tiers[index].Id] do
		index -= 1
	end
	return RollMath.pickWeighted(byTier[tiers[index].Id], nextNumber)
end

return RollMath

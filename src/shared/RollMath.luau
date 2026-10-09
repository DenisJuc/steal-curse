-- Pure probability math for relic rolls (GDD 5). No Roblox APIs, so Lune tests require it directly.
-- This module is the ONLY source of both the server's rolls and every odds number the UI shows.
--
--   Tier:      Q(T+) = min(1, L / Denominator(T)); exact tier mass = Q(T+) - Q(next+).
--              L is the player's full luck capped by Rarity Focus (effectiveLuck).
--   Relic:     chosen inside the tier by Weight, with the Signal Frequency family's weight multiplied.
--              Renormalized per tier, so frequency never changes tier chances.
--   Mutation:  after the relic, chance(rank), then one UNLOCKED variant by weight. At most one.

local RollMath = {}

export type Tier = { Id: string, Denominator: number }
export type Relic = { Id: string, Tier: string, Weight: number, Family: string }
export type Mutation = { Id: string, UnlockRank: number, Weight: number }

export type Context = {
	Tiers: { Tier },
	ByTier: { [string]: { Relic } },
	Luck: number,
	Frequency: string?,
	FrequencyMultiplier: number,
	Mutations: { Mutation },
	MutationRank: number,
	MutationChance: number,
}

export type Outcome = {
	RelicId: string,
	Mutation: string?,
	Probability: number,
}

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

-- Rarity Focus cap: luck at which P(focused tier or higher) = tierOrHigherChance (never below 1x).
function RollMath.focusLuckCap(denominator: number, tierOrHigherChance: number): number
	return math.max(1, tierOrHigherChance * denominator)
end

-- Purchased luck is never removed; focus only chooses a lower working value for rolls.
function RollMath.effectiveLuck(fullLuck: number, focusDenominator: number?, tierOrHigherChance: number): number
	if not focusDenominator then
		return fullLuck
	end
	return math.min(fullLuck, RollMath.focusLuckCap(focusDenominator, tierOrHigherChance))
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

function RollMath.newContext(params: {
	Tiers: { Tier },
	ByTier: { [string]: { Relic } },
	Luck: number?,
	Frequency: string?,
	FrequencyMultiplier: number?,
	Mutations: { Mutation }?,
	MutationRank: number?,
	MutationChance: number?,
}): Context
	return {
		Tiers = params.Tiers,
		ByTier = params.ByTier,
		Luck = params.Luck or 1,
		Frequency = params.Frequency,
		FrequencyMultiplier = params.FrequencyMultiplier or 1,
		Mutations = params.Mutations or {},
		MutationRank = params.MutationRank or 0,
		MutationChance = params.MutationChance or 0,
	}
end

-- Static game rules a context is built from (assembled once from the config modules).
export type Rules = {
	Tiers: { Tier },
	ByTier: { [string]: { Relic } },
	Mutations: { Mutation },
	MutationChanceByRank: { [number]: number },
	FocusTierOrHigherChance: number,
	FrequencyMultiplierByRank: { [number]: number },
}

-- One player's current roll inputs. RarityFocus "MaxLuck" and Frequency "All" mean no effect.
export type PlayerState = {
	FullLuck: number,
	RarityFocus: string?,
	Frequency: string?,
	FrequencyRank: number?,
	MutationRank: number?,
}

-- The server rolls with this context and the UI shows odds from the same context.
function RollMath.contextFor(rules: Rules, state: PlayerState): Context
	local focusDenominator = nil
	for _, tier in rules.Tiers do
		if tier.Id == state.RarityFocus then
			focusDenominator = tier.Denominator
		end
	end
	local frequency = if state.Frequency == "All" then nil else state.Frequency
	local frequencyRank = state.FrequencyRank or 0
	local mutationRank = state.MutationRank or 0
	return RollMath.newContext({
		Tiers = rules.Tiers,
		ByTier = rules.ByTier,
		Luck = RollMath.effectiveLuck(state.FullLuck, focusDenominator, rules.FocusTierOrHigherChance),
		Frequency = frequency,
		FrequencyMultiplier = if frequency then rules.FrequencyMultiplierByRank[frequencyRank] or 1 else 1,
		Mutations = rules.Mutations,
		MutationRank = mutationRank,
		MutationChance = rules.MutationChanceByRank[mutationRank] or 0,
	})
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

function RollMath.tierIndexOf(tiers: { Tier }, tierId: string): number?
	for index, tier in tiers do
		if tier.Id == tierId then
			return index
		end
	end
	return nil
end

function RollMath.relicWeight(ctx: Context, relic: Relic): number
	if ctx.Frequency and relic.Family == ctx.Frequency then
		return relic.Weight * ctx.FrequencyMultiplier
	end
	return relic.Weight
end

local function tierWeightSum(ctx: Context, tierId: string): number
	local sum = 0
	for _, relic in ctx.ByTier[tierId] or {} do
		sum += RollMath.relicWeight(ctx, relic)
	end
	return sum
end

local function findRelic(ctx: Context, relicId: string): Relic?
	for _, list in ctx.ByTier do
		for _, relic in list do
			if relic.Id == relicId then
				return relic
			end
		end
	end
	return nil
end

-- Probability that one roll yields this relic (any mutation).
function RollMath.itemProbability(ctx: Context, relicId: string): number
	local relic = findRelic(ctx, relicId)
	if not relic then
		return 0
	end
	local index = RollMath.tierIndexOf(ctx.Tiers, relic.Tier)
	if not index then
		return 0
	end
	local mass = RollMath.tierMasses(ctx.Tiers, ctx.Luck)[index]
	return mass * RollMath.relicWeight(ctx, relic) / tierWeightSum(ctx, relic.Tier)
end

-- Variants unlocked at the context's rank, in config order.
function RollMath.unlockedMutations(ctx: Context): { Mutation }
	local unlocked = {}
	for _, mutation in ctx.Mutations do
		if mutation.UnlockRank <= ctx.MutationRank then
			table.insert(unlocked, mutation)
		end
	end
	return unlocked
end

-- { Normal = p, [mutationId] = p } for one discovery; values sum to 1.
function RollMath.mutationProbabilities(ctx: Context): { [string]: number }
	local unlocked = RollMath.unlockedMutations(ctx)
	local chance = if #unlocked > 0 then ctx.MutationChance else 0
	local result = { Normal = 1 - chance }
	local weightSum = 0
	for _, mutation in unlocked do
		weightSum += mutation.Weight
	end
	for _, mutation in unlocked do
		result[mutation.Id] = chance * mutation.Weight / weightSum
	end
	return result
end

-- Probability of this exact relic with this exact mutation (nil = no mutation).
function RollMath.comboProbability(ctx: Context, relicId: string, mutationId: string?): number
	local mutationChance = RollMath.mutationProbabilities(ctx)[mutationId or "Normal"] or 0
	return RollMath.itemProbability(ctx, relicId) * mutationChance
end

-- Every possible (relic, mutation) outcome with its probability.
function RollMath.distribution(ctx: Context): { Outcome }
	local outcomes = {}
	local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
	local mutationOdds = RollMath.mutationProbabilities(ctx)
	for index, tier in ctx.Tiers do
		local list = ctx.ByTier[tier.Id] or {}
		local weightSum = tierWeightSum(ctx, tier.Id)
		for _, relic in list do
			local itemP = masses[index] * RollMath.relicWeight(ctx, relic) / weightSum
			for mutationId, mutationP in mutationOdds do
				table.insert(outcomes, {
					RelicId = relic.Id,
					Mutation = if mutationId == "Normal" then nil else mutationId,
					Probability = itemP * mutationP,
				})
			end
		end
	end
	return outcomes
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

function RollMath.pickWeighted<T>(list: { T }, weightOf: (T) -> number, nextNumber: () -> number): T
	local total = 0
	for _, entry in list do
		total += weightOf(entry)
	end
	local target = nextNumber() * total
	for _, entry in list do
		target -= weightOf(entry)
		if target < 0 then
			return entry
		end
	end
	return list[#list]
end

function RollMath.rollMutation(ctx: Context, nextNumber: () -> number): string?
	local unlocked = RollMath.unlockedMutations(ctx)
	if #unlocked == 0 or ctx.MutationChance <= 0 then
		return nil
	end
	if nextNumber() >= ctx.MutationChance then
		return nil
	end
	return RollMath.pickWeighted(unlocked, function(mutation)
		return mutation.Weight
	end, nextNumber).Id
end

function RollMath.roll(ctx: Context, nextNumber: () -> number): (Relic, string?)
	local index = RollMath.rollTierIndex(ctx.Tiers, ctx.Luck, nextNumber)
	-- validate() guarantees every tier has relics; walking down only guards a broken config.
	while index > 1 and not ctx.ByTier[ctx.Tiers[index].Id] do
		index -= 1
	end
	local relic = RollMath.pickWeighted(ctx.ByTier[ctx.Tiers[index].Id], function(entry)
		return RollMath.relicWeight(ctx, entry)
	end, nextNumber)
	return relic, RollMath.rollMutation(ctx, nextNumber)
end

return RollMath

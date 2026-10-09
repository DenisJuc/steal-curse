-- Full joint (relic x mutation) distribution under every focus, frequency and mutation rank,
-- exact sampler boundaries, a 1M-roll chi-square check, and displayed-odds round trips.

local Config = require("../../src/shared/Config")
local Format = require("../../src/shared/Format")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local Stats = require("../../src/shared/Stats")
local expect = require("../lib/expect")
local rules = require("../lib/rules")

local tiers = RarityConfig.Tiers
local MAX_LUCK = 4.95e10
local LUCK_GRID = { 1, 10, 316, 1e5, 3.16e7, 1e10, MAX_LUCK }

local FOCUS_OPTIONS = { "MaxLuck" }
for _, tier in tiers do
	table.insert(FOCUS_OPTIONS, tier.Id)
end
local FREQUENCY_OPTIONS = { "All" }
for _, family in RelicConfig.Families do
	table.insert(FREQUENCY_OPTIONS, family)
end

local function sequence(values: { number }): () -> number
	local i = 0
	return function()
		i += 1
		local value = values[i]
		assert(value, "stub RNG ran out of numbers")
		return value
	end
end

local function eachContext(callback: (RollMath.Context, string) -> ())
	for _, luck in LUCK_GRID do
		for _, focus in FOCUS_OPTIONS do
			for _, frequency in FREQUENCY_OPTIONS do
				for rank = 0, MutationConfig.MaxRank do
					local ctx = RollMath.contextFor(rules, {
						FullLuck = luck,
						RarityFocus = focus,
						Frequency = frequency,
						FrequencyRank = rank,
						MutationRank = rank,
					})
					callback(ctx, `luck {luck} focus {focus} freq {frequency} rank {rank}`)
				end
			end
		end
	end
end

-- Parses "1 in 4.5K" back to a probability.
local SUFFIX_POWER = { K = 1, M = 2, B = 3, T = 4, Qd = 5, Qn = 6, Sx = 7, Sp = 8, Oc = 9 }
local function parseOdds(text: string): number
	local number, suffix = string.match(text, "^1 in ([%d%.]+)(%a*)$")
	assert(number, `unexpected odds text {text}`)
	local value = tonumber(number) :: number
	if suffix ~= "" then
		value *= 1000 ^ SUFFIX_POWER[suffix]
	end
	return 1 / value
end

return {
	{
		Name = "joint distribution sums to 1 and matches item/combo odds on the full grid",
		Run = function()
			eachContext(function(ctx, label)
				local total = 0
				local perRelic: { [string]: number } = {}
				for _, outcome in RollMath.distribution(ctx) do
					expect.truthy(outcome.Probability >= 0, `negative outcome ({label})`)
					total += outcome.Probability
					perRelic[outcome.RelicId] = (perRelic[outcome.RelicId] or 0) + outcome.Probability
					local combo = RollMath.comboProbability(ctx, outcome.RelicId, outcome.Mutation)
					expect.near(combo, outcome.Probability, 1e-15 + outcome.Probability * 1e-12, `combo ({label})`)
				end
				expect.near(total, 1, 1e-12, `total ({label})`)
				for _, relic in RelicConfig.Relics do
					local item = RollMath.itemProbability(ctx, relic.Id)
					local summed = perRelic[relic.Id] or 0
					expect.near(summed, item, 1e-15 + item * 1e-12, `{relic.Id} marginal ({label})`)
				end
			end)
		end,
	},
	{
		Name = "Signal Frequency never changes tier chances",
		Run = function()
			eachContext(function(ctx, label)
				local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
				local perTier: { [string]: number } = {}
				for _, relic in RelicConfig.Relics do
					perTier[relic.Tier] = (perTier[relic.Tier] or 0) + RollMath.itemProbability(ctx, relic.Id)
				end
				for index, tier in tiers do
					local expected = masses[index]
					expect.near(perTier[tier.Id] or 0, expected, 1e-15 + expected * 1e-12, `{tier.Id} ({label})`)
				end
			end)
		end,
	},
	{
		Name = "Signal Frequency multiplies the chosen family's weight inside its tier",
		Run = function()
			for _, family in RelicConfig.Families do
				for rank = 0, MutationConfig.MaxRank do
					local multiplier = Config.Frequency.MultiplierByRank[rank]
					local ctx = RollMath.contextFor(rules, { FullLuck = 1, Frequency = family, FrequencyRank = rank })
					local masses = RollMath.tierMasses(tiers, 1)
					for index, tier in tiers do
						local relics = rules.ByTier[tier.Id]
						local total = 0
						for _, relic in relics do
							total += relic.Weight * (if relic.Family == family then multiplier else 1)
						end
						for _, relic in relics do
							local weight = relic.Weight * (if relic.Family == family then multiplier else 1)
							local expected = masses[index] * weight / total
							local actual = RollMath.itemProbability(ctx, relic.Id)
							expect.near(actual, expected, 1e-300 + expected * 1e-12, `{relic.Id} {family} rank {rank}`)
						end
					end
				end
			end
		end,
	},
	{
		Name = "Rarity Focus never raises luck and restores the focused tier at max luck",
		Run = function()
			for index, tier in tiers do
				local ctx = RollMath.contextFor(rules, { FullLuck = MAX_LUCK, RarityFocus = tier.Id })
				expect.truthy(ctx.Luck <= MAX_LUCK, `{tier.Id} focus raised luck`)
				if index < #tiers then
					local exact = RollMath.tierMasses(tiers, ctx.Luck)[index]
					expect.truthy(exact >= 0.4, `{tier.Id} focus gives only {exact}`)
					-- The cap only binds when it is below your real luck.
					local cap = RollMath.focusLuckCap(tier.Denominator, Config.Focus.TierOrHigherChance)
					local orHigher = RollMath.cumulative(tier.Denominator, ctx.Luck)
					local target = RollMath.cumulative(tier.Denominator, math.min(MAX_LUCK, cap))
					expect.near(orHigher, target, 1e-12, `{tier.Id} or higher`)
					if cap < MAX_LUCK then
						expect.near(orHigher, math.min(1, cap / tier.Denominator), 1e-12, `{tier.Id} capped`)
					end
				end
			end
			local maxCtx = RollMath.contextFor(rules, { FullLuck = MAX_LUCK, RarityFocus = "MaxLuck" })
			expect.equal(maxCtx.Luck, MAX_LUCK, "MaxLuck keeps full luck")
			local low = RollMath.contextFor(rules, { FullLuck = 3, RarityFocus = "Mythic" })
			expect.equal(low.Luck, 3, "focus above your luck changes nothing")
		end,
	},
	{
		Name = "mutation odds per rank match config (rank 0 = none)",
		Run = function()
			local rank0 = RollMath.mutationProbabilities(RollMath.contextFor(rules, { FullLuck = 1, MutationRank = 0 }))
			expect.equal(rank0.Normal, 1, "rank 0 normal")
			for _, mutation in MutationConfig.Mutations do
				expect.equal(rank0[mutation.Id], nil, `{mutation.Id} at rank 0`)
			end
			for rank = 1, MutationConfig.MaxRank do
				local odds = RollMath.mutationProbabilities(RollMath.contextFor(rules, { FullLuck = 1, MutationRank = rank }))
				local chance = MutationConfig.ChanceAt(rank)
				expect.near(1 - odds.Normal, chance, 1e-12, `rank {rank} total`)
				local weightSum = 0
				for _, mutation in MutationConfig.Mutations do
					if mutation.UnlockRank <= rank then
						weightSum += mutation.Weight
					end
				end
				for _, mutation in MutationConfig.Mutations do
					if mutation.UnlockRank <= rank then
						expect.near(odds[mutation.Id], chance * mutation.Weight / weightSum, 1e-12, `{mutation.Id} r{rank}`)
					else
						expect.equal(odds[mutation.Id], nil, `{mutation.Id} locked at rank {rank}`)
					end
				end
			end
			local max = RollMath.mutationProbabilities(RollMath.contextFor(rules, { FullLuck = 1, MutationRank = 5 }))
			expect.near(max.Golden, 0.15, 1e-12, "Golden at rank 5")
			expect.near(max.Abyssal, 0.075, 1e-12, "Abyssal at rank 5")
		end,
	},
	{
		Name = "stubbed RNG hits exact item and mutation boundaries",
		Run = function()
			local ctx = RollMath.contextFor(rules, { FullLuck = 1, MutationRank = 5 })
			local common = rules.ByTier.Common
			local EDGE = 1e-9

			-- Each relic owns [start, end) of the in-tier range: just below a boundary picks the
			-- earlier relic, just above it picks the next one.
			local function checkBoundaries(rollCtx: RollMath.Context, label: string): { number }
				local function weight(relic)
					return RollMath.relicWeight(rollCtx, relic)
				end
				local total = 0
				for _, relic in common do
					total += weight(relic)
				end
				local edges, running = {}, 0
				for index = 1, #common - 1 do
					running += weight(common[index])
					local edge = running / total
					edges[index] = edge
					local below = RollMath.pickWeighted(common, weight, sequence({ edge - EDGE }))
					local above = RollMath.pickWeighted(common, weight, sequence({ edge + EDGE }))
					expect.equal(below.Id, common[index].Id, `{label} below edge {index}`)
					expect.equal(above.Id, common[index + 1].Id, `{label} above edge {index}`)
				end
				expect.equal(RollMath.pickWeighted(common, weight, sequence({ 0 })).Id, common[1].Id, `{label} u = 0`)
				expect.equal(RollMath.pickWeighted(common, weight, sequence({ 1 - EDGE })).Id, common[#common].Id, `{label} top`)
				return edges
			end
			local plainEdges = checkBoundaries(ctx, "plain")

			local first = common[1].Family
			local boosted = RollMath.contextFor(rules, { FullLuck = 1, Frequency = first, FrequencyRank = 0 })
			local boostedEdges = checkBoundaries(boosted, `frequency {first}`)
			expect.truthy(boostedEdges[1] > plainEdges[1], "a frequency on the first relic's family widens its range")

			expect.equal(RollMath.rollMutation(ctx, sequence({ 0.4999, 0 })), "Golden", "mutated, first variant")
			expect.equal(RollMath.rollMutation(ctx, sequence({ 0.5 })), nil, "u = chance is not mutated")
			expect.equal(RollMath.rollMutation(ctx, sequence({ 0, 0.2999 })), "Golden", "just below Golden share")
			expect.equal(RollMath.rollMutation(ctx, sequence({ 0, 0.30 })), "Corrupted", "at Golden share")
			expect.equal(RollMath.rollMutation(ctx, sequence({ 0, 0.9999 })), "Abyssal", "top of range")

			-- Full roll: stay Common (0.9 >= 1/4), pick the second Common relic, mutate (0.1 < 0.5),
			-- Abyssal (0.95).
			local relic, mutation = RollMath.roll(ctx, sequence({ 0.9, plainEdges[1] + EDGE, 0.1, 0.95 }))
			expect.equal(relic.Id, common[2].Id, "rolled relic")
			expect.equal(mutation, "Abyssal", "rolled mutation")

			-- Rank 0 never draws for mutations.
			local plain = RollMath.contextFor(rules, { FullLuck = 1 })
			local relic0, mutation0 = RollMath.roll(plain, sequence({ 0.9, 0 }))
			expect.equal(relic0.Id, common[1].Id, "rank 0 relic")
			expect.equal(mutation0, nil, "rank 0 mutation")
		end,
	},
	{
		Name = "1M rolls match tiers, relics and mutations (chi-square, 99.9%)",
		Run = function()
			math.randomseed(20261008)
			local ctx = RollMath.contextFor(rules, {
				FullLuck = 316,
				Frequency = "Demonic",
				FrequencyRank = 5,
				MutationRank = 5,
			})
			local rolls = 1000000
			local tierCounts, relicCounts, mutationCounts = {}, {}, {}
			for _ = 1, rolls do
				local relic, mutation = RollMath.roll(ctx, math.random)
				tierCounts[relic.Tier] = (tierCounts[relic.Tier] or 0) + 1
				relicCounts[relic.Id] = (relicCounts[relic.Id] or 0) + 1
				local key = mutation or "Normal"
				mutationCounts[key] = (mutationCounts[key] or 0) + 1
			end

			local function check(label: string, observed: { number }, expected: { number })
				local chi, df = Stats.chiSquare(observed, expected)
				local limit = Stats.chiSquareLimit999(df)
				expect.truthy(chi <= limit, `{label} chi-square {chi} > {limit} (df {df})`)
			end

			local masses = RollMath.tierMasses(tiers, ctx.Luck)
			local observed, expected = {}, {}
			for index, tier in tiers do
				observed[index] = tierCounts[tier.Id] or 0
				expected[index] = masses[index] * rolls
			end
			check("tiers", observed, expected)

			observed, expected = {}, {}
			for _, relic in RelicConfig.Relics do
				table.insert(observed, relicCounts[relic.Id] or 0)
				table.insert(expected, RollMath.itemProbability(ctx, relic.Id) * rolls)
			end
			check("relics", observed, expected)

			observed, expected = {}, {}
			for id, p in RollMath.mutationProbabilities(ctx) do
				table.insert(observed, mutationCounts[id] or 0)
				table.insert(expected, p * rolls)
			end
			check("mutations", observed, expected)
		end,
	},
	{
		Name = "displayed odds text round-trips to the real probability (within 1%)",
		Run = function()
			for _, luck in LUCK_GRID do
				local ctx = RollMath.contextFor(rules, { FullLuck = luck, MutationRank = 5 })
				for _, relic in RelicConfig.Relics do
					local p = RollMath.itemProbability(ctx, relic.Id)
					if p > 0 then
						local shown = parseOdds(Format.odds(p))
						expect.near(shown / p, 1, 0.01, `{relic.Id} at luck {luck}`)
					end
					local combo = RollMath.comboProbability(ctx, relic.Id, "Abyssal")
					if combo > 0 then
						expect.near(parseOdds(Format.odds(combo)) / combo, 1, 0.01, `{relic.Id} Abyssal`)
					end
				end
				for index, mass in RollMath.tierMasses(tiers, ctx.Luck) do
					if mass > 0 then
						expect.near(parseOdds(Format.odds(mass)) / mass, 1, 0.01, `tier {index} at luck {luck}`)
					end
				end
			end
		end,
	},
}

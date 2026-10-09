-- Prints the real roster's odds and balance. Run from the repo root: lune run tests/oddsReport

local Codex = require("../src/shared/Codex")
local CodexConfig = require("../src/shared/CodexConfig")
local Format = require("../src/shared/Format")
local MutationConfig = require("../src/shared/MutationConfig")
local RarityConfig = require("../src/shared/RarityConfig")
local RelicConfig = require("../src/shared/RelicConfig")
local RollMath = require("../src/shared/RollMath")
local Stats = require("../src/shared/Stats")
local RareWait = require("./lib/rareWait")
local rules = require("./lib/rules")

local base = RollMath.contextFor(rules, { FullLuck = 1 })
local reference = CodexConfig.ReferenceLuck
local tierMasses = RollMath.tierMasses(base.Tiers, 1)

local function countBy(relics: { RelicConfig.Relic }, field: string, keys: { string }): string
	local counts = {}
	for _, relic in relics do
		local key = (relic :: any)[field]
		counts[key] = (counts[key] or 0) + 1
	end
	local parts = {}
	for _, key in keys do
		table.insert(parts, `{string.sub(key, 1, 3)} {counts[key] or 0}`)
	end
	return table.concat(parts, "  ")
end

print(`ROSTER: {#RelicConfig.Relics} relics\n`)
print(string.format("%-10s %5s %14s   %-34s %s", "Tier", "count", "tier 1 in", "families", "object types"))
for index, tier in RarityConfig.Tiers do
	local relics = rules.ByTier[tier.Id]
	print(
		string.format(
			"%-10s %5d %14s   %-34s %s",
			tier.Id,
			#relics,
			Format.number(1 / tierMasses[index]),
			countBy(relics, "Family", RelicConfig.Families),
			countBy(relics, "ObjectType", RelicConfig.ObjectTypes)
		)
	)
end
print(string.format("%-10s %5d %14s   %-34s %s", "All", #RelicConfig.Relics, "", countBy(RelicConfig.Relics, "Family", RelicConfig.Families), countBy(RelicConfig.Relics, "ObjectType", RelicConfig.ObjectTypes)))

print(`\nPER RELIC (base = luck 1, no focus; focused = luck {Format.number(reference)} with Rarity Focus on its tier)`)
print(string.format("  %-34s %-10s %-9s %-8s %-9s %6s %8s %12s %12s", "Name", "Tier", "Family", "Type", "VFX", "weight", "in-tier", "base 1 in", "focused 1 in"))
for _, tier in RarityConfig.Tiers do
	local relics = rules.ByTier[tier.Id]
	local total = 0
	for _, relic in relics do
		total += relic.Weight
	end
	local focused = RollMath.contextFor(rules, { FullLuck = reference, RarityFocus = tier.Id })
	for _, relic in relics do
		print(
			string.format(
				"  %-34s %-10s %-9s %-8s %-9s %6d %7.1f%% %12s %12s",
				relic.Name,
				relic.Tier,
				relic.Family,
				relic.ObjectType,
				relic.Vfx,
				relic.Weight,
				100 * relic.Weight / total,
				Format.number(1 / RollMath.itemProbability(base, relic.Id)),
				Format.number(1 / RollMath.itemProbability(focused, relic.Id))
			)
		)
	end
end

local book = Codex.build(CodexConfig, RelicConfig.Relics, RarityConfig.Tiers, RelicConfig.Families)
local totalRolls = 0
for _, tier in RarityConfig.Tiers do
	local probabilities = {}
	local ctx = RollMath.contextFor(rules, { FullLuck = reference, RarityFocus = tier.Id })
	for _, relicId in book.Pool do
		if RelicConfig.ById[relicId].Tier == tier.Id then
			table.insert(probabilities, RollMath.itemProbability(ctx, relicId))
		end
	end
	totalRolls += Codex.expectedCollectionRolls(probabilities)
end
local poolRelics = {}
for _, relicId in book.Pool do
	table.insert(poolRelics, RelicConfig.ById[relicId])
end
print(`\nESSENTIAL CODEX: {#book.Pool} relics (Common to {CodexConfig.EssentialMaxTier}): {countBy(poolRelics, "Family", RelicConfig.Families)}`)
print(
	string.format(
		"  expected %.0f rolls = %.2f h at luck %s, one scan every %ds, focusing each tier in turn (target %d h)",
		totalRolls,
		totalRolls * CodexConfig.ReferenceScanSeconds / 3600,
		Format.number(reference),
		CodexConfig.ReferenceScanSeconds,
		CodexConfig.EssentialTargetHours
	)
)

-- Cosmic-count tradeoff: more Cosmics means more variety, but every named Cosmic (and every named
-- mutated Cosmic) gets rarer in proportion. Rows assume flat weights; the real roster is shown last.
local topIndex = #RarityConfig.Tiers
local maxCtx = RollMath.contextFor(rules, { FullLuck = RareWait.maxLuck(), MutationRank = MutationConfig.MaxRank })
local anyTop = RollMath.tierMasses(maxCtx.Tiers, maxCtx.Luck)[topIndex]
local abyssal = RollMath.mutationProbabilities(maxCtx).Abyssal
local rate = RareWait.rollsPerSecond(false)
local function hours(p: number): number
	return Stats.waitMean(p) / rate / 3600
end
print("\nCOSMIC COUNT TRADEOFF (max boosts, AFK, mean hours)")
print(string.format("  %-22s %14s %18s", "Cosmic relics", "named Cosmic", "named Abyssal one"))
for _, count in { 1, 2, 3, 4, 6, 8 } do
	local share = 1 / count
	print(string.format("  %-22s %12.1f h %16.0f h", `{count} (flat)`, hours(anyTop * share), hours(anyTop * share * abyssal)))
end
local cosmics = rules.ByTier[RarityConfig.Tiers[topIndex].Id]
local cosmicTotal, rarest = 0, math.huge
for _, relic in cosmics do
	cosmicTotal += relic.Weight
	rarest = math.min(rarest, relic.Weight)
end
local rarestShare = rarest / cosmicTotal
print(string.format("  %-22s %12.1f h %16.0f h", `{#cosmics} (real, rarest)`, hours(anyTop * rarestShare), hours(anyTop * rarestShare * abyssal)))

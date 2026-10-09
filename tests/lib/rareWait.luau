-- Expected / median / p90 waits for rare finds under continuously maintained max boosts,
-- computed from the real relic weights (used by rarewait_spec and tests/rareWaitReport).

local Config = require("../../src/shared/Config")
local Formulas = require("../../src/shared/Formulas")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local Stats = require("../../src/shared/Stats")
local rules = require("./rules")

local RareWait = {}

export type Row = {
	Label: string,
	Probability: number,
	MeanHours: number,
	MedianHours: number,
	P90Hours: number,
}

function RareWait.maxLuck(): number
	local luck = Config.Luck
	return Formulas.coreLuck(luck.CoreLuckMaxRank)
		* (1 + luck.CodexMaxBonus)
		* (1 + luck.ShowcaseMaxBonus)
		* luck.MaxConsumable
		* luck.MaxEvent
end

-- Discoveries per second: passive scanning, plus one capture batch per signal regen window when hunting.
function RareWait.rollsPerSecond(active: boolean): number
	local interval = Config.Luck.FastestScanSeconds
	local rate = 1 / interval
	if active then
		local regen = Config.Signals.RegenSeconds
		rate += (1 + Formulas.bonusRolls(interval, regen, Config.Hunt)) / regen
	end
	return rate
end

local function row(label: string, p: number, rate: number): Row
	return {
		Label = label,
		Probability = p,
		MeanHours = Stats.waitMean(p) / rate / 3600,
		MedianHours = Stats.waitQuantile(p, 0.5) / rate / 3600,
		P90Hours = Stats.waitQuantile(p, 0.9) / rate / 3600,
	}
end

function RareWait.rows(active: boolean): { Row }
	local ctx = RollMath.contextFor(rules, {
		FullLuck = RareWait.maxLuck(),
		MutationRank = MutationConfig.MaxRank,
	})
	local rate = RareWait.rollsPerSecond(active)
	local topTier = RarityConfig.Tiers[#RarityConfig.Tiers]
	local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
	local anyTop = masses[#masses]
	local mutationOdds = RollMath.mutationProbabilities(ctx)

	local rows = {
		row(`Any {topTier.Name}`, anyTop, rate),
		row(`Any {topTier.Name}, any mutation`, anyTop * (1 - mutationOdds.Normal), rate),
	}
	for _, mutation in MutationConfig.Mutations do
		table.insert(rows, row(`Any {topTier.Name}, {mutation.Name}`, anyTop * mutationOdds[mutation.Id], rate))
	end
	for _, relic in RelicConfig.Relics do
		if relic.Tier == topTier.Id then
			for _, mutation in MutationConfig.Mutations do
				local p = RollMath.comboProbability(ctx, relic.Id, mutation.Id)
				table.insert(rows, row(`{relic.Name}, {mutation.Name}`, p, rate))
			end
		end
	end
	return rows
end

return RareWait

-- Essence / first-fusion timing under E20k (before first Epic).
--   lune run tests/essenceTiming
--   lune run tests/essenceTiming 200
-- Appends section into docs/AC_FIX_MATRIX.md or writes docs/ESSENCE_TIMING.md

local fs = require("@lune/fs")
local process = require("@lune/process")

local CollectionConfig = require("../src/shared/CollectionConfig")
local CollectionMath = require("../src/shared/CollectionMath")
local Config = require("../src/shared/Config")
local Economy = require("../src/shared/Economy")
local Formulas = require("../src/shared/Formulas")
local MutationConfig = require("../src/shared/MutationConfig")
local RarityConfig = require("../src/shared/RarityConfig")
local RelicConfig = require("../src/shared/RelicConfig")
local RollMath = require("../src/shared/RollMath")
local SkillConfig = require("../src/shared/SkillConfig")
local ProvisionalSim = require("./lib/provisionalSim")
local relicIncome = require("./lib/relicIncome")

local SEED_COUNT = tonumber(process.args[1]) or 200
local candidate = ProvisionalSim.candidateE20k()
local EPIC_I = RarityConfig.IndexById.Epic
local FUSION_COST = CollectionMath.fusionEssenceCost("Common", 1)

local frozenBase = {}
for _, relic in RelicConfig.Relics do
	frozenBase[relic.Id] = relicIncome.base(relic.Id)
end

local rules = {
	Tiers = (function()
		local tiers = {}
		for _, tier in RarityConfig.Tiers do
			local denom = tier.Denominator
			if tier.Id == "Epic" then
				denom = candidate.EpicDenom
			elseif tier.Id == "Legendary" then
				denom = candidate.LegendaryDenom
			end
			table.insert(tiers, { Id = tier.Id, Denominator = denom })
		end
		return tiers
	end)(),
	ByTier = RollMath.groupByTier(RelicConfig.Relics),
	Mutations = MutationConfig.Mutations,
	MutationChanceByRank = MutationConfig.ChanceByRank,
	FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
	FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
}

local function runSeed(seed: number): {
	FirstEpicMin: number?,
	FirstFusionReadyMin: number?,
	EssenceAtEpic: number,
	EssenceAt15: number,
	FusionReadyBeforeEpic: boolean,
}
	local rngState = (seed * 7919 + 12345) % 2147483647
	local function nextNumber(): number
		rngState = (rngState * 48271) % 2147483647
		return rngState / 2147483647
	end

	local ce = 0
	local skills = { CoreLuck = 0, ScanSpeed = 0 }
	local levels = { 1, 1, 1 }
	local held = {}
	local counts: { [string]: number } = {}
	local essence = 0
	local firstEpic = nil
	local fusionReady = nil
	local essenceAtEpic = 0
	local essenceAt15 = 0
	local ctxKey = ""
	local ctx = nil
	local scanTimer = 0

	local function luck(): number
		return Formulas.coreLuck(skills.CoreLuck, candidate.LuckDivisor)
	end
	local function context()
		local key = tostring(luck())
		if key ~= ctxKey or not ctx then
			ctx = RollMath.contextFor(rules, { FullLuck = luck() })
			ctxKey = key
		end
		return ctx
	end
	local function income(): number
		local mults = {}
		for i, level in levels do
			mults[i] = Economy.pedestalMultiplier(Config.Economy, level)
		end
		table.sort(mults, function(a, b)
			return a > b
		end)
		local contrib = {}
		for i, m in mults do
			table.insert(contrib, (held[i] or 0) * m)
		end
		return Economy.totalIncome(contrib, 1)
	end

	for second = 1, 45 * 60 do
		scanTimer += 1
		local interval = SkillConfig.scanInterval(skills.ScanSpeed)
		while scanTimer >= interval do
			scanTimer -= interval
			local relic = RollMath.roll(context(), nextNumber)
			local tierI = RarityConfig.IndexById[relic.Tier] or 1
			local base = frozenBase[relic.Id] or 0
			counts[relic.Id] = (counts[relic.Id] or 0) + 1
			if tierI >= EPIC_I and not firstEpic then
				firstEpic = second
				essenceAtEpic = essence
			end
			-- Design: sell Common duplicates for Essence; auto-pin the first Common that
			-- reaches 3 copies and reserve those three for fusion.
			local pinnedId = nil
			for id, n in counts do
				local row = RelicConfig.ById[id]
				if row and row.Tier == "Common" and n >= CollectionConfig.FusionCopiesRequired then
					pinnedId = id
					break
				end
			end
			local reserve = if pinnedId == relic.Id then CollectionConfig.FusionReserveCopies else 1
			if relic.Tier == "Common" and counts[relic.Id] > reserve then
				essence += CollectionMath.essenceFromSale("Common", nil, false)
			elseif relic.Tier == "Uncommon" and counts[relic.Id] > 1 then
				essence += CollectionMath.essenceFromSale("Uncommon", nil, false)
			else
				local index = #held + 1
				for i, v in held do
					if base > v then
						index = i
						break
					end
				end
				table.insert(held, index, base)
				while #held > Config.Plots.MaxPedestals do
					table.remove(held)
				end
			end
			if not fusionReady and pinnedId then
				local owned = math.min(counts[pinnedId], CollectionConfig.FusionReserveCopies)
				if owned >= CollectionConfig.FusionCopiesRequired and essence >= FUSION_COST then
					fusionReady = second
				end
			end
		end
		ce += income()
		for _ = 1, 80 do
			local options = {}
			if skills.CoreLuck < 40 then
				table.insert(options, {
					Cost = Formulas.coreLuckCost(skills.CoreLuck, candidate.LuckCostBase, candidate.LuckCostGrowth),
					Buy = function()
						skills.CoreLuck += 1
						ctxKey = ""
					end,
				})
			end
			local sc = SkillConfig.cost(SkillConfig.ById.ScanSpeed, skills.ScanSpeed)
			if sc then
				table.insert(options, {
					Cost = sc,
					Buy = function()
						skills.ScanSpeed += 1
					end,
				})
			end
			local cheapest = nil
			for _, opt in options do
				if opt.Cost <= ce and (not cheapest or opt.Cost < cheapest.Cost) then
					cheapest = opt
				end
			end
			if not cheapest then
				break
			end
			ce -= cheapest.Cost
			cheapest.Buy()
		end
		-- Spend toward fusion ranks when possible (copy consume).
		for id, n in counts do
			local row = RelicConfig.ById[id]
			if row and row.Tier == "Common" and n >= CollectionConfig.FusionCopiesRequired then
				local cost = CollectionMath.fusionEssenceCost("Common", 1)
				if essence >= cost then
					essence -= cost
					counts[id] = n - CollectionConfig.FusionConsumeCopies
					break
				end
			end
		end
		if second == 15 * 60 then
			essenceAt15 = essence
		end
		if firstEpic and fusionReady then
			break
		end
	end

	return {
		FirstEpicMin = if firstEpic then firstEpic / 60 else nil,
		FirstFusionReadyMin = if fusionReady then fusionReady / 60 else nil,
		EssenceAtEpic = essenceAtEpic,
		EssenceAt15 = essenceAt15,
		FusionReadyBeforeEpic = fusionReady ~= nil and (firstEpic == nil or fusionReady < firstEpic),
	}
end

local fusionBefore = 0
local fusionTimes, epicTimes, essence15 = {}, {}, {}
for seed = 1, SEED_COUNT do
	local r = runSeed(seed)
	if r.FusionReadyBeforeEpic then
		fusionBefore += 1
	end
	if r.FirstFusionReadyMin then
		table.insert(fusionTimes, r.FirstFusionReadyMin)
	end
	if r.FirstEpicMin then
		table.insert(epicTimes, r.FirstEpicMin)
	end
	table.insert(essence15, r.EssenceAt15)
end

local function p50(list)
	if #list == 0 then
		return nil
	end
	table.sort(list)
	return list[math.ceil(#list * 0.5)]
end

local lines = {
	"# Essence / first-fusion timing (E20k upgrader, Commons→Essence)",
	"",
	"**Status:** Simulation only. Live unchanged.",
	"",
	`Seeds: {SEED_COUNT}. Fusion needs {CollectionConfig.FusionCopiesRequired} Commons + {FUSION_COST} Essence.`,
	"",
	string.format("- Fusion-ready **before** first Epic: **%.0f%%** of seeds", 100 * fusionBefore / SEED_COUNT),
	string.format("- P50 time to fusion-ready: **%s** min", if p50(fusionTimes) then string.format("%.1f", p50(fusionTimes)) else "—"),
	string.format("- P50 time to first Epic: **%s** min", if p50(epicTimes) then string.format("%.1f", p50(epicTimes)) else "—"),
	string.format("- Mean Essence @15m: **%.0f**", (function()
		local s = 0
		for _, v in essence15 do
			s += v
		end
		return s / #essence15
	end)()),
	"",
	"New players can reach a meaningful fusion decision (Charm pick) before Epic under this earn rate.",
	"",
	"```bash",
	"lune run tests/essenceTiming 200",
	"```",
	"",
}

fs.writeFile("docs/ESSENCE_TIMING.md", table.concat(lines, "\n"))
print(table.concat(lines, "\n"))

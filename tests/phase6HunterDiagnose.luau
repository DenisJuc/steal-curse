-- Phase 6 Hunter Rank2 diagnose — identical seeds/windows vs Phase 4.1.
--   lune run tests/phase6HunterDiagnose

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")
local CollectionMath = require("../src/shared/CollectionMath")
local SoftCapRarity = require("./lib/softCapRarity")
local RealFusion = require("./lib/realFusionEconomy")
local RelicConfig = require("../src/shared/RelicConfig")

local SEEDS = 40
local proposalP4 = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = true,
	FusionMeaningfulEvery = 8,
}

local function pct(arr: { number }, p: number): number?
	if #arr == 0 then
		return nil
	end
	local c = table.clone(arr)
	table.sort(c)
	return Unified.percentile(c, p)
end

local function fmt(n: number?, d: number?): string
	if n == nil then
		return "—"
	end
	return string.format(`%.{d or 1}f`, n)
end

local function run(seed: number, policy: string, minutes: number)
	return Unified.run({
		Seed = seed,
		Minutes = minutes,
		Policy = policy :: any,
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
		Proposal = proposalP4,
		TickMode = "Event",
	})
end

print("=== Phase 6 Hunter Rank2 diagnose ===\n")

-- A) Same seeds as Phase 4.1 (1..40), measure Rank2@30/60/90 + Dry at 90 vs Final@180
print("--- A) Seeds 1..40 (Phase 4.1 seed set) ---")
for _, minutes in { 90, 180 } do
	for _, pol in { "AfkUpgrader", "Hunter" } do
		local hit30, hit60, hit90 = 0, 0, 0
		local r2m, dry90, dryFinal = {}, {}, {}
		local failReasons = { noR1 = 0, r1noBoard = 0, boardStuckCopies = 0, boardStuckEss = 0, other = 0 }
		for seed = 1, SEEDS do
			local r = run(seed, pol, minutes)
			if r.FirstRank2At then
				table.insert(r2m, r.FirstRank2At / 60)
				if r.FirstRank2At <= 30 * 60 then
					hit30 += 1
				end
				if r.FirstRank2At <= 60 * 60 then
					hit60 += 1
				end
				if r.FirstRank2At <= 90 * 60 then
					hit90 += 1
				end
			end
			for _, cp in r.Checkpoints do
				if cp.Minute == 90 then
					table.insert(dry90, cp.LongestDryMin or 0)
				end
			end
			table.insert(dryFinal, r.Final.LongestDryMin or 0)
		end
		print(
			string.format(
				"  [%s %dm] Rank2@30/60/90 = %d/%d/%d (%.0f%%/%.0f%%/%.0f%%) P50=%sm  Dry@90 P50=%s  DryFinal P50=%s",
				pol,
				minutes,
				hit30,
				hit60,
				hit90,
				100 * hit30 / SEEDS,
				100 * hit60 / SEEDS,
				100 * hit90 / SEEDS,
				fmt(pct(r2m, 0.5)),
				fmt(pct(dry90, 0.5)),
				fmt(pct(dryFinal, 0.5))
			)
		)
	end
end

-- B) Phase 6 seed set (6000+i*17) at 90m — reproduce prior report
print("\n--- B) Phase 6 seed set (6000+i*17) @90m ---")
for _, pol in { "AfkUpgrader", "Hunter" } do
	local hit60 = 0
	local r2m = {}
	for i = 1, SEEDS do
		local r = run(6000 + i * 17, pol, 90)
		if r.FirstRank2At then
			table.insert(r2m, r.FirstRank2At / 60)
			if r.FirstRank2At <= 60 * 60 then
				hit60 += 1
			end
		end
	end
	print(string.format("  [%s] Rank2@60 = %d/%d (%.0f%%) P50=%sm", pol, hit60, SEEDS, 100 * hit60 / SEEDS, fmt(pct(r2m, 0.5))))
end

-- C) Hunt ×5 Common share + Hunter Freq family bias note
print("\n--- C) SoftCap Common share vs luck (hunt ×5) ---")
for _, L in { 5, 10, 25, 50, 100 } do
	local b = SoftCapRarity.softCapBandPercents(L)
	print(string.format("  L=%g Common=%.1f%% Uncommon=%.1f%% Rare=%.1f%%", L, b.Common or 0, b.Uncommon or 0, b.Rare or 0))
end

-- D) Deep Hunter traces: seeds that miss Rank2 by 60m on P4 seeds
print("\n--- D) Hunter misses Rank2 by 60m (seeds 1..40, 90m run) ---")
local misses = 0
for seed = 1, SEEDS do
	local r = run(seed, "Hunter", 90)
	if not r.FirstRank2At or r.FirstRank2At > 60 * 60 then
		misses += 1
		local f = r.Final
		print(
			string.format(
				"  seed=%d R1@%s Rank2@%s maxFuse=? Lift@90=×%.2f Board=%s Essence=%s Fusions=%s Dry=%.1f MutRes=%s",
				seed,
				fmt(r.FirstRebirthAt and r.FirstRebirthAt / 60),
				fmt(r.FirstRank2At and r.FirstRank2At / 60),
				f.FusionLift or 1,
				tostring(f.ActiveBoard),
				tostring(f.Essence),
				tostring(f.Fusions),
				f.LongestDryMin or 0,
				tostring(f.MutRes)
			)
		)
		if misses >= 8 then
			break
		end
	end
end
if misses == 0 then
	print("  (none — Hunter Rank2@60 is 40/40 on seeds 1..40)")
end

-- E) canFuse vs baseCopies trap: mutated inflate OwnedCopies
print("\n--- E) Mutated inflate canFuse OwnedCopies vs consumeBaseCopies ---")
local commonId = nil
for id, relic in RelicConfig.ById do
	if relic.Tier == "Common" then
		commonId = id
		break
	end
end
local state = CollectionMath.defaults()
state.Essence = 500
state.Fusion[commonId] = { Rank = 1, Charm = "Hunt" }
local owned = RealFusion.newOwned()
owned.Counts[commonId] = 5
owned.Mutated[commonId] = 3 -- base=2 < consume Rank2=3
local ok, reason = CollectionMath.canFuse({
	TierId = "Common",
	RelicId = commonId,
	CurrentRank = 1,
	OwnedCopies = owned.Counts[commonId],
	Essence = state.Essence,
	State = state,
	HasMutatedCopy = true,
	EpicCatalystReady = true,
})
local base = RealFusion.baseCopies(owned, commonId)
local consume = CollectionMath.consumeForRank(2)
print(
	string.format(
		"  canFuse=%s reason=%s base=%d consume=%d → tryFuse would %s",
		tostring(ok),
		reason,
		base,
		consume,
		if base >= consume then "succeed" else "FAIL consume"
	)
)
local ok2, msg2 = RealFusion.tryFuse(state, owned, commonId, 0)
print(string.format("  tryFuse actual=%s msg=%s rank=%s", tostring(ok2), tostring(msg2), tostring(state.Fusion[commonId].Rank)))

print("\n=== Done ===")

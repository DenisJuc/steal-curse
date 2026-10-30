-- Measure practical Charm Ascension value (not just ×1.70 potency labels).
--   lune run tests/phase7AscendValue

local CollectionConfig = require("../src/shared/CollectionConfig")
local CollectionMath = require("../src/shared/CollectionMath")
local RelicConfig = require("../src/shared/RelicConfig")
local SoftCapRarity = require("./lib/softCapRarity")
local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")

local proposal = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = true,
	FusionMeaningfulEvery = 8,
}

print("=== Phase 7 Ascension practical value ===\n")

-- 1) Workshop: Essence per sale × expected dupe rate of that exact relic
local function workshopValue(tierId: string, luck: number)
	local pot = CollectionMath.charmPotency(tierId)
	local bonus = CollectionMath.workshopEssenceBonus(tierId)
	local essPerSale = CollectionMath.essenceFromSale(tierId, nil, true, tierId)
	local band = SoftCapRarity.softCapBandPercents(luck)
	local tierShare = (band[tierId] or 0) / 100
	local nInTier = 0
	for _, r in RelicConfig.ById do
		if r.Tier == tierId then
			nInTier += 1
		end
	end
	nInTier = math.max(1, nInTier)
	-- Approx P(exact relic) ≈ tierShare / nInTier (ignores in-tier weights)
	local pExact = tierShare / nInTier
	local essPerScan = essPerSale * pExact -- only when that relic drops as dupe + auto-essence
	return {
		Potency = pot,
		Bonus = bonus,
		EssPerSale = essPerSale,
		TierShare = tierShare,
		NInTier = nInTier,
		PExact = pExact,
		EssPerScan = essPerScan,
	}
end

print("-- Workshop Essence rate (AFK scan proxy at L=20 / L=80) --")
for _, L in { 20, 80 } do
	local c = workshopValue("Common", L)
	local u = workshopValue("Uncommon", L)
	local r = workshopValue("Rare", L)
	print(
		string.format(
			"  L=%d  Common Ess/scan≈%.4f (sale=%d p=%.4f)  Uncommon≈%.4f  Rare≈%.4f  | Rare/Common rate=%.2fx",
			L,
			c.EssPerScan,
			c.EssPerSale,
			c.PExact,
			u.EssPerScan,
			r.EssPerScan,
			r.EssPerScan / math.max(1e-12, c.EssPerScan)
		)
	)
	print(
		string.format(
			"         potency C/U/R = %.2f/%.2f/%.2f  workshopBonus=%.0f%%/%.0f%%/%.0f%%",
			c.Potency,
			u.Potency,
			r.Potency,
			c.Bonus * 100,
			u.Bonus * 100,
			r.Bonus * 100
		)
	)
end

-- 2) Hunt: family weight → SoftCap familyMult impact on band mix
print("\n-- Hunt family bias practical (SoftCap familyMult = 1+bonus) --")
for _, tier in { "Common", "Uncommon", "Rare" } do
	local bonus = CollectionMath.huntFamilyBonus("Hunt", false, tier)
	local mult = 1 + bonus
	print(string.format("  %s Hunt bonus=+%.3f → familyMult=%.3f", tier, bonus, mult))
end

-- 3) Shrine pulse
print("\n-- Shrine pulse interval --")
for _, tier in { "Common", "Uncommon", "Rare", "Epic" } do
	print(string.format("  %s → %.1fs", tier, CollectionMath.shrinePulseSeconds(tier)))
end

-- 4) Timeline: when Ascensions happen vs Rebirths
print("\n-- Ascension timing vs Rebirths (N=10 Hunter + Afk) --")
local function pct(arr, p)
	if #arr == 0 then
		return nil
	end
	local c = table.clone(arr)
	table.sort(c)
	return Unified.percentile(c, p)
end

for _, pol in { "AfkUpgrader", "Hunter" } do
	local a30, a60, a90, a120, a180 = {}, {}, {}, {}, {}
	local firstA, r1, r3 = {}, {}, {}
	for seed = 1, 10 do
		local r = Unified.run({
			Seed = seed,
			Minutes = 180,
			Policy = pol :: any,
			Sampler = "SoftCap",
			RebirthModel = "BPlus",
			CollectionHud = true,
			Proposal = proposal,
			TickMode = "Event",
		})
		if r.FirstCharmAscendAt then
			table.insert(firstA, r.FirstCharmAscendAt / 60)
		end
		if r.FirstRebirthAt then
			table.insert(r1, r.FirstRebirthAt / 60)
		end
		if r.RebirthsAt[3] then
			table.insert(r3, r.RebirthsAt[3] / 60)
		end
		for _, cp in r.Checkpoints do
			local n = cp.CharmAscensions or 0
			if cp.Minute == 30 then
				table.insert(a30, n)
			elseif cp.Minute == 60 then
				table.insert(a60, n)
			elseif cp.Minute == 90 then
				table.insert(a90, n)
			elseif cp.Minute == 120 then
				table.insert(a120, n)
			elseif cp.Minute == 180 then
				table.insert(a180, n)
			end
		end
	end
	print(
		string.format(
			"  [%s] FirstAscend P50=%.1fm  R1=%.1fm R3=%.1fm",
			pol,
			pct(firstA, 0.5) or -1,
			pct(r1, 0.5) or -1,
			pct(r3, 0.5) or -1
		)
	)
	print(
		string.format(
			"         Ascensions P50 @30/60/90/120/180 = %.0f/%.0f/%.0f/%.0f/%.0f",
			pct(a30, 0.5) or 0,
			pct(a60, 0.5) or 0,
			pct(a90, 0.5) or 0,
			pct(a120, 0.5) or 0,
			pct(a180, 0.5) or 0
		)
	)
end

print("\n=== Done ===")

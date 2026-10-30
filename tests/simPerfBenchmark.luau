-- SoftCap sim performance + Event vs PerSecond regression.
--   lune run tests/simPerfBenchmark
-- Does not change gameplay balance.

local process = require("@lune/process")
local SoftCapRarity = require("./lib/softCapRarity")
local Unified = require("./lib/unifiedProgressionSim")
local SimRuntime = require("./lib/simRuntime")

local SEEDS = 5
local MINUTES = 180

print("=== SoftCap roll microbench (50k rolls @ L=150) ===")
local function benchRolls(useCacheNote: string, invalidate: boolean)
	local t0 = SimRuntime.now()
	local state = 42
	local function rng()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
	if invalidate then
		SoftCapRarity.invalidateSampler()
	end
	-- Force rebuild once then roll
	SoftCapRarity.samplerFor(150)
	local tBuild = SimRuntime.now()
	local counts = {}
	for _ = 1, 50000 do
		if invalidate then
			SoftCapRarity.invalidateSampler()
		end
		local _, tier = SoftCapRarity.roll(150, rng)
		counts[tier] = (counts[tier] or 0) + 1
	end
	local t1 = SimRuntime.now()
	print(string.format("  %s: build=%.3fs rolls=%.3fs Rare=%d Epic=%d", useCacheNote, tBuild - t0, t1 - tBuild, counts.Rare or 0, counts.Epic or 0))
	return counts
end

local cCache = benchRolls("cached sampler", false)
local cCold = benchRolls("invalidate each roll (old-style cost)", true)
assert(cCache.Rare == cCold.Rare, "Rare counts must match for same RNG stream shape — cold rebuild changes only CPU not RNG if roll uses same u")
-- Note: cold rebuild with same rng sequence yields identical rolls; Rare counts should match.
print(string.format("  Rare match cached vs cold: %s", tostring((cCache.Rare or 0) == (cCold.Rare or 0))))

print("\n=== Event vs PerSecond regression (identical seeds) ===")
local proposal = {
	Id = "Bench",
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = 4e8,
	ScanMax = 12,
	FusionIncome = true,
	FusionMeaningfulEvery = 8,
}

local function fingerprint(r: Unified.RunResult): string
	local f = r.Final
	return table.concat({
		tostring(f.Unique),
		tostring(f.TotalFinds),
		tostring(f.Dupes),
		tostring(f.Mutations),
		tostring(f.Essence),
		tostring(math.floor(f.IncomePerSec + 0.5)),
		tostring(math.floor(f.CE + 0.5)),
		tostring(f.Rebirths),
		tostring(r.FirstRebirthAt or -1),
		tostring(f.CoreLuck),
		tostring(f.ScanRank),
		tostring(f.Fusions),
		string.format("%.3f", f.Band.Rare or 0),
		string.format("%.3f", f.Band.Common or 0),
	}, "|")
end

local timer = SimRuntime.start("regression")
local mismatches = 0
local eventTotal, perSecTotal = 0, 0

for seed = 1, SEEDS do
	local t0 = SimRuntime.now()
	local a = Unified.run({
		Seed = seed,
		Minutes = MINUTES,
		Policy = "AfkUpgrader",
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
		Proposal = proposal,
		TickMode = "Event",
	})
	eventTotal += SimRuntime.now() - t0

	local t1 = SimRuntime.now()
	local b = Unified.run({
		Seed = seed,
		Minutes = MINUTES,
		Policy = "AfkUpgrader",
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
		Proposal = proposal,
		TickMode = "PerSecond",
	})
	perSecTotal += SimRuntime.now() - t1

	local fa, fb = fingerprint(a), fingerprint(b)
	if fa ~= fb then
		mismatches += 1
		print(string.format("  MISMATCH seed=%d", seed))
		print("    Event:    " .. fa)
		print("    PerSecond:" .. fb)
	else
		print(string.format("  seed %d OK  Unique=%d R1=%s Finds=%d", seed, a.Final.Unique, tostring(a.FirstRebirthAt), a.Final.TotalFinds))
	end
end

SimRuntime.mark(timer, "done")
print(SimRuntime.report(timer))
print(string.format("Event total=%.2fs (%.2fs/seed)  PerSecond total=%.2fs (%.2fs/seed)  speedup=%.1fx", eventTotal, eventTotal / SEEDS, perSecTotal, perSecTotal / SEEDS, perSecTotal / math.max(1e-9, eventTotal)))
print(string.format("Fingerprint mismatches: %d / %d", mismatches, SEEDS))

if mismatches > 0 then
	print("FAIL: Event mode diverged from PerSecond")
	process.exit(1)
end

-- Suite-scale QUICK timing estimate
print("\n=== QUICK suite timing (2 variants × 2 policies × 5 seeds) ===")
local q = SimRuntime.start("QUICK")
local n = 0
for _, variantHud in { true, false } do
	for _, pol in { "AfkUpgrader", "Optimized" } do
		for seed = 1, 5 do
			Unified.run({
				Seed = seed + (if variantHud then 0 else 50),
				Minutes = 180,
				Policy = pol :: any,
				Sampler = "SoftCap",
				RebirthModel = "BPlus",
				CollectionHud = variantHud,
				Proposal = proposal,
				TickMode = "Event",
			})
			n += 1
		end
	end
end
local qEl = SimRuntime.elapsed(q)
print(string.format("QUICK-like %d runs: %.2fs (budget 30s)", n, qEl))
SimRuntime.warnIfSlow("QUICK-like", qEl, 30)

print("\n=== STANDARD estimate (6 variants × 4 policies × 10 seeds = 240) from per-seed ===")
local perSeed = eventTotal / SEEDS
local estStd = perSeed * 240
print(string.format("Est. STANDARD ≈ %.1fs (budget 120s) at %.3fs/seed", estStd, perSeed))
SimRuntime.warnIfSlow("STANDARD estimate", estStd, 120)

print("\nOK simPerfBenchmark")

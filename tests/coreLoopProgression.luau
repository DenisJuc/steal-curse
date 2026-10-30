-- Core Loop progression report (SoftCap_P5_Size, scan-first, no Fusion/Hunt).
-- Calibrated to playtest scan-heavy behavior (pt_153530464_259ca5b2).
-- Run: lune run tests/coreLoopProgression
-- Evidence: SIMULATION only (not rendered-player Studio sessions).

local CoreLoop = require("./lib/coreLoopSim")
local SimRuntime = require("./lib/simRuntime")

local HORIZONS = { 20, 60, 180, 600, 1800 } -- minutes: 20m, 1h, 3h, 10h, 30h
local SEEDS = {
	[20] = 20,
	[60] = 14,
	[180] = 10,
	[600] = 6,
	[1800] = 4,
}

local timer = SimRuntime.start("coreLoopProgression")
print("=== CORE LOOP PROGRESSION (SIMULATION) ===")
print("Trial=SoftCap_P5_Size | Scan-first | No Fusion/Charms/Hunt Quarry")
print("Policy: playtest-like shop dumps + save for Rebirth when sensible")
print("Evidence class: SIMULATION (not live Studio rendered play)\n")

local bottlenecks = {}

for _, minutes in HORIZONS do
	local seeds = SEEDS[minutes]
	local rows = {}
	for s = 1, seeds do
		table.insert(rows, CoreLoop.run({ Minutes = minutes, Seed = 1000 + s * 17 + minutes }))
	end
	local a = CoreLoop.aggregate(rows)
	local label = if minutes < 60 then `{minutes}m` else `{minutes / 60}h`

	print(`--- {label} ×{seeds} seeds ---`)
	print(string.format(
		"  Unique=%.1f (%.0f%% Index)  Valuable=%.1f  avgGap=%.2fm  EquipUps=%.1f  avgEquipGap=%.2fm",
		a.Unique,
		a.CodexFrac * 100,
		a.ValuableDiscoveries,
		a.AvgValuableGapMin,
		a.EquipUpgrades,
		a.AvgEquipGapMin
	))
	print(string.format(
		"  Luck %.2f → %.2f  |  P(Rare+)=%.3f%% → %.3f%% (×%.2f)  |  IncomeEnd=%.0f CE/s",
		a.LuckStart,
		a.LuckEnd,
		a.PRarePlusStart * 100,
		a.PRarePlusEnd * 100,
		if a.PRarePlusStart > 0 then a.PRarePlusEnd / a.PRarePlusStart else 0,
		a.IncomeEnd
	))
	print(string.format(
		"  CL=%.1f Scan=%.1f Energy=%.1f Slots=%.1f PedAvg=%.1f  CE=%.3g",
		a.CoreLuckEnd,
		a.ScanRankEnd,
		a.EnergyEnd,
		a.SlotsEnd,
		a.PedAvgLevel,
		a.CE
	))
	print(string.format(
		"  Rebirths=%.2f  firstR1=%s  pathOk=%s  deadEnd=%s",
		a.Rebirths,
		if a.MinToFirstRebirth then string.format("%.1fm", a.MinToFirstRebirth) else "none",
		tostring(a.RebirthPathOk),
		tostring(a.DeadEnd)
	))
	print(string.format(
		"  Variants≈%.0f  Huge=%.1f Titanic=%.1f Mut=%.1f  Goals: %s",
		a.VariantUniques,
		a.Huge,
		a.Titanic,
		a.Mutations,
		a.GoalsLeft
	))
	print()

	if not a.RebirthPathOk and minutes >= 180 then
		table.insert(bottlenecks, `{label}: first Rebirth not reached / path >12h at end income`)
	end
	if a.DeadEnd then
		table.insert(bottlenecks, `{label}: progression dead end (shop empty, far from Rebirth)`)
	end
	if a.PRarePlusEnd < a.PRarePlusStart * 1.05 and a.LuckEnd > a.LuckStart * 2 and minutes >= 60 then
		table.insert(bottlenecks, `{label}: Luck rose but P(Rare+) barely moved`)
	end
	if a.AvgValuableGapMin > 15 and minutes >= 180 then
		table.insert(
			bottlenecks,
			string.format("%s: valuable discoveries sparse (%.1fm avg gap)", label, a.AvgValuableGapMin)
		)
	end
	if a.CodexFrac > 0.95 and minutes <= 600 then
		table.insert(bottlenecks, `{label}: Index nearly exhausted early — future content risk`)
	end
end

print("=== BOTTLENECKS (from SIMULATION) ===")
if #bottlenecks == 0 then
	print("  (none flagged by heuristics — review numbers above)")
else
	for _, b in bottlenecks do
		print("  - " .. b)
	end
end

print("\n=== vs REAL PLAYTEST (pt_153530464_259ca5b2, 25:42 RENDERED) ===")
print("  Real: ~90% Scan, Unique~52 @25m, CE/s~52k @25m, CL=18, first Rare~4m, first Epic~12m, first Leg~24m")
print("  Real: no Rebirth in session; Fusion used lightly (not required for Core Loop)")
print("  Compare SIM 20m Unique/Income/CL to that band — not identical (policy noise).\n")

SimRuntime.mark(timer, "done")
print(SimRuntime.report(timer))
print("Done.")

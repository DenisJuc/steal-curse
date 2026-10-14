-- Prints AFK progression pacing (CE, CE/sec, luck, Rebirths) over two hours for a few seeds,
-- or every relic's income. Run from the repo root: lune run tests/economyReport [relics]

local process = require("@lune/process")

local Format = require("../src/shared/Format")
local RelicConfig = require("../src/shared/RelicConfig")
local EconomySim = require("./lib/economySim")
local relicIncome = require("./lib/relicIncome")

if process.args[1] == "relics" then
	for _, relic in RelicConfig.Relics do
		print(string.format("  %-10s %-24s 1 in %-8s %s/s", relic.Tier, relic.Id, Format.number(relicIncome.oneIn(relic.Id)), Format.number(relicIncome.base(relic.Id))))
	end
	return
end

local function minutes(seconds: number?): string
	return if seconds then string.format("%5.1f min", seconds / 60) else "not reached"
end

print("AFK progression: auto-roll, auto-equip, auto-sell duplicates, buys the cheapest upgrade, rebirths ASAP")
print("Targets: luck <= x20 at 5 min, ~1M CE by 20 min, first Rebirth 25-45 min, billions-trillions by 1-2 h\n")
for seed = 1, 3 do
	local result = EconomySim.run({ Seed = seed, Hours = 2 })
	print(
		`seed {seed}: pedestal 4 {minutes(result.SlotBoughtAt[4])} | 5 {minutes(result.SlotBoughtAt[5])} | 6 {minutes(
			result.SlotBoughtAt[6]
		)} | first Rebirth {minutes(result.FirstRebirthAt)} | sold {Format.number(result.SoldCE)} of {Format.number(
			result.LifetimeCE
		)} CE`
	)
	for _, snap in result.Snapshots do
		print(
			string.format(
				"  %4d min  CE %-8s total %-8s CE/s %-8s luck x%-8s rebirths %d  Core Luck %d  scan %.2fs  slots %d  best %s",
				snap.Minute,
				Format.number(snap.CE),
				Format.number(snap.LifetimeCE),
				Format.number(snap.IncomePerSec),
				Format.number(snap.Luck),
				snap.Rebirths,
				snap.CoreLuckRank,
				snap.ScanSeconds,
				snap.Slots,
				snap.BestTier
			)
		)
	end
end

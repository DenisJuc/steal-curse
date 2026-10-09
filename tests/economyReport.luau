-- Prints AFK shrine pacing at base luck. Run from the repo root: lune run tests/economyReport

local Config = require("../src/shared/Config")
local EconomySim = require("./lib/economySim")

local function minutes(seconds: number?): string
	return if seconds then string.format("%6.1f min", seconds / 60) else "  not reached"
end

print("AFK shrine pacing at base luck, best relics kept equipped, 5 seeds (GDD 6.8 targets: pedestal 4 at 10-15 min,")
print("pedestal 5 at 45-60 min, pedestal 6 at 2-3 h; skill tree speed-ups are not in yet)\n")
for _, scanSeconds in { Config.Scan.BaseIntervalSeconds, 2 } do
	print(`Scan every {scanSeconds}s`)
	for seed = 1, 5 do
		local result = EconomySim.run({ Seed = seed, ScanSeconds = scanSeconds, Hours = 4 })
		print(
			string.format(
				"  seed %d: pedestal 4 %s | 5 %s | 6 %s | CE/min after 4h %8.0f",
				seed,
				minutes(result.SlotBoughtAt[4]),
				minutes(result.SlotBoughtAt[5]),
				minutes(result.SlotBoughtAt[6]),
				result.FinalIncomePerMin
			)
		)
	end
end

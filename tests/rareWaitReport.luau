-- Prints rare-find waiting times under max boosts. Run from the repo root: lune run tests/rareWaitReport

local RareWait = require("./lib/rareWait")

for _, active in { false, true } do
	print(if active then "\nACTIVE HUNTING (1s scans + captures)" else "\nAFK (1 scan per second)")
	print(string.format("  %-46s %12s %10s %10s %10s", "Outcome", "1 in", "mean h", "median h", "p90 h"))
	for _, row in RareWait.rows(active) do
		print(
			string.format(
				"  %-46s %12.4g %10.1f %10.1f %10.1f",
				row.Label,
				1 / row.Probability,
				row.MeanHours,
				row.MedianHours,
				row.P90Hours
			)
		)
	end
end
print(string.format("\nMax-boost luck: %.4g", RareWait.maxLuck()))
print("Specific named combos scale by 1 / (that relic's share of its tier's weight).")

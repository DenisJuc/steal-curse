-- Lightweight timing helpers for progression sims (Lune).

local SimRuntime = {}

export type Timer = {
	Label: string,
	Started: number,
	Marks: { { Label: string, Sec: number } },
}

function SimRuntime.now(): number
	return os.clock()
end

function SimRuntime.start(label: string): Timer
	return { Label = label, Started = os.clock(), Marks = {} }
end

function SimRuntime.mark(timer: Timer, label: string)
	table.insert(timer.Marks, { Label = label, Sec = os.clock() - timer.Started })
end

function SimRuntime.elapsed(timer: Timer): number
	return os.clock() - timer.Started
end

function SimRuntime.report(timer: Timer): string
	local lines = { string.format("[SimRuntime] %s total=%.2fs", timer.Label, SimRuntime.elapsed(timer)) }
	local prev = 0
	for _, m in timer.Marks do
		table.insert(lines, string.format("  +%.2fs  %s (at %.2fs)", m.Sec - prev, m.Label, m.Sec))
		prev = m.Sec
	end
	return table.concat(lines, "\n")
end

function SimRuntime.warnIfSlow(label: string, elapsedSec: number, budgetSec: number)
	if elapsedSec > budgetSec then
		print(string.format("[SimRuntime] WARNING: %s took %.1fs (budget %.1fs)", label, elapsedSec, budgetSec))
	end
end

-- Soft timeout: returns true if exceeded (caller should stop scheduling more work).
function SimRuntime.overBudget(timer: Timer, budgetSec: number): boolean
	return SimRuntime.elapsed(timer) > budgetSec
end

return SimRuntime

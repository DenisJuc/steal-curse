-- A+C fix matrix across Rebirths 1–3 for Astra review.
--   lune run tests/acFixMatrix
--   lune run tests/acFixMatrix 150
-- Writes docs/AC_FIX_MATRIX.md

local fs = require("@lune/fs")
local process = require("@lune/process")

local Format = require("../src/shared/Format")
local Formulas = require("../src/shared/Formulas")
local ProvisionalSim = require("./lib/provisionalSim")
local RebirthAblation = require("./lib/rebirthAblation")

local SEED_COUNT = tonumber(process.args[1]) or 150
local WINDOW = 30 * 60
local candidate = ProvisionalSim.candidateE20k()
local matrix = RebirthAblation.acMatrix()

print(`A+C matrix: {SEED_COUNT} seeds, candidate {candidate.Id}`)

type Agg = {
	Id: string,
	Epic: number,
	UniqueEpic: number,
	Legendary: number,
	UniqueLegendary: number,
	Mutations: number,
	LuckEnd: number,
	IncomeEnd: number,
	CoreLuckEnd: number,
	SigBuys: number,
	GapMin: number?,
}

local function mean(stats: { RebirthAblation.WindowStats }): Agg
	local n = #stats
	local a = {
		Id = "",
		Epic = 0,
		UniqueEpic = 0,
		Legendary = 0,
		UniqueLegendary = 0,
		Mutations = 0,
		LuckEnd = 0,
		IncomeEnd = 0,
		CoreLuckEnd = 0,
		SigBuys = 0,
		GapMin = nil :: number?,
	}
	if n == 0 then
		return a
	end
	local gaps = {}
	for _, s in stats do
		a.Epic += s.Epic
		a.UniqueEpic += s.UniqueEpic
		a.Legendary += s.Legendary
		a.UniqueLegendary += s.UniqueLegendary
		a.Mutations += s.Mutations
		a.LuckEnd += s.LuckEnd
		a.IncomeEnd += s.IncomeEnd
		a.CoreLuckEnd += s.CoreLuckEnd
		a.SigBuys += s.SignificantBuys
		if s.MeanGapSec then
			table.insert(gaps, s.MeanGapSec)
		end
	end
	a.Epic /= n
	a.UniqueEpic /= n
	a.Legendary /= n
	a.UniqueLegendary /= n
	a.Mutations /= n
	a.LuckEnd /= n
	a.IncomeEnd /= n
	a.CoreLuckEnd /= n
	a.SigBuys /= n
	if #gaps > 0 then
		local g = 0
		for _, v in gaps do
			g += v
		end
		a.GapMin = (g / #gaps) / 60
	end
	return a
end

local byTarget: { [number]: { [string]: Agg } } = {}
for _, targetR in { 1, 2, 3 } do
	print(`--- Rebirth {targetR} ---`)
	local buckets: { [string]: { RebirthAblation.WindowStats } } = {}
	for _, abl in matrix do
		buckets[abl.Id] = {}
	end
	for seed = 1, SEED_COUNT do
		local snap = RebirthAblation.runToRebirth({
			Seed = seed,
			Candidate = candidate,
			TargetRebirth = targetR,
			MaxHours = 6,
		})
		if snap then
			for _, abl in matrix do
				table.insert(
					buckets[abl.Id],
					RebirthAblation.runWindow({
						Seed = seed,
						Candidate = candidate,
						Snapshot = snap,
						Ablation = abl,
						WindowSeconds = WINDOW,
					})
				)
			end
		end
		if seed % 50 == 0 then
			print(`  seed {seed}/{SEED_COUNT}`)
		end
	end
	byTarget[targetR] = {}
	for _, abl in matrix do
		local m = mean(buckets[abl.Id])
		m.Id = abl.Id
		byTarget[targetR][abl.Id] = m
		print(string.format("  %s epic=%.1f uniqueEpic=%.1f luck=%s", abl.Id, m.Epic, m.UniqueEpic, Format.number(m.LuckEnd)))
	end
end

-- Cost curve illustration (rank costs at each growth model)
local lines = {}
local function w(s: string)
	table.insert(lines, s)
end

w("# A+C fix matrix — Rebirths 1–3")
w("")
w("**Status:** Simulation only. Live balance **not** shipped. `BalanceTrials.Active` remains `nil`.")
w("")
w(`**Candidate reach path:** E20k_L12_C17_HR full stack (cost growth 1.7 to reach each Rebirth).`)
w(`**Seeds:** {SEED_COUNT}. **Window:** 30 minutes after each Rebirth.`)
w("")
w("## Cost curve feel (first 25 Core Luck ranks after Rebirth)")
w("")
w("| Rank | Live 1.7 | Flat 1.75 | Flat 1.80 | Flat 1.85 | Soft k=0.04 | Soft k=0.05 | Soft k=0.06 |")
w("|------|----------|-----------|-----------|-----------|-------------|-------------|-------------|")
for rank = 0, 24, 4 do
	w(
		string.format(
			"| %d | %s | %s | %s | %s | %s | %s | %s |",
			rank,
			Format.number(Formulas.coreLuckCost(rank, 100, 1.7)),
			Format.number(Formulas.coreLuckCost(rank, 100, 1.75)),
			Format.number(Formulas.coreLuckCost(rank, 100, 1.80)),
			Format.number(Formulas.coreLuckCost(rank, 100, 1.85)),
			Format.number(Formulas.coreLuckCostSoft(rank, 100, 1.7, 0.04, 1.35)),
			Format.number(Formulas.coreLuckCostSoft(rank, 100, 1.7, 0.05, 1.35)),
			Format.number(Formulas.coreLuckCostSoft(rank, 100, 1.7, 0.06, 1.35))
		)
	)
end
w("")
w("Soft curve stays near 1.7 for early ranks (no cliff), then pulls away — better post-Rebirth feel than jumping straight to 1.85.")
w("")

for _, targetR in { 1, 2, 3 } do
	local ctrl = byTarget[targetR].full
	w(`## After Rebirth {targetR}`)
	w("")
	w(
		string.format(
			"Control: **%.0f** Epics / 30m (unique Epic ids **%.1f**), Leg **%.1f** (unique **%.1f**), mutations **%.1f**, luck end **%s**, CoreLuck **%.0f**, sig-buy gap **%s** min.",
			ctrl.Epic,
			ctrl.UniqueEpic,
			ctrl.Legendary,
			ctrl.UniqueLegendary,
			ctrl.Mutations,
			Format.number(ctrl.LuckEnd),
			ctrl.CoreLuckEnd,
			if ctrl.GapMin then string.format("%.1f", ctrl.GapMin) else "—"
		)
	)
	w("")
	w("| Fix | Epic | %ctrl | Unique Epic | Leg | Unique Leg | Mut | Luck end | CoreLuck | Gap min |")
	w("|-----|------|-------|-------------|-----|------------|-----|----------|----------|---------|")
	for _, abl in matrix do
		local m = byTarget[targetR][abl.Id]
		w(
			string.format(
				"| %s | %.1f | %.0f%% | %.1f | %.2f | %.2f | %.1f | %s | %.0f | %s |",
				abl.Id,
				m.Epic,
				100 * m.Epic / math.max(1e-9, ctrl.Epic),
				m.UniqueEpic,
				m.Legendary,
				m.UniqueLegendary,
				m.Mutations,
				Format.number(m.LuckEnd),
				m.CoreLuckEnd,
				if m.GapMin then string.format("%.1f", m.GapMin) else "—"
			)
		)
	end
	w("")
end

w("## Read for Astra")
w("")
w("- Duplicate Epic **counts** stay higher than **unique** Epic discoveries — acceptable if Resonance / Charms / mutation goals are the post-R objectives.")
w("- Prefer **LuckGrowth 1.25 + soft cost (k≈0.05)** over flat 1.85 if early post-R ranks should feel rebuildable.")
w("- Flat 1.85 + LuckGrowth 1.25 is the strongest flood cut among flat options; re-check R2/R3 rows before approving.")
w("- **Do not ship** until combined with Collection prototype playtest.")
w("")
w("## Reproduce")
w("")
w("```bash")
w("lune run tests/acFixMatrix 150")
w("```")
w("")

fs.writeFile("docs/AC_FIX_MATRIX.md", table.concat(lines, "\n"))
print("Wrote docs/AC_FIX_MATRIX.md")

-- Corrected SoftCap vs Soft A+C Monte Carlo vs the real 35:51 playtest.
-- Uses Scan Speed + skill purchase timelines from pt_153530464_36f8c545.
-- Run: lune run tests/softCapPlaytestCorrected
-- Does NOT change SoftCap R/M, upgrade prices, Rebirth, or Studio trial flags.

local fs = require("@lune/fs")
local Sim = require("./lib/playtestCalibratedSim")

local N = 100
local PLAYTEST = {
	DurationSec = 2151,
	ScanRewards = 1879,
	Unique = 52,
	UniqueAt15 = 41,
	UniqueAt30 = 52,
	EpicExact = 11,
	DuplicateSells = 1667,
	HuntCaptures = 26,
	EssenceAt30 = 7697,
	IncomeAt30 = 134318,
	RareShareApprox = 1726 / 1879, -- ScanAgg only
}

local function fmt(n: number, d: number?): string
	return string.format(`%.{d or 1}f`, n)
end

local function pct3(s: { P10: number, P50: number, P90: number, Mean: number }, d: number?): string
	local dd = d or 1
	return `{fmt(s.P10, dd)} / **{fmt(s.P50, dd)}** / {fmt(s.P90, dd)}`
end

print(`Running {N} seeds × SoftCap + SoftAC (playtest-calibrated ScanSpeed)…`)

local softCapRuns = {}
local softACRuns = {}
for seed = 1, N do
	table.insert(softCapRuns, Sim.run({ Seed = seed, Sampler = "SoftCap" }))
	table.insert(softACRuns, Sim.run({ Seed = seed, Sampler = "SoftAC" }))
	if seed % 20 == 0 then
		print(`  …{seed}/{N}`)
	end
end

local sc = Sim.aggregate(softCapRuns)
local ac = Sim.aggregate(softACRuns)

local lines = {}
local function w(s: string?)
	table.insert(lines, s or "")
end

w("# SoftCap Phase 2 — Corrected Monte Carlo (Playtest-Calibrated)")
w()
w("**Supersedes** the under-rolled MC in `SOFTCAP_PHASE2_REPORT.md` §6 (fixed 525 rolls @ 4s).")
w("**Calibration source:** `docs/playtest/pt_153530464_36f8c545` (35:51, Soft A+C Studio trial).")
w("**Studio trial:** `SoftCap_Rev4` remains the default SoftCap Studio experiment (unchanged).")
w("**N = 100** seeded runs each. Values are **P10 / P50 / P90** (mean noted where useful).")
w()
w("No SoftCap R/M, upgrade prices, Rebirth rules, or live defaults were changed.")
w()

w("## 0. Why the old MC was wrong")
w()
w("| | Old Phase-2 MC | Real playtest |")
w("| --- | ---: | ---: |")
w("| Duration | ~35 min | 35:51 |")
w("| Scan model | constant **4 s** | Scan Speed 0→12 (→ **1 s**) |")
w("| Auto-scan rewards | **525** | **1879** (ScanAgg) |")
w("| Underestimate | — | **~3.6×** fewer rolls |")
w("| SoftAC uniques @35m | ~30 (P50-ish) | **52** |")
w()
w("ScanSpeed path used (from purchases): 0 @0s → 6 @3:40 → 10 @9:50 → 12 @16:29.")
w("CoreLuck / MutRes / FrequencyFocus follow the same session’s purchase times.")
w("Hunt: 26 captures paced ~every 83s with trial-capped bonus rolls.")
w("Playtest also shows a **Common Rarity Focus** burst ~15:51–16:30 (extra Commons in ScanAgg); both sims replay that window.")
w("Scan clock uses a **1.074×** timing factor so ScanSpeed ranks produce ~1879 scans (closed-form path alone ≈1750).")
w()

w("## 1. Roll volume validation (must match playtest first)")
w()
w("| Metric | Playtest | SoftAC P10/P50/P90 | SoftCap P10/P50/P90 |")
w("| --- | ---: | ---: | ---: |")
w(`| Total rolls | ~1879 scans + hunt bonuses | {pct3(ac.TotalRolls, 0)} | {pct3(sc.TotalRolls, 0)} |`)
w(`| Scan rolls | 1879 | {pct3(ac.ScanRolls, 0)} | {pct3(sc.ScanRolls, 0)} |`)
w(`| Hunt rolls | (26 captures × bonus) | {pct3(ac.HuntRolls, 0)} | {pct3(sc.HuntRolls, 0)} |`)
w()
w(`Scan-roll P50 vs playtest 1879: SoftAC **{fmt(100 * ac.ScanRolls.P50 / PLAYTEST.ScanRewards, 1)}%**, SoftCap **{fmt(100 * sc.ScanRolls.P50 / PLAYTEST.ScanRewards, 1)}%** (identical ScanSpeed clock).`)
w()

w("## 2. Discovery comparison @ 35:51")
w()
w("| Metric | Playtest (SoftAC) | SoftAC sim | SoftCap sim |")
w("| --- | ---: | ---: | ---: |")
w(`| Unique @15m | {PLAYTEST.UniqueAt15} | {pct3(ac.UniqueAt15, 0)} | {pct3(sc.UniqueAt15, 0)} |`)
w(`| Unique @30m | {PLAYTEST.UniqueAt30} | {pct3(ac.UniqueAt30, 0)} | {pct3(sc.UniqueAt30, 0)} |`)
w(`| Unique @35m | {PLAYTEST.Unique} | {pct3(ac.UniqueAt35, 0)} | {pct3(sc.UniqueAt35, 0)} |`)
w(`| Dupes | ~{PLAYTEST.DuplicateSells} sells | {pct3(ac.Dupes, 0)} | {pct3(sc.Dupes, 0)} |`)
w(`| Mutations | (many milestones) | {pct3(ac.Mutations, 0)} | {pct3(sc.Mutations, 0)} |`)
w(`| Epic exact | {PLAYTEST.EpicExact} | {pct3(ac.EpicExact, 0)} | {pct3(sc.EpicExact, 0)} |`)
w(`| Epic+ | — | {pct3(ac.EpicPlus, 0)} | {pct3(sc.EpicPlus, 0)} |`)
w(`| Unique Epic IDs | 7 | {pct3(ac.UniqueEpic, 0)} | {pct3(sc.UniqueEpic, 0)} |`)
w(`| Essence (proxy) | ~{PLAYTEST.EssenceAt30} @30m | {pct3(ac.Essence, 0)} | {pct3(sc.Essence, 0)} |`)
w(`| CE/s end (proxy) | ~{PLAYTEST.IncomeAt30} @30m | {pct3(ac.IncomePerSecEnd, 0)} | {pct3(sc.IncomePerSecEnd, 0)} |`)
w(`| Rare % of rolls | ~{fmt(100 * PLAYTEST.RareShareApprox, 1)}% (scans) | {pct3(ac.RarePctEnd, 1)} | {pct3(sc.RarePctEnd, 1)} |`)
w(`| Common+Uncommon % | ~{fmt(100 * (1 - PLAYTEST.RareShareApprox), 1)}% | {pct3(ac.CommonUncommonPct, 1)} | {pct3(sc.CommonUncommonPct, 1)} |`)
w()

w("### Mean rolls by tier (P50-adjacent mean)")
w()
w("| Tier | SoftAC mean | SoftCap mean |")
w("| --- | ---: | ---: |")
for _, t in { "Common", "Uncommon", "Rare", "Epic" } do
	w(`| {t} | {fmt(ac[t].Mean, 1)} | {fmt(sc[t].Mean, 1)} |`)
end
w()

w("## 3. Desirable discoveries (corrected definition)")
w()
w("**Desirable** = new Unique Rare+, new Unique Epic+, or first-ever of a rarity tier.")
w("**Not desirable:** plain Common/Uncommon dupes, or mutation spice on an already-known relic.")
w()
w("| Metric | SoftAC | SoftCap |")
w("| --- | ---: | ---: |")
w(`| Desirable events | {pct3(ac.DesirableEvents, 0)} | {pct3(sc.DesirableEvents, 0)} |`)
w(`| Avg gap (rolls) | {pct3(ac.AvgDesirableGapRolls, 1)} | {pct3(sc.AvgDesirableGapRolls, 1)} |`)
w(`| Avg gap (seconds) | {pct3(ac.AvgDesirableGapSec, 1)} | {pct3(sc.AvgDesirableGapSec, 1)} |`)
w(`| Epic / 1000 rolls (from P50 EpicExact) | {fmt(1000 * ac.EpicExact.P50 / math.max(1, ac.TotalRolls.P50), 2)} | {fmt(1000 * sc.EpicExact.P50 / math.max(1, sc.TotalRolls.P50), 2)} |`)
w()

w("## 4. Why the old “30.6 vs 28.6 valuable gap” looked backwards")
w()
w("The superseded report defined “valuable” as **new Rare+ unique OR any Epic+ drop**, then measured **gap in rolls**.")
w()
w("Under Soft A+C’s Rare wall (~99% Rare mid-session):")
w("- Almost every roll can advance the **Rare Index** until that small pool (~14 relics) is exhausted.")
w("- So “new Rare unique” events cluster early → average gap **in rolls** looks short.")
w("- After the Rare Index fills, desirable Index progress **stalls** even though rolls continue (unique count ~30–52 depending on volume).")
w()
w("Under SoftCap:")
w("- Rare rolls are ~14% at L150, so Rare Index fills **slower per roll** → longer average gap *in roll space* for Rare+ events.")
w("- But Commons/Uncommons keep unlocking early Index entries, and wall-clock gaps matter more than roll gaps when scan rate is 1/s.")
w()
w("Corrected sim legacy metric (same bad definition) for transparency:")
w()
w(`| Legacy valuable avg gap (rolls) | SoftAC {pct3(ac.LegacyValuableAvgGapRolls, 1)} | SoftCap {pct3(sc.LegacyValuableAvgGapRolls, 1)} |`)
w()
w("Use **seconds between desirable events** and **unique@15/30/35** as the player-experience scores, not the old roll-gap alone.")
w()

w("## 5. 85% C/U at mid Luck with realistic 1s scanning")
w()
w(`SoftCap P50 Common+Uncommon share of all rolls: **{fmt(sc.CommonUncommonPct.P50, 1)}%** (session average; midgame Luck is higher C/U than SoftAC’s Rare flood).`)
w(`At ~1 scan/s after Scan Speed 12 (~16:29→end ≈ 19 min): SoftCap still delivers ~{fmt(sc.ScanRolls.P50 * 0.55, 0)} low-tier rolls in that window alone (order-of-magnitude) — Collection/Essence is the intended sink.`)
w()
w("Player-feel risk remains **dupe fatigue**, not Rare color plateau. SoftCap’s win condition is restoring a mixed Index climb without SoftAC’s midgame Rare wallpaper.")
w()

w("## 6. Experience verdict (corrected — no retunes)")
w()
local acU = ac.UniqueAt35.P50
local scU = sc.UniqueAt35.P50
w(`- SoftAC unique@35 P50 **{fmt(acU, 0)}** vs playtest **{PLAYTEST.Unique}** (calibration check).`)
w(`- SoftCap unique@35 P50 **{fmt(scU, 0)}** under the same ScanSpeed/Luck path.`)
w(`- SoftAC Rare% P50 **{fmt(ac.RarePctEnd.P50, 1)}%** vs SoftCap **{fmt(sc.RarePctEnd.P50, 1)}%** — SoftCap still kills the Rare wall.`)
w(`- SoftCap Epic exact P50 **{fmt(sc.EpicExact.P50, 0)}** vs SoftAC **{fmt(ac.EpicExact.P50, 0)}** / playtest {PLAYTEST.EpicExact} — flag early-Epic generosity if SoftCap >> SoftAC.`)
w(`- CE/s proxy is **directional only** (simplified pedestals); SoftCap may land lower-tier income earlier — confirm in Studio, do not retune Rebirth yet.`)
w()
w("**Recommendation:** proceed with the planned short Studio SoftCap playtest. Do not balance costs around SoftCap until that human session.")
w()

w("## 7. Studio safety")
w()
w("- `BalanceTrials.StudioTrialId = \"SoftCap_Rev4\"` still active for Studio.")
w("- Control: `SoftAC_E20k`. Production: live Ladder.")
w("- SoftCap coefficients untouched.")
w()
w("---")
w(`*Generated by \`lune run tests/softCapPlaytestCorrected\` ({N} seeds/side).*`)

local body = table.concat(lines, "\n") .. "\n"
fs.writeFile("docs/SOFTCAP_PHASE2_MC_CORRECTION.md", body)
print("Wrote docs/SOFTCAP_PHASE2_MC_CORRECTION.md")
print(`SoftAC Unique@35 P50={ac.UniqueAt35.P50} ScanP50={ac.ScanRolls.P50} Rare%={fmt(ac.RarePctEnd.P50)}`)
print(`SoftCap Unique@35 P50={sc.UniqueAt35.P50} ScanP50={sc.ScanRolls.P50} Rare%={fmt(sc.RarePctEnd.P50)} CU%={fmt(sc.CommonUncommonPct.P50)}`)
print(`Desirable gap sec SoftAC={fmt(ac.AvgDesirableGapSec.P50)} SoftCap={fmt(sc.AvgDesirableGapSec.P50)}`)

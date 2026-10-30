-- Deep-dive provisional candidate E20k_L12_C17_HR vs baseline with full luck stack.
--   lune run tests/provisionalCandidate
--   lune run tests/provisionalCandidate 500
-- Writes docs/PROVISIONAL_E20k_RESULTS.md — does not change live defaults.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Config = require("../src/shared/Config")
local Format = require("../src/shared/Format")
local ProgressionSweep = require("./lib/progressionSweep")
local ProvisionalSim = require("./lib/provisionalSim")

local SEED_COUNT = tonumber(process.args[1]) or 500
local HOURS = 4

local function fmtMin(seconds: number?): string
	if not seconds then
		return "—"
	end
	return string.format("%.1f", seconds / 60)
end

local function popPct(sorted: { number }, n: number, p: number): number?
	local need = math.ceil(n * p)
	if #sorted < need then
		return nil
	end
	return sorted[need]
end

local function times(results: { ProvisionalSim.DeepResult }, field: string): { number }
	local list = {}
	for _, r in results do
		local v = (r :: any)[field]
		if type(v) == "number" then
			table.insert(list, v)
		end
	end
	table.sort(list)
	return list
end

local function mean(values: { number }): number
	if #values == 0 then
		return 0
	end
	local s = 0
	for _, v in values do
		s += v
	end
	return s / #values
end

local function satMean(results: { ProvisionalSim.DeepResult }, minute: number, field: string): number
	local s, n = 0, 0
	for _, r in results do
		for _, sat in r.Saturations do
			if sat.Minute == minute then
				s += sat[field] or 0
				n += 1
			end
		end
	end
	return if n > 0 then s / n else 0
end

type Row = {
	Label: string,
	Behaviour: string,
	N: number,
	EpicP10: number?,
	EpicP50: number?,
	EpicP90: number?,
	EpicRate: number,
	LegP50: number?,
	LegRate: number,
	Reb1P50: number?,
	Reb2P50: number?,
	Reb3P50: number?,
	Reb1Rate: number,
	Epic15: number,
	Epic60: number,
	Epic120: number,
	Epic240: number,
	Luck15: number,
	Luck60: number,
	Luck120: number,
	Low60: number,
	Low60Focus: number,
	Low120: number,
	Captures: number,
	PotionUptime: number,
	PostRebEpic30: number,
	PostRebLuck: number,
}

local function aggregate(label: string, behaviour: string, results: { ProvisionalSim.DeepResult }): Row
	local n = #results
	local epicT = times(results, "FirstEpicAt")
	local legT = times(results, "FirstLegendaryAt")
	local r1 = times(results, "FirstRebirthAt")
	local r2 = times(results, "SecondRebirthAt")
	local r3 = times(results, "ThirdRebirthAt")
	local postEpic, postLuck = {}, {}
	for _, r in results do
		for _, p in r.PostRebirth do
			if p.RebirthIndex == 1 then
				table.insert(postEpic, p.EpicNext30)
				table.insert(postLuck, p.LuckAfter)
			end
		end
	end
	return {
		Label = label,
		Behaviour = behaviour,
		N = n,
		EpicP10 = popPct(epicT, n, 0.10),
		EpicP50 = popPct(epicT, n, 0.50),
		EpicP90 = popPct(epicT, n, 0.90),
		EpicRate = #epicT / n,
		LegP50 = popPct(legT, n, 0.50),
		LegRate = #legT / n,
		Reb1P50 = popPct(r1, n, 0.50),
		Reb2P50 = popPct(r2, n, 0.50),
		Reb3P50 = popPct(r3, n, 0.50),
		Reb1Rate = #r1 / n,
		Epic15 = satMean(results, 15, "EpicTotal"),
		Epic60 = satMean(results, 60, "EpicTotal"),
		Epic120 = satMean(results, 120, "EpicTotal"),
		Epic240 = satMean(results, 240, "EpicTotal"),
		Luck15 = satMean(results, 15, "Luck"),
		Luck60 = satMean(results, 60, "Luck"),
		Luck120 = satMean(results, 120, "Luck"),
		Low60 = mean((function()
			local t = {}
			for _, r in results do
				table.insert(t, r.LowTierMass60)
			end
			return t
		end)()),
		Low60Focus = mean((function()
			local t = {}
			for _, r in results do
				table.insert(t, r.LowTierMass60Focused)
			end
			return t
		end)()),
		Low120 = mean((function()
			local t = {}
			for _, r in results do
				table.insert(t, r.LowTierMass120)
			end
			return t
		end)()),
		Captures = mean((function()
			local t = {}
			for _, r in results do
				table.insert(t, r.Captures)
			end
			return t
		end)()),
		PotionUptime = mean((function()
			local t = {}
			for _, r in results do
				table.insert(t, r.PotionUptime)
			end
			return t
		end)()),
		PostRebEpic30 = mean(postEpic),
		PostRebLuck = mean(postLuck),
	}
end

local behaviours: { ProgressionSweep.Behaviour } = { "passive", "upgrader", "hunter" }
local candidate = ProvisionalSim.candidateE20k()
local baseline = ProgressionSweep.baselineCandidate()
baseline.Hunt.CaptureCycleSeconds = candidate.Hunt.CaptureCycleSeconds

print(`Provisional deep-dive: {SEED_COUNT} seeds, {HOURS}h, full luck stack`)
print(`Essential pool size (Codex): {ProvisionalSim.essentialPoolSize()}`)
print(
	`Hunter capture cycle: {candidate.Hunt.CaptureCycleSeconds}s (hold+travel); signals {Config.Signals.StartCount}→{Config.Signals.MaxCount}, regen {Config.Signals.RegenSeconds}s`
)

local rows: { Row } = {}
for _, labelCand in { { "baseline", baseline }, { "E20k_L12_C17_HR", candidate } } do
	local label, cand = labelCand[1] :: string, labelCand[2] :: ProgressionSweep.Candidate
	for _, beh in behaviours do
		local results = {}
		local hours = if label == "baseline" then 2 else HOURS
		for seed = 1, SEED_COUNT do
			table.insert(
				results,
				ProvisionalSim.run({
					Seed = seed,
					Hours = hours,
					Behaviour = beh,
					Candidate = cand,
					FullStack = true,
				})
			)
		end
		local row = aggregate(label, beh, results)
		table.insert(rows, row)
		print(
			string.format(
				"  %s/%s  epicP50=%s (%.0f%%) legP50=%s reb1=%s reb2=%s epic@15=%.1f luck@15=%s lowTier60=%.3f focus=%.3f caps=%.0f",
				label,
				beh,
				fmtMin(row.EpicP50),
				row.EpicRate * 100,
				fmtMin(row.LegP50),
				fmtMin(row.Reb1P50),
				fmtMin(row.Reb2P50),
				row.Epic15,
				Format.number(row.Luck15),
				row.Low60,
				row.Low60Focus,
				row.Captures
			)
		)
	end
end

local function find(label: string, beh: string): Row?
	for _, r in rows do
		if r.Label == label and r.Behaviour == beh then
			return r
		end
	end
	return nil
end

local lines = {}
local function w(s: string)
	table.insert(lines, s)
end

w("# Provisional candidate results — E20k_L12_C17_HR")
w("")
w("**For Astra + human review. Live economy defaults were not shipped.**")
w("")
w("## Configuration under test")
w("")
w("| Knob | Value |")
w("|------|-------|")
w("| Epic+ denom | 20,000 (live 500) |")
w("| Legendary+ denom | 500,000 (live 25,000) |")
w("| Core Luck | `10^(rank/12)`, cost growth 1.7 |")
w("| Hunt | floor 2, factor 0.08, ref scan 4s, max bonus 6, hunt luck ×5 |")
w("| Relic CE/sec | **Frozen** to live per-relic incomes (weights preserved) |")
w("")
w("## Sim setup")
w("")
w(`- Seeds: **{SEED_COUNT}** identical across baseline and candidate`)
w(`- Candidate duration: **{HOURS} h**; baseline comparison: **2 h**`)
w("- Behaviours: `passive` (scan, no spend), `upgrader` (scan+buys+rebirth), `hunter` (upgrader + signals)")
w("- **Full luck stack:** Core × Rebirth × (1+Codex essential luck) × (1+Showcase luck) × potion (×2 while buff up)")
w("  - Codex milestones from unique Essential relics (Common→Legendary)")
w("  - Showcase: buys Simple Stance when affordable, upgrades when CE allows")
w("  - Potions: hunter 12% Luck potion per capture; upgrader ~35% chance every 10 min (offering proxy)")
w("- **Hunter fidelity:** start 3 signals, max 5, +1 / 120s; capture cycle = hold 6s + travel 14s = **20s**; cannot capture without a signal (after burst, ~1 capture / 120s)")
w("- Low-tier mass: P(Common)+P(Uncommon) under MaxLuck vs Focus=Common (collection soft-lock check)")
w("")
w("## Headline table")
w("")
w("| Build | Beh | Epic P10/P50/P90 | Epic% | Leg P50 | Rebirth1 P50 | Rebirth2 P50 | Epic@15 | Luck@15 | LowTier@60 (MaxLuck / Focus Common) |")
w("|-------|-----|------------------|-------|---------|--------------|--------------|---------|---------|-------------------------------------|")
for _, r in rows do
	w(
		string.format(
			"| %s | %s | %s / %s / %s | %.0f%% | %s | %s | %s | %.1f | %s | %.4f / %.4f |",
			r.Label,
			r.Behaviour,
			fmtMin(r.EpicP10),
			fmtMin(r.EpicP50),
			fmtMin(r.EpicP90),
			r.EpicRate * 100,
			fmtMin(r.LegP50),
			fmtMin(r.Reb1P50),
			fmtMin(r.Reb2P50),
			r.Epic15,
			Format.number(r.Luck15),
			r.Low60,
			r.Low60Focus
		)
	)
end
w("")

local bu, bh = find("baseline", "upgrader"), find("baseline", "hunter")
local cu, ch, cp = find("E20k_L12_C17_HR", "upgrader"), find("E20k_L12_C17_HR", "hunter"), find("E20k_L12_C17_HR", "passive")

w("## Interpretation for Astra")
w("")
w("### vs playtest / baseline")
w("")
if bu and cu then
	w(`- Baseline upgrader Epic P50 **{fmtMin(bu.EpicP50)} min**, Epic@15 **{string.format("%.1f", bu.Epic15)}**, luck@15 **{Format.number(bu.Luck15)}**.`)
	w(`- Candidate upgrader Epic P50 **{fmtMin(cu.EpicP50)} min**, Epic@15 **{string.format("%.1f", cu.Epic15)}**, luck@15 **{Format.number(cu.Luck15)}**.`)
	w(`- Full stack (Codex/Showcase/potions) makes candidate luck higher than the Phase-0 core-only sweep — expect somewhat earlier Epics than the 25.7 min core-only figure.`)
end
w("")
w("### Hunter model check")
w("")
if ch then
	w(`- Mean captures over {HOURS}h hunter: **{string.format("%.0f", ch.Captures)}** (~{string.format("%.1f", ch.Captures / HOURS)} / hour).`)
	w("- With 20s cycle and 120s regen, after the opening burst the binder is **signal-gated** (~30 captures/hour theoretical max from regen alone; lower if walking longer).")
	w(`- Hunter Epic P50 {fmtMin(ch.EpicP50)} vs upgrader {fmtMin(cu and cu.EpicP50)} — active should stay ahead without returning to baseline flood (Epic@15 hunter {string.format("%.1f", ch.Epic15)}).`)
end
w("")
w("### Post-Rebirth escalation")
w("")
if cu then
	w(`- Rebirth1 P50: **{fmtMin(cu.Reb1P50)}**; Rebirth2 P50: **{fmtMin(cu.Reb2P50)}**; Rebirth3 P50: **{fmtMin(cu.Reb3P50)}**.`)
	w(`- Mean Epics in the **30 minutes after first Rebirth**: **{string.format("%.1f", cu.PostRebEpic30)}** (skills reset; Rebirth luck ×1.5 and kept relics remain).`)
	w(`- Mean luck right after measuring window post-R1: **{Format.number(cu.PostRebLuck)}**.`)
	w("- If post-R1 Epic flood returns, Phase 1 may need softer Rebirth luck growth or a temporary Focus nudge — call out in review.")
end
w("")
w("### High-luck low-tier collection")
w("")
if cu then
	w(`- At 60 min upgrader, P(Common∪Uncommon) under **MaxLuck**: **{string.format("%.4f", cu.Low60)}** (≈0 means soft-locked).`)
	w(`- Same moment with **Rarity Focus = Common**: **{string.format("%.4f", cu.Low60Focus)}**.`)
	if cu.Low60 < 0.01 and cu.Low60Focus > 0.2 then
		w("- **Conclusion:** MaxLuck erases low tiers; Focus restores them. Phase 1 must ship Focus UX / prompts — not optional.")
	elseif cu.Low60 < 0.01 then
		w("- **Conclusion:** Low tiers nearly unreachable even with Focus Common — needs a stronger attunement/pity tool.")
	else
		w("- Low tiers still have mass under MaxLuck at 60m for this candidate (luck not yet erasing Commons).")
	end
end
w("")
w("### Entertainment (not just delay)")
w("")
w("- Candidate removes the 15‑minute Epic carpet-bomb; Epic becomes a mid-session event for upgraders.")
w("- Passive-without-upgrades rarely completes Epic (by design of dual matrix) — spending CE on luck/scan is the on-ramp.")
w("- **Still missing for fun:** duplicate sinks, fusion, mutation unlocks (see Phase 2 plan). Slower rarity without those is emptier waiting.")
w("")
w("## Studio test build (not live)")
w("")
w("1. Open [`src/shared/BalanceTrials.luau`](../src/shared/BalanceTrials.luau).")
w("2. Set `BalanceTrials.Active = \"E20k_L12_C17_HR\"` locally (keep `nil` in shipping commits).")
w("3. Play in Studio: roll denoms, Core Luck curve/cost, and hunt reform apply; **relic CE/sec stays on live incomes**.")
w("4. Set `Active` back to `nil` before any production publish.")
w("")
w("## Reproduce")
w("")
w("```bash")
w("lune run tests/provisionalCandidate 500")
w("```")
w("")

fs.writeFile("docs/PROVISIONAL_E20k_RESULTS.md", table.concat(lines, "\n"))
print("Wrote docs/PROVISIONAL_E20k_RESULTS.md")

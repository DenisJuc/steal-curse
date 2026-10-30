-- Continuous soft A+C + collection Studio loop.
--   lune run tests/studioProgression
--   lune run tests/studioProgression 100
-- Writes docs/STUDIO_PROGRESSION_REPORT.md

local fs = require("@lune/fs")
local process = require("@lune/process")

local Format = require("../src/shared/Format")
local ProvisionalSim = require("./lib/provisionalSim")
local StudioLoop = require("./lib/studioLoop")

local SEEDS = tonumber(process.args[1]) or 100
local candidate = ProvisionalSim.candidateE20k()

print(`Studio progression: {SEEDS} seeds, soft A+C + paced collection (corrected event taxonomy)`)

local sums = {}
local rebirthP50 = { {}, {}, {} }
local firstFusion, firstGoal = {}, {}
local rosterEpic, rosterPlus = 13, 47
local spendSums = {
	Fusion = 0,
	Catalyst = 0,
	AttuneTicket = 0,
	TargetedAttune = 0,
	MutationFocus = 0,
	FamilyAttune = 0,
	CharmRespec = 0,
	CapUpgrade = 0,
}

for seed = 1, SEEDS do
	local r = StudioLoop.run({
		Seed = seed,
		Hours = 3,
		Candidate = candidate,
		LuckGrowth = 1.25,
		SoftK = 0.05,
		SoftPower = 1.35,
		SpendPolicy = "Optimal",
	})
	rosterEpic = r.RosterEpicExact
	rosterPlus = r.RosterEpicPlus
	if r.FirstFusionMin then
		table.insert(firstFusion, r.FirstFusionMin)
	end
	if r.FirstGoalMin then
		table.insert(firstGoal, r.FirstGoalMin)
	end
	for i, at in r.RebirthsAt do
		if rebirthP50[i] then
			table.insert(rebirthP50[i], at / 60)
		end
	end
	for k, v in r.EssenceSpend do
		spendSums[k] = (spendSums[k] or 0) + v
	end
	for _, cp in r.Checkpoints do
		sums[cp.Minute] = sums[cp.Minute] or {}
		local bucket = sums[cp.Minute]
		for k, v in cp do
			if type(v) == "number" then
				bucket[k] = (bucket[k] or 0) + v
			end
		end
		bucket._n = (bucket._n or 0) + 1
	end
	if seed % 25 == 0 then
		print(`  seed {seed}/{SEEDS}`)
	end
end

-- Suboptimal spend policies (smaller sample) for Essence economy honesty.
local altSeeds = math.min(40, SEEDS)
local alt = {
	FusionOnly = { bank = 0, spent = 0, goals = 0, n = 0 },
	Hoard = { bank = 0, spent = 0, goals = 0, n = 0 },
}
for seed = 1, altSeeds do
	for _, policy in { "FusionOnly", "Hoard" } do
		local r = StudioLoop.run({
			Seed = seed + 1000,
			Hours = 3,
			Candidate = candidate,
			LuckGrowth = 1.25,
			SoftK = 0.05,
			SpendPolicy = policy,
		})
		local fin = r.Final
		if fin then
			alt[policy].bank += fin.Essence
			alt[policy].spent += fin.EssenceSpent
			alt[policy].goals += fin.Goals
			alt[policy].n += 1
		end
	end
	if seed % 20 == 0 then
		print(`  alt policy seed {seed}/{altSeeds}`)
	end
end

local function p50(list)
	if #list == 0 then
		return nil
	end
	table.sort(list)
	return list[math.ceil(#list * 0.5)]
end

local function avg(minute, key)
	local b = sums[minute]
	if not b or not b._n then
		return 0
	end
	return (b[key] or 0) / b._n
end

local function spendAvg(key)
	return (spendSums[key] or 0) / SEEDS
end

local function altAvg(policy, key)
	local row = alt[policy]
	if row.n == 0 then
		return 0
	end
	return row[key] / row.n
end

local lines = {}
local function w(s)
	table.insert(lines, s)
end

w("# Studio progression report — soft A+C + paced collection")
w("")
w("**Status:** Simulation + Studio playtest prototype. Live defaults unchanged (`Active = nil`). **Live release blocked.**")
w("")
w(`**Config:** E20k dens + LuckGrowth **1.25** + CoreLuck soft **k=0.05** + fusion slots / targeted recipes / mutation milestones / Essence sinks.`)
w(`**Seeds:** {SEEDS} (Optimal spend). Alt policies: {altSeeds} seeds each. **Duration:** 3h continuous.`)
w("")
w("## Rarity metric integrity")
w("")
w(`Roster: **{rosterEpic}** exact Epic base relics, **{rosterPlus}** Epic+ (Epic through Cosmic).`)
w("Soft A+C rarity pacing is unchanged by collection work.")
w("")
w("## Rebirth timing (population P50)")
w("")
w(
	string.format(
		"- R1: **%s** min · R2: **%s** · R3: **%s**",
		if p50(rebirthP50[1]) then string.format("%.1f", p50(rebirthP50[1])) else "—",
		if p50(rebirthP50[2]) then string.format("%.1f", p50(rebirthP50[2])) else "—",
		if p50(rebirthP50[3]) then string.format("%.1f", p50(rebirthP50[3])) else "—"
	)
)
w(
	string.format(
		"- First fusion P50: **%s** min · First mutation goal P50: **%s** min",
		if p50(firstFusion) then string.format("%.1f", p50(firstFusion)) else "—",
		if p50(firstGoal) then string.format("%.1f", p50(firstGoal)) else "—"
	)
)
w("")
w("### Rebirth depth (not just speed)")
w("")
w("- **Each Rebirth** grants a Resonance pick (Collector / Binder / Seeker). Stacks 2–3 unlock Salvage, Daily Attune, Quick Bind, Free Signal, Mutation Tint, Post-R Attune.")
w("- **R1** also adds a fusion board slot. Later Rebirths deepen Resonance identity rather than only multiplying Luck/Income.")
w("- Do **not** automatically slow R2/R3; validate in Studio whether Resonance choices feel like new objectives.")
w("")
w("## Event taxonomy (corrected)")
w("")
w("Prior 'Meaningful≈2510' counted ordinary mutation drops and repeated sinks. New buckets:")
w("")
w("| Bucket | What counts |")
w("|--------|-------------|")
w("| **UniqueMechanics** | Distinct unlock flags (Attune recipe, board slots, Resonance unlocks, etc.) — once each |")
w("| **FirstMilestones** | First fusion, each mutation goal claim, first Epic/Legendary, each Rebirth, first Epic Catalyst, first rank-3 |")
w("| **BuildDecisions** | Charm pick, Charm respec, Resonance pick |")
w("| **Ordinary** | Fuse rank-ups, Attune crafts, pedestal/skill buys, dup mutations, salvage |")
w("| **LongestNewGap** | Longest minutes between UniqueMechanics / FirstMilestones / BuildDecisions |")
w("| **DeadMinutes** | Sum of (gap − 5 min) over gaps between genuinely new objectives |")
w("")
w("## Checkpoints (means, Optimal spend)")
w("")
w("| Min | Epic | U.Epic | Goals | Board | Fuse | Mech | Mile | Build | Ord | GapMax | Dead | Ess | Spent | R# |")
w("|-----|------|--------|-------|-------|------|------|------|-------|-----|--------|------|-----|-------|----|")
for _, m in { 15, 30, 60, 90, 120, 180 } do
	w(
		string.format(
			"| %d | %.1f | %.1f | %.1f/%d | %.1f/%d | %.1f | %.1f | %.1f | %.1f | %.0f | %.1f | %.1f | %.0f | %.0f | %.1f |",
			m,
			avg(m, "EpicExact"),
			avg(m, "UniqueEpicExact"),
			avg(m, "Goals"),
			math.floor(avg(m, "GoalsTotal") + 0.5),
			avg(m, "FusedRelics"),
			math.floor(avg(m, "BoardSlots") + 0.5),
			avg(m, "FusionRanks"),
			avg(m, "UniqueMechanics"),
			avg(m, "FirstMilestones"),
			avg(m, "BuildDecisions"),
			avg(m, "Ordinary"),
			avg(m, "LongestNewGapMin"),
			avg(m, "DeadMinutes"),
			avg(m, "Essence"),
			avg(m, "EssenceSpent"),
			avg(m, "Rebirths")
		)
	)
end
w("")
w(
	string.format(
		"Luck @180: **%s** · Catalysts: **%.1f** · Resonance picks: **%.1f** · Charm changes: **%.1f**",
		Format.number(avg(180, "Luck")),
		avg(180, "EpicCatalysts"),
		avg(180, "ResonancePicks"),
		avg(180, "CharmChanges")
	)
)
w("")
w("## Essence economy (Optimal bot @180m, means)")
w("")
w("| Sink | Essence spent | Role |")
w("|------|---------------|------|")
w(string.format("| Fusion ranks | **%.0f** | Board specialization (primary early sink) |", spendAvg("Fusion")))
w(string.format("| Epic Catalyst | **%.0f** | Dup Epic → board access |", spendAvg("Catalyst")))
w(string.format("| Attune tickets | **%.0f** | Repeatable Codex soft-lock |", spendAvg("AttuneTicket")))
w(string.format("| Targeted Attune | **%.0f** | Tier Focus bursts |", spendAvg("TargetedAttune")))
w(string.format("| Mutation Focus | **%.0f** | Post-25 unique mutated craft |", spendAvg("MutationFocus")))
w(string.format("| Family Attune | **%.0f** | Frequency family bias |", spendAvg("FamilyAttune")))
w(string.format("| Charm respec | **%.0f** | Build change |", spendAvg("CharmRespec")))
w(string.format("| Attune cap upgrade | **%.0f** | Permanent charge capacity |", spendAvg("CapUpgrade")))
w(string.format("| **Total spent** | **%.0f** | Bank left ≈ **%.0f** |", avg(180, "EssenceSpent"), avg(180, "Essence")))
w("")
w("### Suboptimal spend (same dens, alt policies)")
w("")
w("| Policy | Bank @180 | Spent | Goals | Notes |")
w("|--------|-----------|-------|-------|-------|")
w(
	string.format(
		"| Optimal | %.0f | %.0f | %.1f | Uses all unlocked sinks |",
		avg(180, "Essence"),
		avg(180, "EssenceSpent"),
		avg(180, "Goals")
	)
)
w(
	string.format(
		"| FusionOnly | %.0f | %.0f | %.1f | Fusion + catalysts; skips Attune/Focus loops |",
		altAvg("FusionOnly", "bank"),
		altAvg("FusionOnly", "spent"),
		altAvg("FusionOnly", "goals")
	)
)
w(
	string.format(
		"| Hoard | %.0f | %.0f | %.1f | First fusion only, then banks |",
		altAvg("Hoard", "bank"),
		altAvg("Hoard", "spent"),
		altAvg("Hoard", "goals")
	)
)
w("")
w("A low Optimal bank is not proof of health alone — FusionOnly/Hoard show whether sinks are optional or mandatory. Studio playtest should feel worthwhile Attune/Focus spends, not obligation.")
w("")
w("## Three-hour endgame")
w("")
w("By ~180m Optimal bots often finish **~9/9** launch MutationGoals and fill **5/5** board slots. Remaining in-prototype objectives:")
w("")
w("1. **Resonance stacks ×2–3** — Salvage Focus, Daily Attune, Quick Bind, Free Signal, Mutation Tint, Post-R Attune")
w("2. **Epic Catalyst specialization** — fuse catalyzed Epics; salvage excess dups")
w("3. **Rank-3 fusions** — needs mutated copy of that relic (rare, intentional)")
w("4. **Legendary+ collecting** — soft A+C rarity still the long chase")
w("5. **Charm respec / Family Attune** — build identity changes")
w("")
w("Expansion hooks (config only, not implemented): `CollectionConfig.ExpansionHooks` — LegendaryCatalyst, ResonanceMastery, FusionBranch, VariantCodex, RegionCollection.")
w("")
w("## Collection pacing notes")
w("")
w("- Board starts at **1** slot; milestones / Rebirth open more (max 5).")
w("- Rank recipes: **3 / 5 / 4** copies (rank 3 needs a mutated copy).")
w("- Prior carpet (~21 Charms @15m) fixed via slots + targeted recipes, not Essence cost inflation.")
w("")
w("## Studio playtest checklist")
w("")
w("1. Local only: `BalanceTrials.Active = \"E20k_L12_C17_HR\"` and `CollectionPrototype = true`")
w("2. Open **Collection** panel — confirm Next Goals, Fuse ready, Charm buttons, Attune / Mut Focus")
w("3. First fusion within ~2–5 minutes; Charm choice feels like a decision")
w("4. After Rebirth: Resonance pending; stack unlocks fire Notify")
w("5. Bloodmoon → Epic Catalyst craft → Epic fuse path")
w("6. Revert both flags before any publish. **Do not ship live.**")
w("")
w("## Studio enable")
w("")
w("```lua")
w('BalanceTrials.Active = "E20k_L12_C17_HR"')
w("BalanceTrials.CollectionPrototype = true")
w("```")
w("")
w("```bash")
w("lune run tests/studioProgression 100")
w("```")
w("")

fs.writeFile("docs/STUDIO_PROGRESSION_REPORT.md", table.concat(lines, "\n"))
print("Wrote docs/STUDIO_PROGRESSION_REPORT.md")
print(
	string.format(
		"R1 P50=%s  Mech@180=%.1f Mile@180=%.1f Build@180=%.1f GapMax=%.1f Dead=%.1f EssBank=%.0f",
		if p50(rebirthP50[1]) then string.format("%.1f", p50(rebirthP50[1])) else "—",
		avg(180, "UniqueMechanics"),
		avg(180, "FirstMilestones"),
		avg(180, "BuildDecisions"),
		avg(180, "LongestNewGapMin"),
		avg(180, "DeadMinutes"),
		avg(180, "Essence")
	)
)

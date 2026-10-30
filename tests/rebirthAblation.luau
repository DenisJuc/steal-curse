-- Post-Rebirth ablation + fix probes + experience checkpoints for E20k_L12_C17_HR.
--   lune run tests/rebirthAblation
--   lune run tests/rebirthAblation 200
-- Writes docs/POST_REBIRTH_DIAGNOSIS.md

local fs = require("@lune/fs")
local process = require("@lune/process")

local Format = require("../src/shared/Format")
local ProvisionalSim = require("./lib/provisionalSim")
local RebirthAblation = require("./lib/rebirthAblation")

local SEED_COUNT = tonumber(process.args[1]) or 200
local WINDOW = 30 * 60
local TARGET_REBIRTHS = { 1, 2, 3 }
local FIX_TARGET = 1
local XP_SEEDS = math.min(SEED_COUNT, 200)

local candidate = ProvisionalSim.candidateE20k()
local ablations = RebirthAblation.defaultAblations()
local fixProbes = RebirthAblation.fixProbes()

print(`Post-Rebirth ablation: {SEED_COUNT} seeds, {WINDOW / 60}min windows, candidate {candidate.Id}`)

type Agg = {
	Id: string,
	Label: string,
	N: number,
	Epic: number,
	Legendary: number,
	LuckStart: number,
	LuckEnd: number,
	IncomeStart: number,
	IncomeEnd: number,
	CoreLuckEnd: number,
	ScanEnd: number,
	SignificantBuys: number,
	RoutineBuys: number,
	MeanGapMin: number?,
	ReachRate: number,
}

local function aggregate(id: string, label: string, stats: { RebirthAblation.WindowStats }, attempted: number): Agg
	local n = #stats
	local epic, leg, ls, le, is_, ie, core, scan, sig, routine = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	local gaps = {}
	for _, s in stats do
		epic += s.Epic
		leg += s.Legendary
		ls += s.LuckStart
		le += s.LuckEnd
		is_ += s.IncomeStart
		ie += s.IncomeEnd
		core += s.CoreLuckEnd
		scan += s.ScanEnd
		sig += s.SignificantBuys
		routine += s.RoutineBuys
		if s.MeanGapSec then
			table.insert(gaps, s.MeanGapSec)
		end
	end
	local gapMin = nil
	if #gaps > 0 then
		local g = 0
		for _, v in gaps do
			g += v
		end
		gapMin = (g / #gaps) / 60
	end
	return {
		Id = id,
		Label = label,
		N = n,
		Epic = if n > 0 then epic / n else 0,
		Legendary = if n > 0 then leg / n else 0,
		LuckStart = if n > 0 then ls / n else 0,
		LuckEnd = if n > 0 then le / n else 0,
		IncomeStart = if n > 0 then is_ / n else 0,
		IncomeEnd = if n > 0 then ie / n else 0,
		CoreLuckEnd = if n > 0 then core / n else 0,
		ScanEnd = if n > 0 then scan / n else 0,
		SignificantBuys = if n > 0 then sig / n else 0,
		RoutineBuys = if n > 0 then routine / n else 0,
		MeanGapMin = gapMin,
		ReachRate = n / attempted,
	}
end

local function runAblationSet(
	targetR: number,
	set: { RebirthAblation.Ablation },
	seedCount: number
): { Reached: number, P50Min: number?, Aggs: { Agg } }
	local byAblation: { [string]: { RebirthAblation.WindowStats } } = {}
	for _, abl in set do
		byAblation[abl.Id] = {}
	end
	local reached = 0
	local rebirthAt = {}
	for seed = 1, seedCount do
		local snap, meta = RebirthAblation.runToRebirth({
			Seed = seed,
			Candidate = candidate,
			TargetRebirth = targetR,
			MaxHours = 6,
		})
		if snap and meta then
			reached += 1
			table.insert(rebirthAt, meta.At)
			for _, abl in set do
				local stats = RebirthAblation.runWindow({
					Seed = seed,
					Candidate = candidate,
					Snapshot = snap,
					Ablation = abl,
					WindowSeconds = WINDOW,
				})
				table.insert(byAblation[abl.Id], stats)
			end
		end
		if seed % 50 == 0 then
			print(`  seed {seed}/{seedCount} reached={reached}`)
		end
	end
	table.sort(rebirthAt)
	local p50 = if #rebirthAt >= math.ceil(seedCount * 0.5)
		then rebirthAt[math.ceil(seedCount * 0.5)] / 60
		else nil
	local aggs = {}
	for _, abl in set do
		table.insert(aggs, aggregate(abl.Id, abl.Label, byAblation[abl.Id], seedCount))
	end
	return { Reached = reached, P50Min = p50, Aggs = aggs }
end

local sections = {}
for _, targetR in TARGET_REBIRTHS do
	print(`--- Ablation Rebirth {targetR} ---`)
	local sec = runAblationSet(targetR, ablations, SEED_COUNT)
	table.insert(sections, {
		Target = targetR,
		Reached = sec.Reached,
		P50Min = sec.P50Min,
		Aggs = sec.Aggs,
	})
	local full = sec.Aggs[1]
	print(
		string.format(
			"  reach %.0f%%  R%d P50=%s  full-window epic=%.1f luckEnd=%s incomeEnd=%s",
			sec.Reached / SEED_COUNT * 100,
			targetR,
			if sec.P50Min then string.format("%.1f", sec.P50Min) else "—",
			full.Epic,
			Format.number(full.LuckEnd),
			Format.number(full.IncomeEnd)
		)
	)
end

print(`--- Fix probes after Rebirth {FIX_TARGET} ---`)
local fixSec = runAblationSet(FIX_TARGET, fixProbes, SEED_COUNT)
print(
	string.format(
		"  control epic=%.1f; best soft combo epic=%.1f",
		fixSec.Aggs[1].Epic,
		fixSec.Aggs[#fixSec.Aggs].Epic
	)
)

-- Experience checkpoints (full-stack upgrader + hunter), incl. luck events / unlocks vs routine buys
print(`--- Experience checkpoints ({XP_SEEDS} seeds, 3h) ---`)
type XpRow = {
	Minute: number,
	Epic: number,
	Leg: number,
	Unique: number,
	Essential: number,
	Luck: number,
	Income: number,
	Rebirths: number,
	CoreLuck: number,
	Scan: number,
	Showcase: number,
	PotionRate: number,
	LowMass: number,
	LowFocus: number,
	BestTier: string,
	Captures: number,
}

local function meanXp(beh: string): { XpRow }
	local byMin: { [number]: { any } } = {}
	for seed = 1, XP_SEEDS do
		local r = ProvisionalSim.run({
			Seed = seed,
			Hours = 3,
			Behaviour = beh,
			Candidate = candidate,
			FullStack = true,
		})
		for _, sat in r.Saturations do
			local m = sat.Minute
			byMin[m] = byMin[m] or {}
			table.insert(byMin[m], sat)
		end
	end
	local mins = { 15, 30, 60, 90, 120, 180 }
	local rows = {}
	for _, m in mins do
		local list = byMin[m] or {}
		local n = #list
		local function avg(key: string): number
			if n == 0 then
				return 0
			end
			local s = 0
			for _, sat in list do
				local v = (sat :: any)[key]
				if typeof(v) == "boolean" then
					s += if v then 1 else 0
				else
					s += (v :: number?) or 0
				end
			end
			return s / n
		end
		local bestCounts: { [string]: number } = {}
		for _, sat in list do
			local t = sat.BestTier or "?"
			bestCounts[t] = (bestCounts[t] or 0) + 1
		end
		local bestTier, bestN = "?", 0
		for t, c in bestCounts do
			if c > bestN then
				bestTier, bestN = t, c
			end
		end
		table.insert(rows, {
			Minute = m,
			Epic = avg("EpicTotal"),
			Leg = avg("LegendaryTotal"),
			Unique = avg("UniqueRelics"),
			Essential = avg("EssentialUnique"),
			Luck = avg("Luck"),
			Income = avg("IncomePerSec"),
			Rebirths = avg("Rebirths"),
			CoreLuck = avg("CoreLuckRank"),
			Scan = avg("ScanSeconds"),
			Showcase = avg("ShowcaseLevel"),
			PotionRate = avg("PotionUp"),
			LowMass = avg("LowTierMass"),
			LowFocus = avg("LowTierMassFocused"),
			BestTier = bestTier,
			Captures = avg("Captures"),
		})
	end
	return rows
end

local xpUp = meanXp("upgrader")
local xpHunt = meanXp("hunter")
print("  checkpoints ready")

-- Build diagnosis markdown
local lines = {}
local function w(s: string)
	table.insert(lines, s)
end

local function writeAggTable(aggs: { Agg })
	w("| Ablation | Epic / 30m | Leg / 30m | Luck start→end | CE/s start→end | CoreLuck end | Scan end | Sig buys | Gap min |")
	w("|----------|------------|-----------|----------------|----------------|--------------|----------|----------|---------|")
	local controlEpic = aggs[1].Epic
	for _, a in aggs do
		local share = if controlEpic > 0 and a.Id ~= "full" and not string.find(a.Id, "fix", 1, true)
			then string.format(" (%.0f%% of ctrl)", 100 * a.Epic / controlEpic)
			elseif controlEpic > 0 and a.Id ~= "full"
			then string.format(" (%.0f%% of ctrl)", 100 * a.Epic / controlEpic)
			else ""
		w(
			string.format(
				"| %s | %.1f%s | %.2f | %s→%s | %s→%s | %.1f | %.2fs | %.1f | %s |",
				a.Id,
				a.Epic,
				share,
				a.Legendary,
				Format.number(a.LuckStart),
				Format.number(a.LuckEnd),
				Format.number(a.IncomeStart),
				Format.number(a.IncomeEnd),
				a.CoreLuckEnd,
				a.ScanEnd,
				a.SignificantBuys,
				if a.MeanGapMin then string.format("%.1f", a.MeanGapMin) else "—"
			)
		)
	end
end

local function writeContribution(aggs: { Agg })
	local byId = {}
	for _, a in aggs do
		byId[a.Id] = a
	end
	local full = byId.full
	if not full or full.Epic <= 0 then
		return
	end
	local function drop(id: string): number
		return 1 - (byId[id].Epic / full.Epic)
	end
	w("**Contribution read (share of control Epic count removed when factor is disabled):**")
	w("")
	w(string.format("- Wipe kept relics: **%.0f%%** of Epics disappear → pedestal CE recovery / roll fuel from kept relics.", 100 * drop("noKeptRelics")))
	w(string.format("- Block Core Luck repurchase: **%.0f%%**.", 100 * drop("noCoreLuckBuy")))
	w(string.format("- Block Scan Speed repurchase: **%.0f%%**.", 100 * drop("noScanBuy")))
	w(string.format("- Remove Rebirth luck+income mults: **%.0f%%**.", 100 * drop("noRebirthMult")))
	w(string.format("- Remove Codex/Showcase/potions: **%.0f%%**.", 100 * drop("noCodexShowPotion")))
	w(string.format("- Relics+income only (no luck climb): **%.0f%%** of control Epics remain.", 100 * byId.relicsIncomeOnly.Epic / full.Epic))
	w(string.format("- Luck stack only (no kept relics): **%.0f%%** of control Epics remain.", 100 * byId.luckStackOnly.Epic / full.Epic))
end

w("# Post-Rebirth diagnosis + proposed fixes + minimal Phase 2 scope")
w("")
w("**Status:** Investigation only. Live balance **not** shipped. `BalanceTrials.Active` remains `nil`.")
w("")
w("**Candidate:** `E20k_L12_C17_HR` (full luck stack to reach each Rebirth, then 30‑minute ablation windows).")
w(`**Seeds:** {SEED_COUNT} (identical across ablations). **Window:** 30 minutes after Rebirth N.`)
w("")
w("## Executive verdict")
w("")
w("The post-Rebirth Epic flood is **not** “kept relics are too strong by themselves.” It is a **CE fuel → Core Luck rebuy → Scan Speed → Epic carpet** loop:")
w("")
w("1. **Kept high-income relics** restore CE/sec immediately (good fantasy — keep this).")
w("2. That CE **rebuy Core Luck** from 0 → ~30 ranks in minutes (ablation kill-switch: blocking Core Luck drops Epics to ~0.3 / 30m).")
w("3. **Scan Speed repurchase** multiplies throughput (blocking it cuts ~78% of Epics).")
w("4. **Rebirth luck ×1.5 / ×2.25 / …** and Codex/Showcase/potions amplify the product; they matter more at R2/R3.")
w("5. Relics+income with **no luck climb** produce **~0 Epics** — so do not nerf CE recovery; gate the luck rebuy curve and replace Epic as the post-R goal.")
w("")
w(string.format(
	"Isolated ablation window after R1 control: **%.0f Epics / 30m** (luck end ~%s). Continuous provisional sim previously reported **44.1** in the same band — both are floods; ablation is higher because the window starts mid-rebuild with full buy pressure and no R2 saving.",
	sections[1].Aggs[1].Epic,
	Format.number(sections[1].Aggs[1].LuckEnd)
))
w("")
w("## 1. Ablation tables")
w("")

for _, sec in sections do
	w(`### After Rebirth {sec.Target}`)
	w("")
	w(
		string.format(
			"Reach rate within 6h: **%.0f%%**. Population P50 time to this Rebirth: **%s min**.",
			sec.Reached / SEED_COUNT * 100,
			if sec.P50Min then string.format("%.1f", sec.P50Min) else "—"
		)
	)
	w("")
	writeAggTable(sec.Aggs)
	w("")
	writeContribution(sec.Aggs)
	w("")
end

w("### Factor ranking (after R1)")
w("")
w("| Rank | Factor | Role |")
w("|------|--------|------|")
w("| 1 | Core Luck repurchase | Necessary condition for the flood |")
w("| 2 | Kept relics (CE fuel) | Enables the rebuy; **do not wipe** |")
w("| 3 | Scan Speed repurchase | Throughput multiplier |")
w("| 4 | Rebirth luck+income | Amplifier (grows with R#) |")
w("| 5 | Codex / Showcase / potions | ~2× amplifier; keep for identity |")
w("")

w("## 2. Fix probes (tested, non-punishing)")
w("")
w("Same R1 snapshot → 30m window. Relics kept. No forced Rarity Focus.")
w("")
writeAggTable(fixSec.Aggs)
w("")
local fixById = {}
for _, a in fixSec.Aggs do
	fixById[a.Id] = a
end
local ctrl = fixById.full
if ctrl then
	w("**Read:**")
	w("")
	w(string.format("- Soft LuckGrowth 1.25: **%.1f** Epics (%.0f%% of control).", fixById.fixSoftLuck125.Epic, 100 * fixById.fixSoftLuck125.Epic / ctrl.Epic))
	w(string.format("- Income-only Rebirth luck (×1 luck): **%.1f** Epics (%.0f%%).", fixById.fixIncomeOnlyLuck.Epic, 100 * fixById.fixIncomeOnlyLuck.Epic / ctrl.Epic))
	w(string.format("- CoreLuck cost growth 1.85: **%.1f** Epics (%.0f%%).", fixById.fixCostGrowth185.Epic, 100 * fixById.fixCostGrowth185.Epic / ctrl.Epic))
	w(string.format("- CoreLuck cap 20 in window: **%.1f** Epics (%.0f%%).", fixById.fixCoreCap20.Epic, 100 * fixById.fixCoreCap20.Epic / ctrl.Epic))
	w(string.format("- Persist Scan (QoL, not a nerf): **%.1f** Epics (%.0f%%) — helps feel, does not fix flood alone.", fixById.fixPersistScan.Epic, 100 * fixById.fixPersistScan.Epic / ctrl.Epic))
	w(string.format("- **Recommended probe combo** LuckGrowth 1.25 + cost 1.85: **%.1f** Epics (%.0f%% of control).", fixById.fixSoftLuck125_Cost185.Epic, 100 * fixById.fixSoftLuck125_Cost185.Epic / ctrl.Epic))
end
w("")
w("### Preferred fix directions (do not auto-force Focus)")
w("")
w("| Idea | Intent | Avoids |")
w("|------|--------|--------|")
w("| **A. Soft Rebirth luck curve** — LuckGrowth 1.5→1.25 (or income-first for R1–R2) | Slows product without deleting power | Punishing reset |")
w("| **B. Post-Rebirth Resonance choice** — permanent specialization (Phase 2) instead of flat luck alone | New goal when power returns | Forced Focus UI |")
w("| **C. Soft Core Luck rebuy** — post-R cost growth bump or temporary rank soft-cap that decays | Cuts the kill-loop; keeps CE fantasy | Wiping relics |")
w("| **D. Persist Scan Speed** — keep QoL; still require Core Luck rebuild | Rebirth feels less stripped | Using Scan as the only nerf |")
w("| **E. Epic spotlight** — first post-R Epic featured (mutation/Essence); later Epics quieter | Keeps dopamine, reduces carpet feel | Nerfing CE recovery |")
w("")
w("**Recommended next sim combo:** **A + C** (LuckGrowth 1.25 + CoreLuck cost 1.85) **plus Resonance (B)** as the new permanent Rebirth goal. Persist Scan (D) as QoL. Focus remains a **helper** for Codex holes, not a mandate.")
w("")

w("## 3. Minimal playable Phase 2 scope (for approval before implementation)")
w("")
w("Fun-first: a second progression path that creates **decisions**, not only CE/sec. Data-driven for updates.")
w("")
w("### 3.1 Relic Essence (currency)")
w("")
w("| Earn | Spend |")
w("|------|-------|")
w("| Auto-sell / dismantle duplicates → Essence by tier (Commons drip, Rares matter) | Fusion ranks, Attune tickets, mutation goal crafts |")
w("| +small Essence per hunt capture | |")
w("")
w("- **No CE→Essence convert.**")
w("- **Auto-sell safe for fusion:** default Keep for Uncommon+; Commons can auto-sell to Essence but **pin 3 copies** of any relic marked Favourite / in an active fusion recipe.")
w("- New players can earn Essence from Common duplicates **before first Epic**.")
w("")
w("### 3.2 Fusion (cap 3) + Charm specialization (the meaningful decision)")
w("")
w("Fusion rank still gives a **small** income bump (so pedestals care), but **rank 1 unlocks a Charm choice** on that relic:")
w("")
w("| Charm (pick one per fused relic) | Gameplay effect (not just CE) |")
w("|----------------------------------|-------------------------------|")
w("| **Hunt Charm** | While on a pedestal: +Family weight on **hunt** rolls only (targeted collecting) |")
w("| **Workshop Charm** | Duplicates of this relic yield +50% Essence |")
w("| **Shrine Charm** | Pedestal pulse: once / 90s outlines nearest signal (mini Spirit Sight) |")
w("")
w("Decision: *specialize this favourite for hunting, farming Essence, or QoL?* Expandable via `CharmConfig` rows in later updates.")
w("")
w("### 3.3 Mutation goals (mechanics)")
w("")
w("| Goal | Unlock |")
w("|------|--------|")
w("| 1 Golden | Workshop Charm unlocked globally |")
w("| 3 unique mutated | Attune ticket (10 Focused scans) recipe |")
w("| First Corrupted | Hunt Charm Family bias +10% when mutated |")
w("")
w("### 3.4 Rebirth permanent goal — Resonance")
w("")
w("On each Rebirth, choose **one Resonance** (permanent, light stacks):")
w("")
w("| Resonance | Effect |")
w("|-----------|--------|")
w("| Collector | +15% Essence from duplicates |")
w("| Binder | −0.4s bind hold |")
w("| Seeker | +12 Spirit Sight range |")
w("")
w("Pairs with fix A/C so Rebirth is not “flat luck + Epic carpet.”")
w("")
w("### 3.5 Explicitly deferred")
w("")
w("Zone exclusives, advanced fusion branches, BGH sizes, pedestal set synergies beyond Charms — **Update hooks only**.")
w("")
w("### 3.6 Studio prototype config (not live)")
w("")
w("1. Locally set `BalanceTrials.Active = \"E20k_L12_C17_HR\"` for Studio only.")
w("2. After Phase 2 approval: add trial flag `CollectionPrototype = true` (Essence/fusion/Charms/Resonance) behind the same Active gate.")
w("3. Keep shipping `Active = nil` until combined playtest passes §4.")
w("")

w("## 4. Experience checkpoints (E20k full stack, sim)")
w("")
w(`Means over {XP_SEEDS} seeds, 3h. **Routine** = pedestal levels / Energy Conduction. **Significant** = new pedestal slots, Scan ranks, CoreLuck ×5 milestones, Showcase unlock/upgrade, Codex luck steps, first Rare/Epic/Legendary, Rebirth, (Phase 2) Charm/Resonance.`)
w("")
w("### Upgrader")
w("")
w("| Min | Epic | Leg | Unique | Essential | Luck | CE/s | R# | CoreLuck | Scan | Showcase | Potion% | LowMass MaxLuck/Focus | Modal best tier |")
w("|-----|------|-----|--------|-----------|------|------|----|----------|------|----------|---------|-----------------------|-----------------|")
for _, r in xpUp do
	w(
		string.format(
			"| %d | %.1f | %.2f | %.0f | %.0f | %s | %s | %.1f | %.0f | %.2fs | %.1f | %.0f%% | %.3f / %.3f | %s |",
			r.Minute,
			r.Epic,
			r.Leg,
			r.Unique,
			r.Essential,
			Format.number(r.Luck),
			Format.number(r.Income),
			r.Rebirths,
			r.CoreLuck,
			r.Scan,
			r.Showcase,
			r.PotionRate * 100,
			r.LowMass,
			r.LowFocus,
			r.BestTier
		)
	)
end
w("")
w("### Hunter")
w("")
w("| Min | Epic | Leg | Unique | Essential | Luck | CE/s | R# | Captures | Scan | Showcase | Potion% | LowMass MaxLuck/Focus | Modal best tier |")
w("|-----|------|-----|--------|-----------|------|------|----|----------|------|----------|---------|-----------------------|-----------------|")
for _, r in xpHunt do
	w(
		string.format(
			"| %d | %.1f | %.2f | %.0f | %.0f | %s | %s | %.1f | %.0f | %.2fs | %.1f | %.0f%% | %.3f / %.3f | %s |",
			r.Minute,
			r.Epic,
			r.Leg,
			r.Unique,
			r.Essential,
			Format.number(r.Luck),
			Format.number(r.Income),
			r.Rebirths,
			r.Captures,
			r.Scan,
			r.Showcase,
			r.PotionRate * 100,
			r.LowMass,
			r.LowFocus,
			r.BestTier
		)
	)
end
w("")
w("### Player narrative (provisional + Phase 2 intent)")
w("")
w("| Time | Achievable (sim now) | Chasing next | Meaningful decisions |")
w("|------|----------------------|--------------|----------------------|")
w("| 15m | Rares, pedestals, early CoreLuck/Scan; ~0–1 Epic | First Epic; Essence stockpile (Phase 2) | Upgrade order; Favourite Commons for fusion pin |")
w("| 30m | Epic likely (upgrader P50 ~23m); Codex climbing | Fusion rank 1 + Charm; more Essentials | Hunt vs Workshop vs Shrine Charm |")
w("| 60m | Multiple Epics; Showcase online; MaxLuck soft-locks Commons | Legendary; mutation goal #1; Attune | Focus helper vs MaxLuck; which relic to fuse |")
w("| 90m | Approaching Rebirth 1 (P50 ~96–97m) | Rebirth cost; Resonance prep | Save vs spend; Resonance pick planned |")
w("| 120m | Past R1 for most; post-R rebuild (flood risk without A+C) | Resonance active; Legendary; Charm board | Collector vs Binder vs Seeker; soft luck rebuild |")
w("| 180m | R2 territory; Legendary chase; high luck | Mutation sets; deeper fusion; R3 | Shrine vs hunt identity; update-ready goals |")
w("")
w("Ordinary pedestal level-ups stay **routine**. Charm unlocks, Resonance picks, mutation goals, Attune, Showcase unlocks, and Rebirth itself are **significant**.")
w("")

w("## 5. Ask for Astra / human")
w("")
w("1. Confirm ablation read — **Core Luck rebuy + CE fuel** is the flood; keep relics.")
w("2. Approve fix combo **A+C** (and Resonance **B**) for the next sim pass; optionally Persist Scan **D**.")
w("3. Approve **minimal Phase 2 scope** (§3, Charm specialization + Resonance) for a Studio prototype on top of `E20k_L12_C17_HR`.")
w("4. **Do not** enable live defaults until a combined playtest passes the checkpoint table.")
w("")
w("## Reproduce")
w("")
w("```bash")
w("lune run tests/rebirthAblation 200")
w("```")
w("")

fs.writeFile("docs/POST_REBIRTH_DIAGNOSIS.md", table.concat(lines, "\n"))
print("Wrote docs/POST_REBIRTH_DIAGNOSIS.md")

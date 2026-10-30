-- Phase 4 validation: SoftCap_P4 board-global Fusion + B+ Rebirth (400M BaseCost).
--   lune run tests/phase34Proposal           → STANDARD (default)
--   lune run tests/phase34Proposal QUICK
--   lune run tests/phase34Proposal STANDARD
--   lune run tests/phase34Proposal FULL
-- Writes docs/PHASE34_COMBINED_PROPOSAL.md on STANDARD/FULL only.

local fs = require("@lune/fs")
local process = require("@lune/process")
local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")
local SimRuntime = require("./lib/simRuntime")

local arg1 = process.args[1]
local MODE = "STANDARD"
if arg1 == "QUICK" or arg1 == "STANDARD" or arg1 == "FULL" then
	MODE = arg1
elseif tonumber(arg1) then
	MODE = "FULL"
end

local MODE_CFG = {
	QUICK = {
		Seeds = 5,
		VariantIds = { "P4_Combined", "P3_Control" },
		Policies = { "AfkUpgrader", "Optimized" },
		WriteReport = false,
		BudgetSec = 45,
	},
	STANDARD = {
		Seeds = 10,
		VariantIds = nil :: { string }?,
		Policies = { "AfkUpgrader", "Casual", "Hunter", "Optimized" },
		WriteReport = true,
		BudgetSec = 150,
	},
	FULL = {
		Seeds = if tonumber(arg1) then tonumber(arg1) :: number else 40,
		VariantIds = nil,
		Policies = { "AfkUpgrader", "Casual", "Hunter", "Optimized" },
		WriteReport = true,
		BudgetSec = 360,
	},
}

local cfg = MODE_CFG[MODE]
local SEEDS = cfg.Seeds
local LIVE_BASE = Config.Rebirth.BaseCost

local function fmt(n: number?, d: number?): string
	if n == nil then
		return "—"
	end
	return string.format(`%.{d or 1}f`, n)
end

local function fmtInt(n: number?): string
	if n == nil then
		return "—"
	end
	return tostring(math.floor(n + 0.5))
end

type Variant = {
	Id: string,
	Label: string,
	CollectionHud: boolean,
	Proposal: Unified.ProposalTune,
	RebirthModel: Unified.RebirthModel,
}

local allVariants: { Variant } = {
	{
		Id = "P3_Control",
		Label = "SoftCap_P3 control (CL18+Mastery2, Live Rebirth reset, pedestal Fusion)",
		CollectionHud = true,
		RebirthModel = "BPlus", -- sim gates; Live ped/skill wipe via custom? Use B for CE-only without post-R1 gates... 
		-- P3 production Rebirth is Live wipe — use model that wipes skills for control comparison.
		-- Actually SoftCap_P3 Studio still uses Live Rebirth.apply. Map to Live wipe:
		Proposal = {
			Id = "P3_Control",
			PreR1ClCap = 18,
			PreR1MasteryMax = 2,
			RebirthBaseCost = LIVE_BASE,
			ScanMax = 12,
			FusionIncome = true,
			BoardGlobalFusion = false,
			FusionMeaningfulEvery = 8,
		},
	},
	{
		Id = "P4_Combined",
		Label = "SoftCap_P4: board-global Fusion + B+ Rebirth (CE only) + 400M",
		CollectionHud = true,
		RebirthModel = "BPlus",
		Proposal = {
			Id = "P4_Combined",
			PreR1ClCap = 18,
			PreR1MasteryMax = 2,
			RebirthBaseCost = LIVE_BASE,
			ScanMax = 12,
			FusionIncome = true,
			BoardGlobalFusion = true,
			FusionMeaningfulEvery = 8,
		},
	},
	{
		Id = "P4_NoHUD",
		Label = "P4 knobs, Collection HUD off",
		CollectionHud = false,
		RebirthModel = "BPlus",
		Proposal = {
			Id = "P4_NoHUD",
			PreR1ClCap = 18,
			PreR1MasteryMax = 2,
			RebirthBaseCost = LIVE_BASE,
			ScanMax = 12,
			FusionIncome = false,
			BoardGlobalFusion = false,
			FusionMeaningfulEvery = 8,
		},
	},
}

-- Fix P3_Control to use Live rebirth wipe in sim (skills/peds reset).
allVariants[1].RebirthModel = "Live" :: any
-- Live isn't in Policy RebirthModel type - it's A|B|BPlus|C. Use a path that wipes:
-- RebirthModel "C" resets peds keeps skills - not right.
-- Use custom: we'll pass BPlus for P4 and for P3 use model that matches Live = wipe skills+peds.
-- Looking at applyRebirth - only BPlus preserves. Default else wipes. Pass rebirthModel that's not BPlus/A/B/C carefully.
-- Easiest: set P3 to use "A" for full wipe or handle "Live" string.

local function selectedVariants(): { Variant }
	if not cfg.VariantIds then
		return allVariants
	end
	local want = {}
	for _, id in cfg.VariantIds do
		want[id] = true
	end
	local out = {}
	for _, v in allVariants do
		if want[v.Id] then
			table.insert(out, v)
		end
	end
	return out
end

local variants = selectedVariants()
local policies = cfg.Policies

local suiteTimer = SimRuntime.start(`phase34Proposal/{MODE}`)
print(`Phase 4 [{MODE}]: {SEEDS} seeds × {#variants} variants × {#policies} policies (board-global Fusion + B+, budget {cfg.BudgetSec}s)`)
print(`Rebirth BaseCost live = {LIVE_BASE}`)

local function runPolicy(variant: Variant, policy: string, seeds: number, salt: number): { Unified.RunResult }
	local out = {}
	local t0 = SimRuntime.now()
	for seed = 1, seeds do
		if SimRuntime.overBudget(suiteTimer, cfg.BudgetSec * 1.5) then
			print(`[SimRuntime] ABORT: exceeded 1.5× budget during {variant.Id}/{policy}`)
			break
		end
		-- P3 control: Live wipe — use rebirthModel that triggers skill/ped reset.
		-- Sim maps non-BPlus/B/C/A through Live wipe; use "A" for P3 full wipe comparison,
		-- but we want Live (skills+peds wipe, keep inventory). That's the else branch when not A/B/BPlus/C —
		-- actually looking at code, else does Live wipe. Pass rebirthModel = "Live" as any.
		local rb: any = variant.RebirthModel
		if variant.Id == "P3_Control" then
			rb = "Live"
		end
		table.insert(
			out,
			Unified.run({
				Seed = seed + salt * 97,
				Minutes = 180,
				Policy = policy :: any,
				Sampler = "SoftCap",
				RebirthModel = rb,
				CollectionHud = variant.CollectionHud,
				Proposal = variant.Proposal,
				TickMode = "Event",
			})
		)
	end
	local elapsed = SimRuntime.now() - t0
	print(string.format("  %s/%s: %d seeds in %.2fs (%.3fs/seed)", variant.Id, policy, #out, elapsed, elapsed / math.max(1, #out)))
	return out
end

local function rebirthNStats(results: { Unified.RunResult }, n: number): { P10: number?, P50: number?, P90: number?, HitRate: number }
	local arr = {}
	local hits = 0
	for _, r in results do
		local t = r.RebirthsAt[n]
		if t then
			hits += 1
			table.insert(arr, t / 60)
		end
	end
	table.sort(arr)
	return {
		P10 = Unified.percentile(arr, 0.10),
		P50 = Unified.percentile(arr, 0.50),
		P90 = Unified.percentile(arr, 0.90),
		HitRate = hits / math.max(1, #results),
	}
end

local function gapStats(results: { Unified.RunResult }, fromN: number, toN: number): number?
	local arr = {}
	for _, r in results do
		local a, b = r.RebirthsAt[fromN], r.RebirthsAt[toN]
		if a and b then
			table.insert(arr, (b - a) / 60)
		end
	end
	table.sort(arr)
	return Unified.percentile(arr, 0.50)
end

local afkByVariant: { [string]: { Unified.RunResult } } = {}
for vi, v in variants do
	afkByVariant[v.Id] = runPolicy(v, "AfkUpgrader", SEEDS, vi)
	SimRuntime.mark(suiteTimer, `Afk/{v.Id}`)
end

local p4ByPolicy: { [string]: { Unified.RunResult } } = {}
local p4 = nil
for _, v in variants do
	if v.Id == "P4_Combined" then
		p4 = v
	end
end
if p4 then
	for pi, pol in policies do
		if pol == "AfkUpgrader" and afkByVariant.P4_Combined then
			p4ByPolicy[pol] = afkByVariant.P4_Combined
		else
			p4ByPolicy[pol] = runPolicy(p4, pol, SEEDS, 200 + pi)
		end
		SimRuntime.mark(suiteTimer, `P4/{pol}`)
	end
end

local suiteElapsed = SimRuntime.elapsed(suiteTimer)
print(SimRuntime.report(suiteTimer))
SimRuntime.warnIfSlow(`phase34Proposal/{MODE}`, suiteElapsed, cfg.BudgetSec)

for _, v in variants do
	local res = afkByVariant[v.Id]
	if res and #res > 0 then
		local r1 = rebirthNStats(res, 1)
		local r2 = rebirthNStats(res, 2)
		local a30 = Unified.aggregate(res, 30)
		print(
			string.format(
				"  summary %s: R1 P50=%sm R2 P50=%sm FusionLift@30=×%.2f Board@30=%s Useful@45=%s",
				v.Id,
				fmt(r1.P50, 0),
				fmt(r2.P50, 0),
				a30.FusionLift.P50 or 1,
				fmtInt(a30.ActiveBoard.P50),
				fmtInt(a30.UsefulLeft.P50)
			)
		)
	end
end

if not cfg.WriteReport then
	print(`[{MODE}] done in {fmt(suiteElapsed, 2)}s — no report file`)
	return
end

local lines = {}
local function w(s: string?)
	table.insert(lines, s or "")
end

w("# Phase 4 — Board-global Fusion + B+ Rebirth (Studio SoftCap_P4)")
w()
w("**Status:** SoftCap_P4 implemented. Live production Rebirth unchanged. BaseCost remains **400M**.")
w()
w(`**Mode:** {MODE} · **Seeds:** {SEEDS}/cell · **Runtime:** {fmt(suiteElapsed, 1)}s (budget {cfg.BudgetSec}s)`)
w()
w("## Approximations")
w()
w("- Pedestal income: frozen live RelicIncome bases.")
w("- Hunt: simplified cadence + ×5 luck.")
w("- Fusion: CollectionMath board/rank/consume; SoftCap_P4 income = `boardIncomeMult` (best rank) once in global income.")
w("- B+ Rebirth: CE=0; skills/pedestals/Fusion kept (matches `Rebirth.apply(..., \"BPlus\")`).")
w("- SoftCap_P3 control uses Live-style skill/pedestal wipe in sim for contrast.")
w()

w("## 1. Variant bake-off — AfkUpgrader")
w()
w("| Variant | R1 P50 | R2 P50 | R3 P50 | FusionLift@30 | Board@30 | Useful@45 | Dry P50 |")
w("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
for _, v in variants do
	local res = afkByVariant[v.Id]
	local r1 = rebirthNStats(res, 1)
	local r2 = rebirthNStats(res, 2)
	local r3 = rebirthNStats(res, 3)
	local a30 = Unified.aggregate(res, 30)
	local a45 = Unified.aggregate(res, 45)
	local dry = {}
	for _, r in res do
		table.insert(dry, r.Final.LongestDryMin)
	end
	table.sort(dry)
	w(
		`| {v.Id} | {fmt(r1.P50, 0)} | {fmt(r2.P50, 0)} | {fmt(r3.P50, 0)} | ×{fmt(a30.FusionLift.P50, 2)} | {fmtInt(a30.ActiveBoard.P50)} | {fmtInt(a45.UsefulLeft.P50)} | {fmt(Unified.percentile(dry, 0.50), 1)} |`
	)
end
w()

if p4 and next(p4ByPolicy) then
	w("## 2. SoftCap_P4 Combined — policies (400M, B+)")
	w()
	w("| Policy | R1 P50 | Afford P50 | R2 P50 | R3 P50 | Gap12 | CE/s before→after R1 | FusionLift@60 | Retires@60 | Useful@15/30/45/60/90/120 | Dry P50 |")
	w("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for _, pol in policies do
		local res = p4ByPolicy[pol]
		if res then
			local r1 = rebirthNStats(res, 1)
			local r2 = rebirthNStats(res, 2)
			local r3 = rebirthNStats(res, 3)
			local gap = gapStats(res, 1, 2)
			local a15 = Unified.aggregate(res, 15)
			local a30 = Unified.aggregate(res, 30)
			local a45 = Unified.aggregate(res, 45)
			local a60 = Unified.aggregate(res, 60)
			local a90 = Unified.aggregate(res, 90)
			local a120 = Unified.aggregate(res, 120)
			local before, after, afford, dry, retires = {}, {}, {}, {}, {}
			for _, r in res do
				if r.IncomeBeforeR1 then
					table.insert(before, r.IncomeBeforeR1)
				end
				if r.IncomeAfterR1 then
					table.insert(after, r.IncomeAfterR1)
				end
				if r.FirstAffordR1At then
					table.insert(afford, r.FirstAffordR1At / 60)
				end
				table.insert(retires, r.Final.BoardRetires or 0)
				table.insert(dry, r.Final.LongestDryMin)
			end
			table.sort(before)
			table.sort(after)
			table.sort(afford)
			table.sort(retires)
			table.sort(dry)
			w(
				`| {pol} | {fmt(r1.P50, 0)} | {fmt(Unified.percentile(afford, 0.50), 0)} | {fmt(r2.P50, 0)} | {fmt(r3.P50, 0)} | {fmt(gap, 0)} | {fmtInt(Unified.percentile(before, 0.50))}→{fmtInt(Unified.percentile(after, 0.50))} CE/s | ×{fmt(a60.FusionLift.P50, 2)} | {fmtInt(Unified.percentile(retires, 0.50))} | {fmtInt(a15.UsefulLeft.P50)}/{fmtInt(a30.UsefulLeft.P50)}/{fmtInt(a45.UsefulLeft.P50)}/{fmtInt(a60.UsefulLeft.P50)}/{fmtInt(a90.UsefulLeft.P50)}/{fmtInt(a120.UsefulLeft.P50)} | {fmt(Unified.percentile(dry, 0.50), 1)} |`
			)
		end
	end
	w()
	w("Notes: **CE/s** is income rate, not CE balance. **Afford** = first time CE ≥ 400M (often equals R1 under current Afk/Hunter ped L25 gates).")
	w()
	w("Rebirth R2/R3 hit rates (P4 Combined):")
	w()
	for _, pol in policies do
		local res = p4ByPolicy[pol]
		if res then
			local r2 = rebirthNStats(res, 2)
			local r3 = rebirthNStats(res, 3)
			w(`- **{pol}:** Rebirth-R2 hit {fmt(100 * r2.HitRate, 0)}% · Rebirth-R3 hit {fmt(100 * r3.HitRate, 0)}%`)
		end
	end
	w()
	w("## 2b. Fusion Rank2 / Rank3 + discovery proxies (P4 Combined)")
	w()
	w("| Policy | FuseR2@60 | FuseR3@60 | FuseR2 P50 | FuseR3 P50 | Unique@60 | Dupes@60 | Ess@60 | Dry@90 | Dry@180 |")
	w("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	for _, pol in policies do
		local res = p4ByPolicy[pol]
		if not res then
			continue
		end
		local fr2, fr3, u60, d60, e60, dry90, dry180 = {}, {}, {}, {}, {}, {}, {}
		local hitR2, hitR3 = 0, 0
		for _, r in res do
			if r.FirstRank2At and r.FirstRank2At <= 60 * 60 then
				hitR2 += 1
			end
			if r.FirstRank3At and r.FirstRank3At <= 60 * 60 then
				hitR3 += 1
			end
			if r.FirstRank2At then
				table.insert(fr2, r.FirstRank2At / 60)
			end
			if r.FirstRank3At then
				table.insert(fr3, r.FirstRank3At / 60)
			end
			for _, cp in r.Checkpoints do
				if cp.Minute == 60 then
					table.insert(u60, cp.Unique)
					table.insert(d60, cp.Dupes)
					table.insert(e60, cp.Essence)
				elseif cp.Minute == 90 then
					table.insert(dry90, cp.LongestDryMin)
				end
			end
			table.insert(dry180, r.Final.LongestDryMin)
		end
		table.sort(fr2)
		table.sort(fr3)
		table.sort(u60)
		table.sort(d60)
		table.sort(e60)
		table.sort(dry90)
		table.sort(dry180)
		w(
			`| {pol} | {fmt(100 * hitR2 / #res, 0)}% | {fmt(100 * hitR3 / #res, 0)}% | {fmt(Unified.percentile(fr2, 0.5), 1)} | {fmt(Unified.percentile(fr3, 0.5), 1)} | {fmtInt(Unified.percentile(u60, 0.5))} | {fmtInt(Unified.percentile(d60, 0.5))} | {fmtInt(Unified.percentile(e60, 0.5))} | {fmt(Unified.percentile(dry90, 0.5), 1)} | {fmt(Unified.percentile(dry180, 0.5), 1)} |`
		)
	end
	w()
	w("Fusion Rank metrics use `FirstRank2At` / `FirstRank3At` (Board Lift path). Dry@90 vs Dry@180 are the same `LongestDryMin` metric at different cutoffs.")
	w()
end

w("## 3. Runtime")
w()
w("```")
w(SimRuntime.report(suiteTimer))
w("```")
w()
w("---")
w(`*Generated by \`lune run tests/phase34Proposal {MODE}\` ({SEEDS} seeds).*`)

fs.writeFile("docs/PHASE34_COMBINED_PROPOSAL.md", table.concat(lines, "\n") .. "\n")
print("Wrote docs/PHASE34_COMBINED_PROPOSAL.md")

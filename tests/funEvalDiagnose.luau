-- Skeptical fun / engagement evaluation from SoftCap_P4 sims (0–180m).
--   lune run tests/funEvalDiagnose
-- Timelines + decision bottlenecks — not "metrics green ⇒ fun".

local Unified = require("./lib/unifiedProgressionSim")
local Config = require("../src/shared/Config")
local Format = require("../src/shared/Format")

local SEEDS = 10
local POLICIES = { "AfkUpgrader", "Casual", "Hunter", "Optimized" }
local CUTS = { 15, 30, 45, 60, 90, 180 }

local proposal = {
	PreR1ClCap = 18,
	PreR1MasteryMax = 2,
	RebirthBaseCost = Config.Rebirth.BaseCost,
	ScanMax = 12,
	FusionIncome = true,
	BoardGlobalFusion = true,
	FusionMeaningfulEvery = 8,
}

local function pct(arr: { number }, p: number): number?
	if #arr == 0 then
		return nil
	end
	local c = table.clone(arr)
	table.sort(c)
	return Unified.percentile(c, p)
end

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
	return string.format("%.0f", n)
end

local function cpAt(r: Unified.RunResult, minute: number): Unified.Checkpoint?
	for _, cp in r.Checkpoints do
		if cp.Minute == minute then
			return cp
		end
	end
	return nil
end

local function narrative(cp: Unified.Checkpoint, r: Unified.RunResult): string
	local bits = {}
	if cp.UsefulBuysLeft <= 0 then
		table.insert(bits, "CE shop EMPTY")
	elseif cp.UsefulBuysLeft <= 2 then
		table.insert(bits, `CE shop thin ({cp.UsefulBuysLeft} left)`)
	else
		table.insert(bits, `buying upgrades ({cp.UsefulBuysLeft} useful left)`)
	end
	if cp.ActiveBoard <= 0 then
		table.insert(bits, "no Board yet")
	else
		table.insert(bits, `Board {cp.ActiveBoard}/{cp.BoardSlots} lift×{string.format("%.2f", cp.FusionLift)}`)
	end
	if cp.Rebirths <= 0 then
		if r.FirstAffordR1At and r.FirstAffordR1At / 60 <= cp.Minute and (r.FirstRebirthAt == nil or r.FirstRebirthAt / 60 > cp.Minute) then
			table.insert(bits, "CE≥400M but not rebirthed yet (gate)")
		elseif r.FirstRebirthAt and r.FirstRebirthAt / 60 <= cp.Minute + 0.01 then
			table.insert(bits, "at/near R1")
		else
			table.insert(bits, "pre-Rebirth grind")
		end
	else
		table.insert(bits, `post-R{cp.Rebirths}`)
	end
	local dupeRatio = if cp.TotalFinds > 0 then cp.Dupes / cp.TotalFinds else 0
	table.insert(bits, string.format("dupes %.0f%% of finds", dupeRatio * 100))
	if cp.EssenceSpent < 50 and cp.Minute >= 30 then
		table.insert(bits, "Essence barely spent")
	elseif cp.Essence > 500 and cp.Minute >= 45 then
		table.insert(bits, `Essence banked {fmtInt(cp.Essence)}`)
	end
	return table.concat(bits, " · ")
end

local function run(seed: number, policy: string)
	return Unified.run({
		Seed = seed,
		Minutes = 180,
		Policy = policy :: any,
		Sampler = "SoftCap",
		RebirthModel = "BPlus",
		CollectionHud = true,
		Proposal = proposal,
		TickMode = "Event",
	})
end

print("=== Fun / engagement diagnose (SoftCap_P4, STANDARD N=10, 0–180m) ===")
print(`BaseCost={Config.Rebirth.BaseCost}  B+ Rebirth  CollectionHud=true`)
print("Approximations: frozen pedestal income, simplified hunt cadence, no UI/visual fun.\n")

type Agg = {
	byCut: { [number]: {
		Useful: { number },
		Board: { number },
		Lift: { number },
		Dupes: { number },
		Unique: { number },
		Finds: { number },
		CE: { number },
		Inc: { number },
		Ess: { number },
		EssSpent: { number },
		Fusions: { number },
		Rebirths: { number },
		Dry: { number },
	} },
	r1: { number },
	r2: { number },
	r3: { number },
	afford: { number },
	golden: { number },
	rank2: { number },
	rank3: { number },
	usefulEmpty: { number },
	dry180: { number },
	blockMut: number,
	blockCopy: number,
	blockEss: number,
}

local aggs: { [string]: Agg } = {}
local seed1: { [string]: Unified.RunResult } = {}

for _, pol in POLICIES do
	local a: Agg = {
		byCut = {},
		r1 = {},
		r2 = {},
		r3 = {},
		afford = {},
		golden = {},
		rank2 = {},
		rank3 = {},
		usefulEmpty = {},
		dry180 = {},
		blockMut = 0,
		blockCopy = 0,
		blockEss = 0,
	}
	for _, m in CUTS do
		a.byCut[m] = {
			Useful = {},
			Board = {},
			Lift = {},
			Dupes = {},
			Unique = {},
			Finds = {},
			CE = {},
			Inc = {},
			Ess = {},
			EssSpent = {},
			Fusions = {},
			Rebirths = {},
			Dry = {},
		}
	end
	for seed = 1, SEEDS do
		local r = run(seed, pol)
		if seed == 1 then
			seed1[pol] = r
		end
		if r.FirstRebirthAt then
			table.insert(a.r1, r.FirstRebirthAt / 60)
		end
		if r.RebirthsAt[2] then
			table.insert(a.r2, r.RebirthsAt[2] / 60)
		end
		if r.RebirthsAt[3] then
			table.insert(a.r3, r.RebirthsAt[3] / 60)
		end
		if r.FirstAffordR1At then
			table.insert(a.afford, r.FirstAffordR1At / 60)
		end
		if r.FirstGoldenAt then
			table.insert(a.golden, r.FirstGoldenAt / 60)
		end
		if r.FirstRank2At then
			table.insert(a.rank2, r.FirstRank2At / 60)
		end
		if r.FirstRank3At then
			table.insert(a.rank3, r.FirstRank3At / 60)
		end
		if r.UsefulEmptyAt then
			table.insert(a.usefulEmpty, r.UsefulEmptyAt / 60)
		end
		table.insert(a.dry180, r.Final.LongestDryMin)
		if r.Rank3Blockers then
			a.blockMut += r.Rank3Blockers.Mutation or 0
			a.blockCopy += r.Rank3Blockers.Copies or 0
			a.blockEss += r.Rank3Blockers.Essence or 0
		end
		for _, m in CUTS do
			local cp = cpAt(r, m)
			if cp then
				local b = a.byCut[m]
				table.insert(b.Useful, cp.UsefulBuysLeft)
				table.insert(b.Board, cp.ActiveBoard)
				table.insert(b.Lift, cp.FusionLift)
				table.insert(b.Dupes, cp.Dupes)
				table.insert(b.Unique, cp.Unique)
				table.insert(b.Finds, cp.TotalFinds)
				table.insert(b.CE, cp.CE)
				table.insert(b.Inc, cp.IncomePerSec)
				table.insert(b.Ess, cp.Essence)
				table.insert(b.EssSpent, cp.EssenceSpent)
				table.insert(b.Fusions, cp.Fusions)
				table.insert(b.Rebirths, cp.Rebirths)
				table.insert(b.Dry, cp.LongestDryMin)
			end
		end
	end
	aggs[pol] = a
end

for _, pol in POLICIES do
	local a = aggs[pol]
	print(`\n######## {pol} ########`)
	print(
		string.format(
			"  Milestones P50: AffordR1=%sm  R1=%sm  R2=%sm  R3=%sm  Golden=%sm  FuseR2=%sm  FuseR3=%sm  UsefulEmpty=%sm  Dry180=%sm",
			fmt(pct(a.afford, 0.5), 1),
			fmt(pct(a.r1, 0.5), 1),
			fmt(pct(a.r2, 0.5), 1),
			fmt(pct(a.r3, 0.5), 1),
			fmt(pct(a.golden, 0.5), 1),
			fmt(pct(a.rank2, 0.5), 1),
			fmt(pct(a.rank3, 0.5), 1),
			fmt(pct(a.usefulEmpty, 0.5), 1),
			fmt(pct(a.dry180, 0.5), 1)
		)
	)
	print(
		string.format(
			"  Rank3 blocker samples (sum over seeds): Mutation=%d Copies=%d Essence=%d",
			a.blockMut,
			a.blockCopy,
			a.blockEss
		)
	)
	print("  Checkpoint P50 timeline:")
	print("    min | Useful | Board | Lift  | Unique | Dupes | Finds | CE       | Inc/s    | Ess | Spent | Fus | R | Dry")
	for _, m in CUTS do
		local b = a.byCut[m]
		local finds = pct(b.Finds, 0.5) or 0
		local dupes = pct(b.Dupes, 0.5) or 0
		local dupePct = if finds > 0 then 100 * dupes / finds else 0
		print(
			string.format(
				"    %3d | %6s | %5s | ×%4s | %6s | %5s (%2.0f%%) | %5s | %8s | %8s | %3s | %5s | %3s | %1s | %4s",
				m,
				fmtInt(pct(b.Useful, 0.5)),
				fmtInt(pct(b.Board, 0.5)),
				fmt(pct(b.Lift, 0.5), 2),
				fmtInt(pct(b.Unique, 0.5)),
				fmtInt(pct(b.Dupes, 0.5)),
				dupePct,
				fmtInt(pct(b.Finds, 0.5)),
				Format.number(pct(b.CE, 0.5) or 0),
				Format.number(pct(b.Inc, 0.5) or 0),
				fmtInt(pct(b.Ess, 0.5)),
				fmtInt(pct(b.EssSpent, 0.5)),
				fmtInt(pct(b.Fusions, 0.5)),
				fmtInt(pct(b.Rebirths, 0.5)),
				fmt(pct(b.Dry, 0.5), 1)
			)
		)
	end

	-- Engagement red flags
	local u45 = pct(a.byCut[45].Useful, 0.5) or 99
	local u60 = pct(a.byCut[60].Useful, 0.5) or 99
	local dry = pct(a.dry180, 0.5) or 0
	local r1 = pct(a.r1, 0.5)
	local r2 = pct(a.r2, 0.5)
	local gap12 = if r1 and r2 then r2 - r1 else nil
	local flags = {}
	if u45 <= 2 and u60 <= 2 then
		table.insert(flags, "THIN_SHOP_45-60")
	end
	if dry >= 20 then
		table.insert(flags, "LONG_DRY≥20m")
	end
	if gap12 and gap12 < 12 then
		table.insert(flags, "FAST_R1→R2_LOOP")
	end
	if gap12 and gap12 > 25 then
		table.insert(flags, "SLOW_R1→R2")
	end
	local d60 = pct(a.byCut[60].Dupes, 0.5) or 0
	local f60 = pct(a.byCut[60].Finds, 0.5) or 1
	if d60 / f60 >= 0.92 then
		table.insert(flags, "DUPE_OVERLOAD≥92%")
	end
	local ess60 = pct(a.byCut[60].Ess, 0.5) or 0
	local spent60 = pct(a.byCut[60].EssSpent, 0.5) or 0
	if ess60 > 2000 and spent60 < ess60 * 0.3 then
		table.insert(flags, "ESSENCE_HOARD")
	end
	print(`  Flags: {if #flags > 0 then table.concat(flags, ", ") else "none"}`)
end

print("\n=== Seed-1 narrative (representative timelines) ===")
for _, pol in POLICIES do
	local r = seed1[pol]
	print(`\n-- {pol} seed1 --`)
	print(
		string.format(
			"  Events: Rare@%s Epic@%s Golden@%s R2fuse@%s R3fuse@%s R1@%s R2@%s R3@%s UsefulEmpty@%s",
			if r.FirstRareAt then fmt(r.FirstRareAt / 60, 1) else "—",
			if r.FirstEpicAt then fmt(r.FirstEpicAt / 60, 1) else "—",
			if r.FirstGoldenAt then fmt(r.FirstGoldenAt / 60, 1) else "—",
			if r.FirstRank2At then fmt(r.FirstRank2At / 60, 1) else "—",
			if r.FirstRank3At then fmt(r.FirstRank3At / 60, 1) else "—",
			if r.FirstRebirthAt then fmt(r.FirstRebirthAt / 60, 1) else "—",
			if r.RebirthsAt[2] then fmt(r.RebirthsAt[2] / 60, 1) else "—",
			if r.RebirthsAt[3] then fmt(r.RebirthsAt[3] / 60, 1) else "—",
			if r.UsefulEmptyAt then fmt(r.UsefulEmptyAt / 60, 1) else "—"
		)
	)
	if #r.RebirthTrace > 0 then
		for _, t in r.RebirthTrace do
			print(
				string.format(
					"  Rebirth R%d @%.1fm: CE=%s Inc %.0f→%.0f Board=%d Lift=×%.2f UsefulLeft=%d Golden=%s",
					t.Index,
					t.Sec / 60,
					Format.number(t.CeBefore),
					t.IncomeBefore,
					t.IncomeAfter,
					t.Board,
					t.Lift,
					t.UsefulLeft,
					tostring(t.FirstGolden)
				)
			)
		end
	end
	for _, m in CUTS do
		local cp = cpAt(r, m)
		if cp then
			print(string.format("  t=%3dm  %s", m, narrative(cp, r)))
			print(
				string.format(
					"         CE=%s Inc/s=%s Unique=%d Dupes=%d Ess=%d spent=%d Fus=%d",
					Format.number(cp.CE),
					Format.number(cp.IncomePerSec),
					cp.Unique,
					cp.Dupes,
					cp.Essence,
					cp.EssenceSpent,
					cp.Fusions
				)
			)
		end
	end
end

-- Cross-policy: Hunt vs AFK value
print("\n=== AFK vs Hunter (P50 deltas @60 / @180) ===")
local afk = aggs.AfkUpgrader
local hun = aggs.Hunter
for _, m in { 60, 180 } do
	local au, hu = afk.byCut[m], hun.byCut[m]
	print(
		string.format(
			"  @%dm Unique %+s  Dupes %+s  Ess %+s  Inc/s ratio %.2fx  R count %+s  Dry %+sm",
			m,
			fmtInt((pct(hu.Unique, 0.5) or 0) - (pct(au.Unique, 0.5) or 0)),
			fmtInt((pct(hu.Dupes, 0.5) or 0) - (pct(au.Dupes, 0.5) or 0)),
			fmtInt((pct(hu.Ess, 0.5) or 0) - (pct(au.Ess, 0.5) or 0)),
			(pct(hu.Inc, 0.5) or 1) / math.max(1, pct(au.Inc, 0.5) or 1),
			fmtInt((pct(hu.Rebirths, 0.5) or 0) - (pct(au.Rebirths, 0.5) or 0)),
			fmt((pct(hun.dry180, 0.5) or 0) - (pct(afk.dry180, 0.5) or 0), 1)
		)
	)
end
print(
	string.format(
		"  R1 P50: Afk=%sm Hunter=%sm (Hunter faster by %sm)",
		fmt(pct(afk.r1, 0.5), 1),
		fmt(pct(hun.r1, 0.5), 1),
		fmt((pct(afk.r1, 0.5) or 0) - (pct(hun.r1, 0.5) or 0), 1)
	)
)
print(
	string.format(
		"  FuseR3 P50: Afk=%sm Hunter=%sm",
		fmt(pct(afk.rank3, 0.5), 1),
		fmt(pct(hun.rank3, 0.5), 1)
	)
)

print("\n=== Done ===")

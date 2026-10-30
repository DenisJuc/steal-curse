-- Pure export builders for Studio playtest analytics (Lune-safe, no Roblox APIs).

local PlaytestAnalyticsExport = {}

export type PurchaseKind = "Unlock" | "Routine" | "Specialization" | "Failed"

export type Session = {
	SessionId: string,
	StartedAtUnix: number,
	EndedAtUnix: number?,
	DurationSec: number,
	Events: { any },
	Purchases: { any },
	Milestones: { any },
	Snapshots: { any },
	MinuteMarks: { any },
	Activity: { [string]: number },
	ScanAgg: { any },
	Friction: { any },
	Meta: any,
}

local function pad2(n: number): string
	return if n < 10 then `0{n}` else tostring(n)
end

function PlaytestAnalyticsExport.formatElapsed(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	local m = math.floor(s / 60)
	local r = s % 60
	return `{pad2(m)}:{pad2(r)}`
end

-- Pure rarity counters for tests / export friction. epicIndex is RarityConfig.IndexById.Epic.
export type RarityMetrics = {
	EpicExact: number,
	UniqueEpicExact: number,
	EpicPlus: number,
	UniqueEpicPlus: number,
	UniqueCount: number,
	_seen: { [string]: boolean },
	_uniqueEpic: { [string]: boolean },
	_uniqueEpicPlus: { [string]: boolean },
}

function PlaytestAnalyticsExport.newRarityMetrics(): RarityMetrics
	return {
		EpicExact = 0,
		UniqueEpicExact = 0,
		EpicPlus = 0,
		UniqueEpicPlus = 0,
		UniqueCount = 0,
		_seen = {},
		_uniqueEpic = {},
		_uniqueEpicPlus = {},
	}
end

function PlaytestAnalyticsExport.noteDiscovery(
	m: RarityMetrics,
	relicId: string,
	tierIndex: number,
	epicIndex: number,
	firstUnique: boolean
)
	if firstUnique and not m._seen[relicId] then
		m._seen[relicId] = true
		m.UniqueCount += 1
	end
	if tierIndex == epicIndex then
		m.EpicExact += 1
		if not m._uniqueEpic[relicId] then
			m._uniqueEpic[relicId] = true
			m.UniqueEpicExact += 1
		end
	end
	if tierIndex >= epicIndex then
		m.EpicPlus += 1
		if not m._uniqueEpicPlus[relicId] then
			m._uniqueEpicPlus[relicId] = true
			m.UniqueEpicPlus += 1
		end
	end
end

-- Minimal JSON encoder (tables/arrays/strings/numbers/bools/nil).
function PlaytestAnalyticsExport.toJson(value: any): string
	local t = type(value)
	if value == nil then
		return "null"
	elseif t == "boolean" then
		return if value then "true" else "false"
	elseif t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		return tostring(value)
	elseif t == "string" then
		local escaped = string.gsub(value, "[\\\"\b\f\n\r\t]", {
			["\\"] = "\\\\",
			['"'] = '\\"',
			["\b"] = "\\b",
			["\f"] = "\\f",
			["\n"] = "\\n",
			["\r"] = "\\r",
			["\t"] = "\\t",
		})
		return `"{escaped}"`
	elseif t ~= "table" then
		return "null"
	end
	-- Array if contiguous 1..n
	local n = #value
	local isArray = n > 0
	if not isArray then
		for k in value do
			if type(k) ~= "number" then
				isArray = false
				break
			end
		end
		-- empty table → object
		isArray = false
		for k in value do
			if type(k) == "number" and k == 1 then
				isArray = true
			end
			break
		end
		if next(value) == nil then
			isArray = false
		else
			local max = 0
			local count = 0
			for k in value do
				if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
					isArray = false
					max = -1
					break
				end
				count += 1
				if k > max then
					max = k
				end
			end
			if max >= 0 then
				isArray = count == max
			end
		end
	else
		-- verify dense
		for i = 1, n do
			if value[i] == nil then
				isArray = false
				break
			end
		end
	end
	if isArray then
		local parts = table.create(n)
		for i = 1, n do
			parts[i] = PlaytestAnalyticsExport.toJson(value[i])
		end
		return `[{table.concat(parts, ",")}]`
	end
	local parts = {}
	local keys = {}
	for k in value do
		if type(k) == "string" then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	for _, k in keys do
		table.insert(parts, `{PlaytestAnalyticsExport.toJson(k)}:{PlaytestAnalyticsExport.toJson(value[k])}`)
	end
	return `\{{table.concat(parts, ",")}\}`
end

local function csvEscape(s: string): string
	if string.find(s, '[,"\n]') then
		return `"{string.gsub(s, '"', '""')}"`
	end
	return s
end

function PlaytestAnalyticsExport.purchasesCsv(session: Session): string
	local lines = {
		"Elapsed,ElapsedSec,System,Item,RankBefore,RankAfter,Price,Currency,CE_Before,CE_After,Essence_Before,Essence_After,Luck,IncomePerSec,Rebirths,SecSincePrev,Kind,Ok,Reason",
	}
	for _, p in session.Purchases do
		table.insert(
			lines,
			table.concat({
				csvEscape(p.Elapsed or ""),
				tostring(p.ElapsedSec or 0),
				csvEscape(tostring(p.System or "")),
				csvEscape(tostring(p.Item or "")),
				tostring(p.RankBefore or ""),
				tostring(p.RankAfter or ""),
				tostring(p.Price or 0),
				csvEscape(tostring(p.Currency or "CE")),
				tostring(p.CEBefore or 0),
				tostring(p.CEAfter or 0),
				tostring(p.EssenceBefore or 0),
				tostring(p.EssenceAfter or 0),
				tostring(p.Luck or 0),
				tostring(p.IncomePerSec or 0),
				tostring(p.Rebirths or 0),
				tostring(p.SecSincePrev or 0),
				csvEscape(tostring(p.Kind or "")),
				tostring(p.Ok == true),
				csvEscape(tostring(p.Reason or "")),
			}, ",")
		)
	end
	return table.concat(lines, "\n") .. "\n"
end

function PlaytestAnalyticsExport.summaryMarkdown(session: Session): string
	local lines = {}
	local function w(s)
		table.insert(lines, s)
	end
	w("# Playtest session summary")
	w("")
	w(`**SessionId:** {session.SessionId}`)
	w(`**Duration:** {PlaytestAnalyticsExport.formatElapsed(session.DurationSec)} ({math.floor(session.DurationSec)}s)`)
	w(`**Studio-only analytics** — no production tracking.`)
	w("")
	w("## Activity breakdown (observed seconds)")
	w("")
	local act = session.Activity or {}
	local order = { "Scan", "Hunt", "Travel", "UpgradeUI", "CollectionUI", "Pedestal", "Idle", "Other" }
	w("| Category | Seconds | Share |")
	w("|----------|---------|-------|")
	local totalAct = 0
	for _, k in order do
		totalAct += act[k] or 0
	end
	for _, k in order do
		local sec = act[k] or 0
		local share = if totalAct > 0 then string.format("%.1f%%", 100 * sec / totalAct) else "—"
		w(`| {k} | {string.format("%.1f", sec)} | {share} |`)
	end
	w("")
	w("## Chronological purchases")
	w("")
	w("| Time | Item | ΔRank | Price | Kind | CE after | Essence after |")
	w("|------|------|-------|-------|------|----------|---------------|")
	for _, p in session.Purchases do
		if p.Ok then
			w(
				string.format(
					"| %s | %s/%s | %s→%s | %s %s | %s | %s | %s |",
					p.Elapsed or "",
					tostring(p.System or ""),
					tostring(p.Item or ""),
					tostring(p.RankBefore or "-"),
					tostring(p.RankAfter or "-"),
					tostring(p.Price or 0),
					tostring(p.Currency or "CE"),
					tostring(p.Kind or ""),
					tostring(p.CEAfter or 0),
					tostring(p.EssenceAfter or 0)
				)
			)
		end
	end
	w("")
	w("### Failed purchases")
	w("")
	local anyFail = false
	for _, p in session.Purchases do
		if not p.Ok then
			anyFail = true
			w(`- {p.Elapsed}: {p.System}/{p.Item} — {p.Reason or "failed"}`)
		end
	end
	if not anyFail then
		w("- (none)")
	end
	w("")
	w("## Major milestones")
	w("")
	for _, m in session.Milestones do
		w(`- **{m.Elapsed}** — {m.Label}` .. if m.Detail then ` ({m.Detail})` else "")
	end
	if #(session.Milestones or {}) == 0 then
		w("- (none recorded)")
	end
	w("")
	w("## Collection HUD funnel")
	w("")
	local funnelCounts: { [string]: number } = {}
	for _, ev in session.Events or {} do
		if ev.Kind == "CollectionFunnel" and type(ev.Event) == "string" then
			funnelCounts[ev.Event] = (funnelCounts[ev.Event] or 0) + 1
		end
	end
	local funnelOrder = {
		"FusionReady",
		"CollectionOpen",
		"CollectionClose",
		"RecipeInspect",
		"FuseAttempt",
		"FuseComplete",
		"FuseFailed",
		"CharmEquip",
		"CharmFailed",
	}
	local anyFunnel = false
	for _, name in funnelOrder do
		local n = funnelCounts[name]
		if n and n > 0 then
			anyFunnel = true
			w(`- **{name}:** {n}`)
		end
	end
	if not anyFunnel then
		w("- (none — Collection panel unused or not recording)")
	end
	local friction = session.Friction or {}
	if type(friction.CollectionUISec) == "number" then
		w(
			`- **Time in Collection UI:** {string.format("%.1f", friction.CollectionUISec)}s across {tostring(friction.CollectionPanelVisits or 0)} visit(s)`
		)
	end
	if type(friction.CollectionFailedAttempts) == "number" and friction.CollectionFailedAttempts > 0 then
		w(`- **Failed fuse/charm attempts:** {friction.CollectionFailedAttempts}`)
	end
	w("")
	w("## Minute marks (5–30)")
	w("")
	w("| Min | CE | Essence | Luck | CE/s | CoreLuck | Rebirths | Unique | EpicExact | Goals | Fuse |")
	w("|-----|----|---------|------|------|----------|----------|--------|-----------|-------|------|")
	for _, mark in session.MinuteMarks or {} do
		local s = mark.Snapshot or mark
		w(
			string.format(
				"| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |",
				tostring(mark.Minute or s.Minute or ""),
				tostring(s.CE or 0),
				tostring(s.Essence or 0),
				tostring(s.Luck or 0),
				tostring(s.IncomePerSec or 0),
				tostring(s.CoreLuck or 0),
				tostring(s.Rebirths or 0),
				tostring(s.UniqueDiscoveries or 0),
				tostring(s.EpicExact or 0),
				tostring(s.MutationGoals or 0),
				tostring(s.FusionRanks or 0)
			)
		)
	end
	w("")
	w("## Friction observations (facts only)")
	w("")
	local f = session.Friction or {}
	w(`- Longest gap without meaningful unlock: **{string.format("%.1f", f.LongestGapMin or 0)}** min`)
	w(`- Meaningful unlocks: **{f.MeaningfulCount or 0}**`)
	w(`- Routine purchases: **{f.RoutinePurchases or 0}**`)
	w(`- Failed purchases: **{f.FailedPurchases or 0}**`)
	w(`- Exact Epic discoveries / unique Epic IDs: **{f.EpicExact or 0}** / **{f.UniqueEpicExact or 0}**`)
	w(`- Duplicate sells (auto): **{f.DuplicateSells or 0}**`)
	w(`- Features unlocked but unused: {table.concat(f.UnusedUnlocks or { "(none)" }, ", ")}`)
	w(`- Hunt captures vs AFK scan batches: **{f.HuntCaptures or 0}** / **{f.ScanBatches or 0}**`)
	w(`- Essence idle after earn (max gap before spend): **{string.format("%.1f", f.MaxEssenceIdleMin or 0)}** min`)
	w("")
	w("## Inferred notes (separate from observations)")
	w("")
	for _, note in f.Inferences or {} do
		w(`- {note}`)
	end
	if #(f.Inferences or {}) == 0 then
		w("- (none)")
	end
	w("")
	w("## Key findings")
	w("")
	for _, note in f.Findings or {} do
		w(`- {note}`)
	end
	if #(f.Findings or {}) == 0 then
		w("- Review purchase timeline and gaps above.")
	end
	w("")
	return table.concat(lines, "\n")
end

function PlaytestAnalyticsExport.sessionJson(session: Session): string
	return PlaytestAnalyticsExport.toJson(session)
end

return PlaytestAnalyticsExport

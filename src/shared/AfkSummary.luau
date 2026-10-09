-- Welcome Back AFK summary (GDD 9.4): whether an AFK stretch is worth showing, and everything
-- unlocked during it, read from the timestamps the discovery pipeline already saves (Codex
-- discoveries, seen mutations, rare history, ready milestones). Pure, so Lune can test it.

local AfkSummary = {}

export type Log = {
	Active: boolean,
	StartedAt: number,
	ScansAtStart: number,
	Seconds: number,
	CE: number,
	Discoveries: number,
	Sold: number,
	SoldCE: number,
	Hops: number,
}

-- Kind: "Milestone" (ready to claim in the Codex), "Rare" (rare-history find, grouped by relic and
-- mutation), "Relic" (first discovery), "Variant" (first time this mutation of this relic).
-- A rare find that was also a first discovery or new variant is one "Rare" entry flagged New or
-- NewVariant, so nothing is listed twice.
export type Unlock = {
	Kind: string,
	Id: string,
	Mutation: string?,
	Count: number,
	New: boolean,
	NewVariant: boolean,
	Score: number,
}

type Source = {
	Discovered: { [string]: number },
	CodexMutations: { [string]: { [string]: number } },
	CodexReady: { [string]: number },
	RareHistory: { { Id: string, Mutation: string?, At: number } },
}

function AfkSummary.qualifies(log: Log, minSeconds: number): boolean
	return log.Active and log.Seconds >= minSeconds and (log.Discoveries > 0 or log.CE > 0)
end

local KIND_ORDER = { Milestone = 1, Rare = 2, Variant = 3, Relic = 4 }

-- Everything unlocked at or after `since`, best first (milestones, then rarity), at most `max`
-- entries. Returns the list and how many more were left out. tierOf(relicId) -> tier index.
function AfkSummary.unlocks(source: Source, since: number, tierOf: (string) -> number, max: number): ({ Unlock }, number)
	local list: { Unlock } = {}
	local function score(relicId: string, mutation: string?): number
		return tierOf(relicId) * 2 + (if mutation then 1 else 0)
	end

	for id, at in source.CodexReady do
		if at >= since then
			table.insert(list, {
				Kind = "Milestone",
				Id = id,
				Count = 1,
				New = false,
				NewVariant = false,
				Score = math.huge,
			})
		end
	end

	local rareByKey: { [string]: Unlock } = {}
	local rareById: { [string]: Unlock } = {}
	-- RareHistory is newest first; walk it oldest first so the first find of a relic is flagged.
	for index = #source.RareHistory, 1, -1 do
		local find = source.RareHistory[index]
		if find.At >= since then
			local key = `{find.Id}|{find.Mutation or ""}`
			local entry = rareByKey[key]
			if entry then
				entry.Count += 1
			else
				entry = {
					Kind = "Rare",
					Id = find.Id,
					Mutation = find.Mutation,
					Count = 1,
					New = false,
					NewVariant = false,
					Score = score(find.Id, find.Mutation),
				}
				rareByKey[key] = entry
				table.insert(list, entry)
			end
			if not rareById[find.Id] then
				rareById[find.Id] = entry
			end
		end
	end

	for id, at in source.Discovered do
		if at >= since then
			local rare = rareById[id]
			if rare then
				rare.New = true
			else
				table.insert(list, {
					Kind = "Relic",
					Id = id,
					Count = 1,
					New = true,
					NewVariant = false,
					Score = score(id, nil),
				})
			end
		end
	end

	for id, seen in source.CodexMutations do
		for mutation, at in seen do
			if at >= since then
				local rare = rareByKey[`{id}|{mutation}`]
				if rare then
					rare.NewVariant = true
				else
					table.insert(list, {
						Kind = "Variant",
						Id = id,
						Mutation = mutation,
						Count = 1,
						New = false,
						NewVariant = true,
						Score = score(id, mutation),
					})
				end
			end
		end
	end

	table.sort(list, function(a, b)
		if a.Score ~= b.Score then
			return a.Score > b.Score
		end
		if a.Kind ~= b.Kind then
			return KIND_ORDER[a.Kind] < KIND_ORDER[b.Kind]
		end
		if a.Id ~= b.Id then
			return a.Id < b.Id
		end
		return (a.Mutation or "") < (b.Mutation or "")
	end)

	local more = math.max(0, #list - max)
	for index = #list, max + 1, -1 do
		list[index] = nil
	end
	return list, more
end

return AfkSummary

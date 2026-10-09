-- Codex rules (GDD 7). Pure: callers pass the roster, tiers, families and CodexConfig, so Lune
-- tests can run it. CodexBook builds the game's book once for the server and the UI.
--
-- A Codex entry is a BASE relic id. A mutated find marks the same entry as its plain version and
-- is also recorded as a seen mutation (shown on the item detail); there is no mutation Codex.

local Codex = {}

export type Kind = "Essential" | "Collection" | "MutatedTier" | "Frequency" | "SetComplete"

export type Milestone = {
	Id: string,
	Kind: Kind,
	-- Relic ids that count toward this milestone.
	Pool: { string },
	Need: number,
	Luck: number,
	Income: number,
	Title: string?,
	Family: string?,
	Tier: string?,
}

export type FamilySet = {
	Family: string,
	Members: { string },
	Attainable: { string },
}

export type Book = {
	Pool: { string },
	PoolSet: { [string]: boolean },
	AllIds: { string },
	Sets: { FamilySet },
	Milestones: { Milestone },
	ById: { [string]: Milestone },
}

-- Saved Codex data: Discovered[id] = first time; Mutations[id][mutation] = first time.
export type State = {
	Discovered: { [string]: number },
	Mutations: { [string]: { [string]: number } },
}

type Relic = { Id: string, Tier: string, Family: string }
type Tier = { Id: string }

-- Smallest count that reaches `fraction` of `size` (at least 1 for a non-empty pool).
function Codex.threshold(fraction: number, size: number): number
	if size <= 0 then
		return 0
	end
	return math.clamp(math.ceil(fraction * size - 1e-9), 1, size)
end

function Codex.build(config: any, relics: { Relic }, tiers: { Tier }, families: { string }): Book
	local tierIndex = {}
	for index, tier in tiers do
		tierIndex[tier.Id] = index
	end
	local maxIndex = tierIndex[config.EssentialMaxTier]
	assert(maxIndex, `EssentialMaxTier {config.EssentialMaxTier} is not a tier`)

	local ordered = table.clone(relics)
	table.sort(ordered, function(a, b)
		local ta, tb = tierIndex[a.Tier] or 0, tierIndex[b.Tier] or 0
		if ta ~= tb then
			return ta < tb
		end
		return a.Id < b.Id
	end)

	local pool, poolSet, allIds = {}, {}, {}
	for _, relic in ordered do
		table.insert(allIds, relic.Id)
		if (tierIndex[relic.Tier] or math.huge) <= maxIndex then
			table.insert(pool, relic.Id)
			poolSet[relic.Id] = true
		end
	end

	local milestones: { Milestone } = {}
	local function add(milestone: any)
		milestone.Luck = milestone.Luck or 0
		milestone.Income = milestone.Income or 0
		table.insert(milestones, milestone)
	end

	for _, entry in config.Essential do
		add({
			Id = entry.Id,
			Kind = "Essential",
			Pool = pool,
			Need = Codex.threshold(entry.Fraction, #pool),
			Luck = entry.Luck,
			Income = entry.Income,
		})
	end
	for _, entry in config.Collection do
		add({ Id = entry.Id, Kind = "Collection", Pool = allIds, Need = Codex.threshold(entry.Fraction, #allIds), Title = entry.Title })
	end
	for _, entry in config.MutatedTier do
		local members = {}
		for _, relic in ordered do
			if (tierIndex[relic.Tier] or 0) >= (tierIndex[entry.Tier] or math.huge) then
				table.insert(members, relic.Id)
			end
		end
		add({
			Id = entry.Id,
			Kind = "MutatedTier",
			Pool = members,
			Need = if #members > 0 then 1 else 0,
			Title = entry.Title,
			Tier = entry.Tier,
		})
	end

	local sets: { FamilySet } = {}
	for _, family in families do
		local members, attainable = {}, {}
		for _, relic in ordered do
			if relic.Family == family then
				table.insert(members, relic.Id)
				if poolSet[relic.Id] then
					table.insert(attainable, relic.Id)
				end
			end
		end
		table.insert(sets, { Family = family, Members = members, Attainable = attainable })
		add({
			Id = `Frequency_{family}`,
			Kind = "Frequency",
			Pool = attainable,
			Need = Codex.threshold(config.Themes.FrequencyFraction, #attainable),
			Family = family,
		})
		if #attainable > 0 then
			add({
				Id = `Set_{family}`,
				Kind = "SetComplete",
				Pool = attainable,
				Need = #attainable,
				Title = `{family} {config.Themes.CompletionTitleSuffix}`,
				Family = family,
			})
		end
	end

	local byId = {}
	for _, milestone in milestones do
		byId[milestone.Id] = milestone
	end
	return { Pool = pool, PoolSet = poolSet, AllIds = allIds, Sets = sets, Milestones = milestones, ById = byId }
end

-- How many pool relics count toward the milestone right now.
function Codex.progress(milestone: Milestone, state: State): number
	local have = 0
	for _, relicId in milestone.Pool do
		if milestone.Kind == "MutatedTier" then
			local seen = state.Mutations[relicId]
			if seen and next(seen) ~= nil then
				have += 1
			end
		elseif state.Discovered[relicId] ~= nil then
			have += 1
		end
	end
	return have
end

-- Every milestone the current state qualifies for (callers save these; they are never removed).
-- Milestones that need nothing (e.g. a family with no attainable relics) are open from the start
-- and never need claiming, so they are not listed.
function Codex.earned(book: Book, state: State): { string }
	local list = {}
	for _, milestone in book.Milestones do
		if milestone.Need > 0 and Codex.progress(milestone, state) >= milestone.Need then
			table.insert(list, milestone.Id)
		end
	end
	return list
end

-- Total bonuses from claimed milestones. Unknown ids (removed from config) are ignored.
function Codex.bonuses(book: Book, claimed: { [string]: any }): (number, number)
	local luck, income = 0, 0
	for id in claimed do
		local milestone = book.ById[id]
		if milestone then
			luck += milestone.Luck
			income += milestone.Income
		end
	end
	return luck, income
end

function Codex.unlockedFrequencies(book: Book, claimed: { [string]: any }): { [string]: boolean }
	local unlocked = {}
	for _, milestone in book.Milestones do
		if milestone.Kind == "Frequency" and milestone.Family and (claimed[milestone.Id] or milestone.Need == 0) then
			unlocked[milestone.Family] = true
		end
	end
	return unlocked
end

function Codex.titles(book: Book, claimed: { [string]: any }): { string }
	local list = {}
	for _, milestone in book.Milestones do
		if milestone.Title and claimed[milestone.Id] then
			table.insert(list, milestone.Title)
		end
	end
	return list
end

local function percent(value: number): string
	return `{math.round(value * 100)}%`
end

function Codex.goalText(book: Book, milestone: Milestone): string
	if milestone.Kind == "Essential" then
		return `Discover {milestone.Need} of {#book.Pool} Common-Legendary relics`
	elseif milestone.Kind == "Collection" then
		return `Discover {milestone.Need} of {#book.AllIds} relics`
	elseif milestone.Kind == "MutatedTier" then
		return `Find any mutated {milestone.Tier} or rarer relic`
	elseif milestone.Kind == "Frequency" then
		return `Discover {milestone.Need} {milestone.Family} relics (Common-Legendary)`
	end
	return `Discover all {milestone.Need} Common-Legendary {milestone.Family} relics`
end

function Codex.rewardText(milestone: Milestone): string
	if milestone.Kind == "Frequency" then
		return `Unlocks the {milestone.Family} Signal Frequency`
	end
	local parts = {}
	if milestone.Luck > 0 then
		table.insert(parts, `+{percent(milestone.Luck)} Luck`)
	end
	if milestone.Income > 0 then
		table.insert(parts, `+{percent(milestone.Income)} CE income`)
	end
	if milestone.Title then
		table.insert(parts, `Title: {milestone.Title}`)
	end
	return table.concat(parts, ", ")
end

-- One line for several claimed milestones, e.g. "+15% Luck, +5% CE income, Demonic frequency, Title: X".
function Codex.combinedRewardText(milestones: { Milestone }): string
	local luck, income = 0, 0
	local extras = {}
	for _, milestone in milestones do
		luck += milestone.Luck
		income += milestone.Income
		if milestone.Kind == "Frequency" then
			table.insert(extras, `{milestone.Family} frequency unlocked`)
		end
		if milestone.Title then
			table.insert(extras, `Title: {milestone.Title}`)
		end
	end
	local parts = {}
	if luck > 0 then
		table.insert(parts, `+{percent(luck)} Luck`)
	end
	if income > 0 then
		table.insert(parts, `+{percent(income)} CE income`)
	end
	for _, extra in extras do
		table.insert(parts, extra)
	end
	return table.concat(parts, ", ")
end

-- Expected rolls to see every item at least once, where item i appears with chance p[i] per
-- roll (coupon collector with unequal odds, Poisson approximation):
--   E[T] = integral over t >= 0 of (1 - product(1 - exp(-p_i t))) dt
-- Integrated on a log scale so tiny and large probabilities are both resolved.
function Codex.expectedCollectionRolls(probabilities: { number }): number
	if #probabilities == 0 then
		return 0
	end
	local low, high = math.huge, 0
	for _, p in probabilities do
		if p <= 0 then
			return math.huge
		end
		low = math.min(low, p)
		high = math.max(high, p)
	end
	local function missing(t: number): number
		local allSeen = 1
		for _, p in probabilities do
			allSeen *= 1 - math.exp(-p * t)
		end
		return 1 - allSeen
	end
	local startU = math.log(1e-4 / high)
	local endU = math.log(60 / low)
	local steps = 4000
	local du = (endU - startU) / steps
	-- Below the first point the integrand is ~1, so that slice is worth ~t0.
	local total = math.exp(startU)
	local previous = missing(math.exp(startU)) * math.exp(startU)
	for step = 1, steps do
		local t = math.exp(startU + step * du)
		local current = missing(t) * t
		total += (previous + current) * 0.5 * du
		previous = current
	end
	return total
end

return Codex

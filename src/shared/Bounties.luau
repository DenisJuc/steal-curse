-- Daily bounties (Config.Bounties): the deterministic daily/weekly pick, progress from game events,
-- claiming, the free reroll and the claim streak with its chests. Pure (no Roblox APIs) so Lune
-- tests cover it; BountyService saves the state and pays the rewards.

local Bounties = {}

export type Def = {
	Id: string,
	Difficulty: string,
	Text: string,
	Event: string,
	Goal: number,
	Filter: { [string]: any }?,
}
export type Reward = {
	CEMinutes: number?,
	Potion: boolean?,
	Potions: { [string]: number }?,
	Rolls: number?,
}
export type Chest = Reward & { Day: number }
export type Options = {
	MinCE: number,
	Rewards: { [string]: Reward },
	Chests: { Chest },
	Pool: { Def },
}
export type Slot = { Id: string, Progress: number, Claimed: boolean }
export type Weekly = { Week: number, Id: string, Progress: number, Claimed: boolean }
export type State = {
	Day: number,
	Slots: { Slot },
	Rerolled: boolean,
	Weekly: Weekly,
	Streak: { Count: number, LastDay: number },
}

Bounties.Daily = { "Easy", "Medium", "Hard" }

local SECONDS_PER_DAY = 86400
local MODULUS = 2147483647
local BAND_RANK = { Edge = 1, Deep = 2, Heart = 3 }

function Bounties.dayOf(unixTime: number): number
	return unixTime // SECONDS_PER_DAY
end

-- Weeks start on Monday (day 0 was a Thursday).
function Bounties.weekOf(day: number): number
	return (day + 3) // 7
end

-- Seconds until the next UTC day.
function Bounties.secondsLeft(unixTime: number): number
	return SECONDS_PER_DAY - unixTime % SECONDS_PER_DAY
end

local function hash(values: { number }): number
	local h = 1
	for _, value in values do
		h = (h + math.floor(value) % MODULUS) % MODULUS
		h = (h * 48271) % MODULUS
		h = (h * 48271) % MODULUS
	end
	return h
end

function Bounties.byId(options: Options, id: string): Def?
	for _, def in options.Pool do
		if def.Id == id then
			return def
		end
	end
	return nil
end

-- The bounty of `difficulty` for (userId, period, salt), never one in `excluded` or `avoid`.
function Bounties.pick(
	options: Options,
	userId: number,
	period: number,
	difficulty: string,
	salt: number,
	excluded: { [string]: boolean }?,
	avoid: string?
): string?
	local candidates = {}
	for _, def in options.Pool do
		if def.Difficulty == difficulty and not (excluded and excluded[def.Id]) and def.Id ~= avoid then
			table.insert(candidates, def.Id)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[hash({ userId, period, salt }) % #candidates + 1]
end

-- New dailies on a new day, a new weekly in a new week. Returns true if anything changed.
function Bounties.refresh(state: State, options: Options, userId: number, day: number, excluded: { [string]: boolean }?): boolean
	local changed = false
	if state.Day ~= day then
		state.Day = day
		state.Rerolled = false
		state.Slots = {}
		for index, difficulty in Bounties.Daily do
			local id = Bounties.pick(options, userId, day, difficulty, index, excluded)
			if id then
				table.insert(state.Slots, { Id = id, Progress = 0, Claimed = false })
			end
		end
		changed = true
	end
	local week = Bounties.weekOf(day)
	if state.Weekly.Week ~= week then
		local id = Bounties.pick(options, userId, week, "Weekly", 7, excluded)
		state.Weekly = { Week = week, Id = id or "", Progress = 0, Claimed = false }
		changed = true
	end
	return changed
end

function Bounties.matches(def: Def, event: string, payload: { [string]: any }): boolean
	if def.Event ~= event then
		return false
	end
	local filter = def.Filter
	if not filter then
		return true
	end
	if filter.Area and payload.Area ~= filter.Area then
		return false
	end
	if filter.MinBand and (BAND_RANK[payload.Band] or 0) < (BAND_RANK[filter.MinBand] or 0) then
		return false
	end
	if filter.MinStreak and (tonumber(payload.Streak) or 1) < filter.MinStreak - 1e-9 then
		return false
	end
	if filter.Struck and payload.Struck ~= true then
		return false
	end
	if filter.Event then
		if filter.Event == "Any" then
			if payload.Event == nil then
				return false
			end
		elseif payload.Event ~= filter.Event then
			return false
		end
	end
	return true
end

local function bump(entry: { Id: string, Progress: number, Claimed: boolean }, options: Options, event: string, payload: { [string]: any }): boolean
	local def = Bounties.byId(options, entry.Id)
	if entry.Claimed or not def or entry.Progress >= def.Goal or not Bounties.matches(def, event, payload) then
		return false
	end
	entry.Progress += 1
	return true
end

-- Counts one `event`. Returns the bounties it just completed (empty if none).
function Bounties.record(state: State, options: Options, event: string, payload: { [string]: any }): { Def }
	local completed = {}
	local entries: { { Id: string, Progress: number, Claimed: boolean } } = table.clone(state.Slots)
	table.insert(entries, state.Weekly)
	for _, entry in entries do
		if bump(entry, options, event, payload) then
			local def = Bounties.byId(options, entry.Id) :: Def
			if entry.Progress >= def.Goal then
				table.insert(completed, def)
			end
		end
	end
	return completed
end

-- The streak shown today: it breaks after a day without claiming every daily.
function Bounties.streak(state: State, day: number): number
	return if state.Streak.LastDay >= day - 1 then state.Streak.Count else 0
end

-- The next chest after streak count `count`.
function Bounties.nextChest(options: Options, count: number): Chest?
	for _, chest in options.Chests do
		if chest.Day > count then
			return chest
		end
	end
	return options.Chests[1]
end

local function lastChestDay(options: Options): number
	local last = 0
	for _, chest in options.Chests do
		last = math.max(last, chest.Day)
	end
	return last
end

-- Claims daily slot `which` (1..3) or "Weekly" on `day`. Returns the bounty's reward and, when
-- this claim finished every daily and reached a chest day, that chest.
function Bounties.claim(state: State, options: Options, which: number | string, day: number): (Reward?, Chest?)
	local entry = if which == "Weekly" then state.Weekly else state.Slots[which :: number]
	if not entry or entry.Claimed or entry.Id == "" then
		return nil, nil
	end
	local def = Bounties.byId(options, entry.Id)
	if not def or entry.Progress < def.Goal then
		return nil, nil
	end
	entry.Claimed = true
	local reward = options.Rewards[def.Difficulty]
	if which == "Weekly" then
		return reward, nil
	end
	for _, slot in state.Slots do
		if not slot.Claimed then
			return reward, nil
		end
	end
	local streak = state.Streak
	if streak.LastDay == day then
		return reward, nil
	end
	local count = if streak.LastDay == day - 1 then streak.Count + 1 else 1
	if count > lastChestDay(options) then
		count = 1
	end
	streak.Count = count
	streak.LastDay = day
	for _, chest in options.Chests do
		if chest.Day == count then
			return reward, chest
		end
	end
	return reward, nil
end

-- Swaps unclaimed, unfinished daily slot `index` for another bounty of its difficulty, once a day.
function Bounties.reroll(
	state: State,
	options: Options,
	userId: number,
	index: number,
	excluded: { [string]: boolean }?
): boolean
	local slot = state.Slots[index]
	local def = slot and Bounties.byId(options, slot.Id)
	if state.Rerolled or not slot or not def or slot.Claimed or slot.Progress >= def.Goal then
		return false
	end
	local id = Bounties.pick(options, userId, state.Day, def.Difficulty, 100 + index, excluded, slot.Id)
	if not id then
		return false
	end
	state.Slots[index] = { Id = id, Progress = 0, Claimed = false }
	state.Rerolled = true
	return true
end

-- Finished but unclaimed bounties (dailies and the weekly).
function Bounties.claimable(state: State, options: Options): number
	local count = 0
	local entries: { { Id: string, Progress: number, Claimed: boolean } } = table.clone(state.Slots)
	table.insert(entries, state.Weekly)
	for _, entry in entries do
		local def = Bounties.byId(options, entry.Id)
		if def and not entry.Claimed and entry.Progress >= def.Goal then
			count += 1
		end
	end
	return count
end

return Bounties

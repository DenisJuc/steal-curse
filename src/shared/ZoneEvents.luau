-- Zone events: one area at a time gets a timed event (Blood Moon, Spirit Storm, Star Fall) that
-- boosts captures made inside it. Pure (no Roblox APIs): the schedule is a small state machine
-- advanced with the current time and a random source, so Lune tests cover it.

local ZoneEvents = {}

export type Event = {
	Id: string,
	Name: string,
	Area: string,
	Effect: string,
	Luck: number,
	Bonus: number,
	Mutation: number,
	Color: { number },
	Overlay: { [string]: any },
	StrikeEvery: { number }?,
	Particles: { any },
}

export type Options = {
	FirstAfter: number,
	Every: { number },
	Duration: number,
	Warning: number,
	Events: { Event },
}

-- Phase "Idle": waiting, the next event is chosen at StartsAt - Warning ("Soon").
export type State = {
	Phase: "Idle" | "Soon" | "Active",
	EventId: string?,
	LastId: string?,
	StartsAt: number,
	EndsAt: number,
}

export type Factors = { Luck: number, Bonus: number, Mutation: number }

local NONE: Factors = { Luck = 1, Bonus = 1, Mutation = 1 }

function ZoneEvents.byId(options: Options, id: string?): Event?
	for _, event in options.Events do
		if event.Id == id then
			return event
		end
	end
	return nil
end

function ZoneEvents.new(now: number, options: Options): State
	return { Phase = "Idle", EventId = nil, LastId = nil, StartsAt = now + options.FirstAfter, EndsAt = 0 }
end

-- Any event except the last one, picked with `roll` in [0, 1).
function ZoneEvents.pick(options: Options, lastId: string?, roll: number): Event
	local pool = {}
	for _, event in options.Events do
		if event.Id ~= lastId or #options.Events == 1 then
			table.insert(pool, event)
		end
	end
	return pool[math.clamp(math.floor(roll * #pool) + 1, 1, #pool)]
end

-- Moves the schedule forward to `now`. Returns the transition that happened ("Soon", "Start",
-- "End") or nil. One transition per call; call again to catch up.
function ZoneEvents.advance(state: State, now: number, nextNumber: () -> number, options: Options): string?
	if state.Phase == "Idle" and now >= state.StartsAt - options.Warning then
		state.Phase = "Soon"
		state.EventId = ZoneEvents.pick(options, state.LastId, nextNumber()).Id
		return "Soon"
	elseif state.Phase == "Soon" and now >= state.StartsAt then
		state.Phase = "Active"
		state.EndsAt = state.StartsAt + options.Duration
		return "Start"
	elseif state.Phase == "Active" and now >= state.EndsAt then
		local gap = options.Every[1] + nextNumber() * (options.Every[2] - options.Every[1])
		state.Phase = "Idle"
		state.LastId = state.EventId
		state.EventId = nil
		state.StartsAt = state.EndsAt + gap
		return "End"
	end
	return nil
end

-- Starts `id` right now (debug), replacing whatever was scheduled.
function ZoneEvents.force(state: State, id: string, now: number, options: Options)
	state.Phase = "Active"
	state.EventId = id
	state.StartsAt = now
	state.EndsAt = now + options.Duration
end

-- The active event's effects for a capture in `area` (all 1 when it doesn't apply).
-- Luck is capped by `maxLuck` (Config.Luck.MaxEvent).
function ZoneEvents.factors(state: State, area: string, options: Options, maxLuck: number): Factors
	if state.Phase ~= "Active" then
		return NONE
	end
	local event = ZoneEvents.byId(options, state.EventId)
	if not event or event.Area ~= area then
		return NONE
	end
	return { Luck = math.min(maxLuck, event.Luck), Bonus = event.Bonus, Mutation = event.Mutation }
end

return ZoneEvents

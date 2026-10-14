-- Daily bounties: deterministic picks, progress filters, claiming once, rerolls and the streak.

local Bounties = require("../../src/shared/Bounties")
local Config = require("../../src/shared/Config")
local expect = require("../lib/expect")

local options = Config.Bounties :: any
local USER = 123456
local DAY = 20000

local function fresh(): any
	return {
		Day = 0,
		Slots = {},
		Rerolled = false,
		Weekly = { Week = 0, Id = "", Progress = 0, Claimed = false },
		Streak = { Count = 0, LastDay = 0 },
	}
end

local function finish(state: any, entry: any)
	entry.Progress = (Bounties.byId(options, entry.Id) :: any).Goal
	return state
end

local function claimAll(state: any, day: number): any?
	local chest = nil
	for index, slot in state.Slots do
		finish(state, slot)
		local reward, got = Bounties.claim(state, options, index, day)
		expect.truthy(reward, "daily pays")
		chest = got or chest
	end
	return chest
end

return {
	{
		Name = "every pool bounty has a reward tier and a positive goal",
		Run = function()
			local seen = {}
			for _, def in options.Pool do
				expect.truthy(options.Rewards[def.Difficulty], `{def.Id} reward tier`)
				expect.truthy(def.Goal > 0, `{def.Id} goal`)
				expect.truthy(not seen[def.Id], `{def.Id} unique`)
				seen[def.Id] = true
			end
		end,
	},
	{
		Name = "picks are deterministic per player and day, one of each difficulty",
		Run = function()
			local a, b = fresh(), fresh()
			expect.truthy(Bounties.refresh(a, options, USER, DAY), "first refresh changes")
			Bounties.refresh(b, options, USER, DAY)
			expect.equal(#a.Slots, 3, "three dailies")
			for index, difficulty in Bounties.Daily do
				expect.equal(a.Slots[index].Id, b.Slots[index].Id, "same pick")
				expect.equal((Bounties.byId(options, a.Slots[index].Id) :: any).Difficulty, difficulty, "slot difficulty")
			end
			expect.equal(a.Weekly.Id, b.Weekly.Id, "same weekly")
			expect.equal((Bounties.byId(options, a.Weekly.Id) :: any).Difficulty, "Weekly", "weekly difficulty")
			expect.truthy(not Bounties.refresh(a, options, USER, DAY), "same day keeps the picks")

			local varied = false
			for day = DAY + 1, DAY + 10 do
				local other = fresh()
				Bounties.refresh(other, options, USER, day)
				for index in Bounties.Daily do
					varied = varied or other.Slots[index].Id ~= a.Slots[index].Id
				end
			end
			expect.truthy(varied, "picks change across days")
		end,
	},
	{
		Name = "excluded bounties are never picked",
		Run = function()
			for day = DAY, DAY + 30 do
				local state = fresh()
				Bounties.refresh(state, options, USER, day, { Shrine1 = true })
				expect.truthy(state.Slots[3].Id ~= "Shrine1", "no shrine bounty")
			end
		end,
	},
	{
		Name = "filters count only matching events",
		Run = function()
			local function def(id: string): any
				return Bounties.byId(options, id)
			end
			local forest = { Area = "HauntedForest", Band = "Edge", Streak = 1, Struck = false }
			expect.truthy(Bounties.matches(def("Forest4"), "Captured", forest), "forest capture")
			expect.truthy(not Bounties.matches(def("Village4"), "Captured", forest), "wrong area")
			expect.truthy(not Bounties.matches(def("Forest4"), "OfferingOpened", forest), "wrong event")
			expect.truthy(not Bounties.matches(def("Deep6"), "Captured", forest), "Edge is not Deep")
			expect.truthy(Bounties.matches(def("Deep6"), "Captured", { Band = "Heart" }), "Heart counts as Deep")
			expect.truthy(not Bounties.matches(def("Heart8"), "Captured", { Band = "Deep" }), "Deep is not Heart")
			expect.truthy(not Bounties.matches(def("Struck1"), "Captured", forest), "not struck")
			expect.truthy(Bounties.matches(def("Struck1"), "Captured", { Struck = true }), "struck")
			expect.truthy(not Bounties.matches(def("Event3"), "Captured", forest), "no event")
			expect.truthy(Bounties.matches(def("Event3"), "Captured", { Event = "Mist" }), "any event")
			expect.truthy(Bounties.matches(def("BloodMoon10"), "Captured", { Event = "BloodMoon" }), "blood moon")
			expect.truthy(not Bounties.matches(def("BloodMoon10"), "Captured", { Event = "Mist" }), "other event")
			expect.truthy(not Bounties.matches(def("Streak2"), "Captured", { Streak = 1.9 }), "streak too low")
			expect.truthy(Bounties.matches(def("Streak2"), "Captured", { Streak = 2 }), "streak reached")
		end,
	},
	{
		Name = "progress completes once and claiming pays once",
		Run = function()
			local state = fresh()
			Bounties.refresh(state, options, USER, DAY)
			state.Slots[1] = { Id = "Capture5", Progress = 0, Claimed = false }
			expect.truthy(Bounties.claim(state, options, 1, DAY) == nil, "not ready")
			local completed = 0
			for _ = 1, 8 do
				completed += #Bounties.record(state, options, "Captured", { Area = "HauntedForest", Band = "Edge", Streak = 1 })
			end
			expect.equal(state.Slots[1].Progress, 5, "progress caps at the goal")
			expect.truthy(completed >= 1, "completion reported")
			expect.equal(Bounties.claimable(state, options) >= 1, true, "claimable")
			local reward = Bounties.claim(state, options, 1, DAY)
			expect.equal((reward :: any).CEMinutes, options.Rewards.Easy.CEMinutes, "easy reward")
			expect.truthy(Bounties.claim(state, options, 1, DAY) == nil, "only once")
			expect.truthy(Bounties.claim(state, options, 9, DAY) == nil, "bad slot")
		end,
	},
	{
		Name = "one free reroll a day, never on finished bounties",
		Run = function()
			local state = fresh()
			Bounties.refresh(state, options, USER, DAY)
			local before = state.Slots[2].Id
			finish(state, state.Slots[1])
			expect.truthy(not Bounties.reroll(state, options, USER, 1), "finished can't reroll")
			expect.truthy(Bounties.reroll(state, options, USER, 2), "reroll")
			expect.truthy(state.Slots[2].Id ~= before, "new bounty")
			expect.equal((Bounties.byId(options, state.Slots[2].Id) :: any).Difficulty, "Medium", "same difficulty")
			expect.truthy(not Bounties.reroll(state, options, USER, 3), "only once a day")
			Bounties.refresh(state, options, USER, DAY + 1)
			expect.truthy(not state.Rerolled, "reroll back next day")
		end,
	},
	{
		Name = "streak counts consecutive days, pays chests and rolls over",
		Run = function()
			local state = fresh()
			local chests = {}
			for offset = 0, 7 do
				local day = DAY + offset
				Bounties.refresh(state, options, USER, day)
				local chest = claimAll(state, day)
				chests[state.Streak.Count] = chest
			end
			expect.truthy(chests[3] and chests[3].Day == 3, "day 3 chest")
			expect.truthy(chests[5] and chests[5].Day == 5, "day 5 chest")
			expect.truthy(chests[7] and chests[7].Day == 7, "day 7 chest")
			expect.equal(state.Streak.Count, 1, "rolls over after the last chest")
			expect.equal(Bounties.streak(state, DAY + 8), 1, "shown the next day")
			expect.equal(Bounties.streak(state, DAY + 9), 0, "breaks after a missed day")

			Bounties.refresh(state, options, USER, DAY + 10)
			claimAll(state, DAY + 10)
			expect.equal(state.Streak.Count, 1, "restarts after a gap")
			expect.equal(Bounties.nextChest(options, 1).Day, 3, "next chest day 3")
			expect.equal(Bounties.nextChest(options, 7).Day, 3, "wraps to the first chest")
		end,
	},
	{
		Name = "weekly claims don't touch the streak and weeks start Monday",
		Run = function()
			local state = fresh()
			Bounties.refresh(state, options, USER, DAY)
			finish(state, state.Weekly)
			expect.truthy(Bounties.claim(state, options, "Weekly", DAY), "weekly pays")
			expect.equal(state.Streak.Count, 0, "streak untouched")
			-- 1970-01-05 (day 4) was a Monday.
			expect.equal(Bounties.weekOf(3), 0, "Sunday in week 0")
			expect.equal(Bounties.weekOf(4), 1, "Monday starts week 1")
			expect.equal(Bounties.secondsLeft(86400 * DAY + 3600), 82800, "seconds to midnight")
		end,
	},
}

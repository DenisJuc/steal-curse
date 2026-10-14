-- Zone events: schedule transitions, no repeats, effects only inside the event area, luck cap.

local Config = require("../../src/shared/Config")
local ZoneEvents = require("../../src/shared/ZoneEvents")
local expect = require("../lib/expect")

local options = Config.ZoneEvents

local function fixed(value: number): () -> number
	return function()
		return value
	end
end

return {
	{
		Name = "every event is in a real area with sane effects",
		Run = function()
			local areas = {}
			for _, area in Config.Areas do
				areas[area.Id] = true
			end
			for _, event in options.Events do
				expect.truthy(areas[event.Area], `{event.Id} area`)
				expect.truthy(event.Luck >= 1 and event.Bonus >= 1 and event.Mutation >= 1, `{event.Id} effects`)
			end
		end,
	},
	{
		Name = "the schedule warns, starts, ends and waits Every seconds",
		Run = function()
			local state = ZoneEvents.new(0, options)
			expect.equal(ZoneEvents.advance(state, options.FirstAfter - options.Warning - 1, fixed(0), options), nil, "idle")
			expect.equal(ZoneEvents.advance(state, options.FirstAfter - options.Warning, fixed(0), options), "Soon", "soon")
			expect.truthy(state.EventId ~= nil, "event chosen early")
			expect.equal(ZoneEvents.advance(state, options.FirstAfter, fixed(0), options), "Start", "start")
			expect.equal(state.EndsAt, options.FirstAfter + options.Duration, "ends")
			expect.equal(ZoneEvents.advance(state, state.EndsAt, fixed(0), options), "End", "end")
			expect.equal(state.Phase, "Idle", "idle again")
			expect.equal(state.StartsAt, options.FirstAfter + options.Duration + options.Every[1], "gap")
		end,
	},
	{
		Name = "the same event never runs twice in a row",
		Run = function()
			for roll = 0, 0.99, 0.11 do
				local event = ZoneEvents.pick(options, "BloodMoon", roll)
				expect.truthy(event.Id ~= "BloodMoon", "no repeat")
			end
		end,
	},
	{
		Name = "effects apply only inside the event area, luck capped",
		Run = function()
			local state = ZoneEvents.new(0, options)
			ZoneEvents.force(state, "BloodMoon", 0, options)
			local event = ZoneEvents.byId(options, "BloodMoon") :: any
			local inside = ZoneEvents.factors(state, event.Area, options, 1.2)
			expect.equal(inside.Luck, 1.2, "capped luck")
			local outside = ZoneEvents.factors(state, "NotTheArea", options, Config.Luck.MaxEvent)
			expect.equal(outside.Luck, 1, "outside")
			ZoneEvents.advance(state, options.Duration, fixed(0.5), options)
			expect.equal(ZoneEvents.factors(state, event.Area, options, 2).Luck, 1, "over")
		end,
	},
}

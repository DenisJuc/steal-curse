-- Hunt Streak: depth bands, gains, cap, idle reset and the pause.

local Config = require("../../src/shared/Config")
local HuntStreak = require("../../src/shared/HuntStreak")
local expect = require("../lib/expect")

local options = Config.HuntStreak

return {
	{
		Name = "depth bands follow the distance from the hub",
		Run = function()
			expect.equal(HuntStreak.band(Config.World.WildInner + 10, 0, options), "Edge", "near town")
			expect.equal(HuntStreak.band(0, (options.EdgeUntil + options.DeepUntil) / 2, options), "Deep", "middle")
			expect.equal(HuntStreak.band(-Config.World.WildOuter + 10, 0, options), "Heart", "outer rim")
		end,
	},
	{
		Name = "captures add their band's gain and the streak is capped",
		Run = function()
			local state = HuntStreak.new()
			expect.equal(state.Value, 1, "starts at 1")
			expect.near(HuntStreak.capture(state, "Edge", options), 1 + options.Gains.Edge, 1e-9, "edge")
			expect.near(HuntStreak.capture(state, "Heart", options), 1 + options.Gains.Edge + options.Gains.Heart, 1e-9, "heart")
			for _ = 1, 20 do
				HuntStreak.capture(state, "Heart", options)
			end
			expect.equal(state.Value, options.Max, "capped")
		end,
	},
	{
		Name = "idle time ends the streak, a capture refreshes it",
		Run = function()
			local state = HuntStreak.new()
			HuntStreak.capture(state, "Deep", options)
			expect.equal(HuntStreak.step(state, options.IdleSeconds - 1, false), false, "still going")
			HuntStreak.capture(state, "Deep", options)
			expect.equal(HuntStreak.step(state, options.IdleSeconds - 1, false), false, "refreshed")
			expect.equal(HuntStreak.step(state, 2, false), true, "ended")
			expect.equal(state.Value, 1, "back to 1")
			expect.equal(HuntStreak.active(state), false, "inactive")
		end,
	},
	{
		Name = "the timer pauses while paused and extra idle time lengthens it",
		Run = function()
			local state = HuntStreak.new()
			HuntStreak.capture(state, "Edge", options, 15)
			expect.equal(HuntStreak.step(state, 1000, true), false, "paused")
			expect.equal(HuntStreak.step(state, options.IdleSeconds + 10, false), false, "extra idle")
			expect.equal(HuntStreak.step(state, 6, false), true, "then ends")
		end,
	},
	{
		Name = "bonus factors multiply and are capped",
		Run = function()
			expect.near(HuntStreak.combine({ 1.5, 2 }, 10), 3, 1e-9, "product")
			expect.equal(HuntStreak.combine({ 2, 2, 2 }, Config.Hunt.MaxBonusMultiplier), Config.Hunt.MaxBonusMultiplier, "cap")
			expect.equal(HuntStreak.combine({}, 3), 1, "empty")
		end,
	},
}

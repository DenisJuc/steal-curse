-- Hunt reward math (GDD 4.4) and hunt config sanity.

local Config = require("../../src/shared/Config")
local Formulas = require("../../src/shared/Formulas")
local expect = require("../lib/expect")

-- The GDD's worked examples assume one hunt opportunity every 120 s.
local GDD_WINDOW = 120

return {
	{
		Name = "bonus rolls match GDD examples (4s -> 11, 2s -> 21, 1s -> 42)",
		Run = function()
			expect.equal(Formulas.bonusRolls(4, GDD_WINDOW, Config.Hunt), 11, "4s")
			expect.equal(Formulas.bonusRolls(2, GDD_WINDOW, Config.Hunt), 21, "2s")
			expect.equal(Formulas.bonusRolls(1, GDD_WINDOW, Config.Hunt), 42, "1s")
		end,
	},
	{
		Name = "bonus rolls never drop below the floor",
		Run = function()
			expect.equal(Formulas.bonusRolls(60, GDD_WINDOW, Config.Hunt), Config.Hunt.BonusFloor, "slow scans")
		end,
	},
	{
		Name = "active hunting adds 25-50% more rolls across scan speeds (configured regen)",
		Run = function()
			for _, interval in { 4, 3, 2, 1.5, 1 } do
				local bonus = Formulas.activeRollBonus(interval, Config.Signals.RegenSeconds, Config.Hunt)
				expect.truthy(bonus >= 0.25 and bonus <= 0.5, `interval {interval}s gives +{bonus * 100}%`)
			end
		end,
	},
	{
		Name = "hunt config follows GDD defaults",
		Run = function()
			expect.truthy(Config.Bind.HoldSeconds >= 5 and Config.Bind.HoldSeconds <= 7, "hold is 5-7 s")
			expect.truthy(Config.Signals.StartCount >= 3, "at least 3 signals at start")
			expect.truthy(Config.Signals.MaxCount <= 5, "at most 5 signals")
			expect.truthy(Config.Bind.BreakRange > Config.Bind.LockRange + Config.Bind.RangeSlack, "break > lock")
		end,
	},
}

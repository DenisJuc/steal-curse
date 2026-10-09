-- Max-boost waiting times for rare finds (approved targets: any Cosmic 5-10 h AFK,
-- any Cosmic with the rarest mutation about 100 h or less). Full table: lune run tests/rareWaitReport

local Formulas = require("../../src/shared/Formulas")
local Stats = require("../../src/shared/Stats")
local expect = require("../lib/expect")
local RareWait = require("../lib/rareWait")

local function find(rows: { RareWait.Row }, label: string): RareWait.Row
	for _, row in rows do
		if row.Label == label then
			return row
		end
	end
	error(`no row {label}`)
end

return {
	{
		Name = "max-boost luck is 4.95e10 (Core Luck 100 x Codex x Showcase x consumable x event)",
		Run = function()
			expect.near(RareWait.maxLuck(), 4.95e10, 1, "max luck")
			expect.equal(Formulas.coreLuck(100), 1e10, "Core Luck rank 100")
		end,
	},
	{
		Name = "any Cosmic AFK: mean 7.41 h, median 5.13 h, p90 17.06 h",
		Run = function()
			local row = find(RareWait.rows(false), "Any Cosmic")
			expect.near(row.MeanHours, 7.407, 0.01, "mean")
			expect.near(row.MedianHours, 5.134, 0.01, "median")
			expect.near(row.P90Hours, 17.06, 0.02, "p90")
			expect.truthy(row.MeanHours >= 5 and row.MeanHours <= 10, "inside the 5-10 h target")
		end,
	},
	{
		Name = "any Cosmic with the rarest mutation stays at about 100 h or less (AFK mean)",
		Run = function()
			local rows = RareWait.rows(false)
			expect.near(find(rows, "Any Cosmic, Abyssal").MeanHours, 98.77, 0.05, "Abyssal")
			expect.near(find(rows, "Any Cosmic, Golden").MeanHours, 49.38, 0.05, "Golden")
			expect.near(find(rows, "Any Cosmic, any mutation").MeanHours, 14.81, 0.02, "any mutation")
			for _, row in rows do
				if string.find(row.Label, "^Any Cosmic, ") then
					expect.truthy(row.MeanHours <= 100, `{row.Label} mean {row.MeanHours} h`)
				end
			end
		end,
	},
	{
		Name = "active hunting shortens every wait by the capture-batch rate",
		Run = function()
			local afk = find(RareWait.rows(false), "Any Cosmic")
			local active = find(RareWait.rows(true), "Any Cosmic")
			local ratio = RareWait.rollsPerSecond(true) / RareWait.rollsPerSecond(false)
			expect.near(afk.MeanHours / active.MeanHours, ratio, 1e-9, "speed-up")
			expect.truthy(active.MeanHours < 6, `active mean {active.MeanHours} h`)
		end,
	},
	{
		Name = "geometric wait helpers are exact for simple cases",
		Run = function()
			expect.near(Stats.waitQuantile(0.5, 0.5), 1, 1e-12, "coin median")
			expect.near(Stats.waitQuantile(1e-12, 0.5), math.log(2) * 1e12, 1e3, "tiny p median")
			expect.equal(Stats.waitMean(0.25), 4, "mean")
		end,
	},
}

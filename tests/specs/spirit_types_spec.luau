-- Spirit types: spawn odds by distance, and every type's settings are sane.

local Config = require("../../src/shared/Config")
local SpiritTypes = require("../../src/shared/SpiritTypes")
local expect = require("../lib/expect")

local options = Config.Spirits

local function counts(radius: number): { [string]: number }
	local found = { Wisp = 0, Restless = 0, Vengeful = 0 }
	for i = 0, 999 do
		local id = SpiritTypes.pick(radius, i / 1000, options :: any)
		found[id] += 1
	end
	return found
end

return {
	{
		Name = "no Vengeful spirits near town, some far out",
		Run = function()
			expect.equal(counts(Config.World.WildInner + 10).Vengeful, 0, "near town")
			local far = counts(Config.World.WildOuter - 10)
			expect.truthy(far.Vengeful >= 150 and far.Vengeful <= 250, "about 1 in 5 far out")
			expect.truthy(far.Wisp < counts(Config.World.WildInner + 10).Wisp, "fewer wisps far out")
		end,
	},
	{
		Name = "stronger types give more rolls and take longer to bind",
		Run = function()
			local last = { Bonus = 0, Hold = 0 }
			for _, id in options.Order do
				local spirit = options.Types[id]
				expect.truthy(spirit.Bonus > last.Bonus, `{id} bonus`)
				expect.truthy(spirit.Hold > last.Hold, `{id} hold`)
				expect.truthy(spirit.Bonus <= options.MaxBonusRolls, `{id} under cap`)
				expect.truthy(Config.HuntStreak.Bands[spirit.Band] ~= nil, `{id} band`)
				last = spirit
			end
		end,
	},
	{
		Name = "unknown type falls back to the first",
		Run = function()
			expect.equal(SpiritTypes.get("Nope", options :: any), options.Types.Wisp, "fallback")
		end,
	},
}

-- Seal ladder (Config.SealLadder) and the Lasting Luck source list.

local Config = require("../../src/shared/Config")
local SealLadder = require("../../src/shared/SealLadder")
local expect = require("../lib/expect")

local ladder = Config.SealLadder

return {
	{
		Name = "12 tiers, strictly rising, starting at x1",
		Run = function()
			expect.equal(#ladder, 12, "tier count")
			expect.equal(ladder[1].Luck, 1, "first tier is free")
			for i = 2, #ladder do
				expect.truthy(ladder[i].Luck > ladder[i - 1].Luck, `tier {i} rises`)
			end
		end,
	},
	{
		Name = "tierFor picks the highest reached tier; nextTier the one after",
		Run = function()
			expect.equal(SealLadder.tierFor(ladder, 1), 1, "x1")
			expect.equal(SealLadder.tierFor(ladder, 0.5), 1, "below x1 still tier 1")
			expect.equal(select(2, SealLadder.tierFor(ladder, 31)).Name, "Jade Seal", "x31")
			expect.equal(SealLadder.tierFor(ladder, 600), 12, "x600")
			expect.equal(SealLadder.tierFor(ladder, 1e9), 12, "huge")
			expect.equal((SealLadder.nextTier(ladder, 31) :: any).Name, "Silver Seal", "next after jade")
			expect.equal(SealLadder.nextTier(ladder, 600), nil, "nothing after eternal")
		end,
	},
	{
		Name = "Lasting Luck counts only permanent sources",
		Run = function()
			local sources = Config.LastingLuck.Sources
			for _, name in { "CoreLuck", "Rebirth", "Pass", "Codex", "Showcase" } do
				expect.truthy(sources[name], `{name} counts`)
			end
			for _, name in { "Potion", "Lightning", "ServerLuck", "Friends", "Debug" } do
				expect.truthy(not sources[name], `{name} is temporary`)
			end
		end,
	},
}

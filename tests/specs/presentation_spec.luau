-- Reveal presentation (GDD 3.2): categories, durations, player modes, queue and announcements.

local Config = require("../../src/shared/Config")
local Presentation = require("../../src/shared/Presentation")
local RarityConfig = require("../../src/shared/RarityConfig")
local expect = require("../lib/expect")

local MEDIUM = RarityConfig.IndexById[Config.Reveal.MediumTier]
local LARGE = RarityConfig.IndexById[Config.Reveal.LargeTier]

local function entry(score: number, name: string): Presentation.Entry
	return { Category = "Medium", Score = score, Seq = 0, Name = name }
end

return {
	{
		Name = "tiers map to the GDD presentation categories",
		Run = function()
			local expected = {
				Common = "Small",
				Uncommon = "Small",
				Rare = "Small",
				Epic = "Medium",
				Legendary = "Medium",
				Mythic = "Medium",
				Celestial = "Large",
				Cosmic = "Large",
			}
			for index, tier in RarityConfig.Tiers do
				expect.equal(Presentation.category(index, MEDIUM, LARGE, true), expected[tier.Id], tier.Id)
			end
		end,
	},
	{
		Name = "repeat finds only get the centre reveal at the Large tiers",
		Run = function()
			for index, tier in RarityConfig.Tiers do
				local expected = if index >= LARGE then "Large" else "Small"
				expect.equal(Presentation.category(index, MEDIUM, LARGE, false), expected, tier.Id)
			end
		end,
	},
	{
		Name = "durations stay inside the GDD ranges, mutation included",
		Run = function()
			local small = Presentation.durations("Small", true, Config.Reveal)
			expect.truthy(small >= 0.3 and small <= 0.6, `small reveal {small}s`)
			for _, mutated in { false, true } do
				local base, extra = Presentation.durations("Medium", mutated, Config.Reveal)
				expect.truthy(base + extra >= 1 and base + extra <= 2, `medium reveal {base + extra}s`)
				base, extra = Presentation.durations("Large", mutated, Config.Reveal)
				expect.truthy(base + extra >= 3 and base + extra <= 5, `large reveal {base + extra}s`)
				expect.equal(extra > 0, mutated, "mutation stage only for mutated finds")
			end
		end,
	},
	{
		Name = "player reveal modes: Short caps at Medium, Off shows only the feed",
		Run = function()
			expect.equal(Presentation.applyMode("Large", "Full"), "Large", "Full")
			expect.equal(Presentation.applyMode("Large", "Short"), "Medium", "Short")
			expect.equal(Presentation.applyMode("Medium", "Short"), "Medium", "Short medium")
			expect.equal(Presentation.applyMode("Large", "Off"), "Small", "Off")
			expect.equal(Presentation.applyMode("Medium", "Off"), "Small", "Off medium")
		end,
	},
	{
		Name = "queue plays earlier rewards first and never reorders",
		Run = function()
			local queue = Presentation.newQueue(3)
			Presentation.push(queue, entry(5, "a"))
			Presentation.push(queue, entry(16, "b"))
			Presentation.push(queue, entry(8, "c"))
			local order = {}
			while true do
				local next = Presentation.pop(queue)
				if not next then
					break
				end
				table.insert(order, next.Name)
			end
			expect.equal(table.concat(order, ","), "a,b,c", "FIFO order")
		end,
	},
	{
		Name = "queue coalesces the least important waiting reveal and counts it",
		Run = function()
			local queue = Presentation.newQueue(2)
			Presentation.push(queue, entry(10, "epic"))
			Presentation.push(queue, entry(16, "cosmic"))
			local dropped = Presentation.push(queue, entry(10, "epic2"))
			expect.equal(dropped and dropped.Name, "epic2", "ties drop the newest")
			dropped = Presentation.push(queue, entry(12, "legendary"))
			expect.equal(dropped and dropped.Name, "epic", "lowest score dropped")
			local first, droppedCount = Presentation.pop(queue)
			expect.equal(first and first.Name, "cosmic", "cosmic kept")
			expect.equal(droppedCount, 2, "dropped count reported once")
			local second, again = Presentation.pop(queue)
			expect.equal(second and second.Name, "legendary", "legendary kept")
			expect.equal(again, 0, "count resets after pop")
		end,
	},
	{
		Name = "mutated finds outrank plain finds of the same tier only",
		Run = function()
			expect.truthy(Presentation.score(4, true) > Presentation.score(4, false), "mutated wins within tier")
			expect.truthy(Presentation.score(5, false) > Presentation.score(4, true), "higher tier wins")
		end,
	},
	{
		Name = "only very rare finds are announced to the server",
		Run = function()
			local minIndex = RarityConfig.IndexById[Config.Announce.MinTier]
			local mutatedIndex = RarityConfig.IndexById[Config.Announce.MutatedMinTier]
			for index, tier in RarityConfig.Tiers do
				local plain = Presentation.announces(index, false, minIndex, mutatedIndex)
				local mutated = Presentation.announces(index, true, minIndex, mutatedIndex)
				expect.equal(plain, index >= minIndex, `{tier.Id} plain`)
				expect.equal(mutated, index >= mutatedIndex, `{tier.Id} mutated`)
			end
			expect.truthy(not Presentation.announces(1, true, minIndex, mutatedIndex), "mutated Common never announced")
		end,
	},
}

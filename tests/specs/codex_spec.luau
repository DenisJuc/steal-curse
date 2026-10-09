-- Codex rules (GDD 7): essential rewards come only from attainable base relics, milestones are
-- never revoked, and the essential set can be finished in reasonable time.

local Codex = require("../../src/shared/Codex")
local CodexConfig = require("../../src/shared/CodexConfig")
local Config = require("../../src/shared/Config")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local expect = require("../lib/expect")
local rules = require("../lib/rules")

local book = Codex.build(CodexConfig, RelicConfig.Relics, RarityConfig.Tiers, RelicConfig.Families)
local MAX_INDEX = RarityConfig.IndexById[CodexConfig.EssentialMaxTier]

local function tierIndexOf(relicId: string): number
	return RarityConfig.IndexById[RelicConfig.ById[relicId].Tier]
end

local function emptyState(): Codex.State
	return { Discovered = {}, Mutations = {} }
end

return {
	{
		Name = "no essential reward references a relic above the pool tier or any mutation",
		Run = function()
			expect.truthy(#book.Pool > 0, "essential pool is empty")
			for _, relicId in book.Pool do
				expect.truthy(tierIndexOf(relicId) <= MAX_INDEX, `{relicId} is above {CodexConfig.EssentialMaxTier}`)
			end
			for _, milestone in book.Milestones do
				local rewardsPower = milestone.Luck > 0 or milestone.Income > 0
				if rewardsPower then
					expect.equal(milestone.Kind, "Essential", `{milestone.Id} gives power but is not essential`)
				end
				if milestone.Kind == "Essential" or milestone.Kind == "Frequency" then
					for _, relicId in milestone.Pool do
						expect.truthy(book.PoolSet[relicId], `{milestone.Id} counts unattainable {relicId}`)
					end
				end
			end
		end,
	},
	{
		Name = "essential thresholds fit the pool, rise, and total +50% Luck",
		Run = function()
			local previous, luck = 0, 0
			for _, milestone in book.Milestones do
				if milestone.Kind == "Essential" then
					expect.truthy(milestone.Need >= 1 and milestone.Need <= #book.Pool, `{milestone.Id} need {milestone.Need}`)
					expect.truthy(milestone.Need >= previous, `{milestone.Id} threshold goes down`)
					previous = milestone.Need
					luck += milestone.Luck
				end
			end
			expect.equal(previous, #book.Pool, "last essential milestone needs the whole pool")
			expect.near(luck, Config.Luck.CodexMaxBonus, 1e-9, "total Codex luck")
			expect.equal(Codex.threshold(0.2, 7), 2, "ceil(1.4)")
			expect.equal(Codex.threshold(0.4, 5), 2, "exact fractions don't round up")
			expect.equal(Codex.threshold(0.01, 7), 1, "at least one")
			expect.equal(Codex.threshold(0.5, 0), 0, "empty pool")
		end,
	},
	{
		Name = "a mutated-only find counts for its base entry and essential milestones",
		Run = function()
			local state = emptyState()
			for _, relicId in book.Pool do
				-- The pipeline records every find (mutated or not) under its base id.
				state.Discovered[relicId] = 1
				state.Mutations[relicId] = { Abyssal = 1 }
			end
			for _, milestone in book.Milestones do
				if milestone.Kind == "Essential" then
					expect.equal(Codex.progress(milestone, state), #book.Pool, `{milestone.Id} progress`)
				end
			end
			local luck = Codex.bonuses(book, (function()
				local claimed = {}
				for _, id in Codex.earned(book, state) do
					claimed[id] = 1
				end
				return claimed
			end)())
			expect.near(luck, Config.Luck.CodexMaxBonus, 1e-9, "mutated-only finds earn every essential bonus")
		end,
	},
	{
		Name = "every family frequency is reachable from attainable relics",
		Run = function()
			local unlocked = Codex.unlockedFrequencies(book, {})
			for _, set in book.Sets do
				local milestone = book.ById[`Frequency_{set.Family}`]
				expect.truthy(milestone, `no frequency milestone for {set.Family}`)
				expect.truthy(milestone.Need <= #set.Attainable, `{set.Family} needs more than it has`)
				if #set.Attainable == 0 then
					expect.truthy(unlocked[set.Family], `{set.Family} has no attainable relics, so it starts unlocked`)
				else
					expect.truthy(milestone.Need < #set.Attainable or #set.Attainable == 1, `{set.Family} unlock should be partial`)
					expect.truthy(not unlocked[set.Family], `{set.Family} should start locked`)
				end
			end
		end,
	},
	{
		Name = "claimed milestones are never revoked when the roster grows",
		Run = function()
			local state = emptyState()
			for _, relicId in book.Pool do
				state.Discovered[relicId] = 1
			end
			local claimed = {}
			for _, id in Codex.earned(book, state) do
				claimed[id] = 1
			end
			local luckBefore, incomeBefore = Codex.bonuses(book, claimed)

			local bigger = table.clone(RelicConfig.Relics)
			for index = 1, 20 do
				table.insert(bigger, { Id = `Extra{index}`, Tier = "Common", Family = "Demonic" })
			end
			local biggerBook = Codex.build(CodexConfig, bigger :: any, RarityConfig.Tiers, RelicConfig.Families)
			local luckAfter, incomeAfter = Codex.bonuses(biggerBook, claimed)
			expect.near(luckAfter, luckBefore, 1e-12, "luck kept")
			expect.near(incomeAfter, incomeBefore, 1e-12, "income kept")
			expect.truthy(
				#Codex.earned(biggerBook, state) < #Codex.earned(book, state),
				"the bigger roster raises thresholds (so only saved claims keep the rewards)"
			)
			local _, unknownIncome = Codex.bonuses(book, { Removed = 1 })
			expect.equal(unknownIncome, 0, "unknown milestone ids are ignored")
		end,
	},
	{
		Name = "only claimed milestones give rewards; open milestones never need claiming",
		Run = function()
			local state = emptyState()
			for _, relicId in book.Pool do
				state.Discovered[relicId] = 1
			end
			local luck = Codex.bonuses(book, {})
			expect.equal(luck, 0, "reached but unclaimed milestones give nothing")
			for _, id in Codex.earned(book, state) do
				expect.truthy(book.ById[id].Need > 0, `{id} needs nothing but is listed as claimable`)
			end
			local text = Codex.combinedRewardText({ book.ById.Essential20, book.ById.Essential40 })
			expect.equal(text, "+15% Luck, +5% CE income", "combined reward text")
		end,
	},
	{
		Name = "coupon-collector helper matches exact cases",
		Run = function()
			expect.near(Codex.expectedCollectionRolls({ 0.25 }), 4, 0.01, "one item: 1/p")
			expect.near(Codex.expectedCollectionRolls({ 0.1, 0.1 }), 15, 0.05, "two equal items: 1.5/p")
			-- Two unequal items: 1/p + 1/q - 1/(p+q).
			expect.near(Codex.expectedCollectionRolls({ 0.5, 0.01 }), 2 + 100 - 1 / 0.51, 0.2, "unequal items")
			expect.equal(Codex.expectedCollectionRolls({}), 0, "nothing to collect")
		end,
	},
	{
		Name = "essential set finishes within the target at mid-game luck with matching focus",
		Run = function()
			local totalRolls = 0
			for _, tier in RarityConfig.Tiers do
				local probabilities = {}
				local ctx = RollMath.contextFor(rules, { FullLuck = CodexConfig.ReferenceLuck, RarityFocus = tier.Id })
				for _, relicId in book.Pool do
					if RelicConfig.ById[relicId].Tier == tier.Id then
						table.insert(probabilities, RollMath.itemProbability(ctx, relicId))
					end
				end
				totalRolls += Codex.expectedCollectionRolls(probabilities)
			end
			local hours = totalRolls * CodexConfig.ReferenceScanSeconds / 3600
			print(string.format("        essential Codex: %.0f rolls, about %.2f h at the reference", totalRolls, hours))
			expect.truthy(hours <= CodexConfig.EssentialTargetHours, `essential Codex takes {hours} h`)
		end,
	},
}

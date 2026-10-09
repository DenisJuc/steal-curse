-- Config sanity: tiers, relic roster and placeholder rules.

local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local expect = require("../lib/expect")

return {
	{
		Name = "config has no validation problems",
		Run = function()
			local problems = RollMath.validate(RarityConfig.Tiers, RelicConfig.Relics)
			expect.equal(#problems, 0, table.concat(problems, "; "))
		end,
	},
	{
		Name = "eight tiers in GDD order",
		Run = function()
			local expected = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Cosmic" }
			expect.equal(#RarityConfig.Tiers, #expected, "tier count")
			for index, id in expected do
				expect.equal(RarityConfig.Tiers[index].Id, id, `tier {index}`)
			end
		end,
	},
	{
		Name = "the roster has 92 relics, every tier filled, rarer tiers never larger",
		Run = function()
			expect.equal(#RelicConfig.Relics, 92, "relic count")
			local byTier = RollMath.groupByTier(RelicConfig.Relics)
			local previous = math.huge
			for _, tier in RarityConfig.Tiers do
				local count = byTier[tier.Id] and #byTier[tier.Id] or 0
				expect.truthy(count >= 1, `tier {tier.Id} has a relic`)
				expect.truthy(count <= previous, `{tier.Id} has more relics than the tier below it`)
				previous = count
			end
		end,
	},
	{
		Name = "in-tier weights are all different and no relic falls below 40% of an even share",
		Run = function()
			for tierId, relics in RollMath.groupByTier(RelicConfig.Relics) do
				local seen, total = {}, 0
				for _, relic in relics do
					expect.truthy(not seen[relic.Weight], `{tierId} weight {relic.Weight} is used twice`)
					seen[relic.Weight] = true
					total += relic.Weight
				end
				for _, relic in relics do
					local share = relic.Weight / total
					expect.truthy(share >= 0.4 / #relics, `{relic.Id} share {share} is below the minimum`)
				end
			end
		end,
	},
	{
		Name = "every relic uses a known family, object type and VFX profile, with unique names",
		Run = function()
			local function set(list: { string }): { [string]: boolean }
				local result = {}
				for _, value in list do
					result[value] = true
				end
				return result
			end
			local families, objectTypes, vfx = set(RelicConfig.Families), set(RelicConfig.ObjectTypes), set(RelicConfig.VfxProfiles)
			local names = {}
			for _, relic in RelicConfig.Relics do
				expect.truthy(families[relic.Family], `{relic.Id} family {relic.Family}`)
				expect.truthy(objectTypes[relic.ObjectType], `{relic.Id} object type {relic.ObjectType}`)
				expect.truthy(vfx[relic.Vfx], `{relic.Id} VFX profile {relic.Vfx}`)
				expect.truthy(RelicConfig.ById[relic.Id] == relic, `{relic.Id} lookup`)
				expect.truthy(not names[relic.Name], `name {relic.Name} is used twice`)
				names[relic.Name] = true
				expect.truthy(#relic.Description > 0, `{relic.Id} has no lore line`)
			end
		end,
	},
	{
		Name = "the roster is not dominated by weapons and every family has essential relics",
		Run = function()
			local weapons = 0
			for tierId, relics in RollMath.groupByTier(RelicConfig.Relics) do
				local types = {}
				for _, relic in relics do
					types[relic.ObjectType] = (types[relic.ObjectType] or 0) + 1
				end
				for objectType, count in types do
					expect.truthy(#relics < 4 or count <= #relics / 2, `{tierId} is mostly {objectType}`)
				end
				weapons += types.Weapon or 0
			end
			expect.truthy(weapons <= #RelicConfig.Relics / 3, `{weapons} weapons out of {#RelicConfig.Relics}`)

			local legendary = RarityConfig.IndexById.Legendary
			local perFamily = {}
			for _, relic in RelicConfig.Relics do
				if RarityConfig.IndexById[relic.Tier] <= legendary then
					perFamily[relic.Family] = (perFamily[relic.Family] or 0) + 1
				end
			end
			for _, family in RelicConfig.Families do
				expect.truthy((perFamily[family] or 0) >= 12, `{family} has only {perFamily[family] or 0} essential relics`)
			end
		end,
	},
	{
		Name = "mutations unlock in GDD order, one per rank, with rising total chance",
		Run = function()
			local expected = { "Golden", "Corrupted", "Bloodmoon", "Divine", "Abyssal" }
			expect.equal(#MutationConfig.Mutations, #expected, "mutation count")
			for index, id in expected do
				local mutation = MutationConfig.Mutations[index]
				expect.equal(mutation.Id, id, `mutation {index}`)
				expect.equal(mutation.UnlockRank, index, `{id} unlock rank`)
				expect.truthy(mutation.Weight > 0, `{id} weight`)
			end
			expect.equal(MutationConfig.ChanceAt(0), 0, "rank 0 chance")
			for rank = 1, MutationConfig.MaxRank do
				expect.truthy(MutationConfig.ChanceAt(rank) > MutationConfig.ChanceAt(rank - 1), `rank {rank} rises`)
			end
			expect.equal(MutationConfig.ChanceAt(MutationConfig.MaxRank), 0.5, "max chance")
		end,
	},
}

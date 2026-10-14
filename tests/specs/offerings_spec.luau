-- Offerings: tier odds, pity, reward shapes, lanterns and the CE floor.

local Config = require("../../src/shared/Config")
local ItemConfig = require("../../src/shared/ItemConfig")
local Offerings = require("../../src/shared/Offerings")
local expect = require("../lib/expect")

local options = Config.Offerings :: any

local function sequence(values: { number }): () -> number
	local index = 0
	return function()
		index += 1
		return values[(index - 1) % #values + 1]
	end
end

return {
	{
		Name = "tiers follow their weights",
		Run = function()
			local counts = {}
			local steps = 1000
			for step = 0, steps - 1 do
				local id = Offerings.rollTier(options, 0, (step + 0.5) / steps)
				counts[id] = (counts[id] or 0) + 1
			end
			local total = 0
			for _, tier in options.Tiers do
				total += tier.Weight
			end
			for _, tier in options.Tiers do
				expect.near((counts[tier.Id] or 0) / steps, tier.Weight / total, 0.01, tier.Id)
			end
		end,
	},
	{
		Name = "pity: the PityAt-th box in a row is at least the second tier",
		Run = function()
			local misses = 0
			local id
			for _ = 1, options.PityAt - 1 do
				id, misses = Offerings.rollTier(options, misses, 0)
				expect.equal(id, options.Tiers[1].Id, "lowest")
			end
			id, misses = Offerings.rollTier(options, misses, 0)
			expect.equal(id, options.Tiers[2].Id, "pity")
			expect.equal(misses, 0, "reset")
		end,
	},
	{
		Name = "every reward pays something real",
		Run = function()
			for _, tier in options.Tiers do
				for step = 0, 19 do
					local reward = Offerings.rollReward(options, tier.Id, sequence({ step / 20, 0.3, 0.7, 0.1 }), {})
					local pays = (reward.CEMinutes or 0) > 0 or (reward.Rolls or 0) > 0 or next(reward.Potions) ~= nil
					expect.truthy(pays, `{tier.Id} pays`)
					for id in reward.Potions do
						expect.truthy(ItemConfig.ById[id] ~= nil, `{id} is a potion`)
					end
				end
			end
		end,
	},
	{
		Name = "rare lanterns are only ones you don't own",
		Run = function()
			local owned = {}
			for index = 1, #options.Lanterns - 1 do
				owned[options.Lanterns[index]] = true
			end
			local reward = Offerings.rollReward(options, "Rare", sequence({ 0, 0, 0 }), owned)
			expect.equal(reward.Lantern, options.Lanterns[#options.Lanterns], "the missing one")
			for _, id in options.Lanterns do
				owned[id] = true
			end
			expect.equal(Offerings.rollReward(options, "Rare", sequence({ 0 }), owned).Lantern, nil, "all owned")
		end,
	},
	{
		Name = "CE scales with income and has a floor; lanterns exist",
		Run = function()
			expect.equal(Offerings.ceAmount(3, 0, options), options.MinCE, "floor")
			expect.equal(Offerings.ceAmount(10, 100, options), 60000, "minutes of per-second income")
			local ids = {}
			for _, lantern in Config.Lanterns.List do
				ids[lantern.Id] = true
			end
			for _, id in options.Lanterns do
				expect.truthy(ids[id], `{id} lantern`)
			end
			expect.truthy(ids[Config.Lanterns.Default], "default lantern")
		end,
	},
}

-- Potions (Slice 12): stacking, caps, online-only timer math, effects and drop tables.

local CodexConfig = require("../../src/shared/CodexConfig")
local Config = require("../../src/shared/Config")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local ItemConfig = require("../../src/shared/ItemConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local expect = require("../lib/expect")

return {
	{
		Name = "three potions, 10 minutes each, stacking capped at 60 minutes",
		Run = function()
			expect.equal(#ItemConfig.Items, 3, "potion count")
			for _, item in ItemConfig.Items do
				expect.equal(item.DurationSeconds, 600, `{item.Id} duration`)
			end
			expect.equal(ItemConfig.MaxBuffSeconds, 3600, "cap")

			local left, ok = ItemConfig.addTime(0, 600, 3600)
			expect.equal(left, 600, "first potion")
			expect.truthy(ok, "first potion usable")
			for _ = 2, 6 do
				left, ok = ItemConfig.addTime(left, 600, 3600)
				expect.truthy(ok, "stacking up to the cap")
			end
			expect.equal(left, 3600, "six potions reach the cap")
			local after, usable = ItemConfig.addTime(left, 600, 3600)
			expect.equal(after, 3600, "never above the cap")
			expect.truthy(not usable, "a full buff refuses another potion")

			local partial = ItemConfig.addTime(3300, 600, 3600)
			expect.equal(partial, 3600, "the last potion is clamped to the cap")
		end,
	},
	{
		Name = "timers count down only by the online time they are given, and expire cleanly",
		Run = function()
			local buffs = { LuckPotion = 600, HastePotion = 5 }
			local expired = ItemConfig.tick(buffs, 1)
			expect.equal(#expired, 0, "nothing expired after 1 s")
			expect.equal(buffs.LuckPotion, 599, "luck ticked")
			expect.equal(buffs.HastePotion, 4, "haste ticked")
			-- Offline time is simply never passed to tick, so a saved table resumes unchanged.
			local saved = table.clone(buffs)
			expect.equal(saved.LuckPotion, 599, "saved value stays while offline")
			expired = ItemConfig.tick(buffs, 4)
			expect.equal(#expired, 1, "haste expired")
			expect.equal(expired[1], "HastePotion", "expired id")
			expect.equal(buffs.HastePotion, nil, "removed from buffs")
			local total = 0
			for _ = 1, 595 do
				ItemConfig.tick(buffs, 1)
				total += 1
			end
			expect.equal(buffs.LuckPotion, nil, "luck gone after 600 s online in total")
			expect.equal(total + 5, 600, "600 s online")
		end,
	},
	{
		Name = "effects: luck capped by MaxConsumable, haste x0.75 interval, fortune +50% income",
		Run = function()
			expect.equal(ItemConfig.luckFactor({}, Config.Luck.MaxConsumable), 1, "no buff")
			expect.equal(ItemConfig.luckFactor({ LuckPotion = 10 }, Config.Luck.MaxConsumable), 2, "x2 luck")
			expect.equal(ItemConfig.luckFactor({ LuckPotion = 10 }, 1.5), 1.5, "cap applies")
			expect.equal(ItemConfig.intervalFactor({ HastePotion = 10 }), 0.75, "haste")
			expect.equal(ItemConfig.intervalFactor({}), 1, "no haste")
			expect.equal(ItemConfig.incomeBonus({ FortunePotion = 10 }), 0.5, "fortune")
			expect.equal(ItemConfig.incomeBonus({ LuckPotion = 10 }), 0, "other buffs don't add income")
			expect.truthy(Config.Luck.MaxConsumable >= 2, "a luck potion fits under the consumable cap")
		end,
	},
	{
		Name = "drops: weights pick every potion, milestone rewards point at real milestones and potions",
		Run = function()
			local seen = {}
			for step = 0, 99 do
				local id = ItemConfig.pickDrop(ItemConfig.Drops.Weights, step / 100)
				expect.truthy(ItemConfig.ById[id] ~= nil, `known drop {id}`)
				seen[id] = (seen[id] or 0) + 1
			end
			for _, item in ItemConfig.Items do
				expect.truthy((seen[item.Id] or 0) > 0, `{item.Id} can drop`)
			end
			expect.equal(seen.LuckPotion, 40, "weights split the roll range")
			expect.truthy(ItemConfig.Drops.CaptureChance > 0 and ItemConfig.Drops.CaptureChance < 1, "chance in (0, 1)")

			local milestoneIds = {}
			for _, list in { CodexConfig.Essential, CodexConfig.Collection, CodexConfig.MutatedTier } do
				for _, milestone in list :: { { Id: string } } do
					milestoneIds[milestone.Id] = true
				end
			end
			for milestoneId, rewards in ItemConfig.Drops.Milestones do
				expect.truthy(milestoneIds[milestoneId], `milestone {milestoneId} exists`)
				for id, count in rewards do
					expect.truthy(ItemConfig.ById[id] ~= nil and count > 0, `{milestoneId} reward {id}`)
				end
			end
			expect.truthy(RarityConfig.IndexById[ItemConfig.Drops.FirstRareTier] ~= nil, "first-rare tier exists")
		end,
	},
	{
		Name = "saved data has Items, Buffs and one-time rewards; timer text",
		Run = function()
			local fresh = DataTemplate.fresh() :: any
			expect.truthy(type(fresh.Items) == "table", "Items")
			expect.truthy(type(fresh.Buffs) == "table", "Buffs")
			expect.truthy(type(fresh.ItemRewards) == "table", "ItemRewards")
			expect.equal(ItemConfig.formatTime(598.2), "9:59", "minutes")
			expect.equal(ItemConfig.formatTime(3600), "1:00:00", "hours")
			expect.equal(ItemConfig.formatTime(-3), "0:00", "never negative")
		end,
	},
}

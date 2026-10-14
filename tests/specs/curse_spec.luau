-- Lift the Curse: progress, purified zones, titles, the zone bonus and rewards.

local Config = require("../../src/shared/Config")
local Curse = require("../../src/shared/Curse")
local WildLayout = require("../../src/shared/WildLayout")
local expect = require("../lib/expect")

local options = Config.Curse :: any
local shrines = WildLayout.CursedShrines

local function cleanseArea(cleansed: { [string]: number }, area: string, count: number)
	local done = 0
	for _, shrine in shrines do
		if shrine.Area == area and done < count then
			cleansed[shrine.Id] = 1
			done += 1
		end
	end
end

return {
	{
		Name = "progress and fog lift count only that zone's shrines",
		Run = function()
			local cleansed = {}
			cleanseArea(cleansed, "HauntedForest", 3)
			local done, total = Curse.progress(cleansed, shrines, "HauntedForest")
			expect.equal(done, 3, "three cleansed")
			expect.equal(total, 5, "five in the zone")
			expect.near(Curse.lifted(cleansed, shrines, "HauntedForest"), 0.6, 1e-9, "60% lifted")
			expect.equal(Curse.lifted(cleansed, shrines, "AncientRuins"), 0, "other zones untouched")
			expect.equal(Curse.purified(cleansed, shrines, "HauntedForest"), false, "not purified yet")
		end,
	},
	{
		Name = "a purified zone gives its title and a capped-in bonus",
		Run = function()
			local cleansed = {}
			cleanseArea(cleansed, "AbandonedVillage", 5)
			expect.equal(Curse.purified(cleansed, shrines, "AbandonedVillage"), true, "purified")
			local titles = Curse.titles(cleansed, shrines, options)
			expect.equal(titles.AbandonedVillage, options.Zones.AbandonedVillage.Title, "village title")
			expect.equal(titles.HauntedForest, nil, "no forest title")
			expect.equal(Curse.bonus(cleansed, shrines, "AbandonedVillage", options), options.PurifiedBonus, "bonus there")
			expect.equal(Curse.bonus(cleansed, shrines, "AncientRuins", options), 1, "no bonus elsewhere")
			expect.truthy(options.PurifiedBonus > 1 and options.PurifiedBonus <= 1.25, "small bonus")
		end,
	},
	{
		Name = "rewards: CE from income with a floor; every shrine has lore; zone lanterns exist",
		Run = function()
			expect.equal(Curse.ceReward(0, options), options.MinCE, "floor for new players")
			expect.equal(Curse.ceReward(1000, options), math.floor(options.CEMinutes * 60 * 1000), "minutes of income")
			for _, shrine in shrines do
				expect.truthy(type(options.Lore[shrine.Id]) == "string", `{shrine.Id} has lore`)
			end
			local lanterns = {}
			for _, lantern in Config.Lanterns.List do
				lanterns[lantern.Id] = true
			end
			for _, area in Config.Areas do
				local zone = options.Zones[area.Id]
				expect.truthy(zone and lanterns[zone.Lantern], `{area.Id} purify lantern exists`)
			end
		end,
	},
}

-- Zone mastery: XP, levels, zone perks, unlocks and titles.

local Config = require("../../src/shared/Config")
local ShowcaseConfig = require("../../src/shared/ShowcaseConfig")
local Titles = require("../../src/shared/Titles")
local ZoneMastery = require("../../src/shared/ZoneMastery")
local expect = require("../lib/expect")

local options = Config.Mastery :: any

return {
	{
		Name = "deeper captures give more XP; levels rise with total XP",
		Run = function()
			expect.equal(ZoneMastery.xpFor("Edge", options), 1, "edge")
			expect.equal(ZoneMastery.xpFor("Deep", options), 2, "deep")
			expect.equal(ZoneMastery.xpFor("Heart", options), 3, "heart")
			expect.equal(#options.Levels, 10, "ten levels")
			for index = 2, #options.Levels do
				expect.truthy(options.Levels[index] > options.Levels[index - 1], `level {index} needs more XP`)
			end
			local level, into, size = ZoneMastery.level(0, options)
			expect.equal(level, 0, "no XP")
			expect.equal(into, 0, "nothing into level 1")
			expect.equal(size, options.Levels[1], "level 1 size")
			level, into, size = ZoneMastery.level(options.Levels[3] + 1, options)
			expect.equal(level, 3, "just past level 3")
			expect.equal(into, 1, "1 XP into level 4")
			expect.equal(size, options.Levels[4] - options.Levels[3], "level 4 size")
			level, _, size = ZoneMastery.level(options.Levels[10] * 2, options)
			expect.equal(level, 10, "capped at 10")
			expect.equal(size, 0, "no next level")
		end,
	},
	{
		Name = "perks: bind time at 2 and 6, sight range at 4, streak time at 8",
		Run = function()
			local none = ZoneMastery.perks(1, options)
			expect.equal(none.Hold, 1, "no hold perk yet")
			expect.equal(none.Pulse, 1, "no range perk yet")
			expect.equal(none.Idle, 0, "no idle perk yet")
			expect.near(ZoneMastery.perks(2, options).Hold, 0.95, 1e-9, "level 2")
			expect.near(ZoneMastery.perks(4, options).Pulse, 1.15, 1e-9, "level 4")
			expect.near(ZoneMastery.perks(6, options).Hold, 0.9, 1e-9, "level 6")
			local all = ZoneMastery.perks(10, options)
			expect.equal(all.Idle, 15, "level 8")
			expect.near(all.Hold, 0.9, 1e-9, "hold stays")
			expect.equal(ZoneMastery.nextPerk(4, options).Level, 6, "next perk after 4")
			expect.equal(ZoneMastery.nextPerk(8, options), nil, "none after the last")
			expect.truthy(ZoneMastery.perkText(options.Perks[1]) ~= "", "perk text")
		end,
	},
	{
		Name = "every zone has three real lanterns, a title and a mastery Showcase",
		Run = function()
			local lanterns = {}
			for _, lantern in Config.Lanterns.List do
				lanterns[lantern.Id] = true
			end
			for _, area in Config.Areas do
				local zone = options.Zones[area.Id]
				expect.truthy(zone, `{area.Id} has mastery rewards`)
				expect.equal(#zone.Lanterns, 3, `{area.Id} lanterns`)
				for _, lantern in zone.Lanterns do
					expect.truthy(lanterns[lantern.Id], `{lantern.Id} exists`)
				end
				local showcase = ShowcaseConfig.ById[zone.Showcase]
				expect.truthy(showcase, `{zone.Showcase} exists`)
				expect.equal(showcase.Unlock.Kind, "Mastery", "unlocked by mastery")
				expect.equal(showcase.Unlock.Area, area.Id, "its own zone")
				expect.equal(showcase.Unlock.Level, options.ShowcaseAt, "at the Showcase level")
			end
		end,
	},
	{
		Name = "unlocks only what was crossed; mastery titles from level 9",
		Run = function()
			local unlocks = ZoneMastery.unlocks("HauntedForest", 2, 5, options)
			expect.equal(#unlocks.Lanterns, 2, "levels 3 and 5")
			expect.equal(unlocks.Title, nil, "no title yet")
			unlocks = ZoneMastery.unlocks("HauntedForest", 8, 10, options)
			expect.equal(#unlocks.Lanterns, 0, "no lanterns past 7")
			expect.equal(unlocks.Title, "Forest Warden", "title at 9")
			expect.equal(unlocks.Showcase, "ForestGrove", "Showcase at 10")
			expect.equal(#ZoneMastery.unlocks("HauntedForest", 5, 5, options).Lanterns, 0, "nothing without a level up")

			local order = { "HauntedForest", "AbandonedVillage", "AncientRuins" }
			expect.equal(#ZoneMastery.titles({}, order, options), 0, "no title")
			local titles = ZoneMastery.titles({ AncientRuins = 9, HauntedForest = 10, AbandonedVillage = 8 }, order, options)
			expect.equal(#titles, 2, "level 9+ only")
			expect.equal(titles[1], "Forest Warden", "zone order")
			expect.equal(titles[2], "Ruins Seer", "ruins title")
		end,
	},
	{
		Name = "titles: earned list keeps source order; the choice can be Auto, Off or an earned title",
		Run = function()
			local earned = Titles.earned({ { "Village Purifier" }, { "Forest Warden", "Village Purifier" }, { "Collector" } })
			expect.equal(#earned, 3, "no duplicates")
			expect.equal(earned[1], "Village Purifier", "best source first")
			expect.equal(Titles.shown(Titles.Auto, earned), "Village Purifier", "auto shows the first")
			expect.equal(Titles.shown(Titles.Off, earned), nil, "off hides it")
			expect.equal(Titles.shown("Collector", earned), "Collector", "picked title")
			expect.equal(Titles.shown("Ruins Seer", earned), "Village Purifier", "lost title falls back to auto")
			expect.equal(Titles.shown(Titles.Auto, {}), nil, "nothing earned")
			expect.truthy(Titles.valid("Collector", earned), "earned is valid")
			expect.truthy(Titles.valid(Titles.Off, earned), "off is valid")
			expect.truthy(not Titles.valid("Ruins Seer", earned), "unearned is not")
			expect.truthy(not Titles.valid(5, earned), "wrong type")
		end,
	},
	{
		Name = "titles: the catalog lists each title once, earned first, then closest to done",
		Run = function()
			local function entry(title: string, have: number, need: number, earned: boolean): Titles.Entry
				return { Title = title, Source = title .. " source", Have = have, Need = need, Unit = "x", Earned = earned }
			end
			local catalog = Titles.catalog({
				{ entry("Purifier", 1, 5, false), entry("Cleanser", 5, 5, true) },
				{ entry("Warden", 8, 9, false), entry("Purifier", 9, 9, true) },
				{ entry("Collector", 0, 10, false), entry("Seer", 9, 9, true) },
			})
			expect.equal(#catalog, 5, "Purifier only once")
			expect.equal(catalog[1].Title, "Cleanser", "earned first, source order")
			expect.equal(catalog[2].Title, "Seer", "second earned")
			expect.equal(catalog[3].Title, "Warden", "8/9 is closest")
			expect.equal(catalog[4].Title, "Purifier", "first source wins (1/5)")
			expect.equal(catalog[4].Earned, false, "kept the first source's state")
			expect.equal(catalog[5].Title, "Collector", "0/10 last")
		end,
	},
}

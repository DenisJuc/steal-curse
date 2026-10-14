-- Showcases (GDD 6.7, 10.2): equal stats at equal levels, only the active one buffs, switching
-- moves the buff, unlock conditions and accessories.

local Codex = require("../../src/shared/Codex")
local CodexConfig = require("../../src/shared/CodexConfig")
local Config = require("../../src/shared/Config")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local ShowcaseConfig = require("../../src/shared/ShowcaseConfig")
local Showcases = require("../../src/shared/Showcases")
local expect = require("../lib/expect")

local LEVELS = ShowcaseConfig.Levels

local function state(active: string, owned: { [string]: number }): Showcases.State
	return { Active = active, Owned = owned, AccessoriesOff = {} }
end

return {
	{
		Name = "level table matches the GDD (+2/5/10/15% income, +1/3/5/10% luck, 5K/250K/5M)",
		Run = function()
			local income = { 0.02, 0.05, 0.10, 0.15 }
			local luck = { 0.01, 0.03, 0.05, 0.10 }
			local costs = { nil, 200000, 20000000, 2000000000 }
			expect.equal(ShowcaseConfig.MaxLevel, 4, "max level")
			for level = 1, 4 do
				expect.equal(LEVELS[level].Income, income[level], `income at level {level}`)
				expect.equal(LEVELS[level].Luck, luck[level], `luck at level {level}`)
				expect.equal(Showcases.upgradeCost(LEVELS, level - 1), costs[level], `cost to reach level {level}`)
			end
			expect.equal(Showcases.upgradeCost(LEVELS, 4), nil, "max level has no upgrade")
			expect.equal(LEVELS[4].Luck, Config.Luck.ShowcaseMaxBonus, "Config.Luck.ShowcaseMaxBonus")
		end,
	},
	{
		Name = "every Showcase gives equal stats at equal levels",
		Run = function()
			expect.equal(#ShowcaseConfig.Showcases, 6, "three prototypes and three zone Showcases")
			for level = 1, ShowcaseConfig.MaxLevel do
				local firstIncome, firstLuck = nil, nil
				for _, showcase in ShowcaseConfig.Showcases do
					local income, luck = Showcases.bonus(state(showcase.Id, { [showcase.Id] = level }), LEVELS)
					firstIncome = firstIncome or income
					firstLuck = firstLuck or luck
					expect.equal(income, firstIncome, `{showcase.Id} income at level {level}`)
					expect.equal(luck, firstLuck, `{showcase.Id} luck at level {level}`)
				end
			end
		end,
	},
	{
		Name = "only the active Showcase buffs; buffs never stack",
		Run = function()
			local owned = { SimpleStance = 4, CrimsonThrone = 3, GoldenGuardian = 2 }
			local income, luck = Showcases.bonus(state("CrimsonThrone", owned), LEVELS)
			expect.equal(income, LEVELS[3].Income, "active income only")
			expect.equal(luck, LEVELS[3].Luck, "active luck only")
			income, luck = Showcases.bonus(state("", owned), LEVELS)
			expect.equal(income, 0, "no active, no income")
			expect.equal(luck, 0, "no active, no luck")
			income = Showcases.bonus(state("GoldenGuardian", { SimpleStance = 4 }), LEVELS)
			expect.equal(income, 0, "an unowned active Showcase gives nothing")
		end,
	},
	{
		Name = "switching the active Showcase moves the buff at once, without penalty",
		Run = function()
			local current = state("SimpleStance", { SimpleStance = 3, CrimsonThrone = 3 })
			local before = Showcases.bonus(current, LEVELS)
			current.Active = "CrimsonThrone"
			local after = Showcases.bonus(current, LEVELS)
			expect.equal(after, before, "same level, same buff after switching")
			expect.equal(current.Owned.SimpleStance, 3, "switching keeps the old level")
			current.Owned.CrimsonThrone = 1
			expect.equal(Showcases.bonus(current, LEVELS), LEVELS[1].Income, "buff follows the active level")
			current.Active = "SimpleStance"
			expect.equal(Showcases.bonus(current, LEVELS), LEVELS[3].Income, "switching back restores it")
		end,
	},
	{
		Name = "unlocks: one by CE, one by a relic, one by a Codex milestone; all targets exist",
		Run = function()
			local book = Codex.build(CodexConfig, RelicConfig.Relics, RarityConfig.Tiers, RelicConfig.Families)
			local kinds = {}
			for _, showcase in ShowcaseConfig.Showcases do
				local unlock = showcase.Unlock
				kinds[unlock.Kind] = true
				if unlock.Kind == "CE" then
					expect.truthy(unlock.Price and unlock.Price > 0, `{showcase.Id} price`)
				elseif unlock.Kind == "Relic" then
					expect.truthy(RelicConfig.ById[unlock.RelicId :: string], `{showcase.Id} relic exists`)
				elseif unlock.Kind == "Mastery" then
					expect.truthy(unlock.Area and unlock.Level and unlock.Level >= 1, `{showcase.Id} mastery goal`)
				else
					expect.truthy(book.ById[unlock.Milestone :: string], `{showcase.Id} milestone exists`)
				end
				for _, accessory in showcase.Accessories do
					expect.truthy(RelicConfig.ById[accessory.RelicId], `{accessory.Id} relic exists`)
					expect.equal(ShowcaseConfig.AccessoryOwner[accessory.Id], showcase.Id, `{accessory.Id} owner`)
				end
			end
			expect.truthy(kinds.CE and kinds.Relic and kinds.Codex, "all three unlock kinds")

			local empty = { Discovered = {}, Milestones = {} }
			local throne = ShowcaseConfig.ById.CrimsonThrone
			local guardian = ShowcaseConfig.ById.GoldenGuardian
			local stance = ShowcaseConfig.ById.SimpleStance
			expect.equal(Showcases.freeUnlockMet(throne, empty), false, "throne locked")
			expect.equal(Showcases.freeUnlockMet(guardian, empty), false, "guardian locked")
			local progress = {
				Discovered = { [throne.Unlock.RelicId :: string] = 1 },
				Milestones = { [guardian.Unlock.Milestone :: string] = 1 },
			}
			expect.equal(Showcases.freeUnlockMet(throne, progress), true, "throne by relic")
			expect.equal(Showcases.freeUnlockMet(guardian, progress), true, "guardian by milestone")
			expect.equal(Showcases.freeUnlockMet(stance, progress), false, "CE Showcases are never free")
		end,
	},
	{
		Name = "accessories show once their relic is discovered and can be hidden",
		Run = function()
			local stance = ShowcaseConfig.ById.SimpleStance
			local accessory = stance.Accessories[1]
			local current = state("SimpleStance", { SimpleStance = 1 })
			local none = Showcases.visibleAccessories(current, stance, { Discovered = {}, Milestones = {} })
			expect.equal(#none, 0, "locked accessory hidden")
			local progress = { Discovered = { [accessory.RelicId] = 1 }, Milestones = {} }
			local shown = Showcases.visibleAccessories(current, stance, progress)
			expect.equal(shown[1], accessory.Id, "unlocked accessory shown")
			current.AccessoriesOff[accessory.Id] = true
			expect.equal(#Showcases.visibleAccessories(current, stance, progress), 0, "switched off")
			-- Cosmetic only: accessories never change the buff.
			expect.equal(Showcases.bonus(current, LEVELS), LEVELS[1].Income, "no stat change")
		end,
	},
}

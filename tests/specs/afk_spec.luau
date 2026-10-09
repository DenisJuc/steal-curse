-- Welcome Back AFK summary (GDD 9.4): when it shows and what the "Unlocked" list contains.

local AfkSummary = require("../../src/shared/AfkSummary")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local expect = require("../lib/expect")

local TIERS = { Common1 = 1, Common2 = 1, Epic1 = 4, Mythic1 = 6 }
local function tierOf(id: string): number
	return TIERS[id] or 1
end

local function log(overrides: { [string]: any }): any
	local result = DataTemplate.deepCopy(DataTemplate.Template.AfkLog) :: any
	for key, value in overrides do
		result[key] = value
	end
	return result
end

return {
	{
		Name = "summary needs an active log, enough AFK time and a find or CE",
		Run = function()
			expect.equal(AfkSummary.qualifies(log({ Seconds = 600, Discoveries = 5 }), 60), false, "inactive")
			expect.equal(AfkSummary.qualifies(log({ Active = true, Seconds = 30, Discoveries = 5 }), 60), false, "too short")
			expect.equal(AfkSummary.qualifies(log({ Active = true, Seconds = 600 }), 60), false, "nothing happened")
			expect.equal(AfkSummary.qualifies(log({ Active = true, Seconds = 600, Discoveries = 1 }), 60), true, "a find")
			expect.equal(AfkSummary.qualifies(log({ Active = true, Seconds = 600, CE = 2 }), 60), true, "shrine CE only")
		end,
	},
	{
		Name = "unlocks list only what happened since the AFK start, merged and best first",
		Run = function()
			local source = {
				Discovered = { Common1 = 50, Common2 = 150, Epic1 = 120, Mythic1 = 130 },
				CodexMutations = { Common1 = { Golden = 140 }, Mythic1 = { Abyssal = 130 } },
				CodexReady = { Essential10 = 160, OldMilestone = 10 },
				RareHistory = {
					{ Id = "Epic1", At = 170 },
					{ Id = "Mythic1", Mutation = "Abyssal", At = 130 },
					{ Id = "Epic1", At = 120 },
					{ Id = "Epic1", At = 40 },
				},
			}
			local list, more = AfkSummary.unlocks(source, 100, tierOf, 10)
			expect.equal(more, 0, "nothing cut")
			expect.equal(#list, 5, "milestone, mythic, epic, golden variant, new common")
			expect.equal(list[1].Kind, "Milestone", "milestones first")
			expect.equal(list[1].Id, "Essential10", "only the new milestone")
			expect.equal(list[2].Id, "Mythic1", "rarest find next")
			expect.equal(list[2].Mutation, "Abyssal", "mutated rare find")
			expect.equal(list[2].NewVariant, true, "new variant merged into the rare find")
			expect.equal(list[2].New, true, "first discovery merged into the rare find")
			expect.equal(list[3].Id, "Epic1", "epic after mythic")
			expect.equal(list[3].Count, 2, "two epic copies since the start, the older one excluded")
			expect.equal(list[3].New, true, "epic was first discovered while AFK")
			expect.equal(list[4].Kind, "Variant", "golden common variant")
			expect.equal(list[5].Kind, "Relic", "new common relic")
			expect.equal(list[5].Id, "Common2", "Common1 was discovered before the AFK start")
		end,
	},
	{
		Name = "unlock list is capped and counts the rest",
		Run = function()
			local discovered = {}
			for index = 1, 12 do
				discovered[`Relic{index}`] = 200
			end
			local source = { Discovered = discovered, CodexMutations = {}, CodexReady = {}, RareHistory = {} }
			local list, more = AfkSummary.unlocks(source, 100, tierOf, 5)
			expect.equal(#list, 5, "capped")
			expect.equal(more, 7, "rest counted")
		end,
	},
}

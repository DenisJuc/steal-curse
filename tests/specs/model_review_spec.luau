-- The model redo list (/modelreview): every entry is a real relic, listed once, with a reason.

local ModelReview = require("../../src/shared/ModelReview")
local RelicConfig = require("../../src/shared/RelicConfig")
local expect = require("../lib/expect")

return {
	{
		Name = "every redo entry is a real relic, listed once, with a reason",
		Run = function()
			local seen = {}
			for _, entry in ModelReview.Redo do
				expect.truthy(RelicConfig.ById[entry.Id] ~= nil, `{entry.Id} is not a relic id`)
				expect.truthy(not seen[entry.Id], `{entry.Id} is listed twice`)
				seen[entry.Id] = true
				expect.truthy(#entry.Reason > 0, `{entry.Id} has no reason`)
				expect.truthy(ModelReview.ById[entry.Id] == entry, `{entry.Id} lookup`)
			end
		end,
	},
	{
		Name = "every later entry is a real relic with a reason, never also on the redo list",
		Run = function()
			local seen = {}
			for _, entry in ModelReview.Later do
				expect.truthy(RelicConfig.ById[entry.Id] ~= nil, `{entry.Id} is not a relic id`)
				expect.truthy(not seen[entry.Id], `{entry.Id} is listed twice`)
				expect.truthy(ModelReview.ById[entry.Id] == nil, `{entry.Id} is on both lists`)
				seen[entry.Id] = true
				expect.truthy(#entry.Reason > 0, `{entry.Id} has no reason`)
				expect.truthy(ModelReview.LaterById[entry.Id] == entry, `{entry.Id} lookup`)
			end
		end,
	},
}

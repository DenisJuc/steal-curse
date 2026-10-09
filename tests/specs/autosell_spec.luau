-- Auto-sell decision table (GDD 9.2, 9.3).

local AutoSell = require("../../src/shared/AutoSell")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local RarityConfig = require("../../src/shared/RarityConfig")
local expect = require("../lib/expect")

local TIER_IDS = {}
for _, tier in RarityConfig.Tiers do
	table.insert(TIER_IDS, tier.Id)
end

local function rules(overrides: { [string]: any }?): AutoSell.Rules
	local result = AutoSell.defaults(TIER_IDS)
	for key, value in overrides or {} do
		(result :: any)[key] = value
	end
	return result
end

local function withTier(tierId: string, mode: AutoSell.Mode, overrides: { [string]: any }?): AutoSell.Rules
	local result = rules(overrides)
	result.Tiers[tierId] = mode
	return result
end

local function facts(overrides: { [string]: any }?): AutoSell.Facts
	local result = {
		Tier = "Common",
		BaseOneIn = 2,
		First = false,
		Mutated = false,
		Duplicate = false,
		Favorite = false,
	}
	for key, value in overrides or {} do
		(result :: any)[key] = value
	end
	return result
end

return {
	{
		Name = "saved defaults equal AutoSell.defaults and keep everything",
		Run = function()
			local defaults = AutoSell.defaults(TIER_IDS)
			local saved = DataTemplate.Template.Settings.AutoSell
			for _, tierId in TIER_IDS do
				expect.equal(saved.Tiers[tierId], defaults.Tiers[tierId], `saved {tierId} mode`)
			end
			for _, key in { "SellAllDuplicates", "SellEasierThan", "ProtectFirst", "ProtectMutated" } do
				expect.equal((saved :: any)[key], (defaults :: any)[key], `saved {key}`)
			end
			for _, tierId in TIER_IDS do
				local sell = AutoSell.decide(defaults, facts({ Tier = tierId, Duplicate = true }))
				expect.equal(sell, false, `default rules keep a {tierId} duplicate`)
			end
		end,
	},
	{
		Name = "decision table follows the documented precedence",
		Run = function()
			-- { name, rules, facts, expected sell, expected reason }
			local cases: { { any } } = {
				{ "favorite beats Sell All", withTier("Common", "SellAll"), facts({ Favorite = true }), false, "Favorite" },
				{ "favorite beats odds rule", rules({ SellEasierThan = 100 }), facts({ Favorite = true }), false, "Favorite" },
				{ "protected first beats Sell All", withTier("Common", "SellAll"), facts({ First = true }), false, "FirstDiscovery" },
				{
					"unprotected first is sold by Sell All",
					withTier("Common", "SellAll", { ProtectFirst = false }),
					facts({ First = true }),
					true,
					"RarityRule",
				},
				{ "protected mutation beats Sell All", withTier("Common", "SellAll"), facts({ Mutated = true }), false, "Mutated" },
				{
					"unprotected mutation is sold by Sell All",
					withTier("Common", "SellAll", { ProtectMutated = false }),
					facts({ Mutated = true }),
					true,
					"RarityRule",
				},
				{ "Sell All sells non-duplicates", withTier("Common", "SellAll"), facts(), true, "RarityRule" },
				{ "Sell Duplicates sells a duplicate", withTier("Common", "SellDuplicates"), facts({ Duplicate = true }), true, "Duplicate" },
				{ "Sell Duplicates keeps a non-duplicate", withTier("Common", "SellDuplicates"), facts(), false, "NoRule" },
				{ "rule of another tier does nothing", withTier("Rare", "SellAll"), facts(), false, "NoRule" },
				{ "global duplicates toggle overrides Keep All", rules({ SellAllDuplicates = true }), facts({ Duplicate = true }), true, "Duplicate" },
				{ "global duplicates toggle keeps a non-duplicate", rules({ SellAllDuplicates = true }), facts(), false, "NoRule" },
				{ "odds rule sells more common finds", rules({ SellEasierThan = 100 }), facts({ BaseOneIn = 50 }), true, "OddsThreshold" },
				{ "odds rule is strict at the boundary", rules({ SellEasierThan = 100 }), facts({ BaseOneIn = 100 }), false, "NoRule" },
				{ "odds rule keeps rarer finds", rules({ SellEasierThan = 100 }), facts({ BaseOneIn = 5000 }), false, "NoRule" },
				{ "odds rule 0 is off", rules({ SellEasierThan = 0 }), facts({ BaseOneIn = 1 }), false, "NoRule" },
				{ "protected first beats odds rule", rules({ SellEasierThan = 100 }), facts({ First = true }), false, "FirstDiscovery" },
			}
			for _, case in cases do
				local sell, reason = AutoSell.decide(case[2], case[3])
				expect.equal(sell, case[4], `{case[1]}: sell`)
				expect.equal(reason, case[5], `{case[1]}: reason`)
			end
		end,
	},
	{
		Name = "sanitize rejects bad client input and keeps the previous value",
		Run = function()
			local base = withTier("Common", "SellDuplicates", { SellEasierThan = 10 })
			local clean = AutoSell.sanitize({
				Tiers = { Common = "Explode", Uncommon = "SellAll", Bogus = "SellAll" },
				SellAllDuplicates = "yes",
				SellEasierThan = -5,
				ProtectFirst = false,
			}, TIER_IDS, base)
			expect.equal(clean.Tiers.Common, "SellDuplicates", "invalid mode keeps previous")
			expect.equal(clean.Tiers.Uncommon, "SellAll", "valid mode applied")
			expect.equal((clean.Tiers :: any).Bogus, nil, "unknown tier dropped")
			expect.equal(clean.SellAllDuplicates, false, "non-boolean toggle keeps previous")
			expect.equal(clean.SellEasierThan, 10, "negative threshold keeps previous")
			expect.equal(clean.ProtectFirst, false, "valid toggle applied")
			local nan = AutoSell.sanitize({ SellEasierThan = 0 / 0 }, TIER_IDS, base)
			expect.equal(nan.SellEasierThan, 10, "NaN threshold keeps previous")
			local garbage = AutoSell.sanitize("nope", TIER_IDS, base)
			expect.equal(garbage.Tiers.Common, "SellDuplicates", "non-table input keeps previous")
		end,
	},
	{
		Name = "favorite keys separate mutations of the same relic",
		Run = function()
			expect.equal(AutoSell.favoriteKey("A", nil), "A", "plain key")
			expect.equal(AutoSell.favoriteKey("A", "Golden"), "A|Golden", "mutated key")
		end,
	},
}

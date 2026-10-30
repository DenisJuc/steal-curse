-- The game's roll rules assembled from config, shared by RollService (rolls) and the UI (odds),
-- so both always use identical inputs.
-- Optional BalanceTrials.Active overrides Epic/Legendary denominators for Studio test builds only.

local Config = require(script.Parent.Config)
local BalanceTrials = require(script.Parent.BalanceTrials)
local MutationConfig = require(script.Parent.MutationConfig)
local RarityConfig = require(script.Parent.RarityConfig)
local RelicConfig = require(script.Parent.RelicConfig)
local RollMath = require(script.Parent.RollMath)

local function tiersForRules(): { RollMath.Tier }
	local tiers = {}
	for _, tier in RarityConfig.Tiers do
		table.insert(tiers, {
			Id = tier.Id,
			Denominator = BalanceTrials.tierDenominator(tier.Id, tier.Denominator),
		})
	end
	return tiers
end

local rules: RollMath.Rules = {
	Tiers = tiersForRules(),
	ByTier = RollMath.groupByTier(RelicConfig.Relics),
	Mutations = MutationConfig.Mutations,
	MutationChanceByRank = MutationConfig.ChanceByRank,
	FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
	FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
}

return rules

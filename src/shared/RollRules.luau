-- The game's roll rules assembled from config, shared by RollService (rolls) and the UI (odds),
-- so both always use identical inputs.

local Config = require(script.Parent.Config)
local MutationConfig = require(script.Parent.MutationConfig)
local RarityConfig = require(script.Parent.RarityConfig)
local RelicConfig = require(script.Parent.RelicConfig)
local RollMath = require(script.Parent.RollMath)

local rules: RollMath.Rules = {
	Tiers = RarityConfig.Tiers,
	ByTier = RollMath.groupByTier(RelicConfig.Relics),
	Mutations = MutationConfig.Mutations,
	MutationChanceByRank = MutationConfig.ChanceByRank,
	FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
	FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
}

return rules

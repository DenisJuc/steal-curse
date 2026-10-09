-- Builds RollMath rules from the real config files (mirror of src/shared/RollRules, which needs Roblox `script`).

local Config = require("../../src/shared/Config")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")

local rules: RollMath.Rules = {
	Tiers = RarityConfig.Tiers,
	ByTier = RollMath.groupByTier(RelicConfig.Relics),
	Mutations = MutationConfig.Mutations,
	MutationChanceByRank = MutationConfig.ChanceByRank,
	FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
	FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
}

return rules

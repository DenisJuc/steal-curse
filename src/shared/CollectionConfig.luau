-- Phase 2 collection layer (Essence, fusion, Charms, Resonance, mutation goals).
-- Data-driven so Update 1–3 can add rows without rewriting services.
-- Gated by BalanceTrials.collectionEnabled() — live defaults leave this inert.
--
-- Pacing intent:
--   First fusion: 2–5 minutes (one board slot, Common recipe).
--   More Charms require unlocked slots + targeted duplicates — not a cheap Common carpet.

local CollectionConfig = {}

CollectionConfig.MaxFusionRank = 3
CollectionConfig.MaxFusionSlots = 5
-- Board starts at 1; milestones open more concurrent fused relics (each can hold a Charm).
CollectionConfig.StartingFusionSlots = 1

-- Copies required to purchase the next rank (rank 1 / 2 / 3).
CollectionConfig.CopiesForRank = {
	[1] = 3,
	[2] = 5, -- targeted: same relic again, not any Common
	[3] = 4, -- plus a mutated copy of that relic (see Rank3NeedsMutation)
}
CollectionConfig.FusionConsumeByRank = {
	[1] = 2,
	[2] = 3,
	[3] = 2,
}
CollectionConfig.Rank3NeedsMutation = true

CollectionConfig.EssenceByTier = {
	Common = 1,
	Uncommon = 2,
	Rare = 5,
	Epic = 12,
	Legendary = 35,
	Mythic = 90,
	Celestial = 220,
	Cosmic = 550,
}

CollectionConfig.AutoEssenceMaxTier = "Rare"
CollectionConfig.HuntCaptureEssence = 1
-- SoftCap_P4 midgame: Hunt Charm pedestal — bonus Essence per capture relic matching its family.
-- Rewards active hunting decisions when the CE shop is empty (not AFK scan power).
CollectionConfig.HuntFamilyMatchEssence = 2
-- SoftCap: hunt-only SoftCap weight multiplier for the chosen Hunt Quarry relic.
-- Applied as weight×mult on binds (not AFK). Soft-pin first-fuse + Board recipes.
-- ×7 ≈ mid-Common ~23% on binds at Luck 20 (Scan ~4%); focused Hunt clearly beats AFK Scan.
CollectionConfig.HuntQuarryMult = 7
-- Short debounce only (remote spam). Legitimate quarry switches between binds stay free.
CollectionConfig.HuntQuarryRetargetSeconds = 3

-- Modest Essence costs; scarcity comes from slots + targeted copies.
CollectionConfig.FusionEssenceCostByTier = {
	Common = 16,
	Uncommon = 40,
	Rare = 95,
	Epic = 220,
	Legendary = 550,
	Mythic = 1400,
	Celestial = 3500,
	Cosmic = 8000,
}

CollectionConfig.FusionRankCostMult = {
	[1] = 1,
	[2] = 1.8,
	[3] = 3,
}

CollectionConfig.FusionIncomeMultByRank = {
	[1] = 1.12,
	[2] = 1.28,
	[3] = 1.5,
}

-- Charm respec (meaningful specialization change).
CollectionConfig.CharmRespecEssence = 120
-- Studio SoftCap_P4: retire a Board entry (clears Fusion rank + Charm; frees one slot).
CollectionConfig.BoardRetireEssence = 80

-- Attune / targeted sinks (repeatable).
CollectionConfig.AttuneTicketEssenceCost = 75
CollectionConfig.AttuneScanCount = 10
CollectionConfig.MaxAttuneCharges = 3
CollectionConfig.AttuneChargeUpgradeEssence = 200 -- raise max charges by 1 (cap 8)
CollectionConfig.MaxAttuneChargesHardCap = 8
CollectionConfig.TargetedAttuneEssence = 110
CollectionConfig.TargetedAttuneScans = 12
-- Repeatable mutation-crafting sink (no new currency).
CollectionConfig.MutationFocusEssence = 140
CollectionConfig.MutationFocusScans = 25
CollectionConfig.FamilyAttuneEssence = 160

-- Epic duplicate utility (no new currency): catalyst unlocks Epic fusion for that relic id.
-- SoftCap_P4 Phase 7.1: 2 copies + Essence (was 3) so EpicLineage Ascend is reachable in-session
-- without requiring six exact-id Epic finds before Retire→Fuse.
CollectionConfig.EpicCatalyst = {
	Copies = 2,
	Essence = 90,
	-- Also grants Essence shard value when salvaging Epics after FirstBloodmoon goal.
}
CollectionConfig.EpicSalvageEssenceMult = 1.75 -- after EpicSalvageBoost unlock

CollectionConfig.Charms = {
	Hunt = {
		Id = "Hunt",
		Name = "Hunt Charm",
		Summary = "USE: Equip on a pedestal → hunt rolls favor this relic's family (not AFK scans).",
		HuntFamilyWeightBonus = 0.75,
	},
	Workshop = {
		Id = "Workshop",
		Name = "Workshop Charm",
		Summary = "USE: Dupes of this relic pay bonus Essence (no pedestal needed).",
		EssenceBonus = 0.5,
	},
	Shrine = {
		Id = "Shrine",
		Name = "Shrine Charm",
		Summary = "USE: Equip on a pedestal → pulse outlines the nearest spirit signal.",
		PulseSeconds = 60,
		OutlineNearestSignal = true,
		MinPulseSeconds = 20,
	},
}

-- SoftCap_P4 Phase 7: Charm potency by fused relic tier (Board income stays best-rank only).
-- Post-×1.50 goal: Retire a Common Charm lineage → Fuse Uncommon/Rare/Epic → stronger specialty.
CollectionConfig.CharmPotencyByTier = {
	Common = 1,
	Uncommon = 1.35,
	Rare = 1.7,
	Epic = 2.1,
	Legendary = 2.5,
	Mythic = 2.9,
	Celestial = 3.3,
	Cosmic = 3.8,
}

CollectionConfig.Resonances = {
	Collector = {
		Id = "Collector",
		Name = "Collector",
		Summary = "Essence from duplicates; later unlocks Salvage Focus and a daily Attune.",
		EssenceMultPerStack = 0.12,
		Unlocks = {
			{ Stacks = 2, Id = "SalvageFocus", Summary = "Dismantle non-favourites for Essence (no CE)." },
			{ Stacks = 3, Id = "DailyAttune", Summary = "One free Attune ticket each UTC day." },
		},
	},
	Binder = {
		Id = "Binder",
		Name = "Binder",
		Summary = "Faster binds; later unlocks Quick Bind and a free signal pulse.",
		HoldSecondsPerStack = -0.4,
		Unlocks = {
			{ Stacks = 2, Id = "QuickBind", Summary = "Once / 90s: next bind uses shortened hold." },
			{ Stacks = 3, Id = "FreeSignal", Summary = "Every 8 minutes in the wild: +1 signal (capped)." },
		},
	},
	Seeker = {
		Id = "Seeker",
		Name = "Seeker",
		Summary = "Farther Spirit Sight; later unlocks mutation tint pulses and post-Rebirth Attune.",
		SightRangePerStack = 12,
		Unlocks = {
			{ Stacks = 2, Id = "MutationTint", Summary = "Pulses mark signals that can roll mutated." },
			{ Stacks = 3, Id = "PostRebirthAttune", Summary = "After each Rebirth: 10 Focused Common scans." },
		},
	},
}

-- SoftCap_P4 Phase 7.1: each Rebirth picks a Pursuit for this life (cleared next Rebirth).
-- Changes what you chase after R1 — not another CE multiplier.
CollectionConfig.RebirthPursuits = {
	FamilyHunt = {
		Id = "FamilyHunt",
		Name = "Family Hunt",
		Summary = "This life: Hunt Charm family-match captures grant +2 bonus Essence.",
		HuntMatchEssenceBonus = 2,
	},
	MutationLedger = {
		Id = "MutationLedger",
		Name = "Mutation Ledger",
		Summary = "This life: chase Mutation Goals; each new unique mutated relic grants +3 Essence.",
		NewUniqueMutEssence = 3,
	},
	EpicLineage = {
		Id = "EpicLineage",
		Name = "Epic Lineage",
		Summary = "This life: Epic dupes pay +50% Essence; craft Catalysts and Ascend a Charm to Epic.",
		RequiresUnlock = "EpicSalvageBoost",
		EpicDupeEssenceMult = 1.5,
	},
}

CollectionConfig.QuickBindCooldownSeconds = 90
CollectionConfig.QuickBindHoldFactor = 0.45
CollectionConfig.FreeSignalEverySeconds = 480

-- Staged goals: each unlocks a mechanic or board slot — not busywork.
-- SlotBonus adds concurrent fusion board capacity.
CollectionConfig.MutationGoals = {
	{
		Id = "FirstGolden",
		Name = "First Golden",
		MutationId = "Golden",
		UniqueRequired = 1,
		Unlock = "WorkshopCharmGlobal",
		SlotBonus = 1,
		Summary = "Workshop Charm + second fusion board slot.",
	},
	{
		Id = "ThreeMutated",
		Name = "Three Unique Mutated",
		AnyMutation = true,
		UniqueRequired = 3,
		Unlock = "AttuneTicketRecipe",
		Summary = "Craft Attune tickets with Essence.",
	},
	{
		Id = "FirstCorrupted",
		Name = "First Corrupted",
		MutationId = "Corrupted",
		UniqueRequired = 1,
		Unlock = "HuntCharmBonus",
		Summary = "Hunt Charm family bias +10% when the fused relic is mutated.",
	},
	{
		Id = "FiveMutated",
		Name = "Five Unique Mutated",
		AnyMutation = true,
		UniqueRequired = 5,
		Unlock = "TargetedAttune",
		Summary = "Targeted Attune — pick a Focus tier for Essence.",
	},
	{
		Id = "FirstBloodmoon",
		Name = "First Bloodmoon",
		MutationId = "Bloodmoon",
		UniqueRequired = 1,
		Unlock = "EpicSalvageBoost",
		Summary = "Epic Salvage pays more Essence; Epic Catalyst crafting unlocked.",
	},
	{
		Id = "TenMutated",
		Name = "Ten Unique Mutated",
		AnyMutation = true,
		UniqueRequired = 10,
		Unlock = "CharmRespec",
		Summary = "Charm respec — change specialization for Essence.",
	},
	{
		Id = "FirstDivine",
		Name = "First Divine",
		MutationId = "Divine",
		UniqueRequired = 1,
		Unlock = "FamilyAttune",
		Summary = "Family Attune: next scans bias one Frequency family.",
	},
	{
		Id = "FifteenMutated",
		Name = "Fifteen Unique Mutated",
		AnyMutation = true,
		UniqueRequired = 25,
		Unlock = "MutationFocus",
		SlotBonus = 1,
		Summary = "Mutation Focus craft + third board slot (Rebirth adds a fourth).",
	},
	{
		Id = "EpicCatalystThree",
		Name = "Three Epic Catalysts",
		EpicCatalystsRequired = 3,
		Unlock = "EpicBoardSlot",
		SlotBonus = 1,
		Summary = "Fifth board slot — specialize an Epic.",
	},
}

CollectionConfig.FusionReserveCopies = 3

-- Legacy aliases (rank-1 recipe) for older tests / call sites.
CollectionConfig.FusionCopiesRequired = CollectionConfig.CopiesForRank[1]
CollectionConfig.FusionConsumeCopies = CollectionConfig.FusionConsumeByRank[1]

-- Future-update hooks (not implemented). Preserve expansion room without shipping systems now.
CollectionConfig.ExpansionHooks = {
	{
		Id = "LegendaryCatalyst",
		Summary = "After Epic board mastery: catalyst path for Legendary specialization.",
	},
	{
		Id = "ResonanceMastery",
		Summary = "Resonance ×4–5 unlocks region-tagged Attune / salvage variants.",
	},
	{
		Id = "FusionBranch",
		Summary = "Update fusion branches (alt Charm lines) once board slots feel settled.",
	},
	{
		Id = "VariantCodex",
		Summary = "Mutated+tier variant goals beyond the nine launch MutationGoals.",
	},
	{
		Id = "RegionCollection",
		Summary = "Zone-exclusive relics feed Essence/fusion without a new currency.",
	},
}

return CollectionConfig

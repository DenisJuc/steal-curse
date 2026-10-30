-- Phase 5: ProgressObjective selection (server-authoritative next goal).

local CollectionConfig = require("../../src/shared/CollectionConfig")
local CollectionMath = require("../../src/shared/CollectionMath")
local ProgressObjective = require("../../src/shared/ProgressObjective")
local expect = require("../lib/expect")

return {
	{
		Name = "prefers Charm pick over other goals",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				CharmNeededCount = 1, -- USE step after Fuse
				FuseReadyCount = 2,
				Progress = {
					{
						Id = "A",
						Name = "Knife",
						Rank = 0,
						NextRank = 1,
						Owned = 3,
						Need = 3,
						Missing = 0,
						Cost = 16,
						Ready = true,
					},
				},
			})
			expect.equal(obj and obj.Kind, "Charm", "charm first")
			expect.truthy(obj and string.find(obj.Text, "USE", 1, true), obj and obj.Text)
			expect.truthy(obj and string.find(obj.Text, "Charm", 1, true), obj and obj.Text)
		end,
	},
	{
		Name = "surfaces ready Rank2 upgrade with next Board lift",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.12,
				FusedCount = 1,
				FusionSlots = 2,
				Progress = {
					{
						Id = "Knife",
						Name = "Knife",
						Rank = 1,
						NextRank = 2,
						Owned = 5,
						Need = 5,
						Missing = 0,
						Cost = 29,
						Ready = true,
						OnBoard = true,
						CurrentIncomeMult = 1.12,
						NextIncomeMult = 1.28,
					},
				},
			})
			expect.equal(obj and obj.Kind, "FuseReady", "ready")
			expect.truthy(obj and string.find(obj.Text, "Rank 2", 1, true), obj and obj.Text)
			expect.truthy(obj and string.find(obj.Text, "1.28", 1, true), "shows next mult")
		end,
	},
	{
		Name = "blocked Rank2 asks for missing copies from recipe",
		Run = function()
			local need = CollectionMath.copiesForRank(2)
			local obj = ProgressObjective.pick({
				Enabled = true,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.12,
				FusedCount = 1,
				Progress = {
					{
						Id = "Knife",
						Name = "Knife",
						Rank = 1,
						NextRank = 2,
						Owned = 3,
						Need = need,
						Missing = need - 3,
						Cost = 29,
						Ready = false,
						OnBoard = true,
						BlockKind = "Copies",
						CurrentIncomeMult = 1.12,
						NextIncomeMult = 1.28,
					},
				},
			})
			expect.equal(obj and obj.Kind, "FuseProgress", "progress")
			expect.truthy(obj and obj.Detail and string.find(obj.Detail, "more", 1, true), obj and obj.Detail)
		end,
	},
	{
		Name = "mutation goal when no fuse progress",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 1,
				FusionSlots = 1,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.12,
				Progress = {},
				NextGoals = {
					{
						Id = "FirstGolden",
						Name = "First Golden",
						Summary = CollectionConfig.MutationGoals[1].Summary,
						Progress = 0,
						Required = 1,
					},
				},
			})
			expect.equal(obj and obj.Kind, "MutationGoal", "goal")
			expect.equal(obj and obj.Id, "FirstGolden", "id")
		end,
	},
	{
		Name = "Rebirth surfaces when CE covers cost",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 1,
				Progress = {},
				NextGoals = {},
				CE = 4e8,
				RebirthCost = 4e8,
				Rebirths = 0,
			})
			expect.equal(obj and obj.Kind, "Rebirth", "rebirth")
		end,
	},
	{
		Name = "disabled Collection yields nil",
		Run = function()
			expect.equal(ProgressObjective.pick({ Enabled = false }), nil, "nil")
		end,
	},
	{
		Name = "Phase6: BoardFocusId Rank3 mutation blocker preferred when Board is full",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.28,
				FusedCount = 2,
				FusionSlots = 2,
				BoardFocusId = "Knife",
				Progress = {
					{
						Id = "Other",
						Name = "Other",
						Rank = 0,
						NextRank = 1,
						Owned = 2,
						Need = 3,
						Missing = 1,
						Cost = 16,
						Ready = false,
						OnBoard = false,
						BlockKind = "Copies",
					},
					{
						Id = "Knife",
						Name = "Knife",
						Rank = 2,
						NextRank = 3,
						Owned = 4,
						Need = 4,
						Missing = 0,
						Cost = 52,
						Ready = false,
						OnBoard = true,
						BlockKind = "Mutation",
						NeedsMutation = true,
						HasMutated = false,
						CurrentIncomeMult = 1.28,
						NextIncomeMult = 1.5,
						Charm = "Hunt",
						OnPedestal = false,
					},
				},
			})
			expect.equal(obj and obj.Kind, "FuseProgress", "progress")
			expect.equal(obj and obj.RelicId, "Knife", "focus relic")
			expect.truthy(obj and string.find(obj.Text, "Rank 3", 1, true), obj and obj.Text)
			expect.truthy(obj and obj.Detail and string.find(obj.Detail, "mutated", 1, true), obj and obj.Detail)
			expect.truthy(obj and obj.Detail and string.find(obj.Detail, "pedestal", 1, true), "hunt pedestal note")
		end,
	},
	{
		Name = "midgame: empty Board slot prioritizes Charm fuse over Rank3 mutation wait",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.28,
				FusedCount = 1,
				FusionSlots = 2,
				BoardFocusId = "Knife",
				Progress = {
					{
						Id = "Spare",
						Name = "Spare Common",
						Rank = 0,
						NextRank = 1,
						Owned = 2,
						Need = 3,
						Missing = 1,
						Cost = 16,
						Ready = false,
						OnBoard = false,
						BlockKind = "Copies",
					},
					{
						Id = "Knife",
						Name = "Knife",
						Rank = 2,
						NextRank = 3,
						Owned = 4,
						Need = 4,
						Missing = 0,
						Cost = 52,
						Ready = false,
						OnBoard = true,
						BlockKind = "Mutation",
						NeedsMutation = true,
						HasMutated = false,
						CurrentIncomeMult = 1.28,
						NextIncomeMult = 1.5,
						Charm = "Hunt",
					},
				},
			})
			expect.equal(obj and obj.RelicId, "Spare", "fill free slot")
			expect.truthy(obj and string.find(obj.Text, "Board slot", 1, true), obj and obj.Text)
			expect.truthy(obj and obj.Detail and string.find(obj.Detail, "Charm", 1, true), obj and obj.Detail)
		end,
	},

	{
		Name = "boardStatusLine shows current and next lift",
		Run = function()
			local line = ProgressObjective.boardStatusLine({
				Enabled = true,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.12,
				FusedCount = 1,
				FusionSlots = 2,
				Progress = {
					{
						Id = "A",
						Name = "A",
						Rank = 1,
						NextRank = 2,
						Owned = 4,
						Need = 5,
						Missing = 1,
						Cost = 29,
						Ready = false,
						OnBoard = true,
						NextIncomeMult = 1.28,
					},
				},
			})
			expect.truthy(string.find(line, "1.12", 1, true), line)
			expect.truthy(string.find(line, "1.28", 1, true), line)
		end,
	},
	{
		Name = "midgame: Attune craft surfaces when recipe unlocked and Essence available",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 2,
				FusionSlots = 2,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.28,
				Progress = {},
				NextGoals = {},
				HasAttuneRecipe = true,
				AttuneCharges = 0,
				AttuneScansLeft = 0,
				Essence = 100,
				AttuneTicketCost = CollectionConfig.AttuneTicketEssenceCost,
			})
			expect.equal(obj and obj.Kind, "Attune", "attune")
			expect.equal(obj and obj.Id, "AttuneCraft", "craft")
		end,
	},
	{
		Name = "midgame: Attune use preferred over craft when charges exist",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 2,
				FusionSlots = 2,
				Progress = {},
				NextGoals = {},
				HasAttuneRecipe = true,
				AttuneCharges = 2,
				AttuneScansLeft = 0,
				Essence = 200,
			})
			expect.equal(obj and obj.Id, "AttuneUse", "use ticket")
		end,
	},
	{
		Name = "midgame: Attune beats Rank3 mutation wait when Board is full",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.28,
				FusedCount = 2,
				FusionSlots = 2,
				BoardFocusId = "Knife",
				HasAttuneRecipe = true,
				Essence = 90,
				AttuneCharges = 0,
				AttuneScansLeft = 0,
				Progress = {
					{
						Id = "Knife",
						Name = "Knife",
						Rank = 2,
						NextRank = 3,
						Owned = 4,
						Need = 4,
						Missing = 0,
						Cost = 52,
						Ready = false,
						OnBoard = true,
						BlockKind = "Mutation",
						NeedsMutation = true,
						HasMutated = false,
						CurrentIncomeMult = 1.28,
						NextIncomeMult = 1.5,
						Charm = "Hunt",
						OnPedestal = true,
					},
				},
			})
			expect.equal(obj and obj.Kind, "Attune", "attune during mut drought")
			expect.equal(obj and obj.Id, "AttuneCraft", "craft")
		end,
	},
	{
		Name = "Phase7: Charm ascend Ready beats post-cap Explore/Attune",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.5,
				FusedCount = 3,
				FusionSlots = 3,
				Progress = {},
				NextGoals = {},
				HasAttuneRecipe = true,
				Essence = 200,
				AscendHint = {
					Charm = "Hunt",
					CurrentRelicId = "Knife",
					CurrentName = "Knife",
					CurrentTier = "Common",
					CurrentPotency = 1,
					TargetRelicId = "RareBlade",
					TargetName = "Rare Blade",
					TargetTier = "Rare",
					TargetPotency = 1.7,
					Owned = 3,
					Need = 3,
					Missing = 0,
					EssenceCost = 95,
					RetireCost = 80,
					Ready = true,
				},
			})
			expect.equal(obj and obj.Kind, "CharmAscend", "ascend")
			expect.equal(obj and obj.Id, "CharmAscendReady", "ready")
			expect.truthy(obj and string.find(obj.Text, "Rare Blade", 1, true), obj and obj.Text)
		end,
	},
	{
		Name = "Phase7.1: Rebirth Pursuit surfaces after Ascend/goals quiet",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.5,
				FusedCount = 3,
				FusionSlots = 3,
				Progress = {},
				NextGoals = {},
				ActivePursuit = "FamilyHunt",
				PursuitName = "Family Hunt",
				PursuitSummary = "Hunt family matches grant bonus Essence.",
			})
			expect.equal(obj and obj.Kind, "Pursuit", "pursuit")
			expect.truthy(obj and string.find(obj.Text, "Family Hunt", 1, true), obj and obj.Text)
		end,
	},
	{
		Name = "Phase7.1: Pending Resonance mentions Pursuit",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				PendingResonance = true,
			})
			expect.equal(obj and obj.Kind, "Resonance", "res")
			expect.truthy(obj and string.find(obj.Text, "Pursuit", 1, true), obj and obj.Text)
		end,
	},
	{
		Name = "HuntQuarry surfaces as the one midgame hunt goal before FuseProgress",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 1,
				FusionSlots = 1,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.12,
				HuntQuarryEligible = true,
				HuntQuarryId = "VivraCard",
				HuntQuarryName = "Vivra Card",
				HuntQuarryUseful = true,
				HuntQuarryNeedDetail = "Need 2 more for Rank 2 (1/3)",
				Progress = {
					{
						Id = "VivraCard",
						Name = "Vivra Card",
						Rank = 1,
						NextRank = 2,
						Owned = 1,
						Need = 3,
						Missing = 2,
						Cost = 29,
						Ready = false,
						OnBoard = true,
					},
				},
			})
			expect.equal(obj and obj.Kind, "HuntQuarry", "hunt wins")
			expect.truthy(obj and string.find(obj.Text, "Hunt Vivra Card", 1, true), obj and obj.Text)
			expect.truthy(obj and string.find(obj.Text, "×", 1, true), obj and obj.Text)
			expect.truthy(obj and obj.Detail and string.find(obj.Detail, "Rank 2", 1, true), obj and obj.Detail)
			expect.truthy(obj and obj.Detail and string.find(obj.Detail, "AFK", 1, true), obj and obj.Detail)
		end,
	},
	{
		Name = "FuseReady still beats HuntQuarry when copies are ready",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 1,
				FusionSlots = 1,
				HuntQuarryEligible = true,
				HuntQuarryId = "VivraCard",
				HuntQuarryName = "Vivra Card",
				HuntQuarryUseful = true,
				HuntQuarryNeedDetail = "Need a mutated copy for Rank 3",
				Progress = {
					{
						Id = "VivraCard",
						Name = "Vivra Card",
						Rank = 1,
						NextRank = 2,
						Owned = 3,
						Need = 3,
						Missing = 0,
						Cost = 29,
						Ready = true,
						OnBoard = true,
					},
				},
			})
			expect.equal(obj and obj.Kind, "FuseReady", "fuse ready")
		end,
	},
	{
		Name = "RebirthSave when CE shop exhausted (does not steal FirstFuse)",
		Run = function()
			local early = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 0,
				FusionSlots = 1,
				Progress = {},
				NextGoals = {},
				CE = 50_000_000,
				RebirthCost = 400_000_000,
				IncomePerSec = 10_000,
				AffordableShopBuys = 0,
			})
			expect.equal(early and early.Id, "FirstFuse", "first fuse wins")

			local save = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 3,
				FusionSlots = 3,
				BoardGlobalIncome = true,
				BoardIncomeMult = 1.5,
				Progress = {},
				NextGoals = {},
				CE = 50_000_000,
				RebirthCost = 400_000_000,
				IncomePerSec = 20_000,
				AffordableShopBuys = 0,
			})
			expect.equal(save and save.Kind, "RebirthSave", "save")
			expect.truthy(save and string.find(save.Text, "400", 1, true), save and save.Text)
			expect.truthy(save and save.Detail and string.find(save.Detail, "income", 1, true), save and save.Detail)

			local shopOpen = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 3,
				FusionSlots = 3,
				Progress = {},
				NextGoals = {},
				CE = 50_000_000,
				RebirthCost = 400_000_000,
				IncomePerSec = 20_000,
				AffordableShopBuys = 2,
			})
			expect.truthy(shopOpen and shopOpen.Kind ~= "RebirthSave", "shop buys block save")
		end,
	},
	{
		Name = "RebirthSave does not steal FuseReady",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				FusedCount = 1,
				FusionSlots = 2,
				CE = 80_000_000,
				RebirthCost = 400_000_000,
				IncomePerSec = 50_000,
				AffordableShopBuys = 0,
				Progress = {
					{
						Id = "SenzoBean",
						Name = "Senzo Bean",
						Rank = 0,
						NextRank = 1,
						Owned = 3,
						Need = 3,
						Missing = 0,
						Cost = 16,
						Ready = true,
					},
				},
			})
			expect.equal(obj and obj.Kind, "FuseReady", "fuse ready")
		end,
	},
	{
		Name = "CoreLoopPresentation hides Fusion/Hunt and points at sealing",
		Run = function()
			local obj = ProgressObjective.pick({
				Enabled = true,
				CoreLoopPresentation = true,
				CharmNeededCount = 1,
				HuntQuarryEligible = true,
				HuntQuarryUseful = true,
				HuntQuarryName = "Senzo Bean",
				DiscoveredCount = 12,
				CodexTotal = 92,
				AffordableShopBuys = 0,
				CE = 1_000,
				RebirthCost = 400_000_000,
			})
			expect.equal(obj and obj.Kind, "Scan", "seal/index")
			expect.truthy(obj and string.find(obj.Text, "Seal", 1, true), obj and obj.Text)
		end,
	},
}

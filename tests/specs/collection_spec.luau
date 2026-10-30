-- Phase 2 collection pure math + AutoSell fusion reserve + migration v7.
-- Phase 3: real Fusion economy helpers (board / consume / pedestal income).

local AutoSell = require("../../src/shared/AutoSell")
local CollectionConfig = require("../../src/shared/CollectionConfig")
local CollectionMath = require("../../src/shared/CollectionMath")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local Migrations = require("../../src/server/Data/Migrations")
local RealFusion = require("../lib/realFusionEconomy")
local expect = require("../lib/expect")

return {
	{
		Name = "fusion reserve protects pinned copies from auto-sell",
		Run = function()
			local rules = AutoSell.defaults({ "Common", "Rare" })
			rules.Tiers.Common = "SellDuplicates"
			local sell, reason = AutoSell.decide(rules, {
				Tier = "Common",
				BaseOneIn = 2,
				First = false,
				Mutated = false,
				Duplicate = true,
				Favorite = false,
				FusionReserve = true,
			})
			expect.equal(sell, false, "must keep")
			expect.equal(reason, "FusionReserve", "reason")
		end,
	},
	{
		Name = "soft-pin targets closest Common for first fuse when board has room",
		Run = function()
			local state = CollectionMath.defaults()
			local owned = { Zabimaru = 2, Knife = 1, HolloBait = 1 }
			local tiers = { Zabimaru = "Common", Knife = "Common", HolloBait = "Rare" }
			local soft = CollectionMath.softPinTarget(state, owned, tiers, 0)
			expect.equal(soft, "Zabimaru", "closest Common")
			expect.equal(CollectionMath.wouldBreachReserve("Zabimaru", 2, state, false, soft), true, "keep 2/3")
			expect.equal(CollectionMath.wouldBreachReserve("Zabimaru", 4, state, false, soft), false, "sell 4th")
			expect.equal(CollectionMath.wouldBreachReserve("Knife", 1, state, false, soft), false, "other commons not reserved")
			state.Fusion.Zabimaru = { Rank = 1, Charm = "Hunt" }
			expect.equal(CollectionMath.softPinTarget(state, owned, tiers, 0), nil, "board full → no soft pin")
		end,
	},
	{
		Name = "Sell-all skips FusionReserve copies",
		Run = function()
			local uids = AutoSell.sellAll({
				{ Uid = 1, Displayed = false, Locked = false, Favorite = false, Floating = false, FusionReserve = true },
				{ Uid = 2, Displayed = false, Locked = false, Favorite = false, Floating = false, FusionReserve = false },
			})
			expect.equal(#uids, 1, "one sold")
			expect.equal(uids[1], 2, "non-reserved")
		end,
	},
	{
		Name = "favourite still wins over fusion reserve",
		Run = function()
			local rules = AutoSell.defaults({ "Common" })
			local sell, reason = AutoSell.decide(rules, {
				Tier = "Common",
				BaseOneIn = 2,
				First = false,
				Mutated = false,
				Duplicate = true,
				Favorite = true,
				FusionReserve = true,
			})
			expect.equal(sell, false, "keep")
			expect.equal(reason, "Favorite", "favourite first")
		end,
	},
	{
		Name = "canFuse requires copies and Essence; Common fusion reachable pre-Epic cost",
		Run = function()
			local ok, _ = CollectionMath.canFuse({
				TierId = "Common",
				CurrentRank = 0,
				OwnedCopies = 3,
				Essence = CollectionMath.fusionEssenceCost("Common"),
			})
			expect.equal(ok, true, "ready")
			local tooPoor = CollectionMath.canFuse({
				TierId = "Common",
				CurrentRank = 0,
				OwnedCopies = 3,
				Essence = 0,
			})
			expect.equal(tooPoor, false, "needs essence")
			expect.truthy(CollectionMath.fusionEssenceCost("Common", 1) <= 25, "rank1 cheap enough for early game")
			expect.truthy(CollectionMath.fusionEssenceCost("Common", 3) > CollectionMath.fusionEssenceCost("Common", 1), "rank3 costs more")
		end,
	},
	{
		Name = "fusion board slots gate concurrent Charms; rank2 needs targeted copies",
		Run = function()
			local state = CollectionMath.defaults()
			state.Fusion.A = { Rank = 1, Charm = "Hunt" }
			expect.equal(CollectionMath.fusionSlots(state, 0), 1, "start one slot")
			local blocked, boardMsg, boardKind = CollectionMath.canFuse({
				TierId = "Common",
				CurrentRank = 0,
				OwnedCopies = 3,
				Essence = 100,
				State = state,
				Rebirths = 0,
			})
			expect.equal(blocked, false, "board full")
			expect.equal(boardKind, "Board", "kind")
			expect.truthy(string.find(boardMsg, "Board full", 1, true), boardMsg)
			state.MutationGoalsClaimed.FirstGolden = 1
			expect.equal(CollectionMath.fusionSlots(state, 0), 2, "golden opens slot")
			expect.equal(CollectionMath.copiesForRank(2), 5, "rank2 targeted")
			local rank2 = CollectionMath.canFuse({
				TierId = "Common",
				CurrentRank = 1,
				OwnedCopies = 4,
				Essence = 100,
				State = state,
			})
			expect.equal(rank2, false, "need 5 copies for rank2")
			local epicBlocked = CollectionMath.canFuse({
				TierId = "Epic",
				CurrentRank = 0,
				OwnedCopies = 5,
				Essence = 500,
				State = state,
				EpicCatalystReady = false,
			})
			expect.equal(epicBlocked, false, "epic needs catalyst")
		end,
	},
	{
		Name = "board unlock ladder grants slots without inventing remove/swap",
		Run = function()
			local ladder = CollectionMath.boardUnlockLadder()
			expect.truthy(#ladder >= 4, "ladder length")
			expect.equal(ladder[1].Kind, "Start", "slot1 start")
			expect.equal(ladder[2].GoalId, "FirstGolden", "slot2 golden")
			local state = CollectionMath.defaults()
			local meta0 = CollectionMath.boardSlotMeta(state, 0, {
				{ Id = "FirstGolden", Progress = 0, Required = 1, Name = "First Golden" },
			})
			expect.equal(meta0[1].Unlocked, true, "starter unlocked")
			expect.equal(meta0[2].Unlocked, false, "slot2 locked")
			expect.equal(meta0[2].UnlockName, "First Golden", "unlock name")
			state.MutationGoalsClaimed.FirstGolden = 1
			local meta1 = CollectionMath.boardSlotMeta(state, 0, {})
			expect.equal(meta1[2].Unlocked, true, "golden unlocks slot2")
			expect.equal(CollectionMath.fusionSlots(state, 0), 2, "two slots")
		end,
	},
	{
		Name = "rank upgrade on a full board does not need a free slot; rank3 needs mutation",
		Run = function()
			local state = CollectionMath.defaults()
			state.Fusion.HuntarLicense = { Rank = 2, Charm = "Hunt" }
			expect.equal(CollectionMath.fusionSlots(state, 0), 1, "one slot")
			expect.equal(CollectionMath.fusedCount(state), 1, "board full")
			local upgradeOk, _, kind = CollectionMath.canFuse({
				TierId = "Common",
				RelicName = "Huntar License",
				CurrentRank = 2,
				OwnedCopies = 4,
				Essence = 48,
				State = state,
				Rebirths = 0,
				HasMutatedCopy = true,
			})
			expect.equal(upgradeOk, true, "in-place upgrade ignores board full")
			expect.equal(kind, "Ok", "ok kind")
			local mutBlock, mutMsg, mutKind = CollectionMath.canFuse({
				TierId = "Common",
				RelicName = "Huntar License",
				CurrentRank = 2,
				OwnedCopies = 4,
				Essence = 48,
				State = state,
				HasMutatedCopy = false,
			})
			expect.equal(mutBlock, false, "mutation required")
			expect.equal(mutKind, "Mutation", "mut kind")
			expect.equal(mutMsg, "Missing mutated Huntar License.", "mut msg")
			expect.equal(CollectionMath.copiesForRank(3), 4, "own 4")
			expect.equal(CollectionMath.consumeForRank(3), 2, "spend 2")
		end,
	},
	{
		Name = "mutation goals include post-R1 depth and Epic catalyst row",
		Run = function()
			expect.truthy(#CollectionConfig.MutationGoals >= 8, "enough staged goals")
			local ids = {}
			for _, g in CollectionConfig.MutationGoals do
				ids[g.Id] = g
			end
			expect.truthy(ids.TenMutated ~= nil, "ten mutated")
			expect.truthy(ids.FifteenMutated ~= nil, "fifteen mutated")
			expect.truthy(ids.FirstBloodmoon ~= nil, "bloodmoon")
			expect.truthy(ids.EpicCatalystThree ~= nil, "catalyst goal")
			expect.truthy(CollectionConfig.EpicCatalyst.Copies >= 2, "catalyst copies")
			expect.truthy(CollectionConfig.TargetedAttuneEssence > 0, "targeted attune sink")
			expect.truthy(CollectionConfig.MutationFocusEssence > 0, "mutation focus sink")
			expect.truthy(#CollectionConfig.ExpansionHooks >= 3, "expansion hooks reserved")
		end,
	},
	{
		Name = "nextUnclaimedGoals surfaces first incomplete milestone for UI",
		Run = function()
			local state = CollectionMath.defaults()
			local nextGoals = CollectionMath.nextUnclaimedGoals(state, {
				UniqueMutated = 0,
				ByMutation = {},
				EpicCatalysts = 0,
			}, 2)
			expect.equal(#nextGoals, 2, "two next")
			expect.equal(nextGoals[1].Id, CollectionConfig.MutationGoals[1].Id, "first goal first")
			state.MutationGoalsClaimed.FirstGolden = 1
			local after = CollectionMath.nextUnclaimedGoals(state, {
				UniqueMutated = 2,
				ByMutation = { Golden = 1 },
				EpicCatalysts = 0,
			}, 1)
			expect.truthy(after[1].Id ~= "FirstGolden", "skips claimed")
		end,
	},
	{
		Name = "Charms are orthogonal to Frequency Focus and Spirit Sight (config summaries)",
		Run = function()
			local hunt = CollectionConfig.Charms.Hunt.Summary
			local workshop = CollectionConfig.Charms.Workshop.Summary
			local shrine = CollectionConfig.Charms.Shrine.Summary
			expect.truthy(string.find(hunt, "hunt") ~= nil or string.find(hunt, "Hunt") ~= nil, "hunt-only")
			expect.truthy(string.find(hunt, "pedestal") ~= nil, "hunt needs pedestal")
			expect.truthy(string.find(workshop, "Essence") ~= nil, "workshop essence copy")
			expect.truthy(string.find(shrine, "spirit") ~= nil or string.find(shrine, "pulse") ~= nil, "shrine distinct")
			expect.truthy(CollectionConfig.Charms.Workshop.EssenceBonus > 0, "workshop essence")
		end,
	},
	{
		Name = "Resonance unlocks distinct capabilities at stacks 2–3",
		Run = function()
			local u2 = CollectionMath.resonanceUnlocked("Collector", 2)
			local u3 = CollectionMath.resonanceUnlocked("Binder", 3)
			expect.truthy(table.find(u2, "SalvageFocus") ~= nil, "collector stack 2")
			expect.truthy(table.find(u3, "FreeSignal") ~= nil, "binder stack 3")
			expect.equal(CollectionMath.binderHoldBonus(1), -0.4, "binder stack 1")
			expect.equal(CollectionMath.seekerSightBonus(1), 12, "seeker stack 1")
		end,
	},
	{
		Name = "v6 data migrates to current with Collection and CodexSizes",
		Run = function()
			local data = {
				DataVersion = 6,
				Inventory = {},
				Cosmetic = { Uid = 0 },
			}
			expect.equal(Migrations.run(data, DataTemplate.Version), "Migrated", "outcome")
			expect.equal(data.DataVersion, DataTemplate.Version, "version")
			expect.equal(type(data.Collection), "table", "collection table")
			expect.equal(data.Collection.Essence, 0, "essence")
			expect.equal(data.Collection.ResonanceStacks.Collector, 0, "resonance")
			expect.equal(type(data.CodexSizes), "table", "codex sizes")
		end,
	},
	{
		Name = "template version is current and Collection is save-safe",
		Run = function()
			expect.equal(DataTemplate.Version, 8, "version")
			expect.equal(DataTemplate.Template.Collection.Essence, 0, "template essence")
			expect.equal(type(DataTemplate.Template.CodexSizes), "table", "codex sizes")
			local fresh = DataTemplate.fresh()
			fresh.Collection.Essence = 9
			expect.equal(DataTemplate.Template.Collection.Essence, 0, "template untouched")
		end,
	},
	{
		Name = "real fuse respects board slots, consumes base copies, applies pedestal-only income",
		Run = function()
			local state = CollectionMath.defaults()
			state.Essence = 100
			local owned = RealFusion.newOwned()
			-- Pick any Common with enough copies in RelicConfig via soft pin path.
			local commonId = nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					commonId = id
					break
				end
			end
			expect.truthy(commonId ~= nil, "have common")
			owned.Counts[commonId] = 5
			local ok, _ = RealFusion.tryFuse(state, owned, commonId, 0)
			expect.equal(ok, true, "first fuse")
			expect.equal(state.Fusion[commonId].Rank, 1, "rank 1")
			expect.equal(owned.Counts[commonId], 3, "consumed 2 base")
			expect.equal(RealFusion.activeBoardCount(state), 1, "one board")
			expect.equal(RealFusion.boardSlots(state, 0), 1, "start slots")
			-- Second distinct Common cannot fuse while board full.
			local otherId = nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" and id ~= commonId then
					otherId = id
					break
				end
			end
			owned.Counts[otherId] = 5
			state.Essence = 100
			local ok2, reason = RealFusion.tryFuse(state, owned, otherId, 0)
			expect.equal(ok2, false, "board full rejects")
			expect.truthy(string.find(reason, "Board") ~= nil or string.find(reason, "slot") ~= nil, "board reason")
			-- Income mult only on pedestaled fused relic.
			local multOn = RealFusion.pedestalContribution(state, commonId, 10, 2, 1)
			local multOff = RealFusion.pedestalContribution(state, otherId, 10, 2, 1)
			expect.equal(multOn, 10 * 2 * CollectionMath.fusionIncomeMult(1), "fused on ped")
			expect.equal(multOff, 20, "unfused no bonus")
			-- Rank-up in place does not need a new slot.
			owned.Counts[commonId] = 8
			state.Essence = 200
			local ok3 = RealFusion.tryFuse(state, owned, commonId, 0)
			expect.equal(ok3, true, "rank 2 in place")
			expect.equal(state.Fusion[commonId].Rank, 2, "rank 2")
			expect.equal(RealFusion.activeBoardCount(state), 1, "still one board entry")
		end,
	},
	{
		Name = "real fuse rejects when only mutated copies available to consume",
		Run = function()
			local state = CollectionMath.defaults()
			state.Essence = 100
			local owned = RealFusion.newOwned()
			local commonId = nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					commonId = id
					break
				end
			end
			owned.Counts[commonId] = 3
			owned.Mutated[commonId] = 3 -- all mutated → no base to consume
			local ok, reason = RealFusion.tryFuse(state, owned, commonId, 0)
			expect.equal(ok, false, "cannot consume mutated-only")
			expect.truthy(string.find(reason, "consume") ~= nil or string.find(reason, "copies") ~= nil or reason ~= "", "reason")
		end,
	},
	{
		Name = "boardIncomeMult is best rank only and retire clears contribution",
		Run = function()
			local state = CollectionMath.defaults()
			expect.equal(CollectionMath.boardIncomeMult(state), 1, "empty")
			state.Fusion.A = { Rank = 1, Charm = "Hunt" }
			state.Fusion.B = { Rank = 3, Charm = "Workshop" }
			local best = CollectionMath.fusionIncomeMult(3)
			expect.equal(CollectionMath.boardIncomeMult(state), best, "max rank wins")
			expect.truthy(best > CollectionMath.fusionIncomeMult(1), "rank3 > rank1")
			-- Product would be > best; ensure we did not multiply.
			expect.truthy(
				CollectionMath.boardIncomeMult(state) < CollectionMath.fusionIncomeMult(1) * CollectionMath.fusionIncomeMult(3),
				"not a product"
			)
			state.Essence = CollectionConfig.BoardRetireEssence or 80
			local ok = RealFusion.tryRetire(state, "B")
			expect.equal(ok, true, "retire")
			expect.equal(state.Fusion.B, nil, "cleared")
			expect.equal(CollectionMath.boardIncomeMult(state), CollectionMath.fusionIncomeMult(1), "only A left")
			local ok2 = RealFusion.tryRetire(state, "B")
			expect.equal(ok2, false, "no double retire")
		end,
	},
	{
		Name = "reserveCopies: soft-pin/favorite=3; Board Rank1=5; Rank2→3 recipe; max=0; retire clears",
		Run = function()
			local state = CollectionMath.defaults()
			local need1 = CollectionMath.copiesForRank(1)
			local need2 = CollectionMath.copiesForRank(2)
			local need3 = CollectionMath.copiesForRank(3)
			expect.equal(need1, CollectionConfig.FusionReserveCopies, "rank1 recipe matches pin size")
			expect.equal(need2, 5, "rank2 recipe")
			expect.equal(need3, 4, "rank3 recipe")

			-- Pre-fusion soft-pin
			expect.equal(CollectionMath.reserveCopies("Knife", state, false, "Knife"), need1, "soft-pin")
			expect.equal(CollectionMath.wouldBreachReserve("Knife", 3, state, false, "Knife"), true, "keep at 3")
			expect.equal(CollectionMath.wouldBreachReserve("Knife", 4, state, false, "Knife"), false, "sell 4th")

			-- Favorite uses flat FusionReserveCopies even without board
			expect.equal(CollectionMath.reserveCopies("Knife", state, true, nil), CollectionConfig.FusionReserveCopies, "favorite")

			-- Manual pin pre-fusion
			state.FusionPins.Knife = true
			expect.equal(CollectionMath.reserveCopies("Knife", state, false, nil), CollectionConfig.FusionReserveCopies, "manual pin")
			state.FusionPins.Knife = nil

			-- Board Rank 1 (also auto-pinned as live TryFuse does) must reserve Rank2 recipe
			state.Fusion.Knife = { Rank = 1, Charm = "Hunt" }
			state.FusionPins.Knife = true
			expect.equal(CollectionMath.reserveCopies("Knife", state, false, nil), need2, "rank1→2 reserve")
			expect.equal(CollectionMath.wouldBreachReserve("Knife", 5, state, false, nil), true, "keep 5th")
			expect.equal(CollectionMath.wouldBreachReserve("Knife", 6, state, false, nil), false, "sell 6th")

			-- Board Rank 2 → reserve Rank3 recipe
			state.Fusion.Knife.Rank = 2
			expect.equal(CollectionMath.reserveCopies("Knife", state, false, nil), need3, "rank2→3 reserve")

			-- Max rank → no next-rank stockpile
			state.Fusion.Knife.Rank = CollectionConfig.MaxFusionRank
			expect.equal(CollectionMath.reserveCopies("Knife", state, false, nil), 0, "max rank")
			expect.equal(CollectionMath.wouldBreachReserve("Knife", 1, state, false, nil), false, "max not reserved")

			-- Retire clears Board protection
			state.Essence = CollectionConfig.BoardRetireEssence or 80
			expect.equal(RealFusion.tryRetire(state, "Knife"), true, "retire")
			expect.equal(state.Fusion.Knife, nil, "fusion gone")
			expect.equal(state.FusionPins.Knife, nil, "pin cleared")
			expect.equal(CollectionMath.reserveCopies("Knife", state, false, nil), 0, "retired unprotected")
		end,
	},
	{
		Name = "AutoSell cannot burn Rank2 stockpile; Rank2 fuse succeeds after reserve holds",
		Run = function()
			local state = CollectionMath.defaults()
			state.Essence = 200
			local owned = RealFusion.newOwned()
			local commonId = nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					commonId = id
					break
				end
			end
			expect.truthy(commonId ~= nil, "common")
			owned.Counts[commonId] = 3
			expect.equal(RealFusion.tryFuse(state, owned, commonId, 0), true, "rank1")
			expect.equal(state.Fusion[commonId].Rank, 1, "on board")
			expect.equal(state.FusionPins[commonId], true, "auto-pinned")
			-- Rebuild toward Rank2 while AutoSell would otherwise dump duplicates.
			owned.Counts[commonId] = 5
			local rules = AutoSell.defaults({ "Common" })
			rules.Tiers.Common = "SellDuplicates"
			local soft = RealFusion.softPin(state, owned, 0, { commonId })
			for copies = 1, 8 do
				local reserved = CollectionMath.wouldBreachReserve(commonId, copies, state, false, soft)
				local sell, reason = AutoSell.decide(rules, {
					Tier = "Common",
					BaseOneIn = 2,
					First = false,
					Mutated = false,
					Duplicate = true,
					Favorite = false,
					FusionReserve = reserved,
				})
				if copies <= CollectionMath.copiesForRank(2) then
					expect.equal(sell, false, `must keep copy #{copies}`)
					expect.equal(reason, "FusionReserve", `reason @{copies}`)
				else
					expect.equal(sell, true, `may sell copy #{copies}`)
				end
			end
			-- Insufficient copies / essence still block Rank2.
			owned.Counts[commonId] = 4
			local blockedCopies = CollectionMath.canFuse({
				TierId = "Common",
				CurrentRank = 1,
				OwnedCopies = 4,
				Essence = 200,
				State = state,
			})
			expect.equal(blockedCopies, false, "need 5")
			owned.Counts[commonId] = 5
			local blockedEss = CollectionMath.canFuse({
				TierId = "Common",
				CurrentRank = 1,
				OwnedCopies = 5,
				Essence = 0,
				State = state,
			})
			expect.equal(blockedEss, false, "need essence")
			state.Essence = CollectionMath.fusionEssenceCost("Common", 2)
			local ok2 = RealFusion.tryFuse(state, owned, commonId, 0)
			expect.equal(ok2, true, "rank2 after reserve")
			expect.equal(state.Fusion[commonId].Rank, 2, "rank 2")
			expect.equal(CollectionMath.boardIncomeMult(state), CollectionMath.fusionIncomeMult(2), "lift ×1.28")
		end,
	},
	{
		Name = "pickFuseTarget prefers Lift-raising Rank2 over a second Rank1 when both ready",
		Run = function()
			local state = CollectionMath.defaults()
			state.MutationGoalsClaimed.FirstGolden = 1 -- free second board slot
			state.Essence = 500
			local owned = RealFusion.newOwned()
			local a, b = nil, nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					if not a then
						a = id
					elseif not b then
						b = id
						break
					end
				end
			end
			state.Fusion[a] = { Rank = 1, Charm = "Hunt" }
			state.FusionPins[a] = true
			owned.Counts[a] = 5 -- Rank2 ready
			owned.Counts[b] = 3 -- new Rank1 ready
			-- Pedestal shows B so old scoring (+120) would prefer B unless Lift-aware.
			local pick = RealFusion.pickFuseTarget(state, owned, 0, { b, nil, nil })
			expect.equal(pick, a, "must rank-up A for board Lift")
			expect.equal(RealFusion.tryFuse(state, owned, pick, 0), true, "fuse")
			expect.equal(state.Fusion[a].Rank, 2, "ranked up")
			expect.equal(CollectionMath.boardIncomeMult(state), CollectionMath.fusionIncomeMult(2), "global lift")
		end,
	},
	{
		Name = "softPin matches server: free Board slot pins a NEW Common (not Board upgrade)",
		Run = function()
			local state = CollectionMath.defaults()
			state.MutationGoalsClaimed.FirstGolden = 1
			local owned = RealFusion.newOwned()
			local a, b = nil, nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					if not a then
						a = id
					elseif not b then
						b = id
						break
					end
				end
			end
			state.Fusion[a] = { Rank = 2, Charm = "Hunt" }
			owned.Counts[a] = 4
			owned.Counts[b] = 2
			local pin = RealFusion.softPin(state, owned, 0, { a, nil, nil })
			expect.equal(pin, b, "pin empty-slot lineage")
			expect.equal(CollectionMath.wouldBreachReserve(b, 2, state, false, pin), true, "keep soft-pin")
			expect.equal(CollectionMath.reserveCopies(a, state, false, pin), CollectionMath.copiesForRank(3), "Board still reserved")
		end,
	},
	{
		Name = "pickFuseTarget fills free Board slot when Lift upgrade is not ready",
		Run = function()
			local state = CollectionMath.defaults()
			state.MutationGoalsClaimed.FirstGolden = 1
			state.Essence = 200
			local owned = RealFusion.newOwned()
			local a, b = nil, nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					if not a then
						a = id
					elseif not b then
						b = id
						break
					end
				end
			end
			state.Fusion[a] = { Rank = 2, Charm = "Hunt" }
			owned.Counts[a] = 1 -- Rank3 not ready
			owned.Counts[b] = 3 -- new fuse ready
			local pick = RealFusion.pickFuseTarget(state, owned, 0, { a, nil, nil })
			expect.equal(pick, b, "fill Charm slot")
			expect.equal(RealFusion.tryFuse(state, owned, pick, 0), true, "fuse second")
			expect.equal(CollectionMath.fusedCount(state), 2, "two board entries")
		end,
	},
	{
		Name = "Phase6: Rank2 reserves exactly one mutated copy; max/retire clears",
		Run = function()
			local state = CollectionMath.defaults()
			state.Essence = CollectionConfig.BoardRetireEssence or 80
			state.Fusion.Knife = { Rank = 2, Charm = "Hunt" }
			expect.equal(CollectionMath.needsMutatedCopyForNextRank(2), true, "rank2 needs mut")
			expect.equal(CollectionMath.mutatedCopiesToReserve(state, "Knife"), 1, "reserve 1")
			expect.equal(CollectionMath.mutatedCopiesToReserve(state, "Other"), 0, "off-board 0")
			state.Fusion.Knife.Rank = 3
			expect.equal(CollectionMath.mutatedCopiesToReserve(state, "Knife"), 0, "max clears")
			state.Fusion.Knife.Rank = 2
			state.BoardFocusId = "Knife"
			expect.equal(RealFusion.tryRetire(state, "Knife"), true, "retire")
			expect.equal(state.BoardFocusId, nil, "focus cleared")
			expect.equal(CollectionMath.mutatedCopiesToReserve(state, "Knife"), 0, "retired 0")
		end,
	},
	{
		Name = "Phase6: sell-all style reserve keeps one mutated UID worth; extras sellable",
		Run = function()
			local state = CollectionMath.defaults()
			state.Essence = 500
			local owned = RealFusion.newOwned()
			local commonId = nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					commonId = id
					break
				end
			end
			owned.Counts[commonId] = 3
			expect.equal(RealFusion.tryFuse(state, owned, commonId, 0), true, "r1")
			owned.Counts[commonId] = 5
			state.Essence = math.max(state.Essence, CollectionMath.fusionEssenceCost("Common", 2))
			expect.equal(RealFusion.tryFuse(state, owned, commonId, 0), true, "r2")
			expect.equal(state.BoardFocusId, commonId, "auto focus")
			-- Two mutated copies: keep first, sell second (mirrors FusionReserveByUid N=1).
			owned.Counts[commonId] = (owned.Counts[commonId] or 0) + 2
			owned.Mutated[commonId] = 2
			local slots = RealFusion.reserveSlots(state, owned, 0, { commonId })
			expect.equal(slots.Mutated[commonId], 1, "exactly one mut slot")
			expect.equal(
				RealFusion.shouldKeepForReserve(state, owned, commonId, 0, { commonId }, "Golden"),
				false,
				"2nd mut sellable when already have 2"
			)
			owned.Mutated[commonId] = 1
			expect.equal(
				RealFusion.shouldKeepForReserve(state, owned, commonId, 0, { commonId }, "Golden"),
				true,
				"keep sole mut"
			)
			-- Rank3 fuse succeeds with base copies + mut + essence (OwnedCopies = base only).
			local need = CollectionMath.copiesForRank(3)
			owned.Mutated[commonId] = 1
			owned.Counts[commonId] = need + 1 -- 4 base + 1 mutated
			state.Essence = math.max(state.Essence, CollectionMath.fusionEssenceCost("Common", 3))
			expect.equal(RealFusion.tryFuse(state, owned, commonId, 0), true, "rank3")
			expect.equal(state.Fusion[commonId].Rank, 3, "rank 3")
			expect.equal(CollectionMath.boardIncomeMult(state), CollectionMath.fusionIncomeMult(3), "lift ×1.50")
			expect.equal(state.BoardFocusId, nil, "focus cleared at max")
		end,
	},
	{
		Name = "Phase6: BoardFocusId chooses among 2+ Rank2 candidates",
		Run = function()
			local state = CollectionMath.defaults()
			state.Fusion.A = { Rank = 2, Charm = "Hunt" }
			state.Fusion.B = { Rank = 2, Charm = "Shrine" }
			local cands = CollectionMath.boardFocusCandidates(state)
			expect.equal(#cands, 2, "two candidates")
			expect.equal(CollectionMath.resolveBoardFocusId(state), "A", "default sorted first")
			state.BoardFocusId = "B"
			expect.equal(CollectionMath.resolveBoardFocusId(state), "B", "explicit focus")
			state.Fusion.B.Rank = 3
			expect.equal(CollectionMath.resolveBoardFocusId(state), "A", "invalid focus falls back")
		end,
	},
	{
		Name = "Phase6: sim canFuse OwnedCopies matches server base-only (mutated cannot inflate)",
		Run = function()
			local state = CollectionMath.defaults()
			state.Essence = 500
			local owned = RealFusion.newOwned()
			local commonId = nil
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					commonId = id
					break
				end
			end
			owned.Counts[commonId] = 3
			expect.equal(RealFusion.tryFuse(state, owned, commonId, 0), true, "rank1")
			-- Total 5 with 3 mutated → only 2 base; Rank2 needs 5 base / consume 3.
			owned.Counts[commonId] = 5
			owned.Mutated[commonId] = 3
			state.Essence = math.max(state.Essence, CollectionMath.fusionEssenceCost("Common", 2))
			local ok, msg = RealFusion.tryFuse(state, owned, commonId, 0)
			expect.equal(ok, false, "cannot fuse on mutated inflate")
			expect.truthy(msg and string.find(msg, "more", 1, true) or string.find(msg or "", "Need", 1, true), msg)
			owned.Mutated[commonId] = 0
			owned.Counts[commonId] = 5
			expect.equal(RealFusion.tryFuse(state, owned, commonId, 0), true, "rank2 with 5 base")
		end,
	},
	{
		Name = "Phase6: Hunt Charm family bonus converts to SoftCap familyMult > 1",
		Run = function()
			local bonus = CollectionMath.huntFamilyBonus("Hunt", false)
			expect.truthy(bonus > 0, "hunt bonus")
			expect.truthy(1 + bonus > 1, "SoftCap weight path requires mult>1")
			expect.equal(CollectionMath.huntFamilyBonus("Workshop", false), 0, "non-hunt")
		end,
	},
	{
		Name = "Board Charms are unique specialties (Hunt → Workshop → Shrine)",
		Run = function()
			local state = CollectionMath.defaults()
			expect.equal(CollectionMath.suggestBoardCharm(state, false), "Hunt", "first Hunt")
			state.Fusion.A = { Rank = 1, Charm = "Hunt" }
			expect.equal(CollectionMath.boardCharmOwner(state, "Hunt"), "A", "owner")
			expect.equal(CollectionMath.suggestBoardCharm(state, false), "Shrine", "no Workshop yet")
			expect.equal(CollectionMath.suggestBoardCharm(state, true), "Workshop", "Workshop free")
			state.Fusion.B = { Rank = 1, Charm = "Workshop" }
			expect.equal(CollectionMath.suggestBoardCharm(state, true), "Shrine", "third Shrine")
			state.Fusion.C = { Rank = 1, Charm = "Shrine" }
			expect.equal(CollectionMath.boardCharmOwner(state, "Shrine"), "C", "shrine owner")
			local okDup, owner = CollectionMath.canAssignBoardCharm(state, "Hunt", "D")
			expect.equal(okDup, false, "no duplicate Hunt")
			expect.equal(owner, "A", "owner id")
			expect.equal(CollectionMath.canAssignBoardCharm(state, "Hunt", "A"), true, "same relic ok")
		end,
	},
	{
		Name = "Hunt family-match Essence rewards pedestaled Hunt Charm captures",
		Run = function()
			local baseOnly = CollectionMath.huntCaptureEssenceAmount(0, 0)
			expect.equal(baseOnly, CollectionConfig.HuntCaptureEssence, "base drip")
			local withMatches = CollectionMath.huntCaptureEssenceAmount(3, 0)
			local expected = CollectionConfig.HuntCaptureEssence
				+ 3 * (CollectionConfig.HuntFamilyMatchEssence or 0)
			expect.equal(withMatches, expected, "match bonus")
			expect.truthy(withMatches > baseOnly, "match pays more than AFK drip")
			local pursuit = CollectionMath.huntCaptureEssenceAmount(3, 0, "FamilyHunt")
			expect.truthy(pursuit > withMatches, "FamilyHunt pursuit adds match Essence")
		end,
	},
	{
		Name = "Phase7: Charm potency scales Hunt/Workshop/Shrine; Board income stays rank-only",
		Run = function()
			expect.equal(CollectionMath.charmPotency("Common"), 1, "common")
			expect.truthy(CollectionMath.charmPotency("Rare") > CollectionMath.charmPotency("Common"), "rare>")
			local huntC = CollectionMath.huntFamilyBonus("Hunt", false, "Common")
			local huntR = CollectionMath.huntFamilyBonus("Hunt", false, "Rare")
			expect.truthy(huntR > huntC + 1e-9, "rare Hunt stronger")
			local board = CollectionMath.defaults()
			board.Fusion.A = { Rank = 3, Charm = "Hunt" }
			expect.equal(CollectionMath.boardIncomeMult(board), 1.5, "lift capped")
			local shopC = CollectionMath.workshopEssenceBonus("Common")
			local shopR = CollectionMath.workshopEssenceBonus("Rare")
			expect.truthy(shopR > shopC, "workshop rare>")
			expect.truthy(
				CollectionMath.shrinePulseSeconds("Rare") < CollectionMath.shrinePulseSeconds("Common"),
				"shrine faster"
			)
			-- Common Workshop must beat plain Common sale (floor bug regression).
			local plain = CollectionMath.essenceFromSale("Common", nil, false)
			local withShop = CollectionMath.essenceFromSale("Common", nil, true, "Common")
			expect.truthy(withShop > plain, "workshop common pays")
		end,
	},
	{
		Name = "Phase7.1: Rebirth Pursuits are distinct and gate EpicLineage",
		Run = function()
			expect.truthy(CollectionMath.pursuitConfig("FamilyHunt"), "family")
			expect.truthy(CollectionMath.pursuitConfig("MutationLedger"), "ledger")
			expect.truthy(CollectionMath.pursuitConfig("EpicLineage"), "epic")
			expect.equal(CollectionMath.pursuitAvailable("FamilyHunt", function()
				return false
			end), true, "family open")
			expect.equal(CollectionMath.pursuitAvailable("EpicLineage", function()
				return false
			end), false, "epic locked")
			expect.equal(CollectionMath.pursuitAvailable("EpicLineage", function(id)
				return id == "EpicSalvageBoost"
			end), true, "epic unlock")
		end,
	},
	{
		Name = "Phase7.1: soft-pin reserves Epic Catalyst stockpile after Bloodmoon",
		Run = function()
			local state = CollectionMath.defaults()
			state.MutationGoalsClaimed.FirstBloodmoon = 1
			state.ActivePursuit = "EpicLineage"
			-- Board full + Lift capped with spare Rank3 so Ascend is legal later.
			state.Fusion.A = { Rank = 3, Charm = "Hunt" }
			state.Fusion.B = { Rank = 3, Charm = "Workshop" }
			state.Fusion.C = { Rank = 1, Charm = "Shrine" }
			local owned = { EpicRelic = 2, CommonFill = 3 }
			local tiers = { EpicRelic = "Epic", CommonFill = "Common", A = "Common", B = "Common", C = "Common" }
			local pin = CollectionMath.softPinTarget(state, owned, tiers, 1)
			expect.equal(pin, "EpicRelic", "EpicLineage pins catalyst stock")
			expect.equal(CollectionMath.wouldBreachReserve("EpicRelic", 2, state, false, pin), true, "keep epic")
			-- Without pursuit, board-full still protects Epic catalyst progress.
			state.ActivePursuit = "FamilyHunt"
			local pin2 = CollectionMath.softPinTarget(state, owned, tiers, 1)
			expect.truthy(pin2 == "EpicRelic" or pin2 ~= nil, "still pins something")
			-- Prefer Epic catalyst over dumping when Ascend has no higher non-Epic target stocked.
			local pin3 = CollectionMath.epicCatalystSoftPin(state, owned, tiers)
			expect.equal(pin3, "EpicRelic", "catalyst helper")
		end,
	},
	{
		Name = "Phase7.1: ActivePursuit + PursuitMutSeen sanitize; catalyst recipe is 2 copies once",
		Run = function()
			expect.equal(CollectionConfig.EpicCatalyst.Copies, 2, "two-copy recipe")
			local raw = CollectionMath.defaults()
			raw.ActivePursuit = "MutationLedger"
			raw.PursuitMutSeen = { Knife = true }
			raw.EpicCatalysts = { EpicA = true }
			local s = CollectionMath.sanitize(raw)
			expect.equal(s.ActivePursuit, "MutationLedger", "pursuit persists")
			expect.equal(s.PursuitMutSeen.Knife, true, "mut seen persists")
			expect.equal(s.EpicCatalysts.EpicA, true, "catalyst persists")
			-- Invalid pursuit drops; duplicate catalyst flag stays boolean map (craft is one-shot per id).
			raw.ActivePursuit = "NotAPursuit"
			expect.equal(CollectionMath.sanitize(raw).ActivePursuit, nil, "bad pursuit cleared")
			expect.equal(CollectionMath.pursuitAvailable("EpicLineage", function()
				return false
			end), false, "epic gated")
		end,
	},
	{
		Name = "Hunt Quarry: SoftCap exact bias from session start; AFK path has no quarry",
		Run = function()
			expect.truthy(CollectionConfig.HuntQuarryMult >= 6, "meaningful quarry mult")
			expect.truthy((CollectionConfig.HuntQuarryRetargetSeconds or 0) >= 1, "debounce")
			expect.truthy((CollectionConfig.HuntQuarryRetargetSeconds or 0) <= 5, "not a long lockout")
			local state = CollectionMath.defaults()
			expect.equal(CollectionMath.huntQuarryEligible(state), true, "pre-fuse eligible")
			state.Fusion.A = { Rank = 1, Charm = "Hunt" }
			expect.equal(CollectionMath.huntQuarryEligible(state), true, "post first Board fuse")
			state.Fusion.A = { Rank = 3, Charm = "Hunt" }
			expect.equal(CollectionMath.huntQuarryEligible(state), true, "still eligible at Lift")
			state.HuntQuarryId = "TargetX"
			expect.equal(CollectionMath.resolveHuntQuarryId(state, "SoftY"), "TargetX", "chosen wins")
			expect.equal(
				CollectionMath.resolveHuntQuarryId(state, "SoftY", "SuggestZ", true),
				"TargetX",
				"useful chosen beats suggest"
			)
			expect.equal(
				CollectionMath.resolveHuntQuarryId(state, "SoftY", "SuggestZ", false),
				"SuggestZ",
				"exhausted chosen steers to suggest"
			)
			state.HuntQuarryId = nil
			expect.equal(CollectionMath.resolveHuntQuarryId(state, "SoftY"), "SoftY", "soft-pin fallback")
			expect.equal(
				CollectionMath.resolveHuntQuarryId(state, "SoftY", "SuggestZ", nil),
				"SuggestZ",
				"suggest before soft-pin"
			)
			local SoftCapRarity = require("../lib/softCapRarity")
			local rows = SoftCapRarity.rows()
			local target = rows[1].Id
			local p0 = SoftCapRarity.probabilities(80)
			local pQ = SoftCapRarity.probabilities(80, nil, nil, target, CollectionConfig.HuntQuarryMult)
			expect.truthy((pQ[target] or 0) > (p0[target] or 0) + 1e-12, "quarry raises p")
			local lift = (pQ[target] or 0) / math.max(1e-12, p0[target] or 0)
			expect.truthy(lift >= 5, "weight×mult gives real share lift")
			local firstStock = CollectionMath.quarryNeed({
				State = CollectionMath.defaults(),
				RelicId = "CommonPin",
				TierId = "Common",
				OwnedBase = 0,
				OwnedMutated = 0,
				Discovered = true,
			})
			expect.equal(firstStock.Kind, "FuseCopies", "pre-Board stockpile from 0")
			expect.equal(firstStock.Useful, true, "first-fuse Hunt useful at 0 owned")
			-- Useful vs dupe classification.
			state.Fusion.B = { Rank = 2, Charm = "Workshop" }
			local mutNeed = CollectionMath.quarryNeed({
				State = state,
				RelicId = "B",
				TierId = "Common",
				OwnedBase = 4,
				OwnedMutated = 0,
			})
			expect.equal(mutNeed.Useful, true, "mut useful")
			expect.equal(mutNeed.Kind, "Mutation", "mut kind")
			local dupe = CollectionMath.quarryNeed({
				State = state,
				RelicId = "A",
				TierId = "Common",
				OwnedBase = 0,
				OwnedMutated = 0,
			})
			expect.equal(dupe.Useful, false, "maxed Rank3 not useful")
			local discover = CollectionMath.quarryNeed({
				State = state,
				RelicId = "GhostRare",
				TierId = "Rare",
				OwnedBase = 0,
				OwnedMutated = 0,
				Discovered = false,
			})
			expect.equal(discover.Kind, "Discover", "undiscovered useful")
			expect.equal(discover.Useful, true, "discover useful")
			local mutCodex = CollectionMath.quarryNeed({
				State = state,
				RelicId = "A",
				TierId = "Common",
				OwnedBase = 0,
				OwnedMutated = 0,
				Discovered = true,
				CodexMutCount = 0,
			})
			expect.equal(mutCodex.Kind, "MutCodex", "board first mut useful")
			expect.equal(mutCodex.Useful, true, "mutcodex useful")
			local suggested = CollectionMath.suggestHuntQuarry({
				State = state,
				OwnedBase = { A = 0, B = 4, GhostRare = 0 },
				OwnedMutated = { A = 0, B = 0, GhostRare = 0 },
				Discovered = { A = true, B = true, GhostRare = false },
				CodexMutCounts = { A = 0, B = 0, GhostRare = 0 },
				RelicMeta = {
					A = { Tier = "Common", Name = "A", Family = "Demonic" },
					B = { Tier = "Common", Name = "B", Family = "Spirit" },
					GhostRare = { Tier = "Rare", Name = "Ghost", Family = "Demonic" },
				},
			})
			-- Rank2 mut need outranks Discover/MutCodex.
			expect.equal(suggested, "B", "suggest mut recipe first")
			-- UsefulHits must advance an objective — not Ready-state or plain dupes.
			expect.equal(
				CollectionMath.quarryCaptureAdvances(mutNeed, false),
				false,
				"mut without mut hit"
			)
			expect.equal(CollectionMath.quarryCaptureAdvances(mutNeed, true), true, "mut with mut hit")
			expect.equal(CollectionMath.quarryCaptureAdvances(discover, false), true, "discover advances")
			expect.equal(CollectionMath.quarryCaptureAdvances(dupe, true), false, "dupe never advances")
			local readyCat = CollectionMath.quarryNeed({
				State = state,
				RelicId = "EpicZ",
				TierId = "Epic",
				OwnedBase = 2,
				OwnedMutated = 0,
				Discovered = true,
			})
			expect.equal(readyCat.Kind, "Catalyst", "catalyst ready kind")
			expect.equal(readyCat.Missing, 0, "catalyst ready missing0")
			expect.equal(
				CollectionMath.quarryCaptureAdvances(readyCat, false),
				false,
				"ready catalyst hit is not progress"
			)
			state.HuntQuarrySetAt = 100
			local ready, left = CollectionMath.huntQuarryRetargetReady(state, 101)
			expect.equal(ready, false, "debounce blocks")
			expect.truthy(left > 0, "debounce left")
			local ready2 = CollectionMath.huntQuarryRetargetReady(state, 104)
			expect.equal(ready2, true, "debounce cleared")
		end,
	},
	{
		Name = "Retire preview: sole Rank3 drop warns; non-lift retire keeps ×income",
		Run = function()
			local state = CollectionMath.defaults()
			state.Fusion.A = { Rank = 3, Charm = "Hunt" }
			state.Fusion.B = { Rank = 1, Charm = "Workshop" }
			local sole = CollectionMath.previewRetire(state, "A")
			expect.truthy(sole, "preview A")
			expect.equal(sole and sole.Rank, 3, "rank")
			expect.equal(sole and sole.CharmId, "Hunt", "charm")
			expect.equal(sole and sole.IncomeBefore, 1.5, "before ×1.50")
			expect.equal(sole and sole.IncomeAfter, 1.12, "after Rank1 only")
			expect.equal(sole and sole.DropsBoardLift, true, "drops")
			expect.equal(sole and sole.IsSoleHighest, true, "sole highest")
			local keep = CollectionMath.previewRetire(state, "B")
			expect.truthy(keep, "preview B")
			expect.equal(keep and keep.IncomeBefore, 1.5, "lift stays before")
			expect.equal(keep and keep.IncomeAfter, 1.5, "lift stays after")
			expect.equal(keep and keep.DropsBoardLift, false, "no drop")
			expect.equal(keep and keep.IsSoleHighest, false, "not sole")
			expect.equal(CollectionMath.previewRetire(state, "Missing"), nil, "missing nil")
		end,
	},
	{
		Name = "Phase7: bestAscendHint Retire→Fuse higher-tier Charm lineage",
		Run = function()
			local state = CollectionMath.defaults()
			state.MutationGoalsClaimed.FirstGolden = 1
			state.Essence = 500
			-- Two Rank3s so Retire of Hunt holder cannot drop Board Lift.
			state.Fusion.CommonA = { Rank = 3, Charm = "Hunt" }
			state.Fusion.CommonB = { Rank = 3, Charm = "Workshop" }
			state.Fusion.CommonC = { Rank = 1, Charm = "Shrine" }
			local meta = {
				CommonA = { Tier = "Common", Name = "Knife", Family = "Demonic" },
				CommonB = { Tier = "Common", Name = "Bell", Family = "Spirit" },
				CommonC = { Tier = "Common", Name = "Lantern", Family = "Spirit" },
				RareX = { Tier = "Rare", Name = "RareBlade", Family = "Demonic" },
			}
			local owned = { CommonA = 0, CommonB = 0, CommonC = 0, RareX = 3 }
			local hint = CollectionMath.bestAscendHint(state, owned, meta, true)
			expect.truthy(hint, "hint")
			expect.equal(hint and hint.Charm, "Hunt", "ascend Hunt")
			expect.equal(hint and hint.TargetRelicId, "RareX", "target")
			expect.equal(hint and hint.Ready, true, "ready")
			expect.truthy((hint and hint.TargetPotency or 0) > (hint and hint.CurrentPotency or 0), "potency up")
			-- Sole Rank3 Hunt must not be retired (would drop Lift).
			local sole = CollectionMath.defaults()
			sole.Essence = 500
			sole.Fusion.Only = { Rank = 3, Charm = "Hunt" }
			local soleMeta = {
				Only = { Tier = "Common", Name = "Knife", Family = "Demonic" },
				RareX = { Tier = "Rare", Name = "RareBlade", Family = "Demonic" },
			}
			expect.equal(CollectionMath.bestAscendHint(sole, { RareX = 3 }, soleMeta, true), nil, "no lift drop")
		end,
	},
	{
		Name = "sim fuses diversify Board Charms instead of stacking Workshop",
		Run = function()
			local state = CollectionMath.defaults()
			state.MutationGoalsClaimed.FirstGolden = 1
			state.MutationGoalsClaimed.FifteenMutated = 1 -- third Board slot
			state.Essence = 500
			local owned = RealFusion.newOwned()
			local ids = {}
			for id, relic in require("../../src/shared/RelicConfig").ById do
				if relic.Tier == "Common" then
					table.insert(ids, id)
					if #ids >= 3 then
						break
					end
				end
			end
			expect.equal(CollectionMath.fusionSlots(state, 0) >= 3, true, "3 slots")
			for _, id in ids do
				owned.Counts[id] = 3
				expect.equal(RealFusion.tryFuse(state, owned, id, 0), true, `fuse {id}`)
			end
			local charms = {}
			for _, entry in state.Fusion do
				charms[entry.Charm] = true
			end
			expect.equal(charms.Hunt == true, true, "has Hunt")
			expect.equal(charms.Workshop == true, true, "has Workshop")
			expect.equal(charms.Shrine == true, true, "has Shrine")
		end,
	},
}

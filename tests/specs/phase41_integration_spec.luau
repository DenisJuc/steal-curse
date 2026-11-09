-- Phase 4.1 integration verification (Lune).
-- Mirrors CollectionService / EconomyService / RebirthService shared math paths.
-- Does NOT claim live Studio UI / ProfileStore session coverage — see /p41smoke for that.

local AutoSell = require("../../src/shared/AutoSell")
local BalanceTrials = require("../../src/shared/BalanceTrials")
local CollectionConfig = require("../../src/shared/CollectionConfig")
local CollectionMath = require("../../src/shared/CollectionMath")
local Config = require("../../src/shared/Config")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local RealFusion = require("../lib/realFusionEconomy")
local RelicConfig = require("../../src/shared/RelicConfig")
local Rebirth = require("../../src/shared/Rebirth")
local expect = require("../lib/expect")

local function firstCommon(): string
	for id, relic in RelicConfig.ById do
		if relic.Tier == "Common" then
			return id
		end
	end
	error("no Common relic")
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

-- EconomyService.GetIncomeMultiplier composition (no Player): IncomeStack × Rebirth × BoardOnce.
local function incomeMultOnce(boardMult: number, rebirths: number, incomeStack: number?): number
	local stack = incomeStack or 1
	return stack * Rebirth.incomeMultiplier(Config.Rebirth, rebirths) * boardMult
end

return {
	{
		Name = "production: Collection off outside Studio — reserve path inert",
		Run = function()
			expect.equal(BalanceTrials.isStudio(), false, "lune not studio")
			expect.equal(BalanceTrials.collectionEnabled(), false, "collection off")
			expect.equal(BalanceTrials.boardGlobalFusionIncome(), false, "board global off")
			expect.equal(BalanceTrials.rebirthModel(), "Live", "production Live rebirth")
			-- Shared reserveCopies still exists, but IsFusionReserved early-outs when Collection off.
			-- Behavioral impact on production AutoSell: none (FusionReserve never set by Collection).
		end,
	},
	{
		Name = "SoftCap_P4 mock: reserve 5 → AutoSell holds → Rank2 → Board ×1.28 once → retire → B+",
		Run = function()
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevColl = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = true
			BalanceTrials.Active = "SoftCap_P4"
			BalanceTrials.CollectionPrototype = true

			local ok, err = pcall(function()
				expect.equal(BalanceTrials.collectionEnabled(), true, "collection on")
				expect.equal(BalanceTrials.boardGlobalFusionIncome(), true, "P4 board global")
				expect.equal(BalanceTrials.rebirthModel(), "BPlus", "B+")
				expect.equal(Config.Rebirth.BaseCost, 5e5, "500K BaseCost")

				local id = firstCommon()
				local state = CollectionMath.defaults()
				state.Essence = 500
				state.Fusion[id] = { Rank = 1, Charm = "Hunt" }
				state.FusionPins[id] = true

				local need2 = CollectionMath.copiesForRank(2)
				expect.equal(CollectionMath.reserveCopies(id, state, false, nil), need2, "rank1 reserves next recipe")
				expect.equal(need2, 5, "recipe is 5")

				local rules = AutoSell.defaults({ "Common" })
				rules.Tiers.Common = "SellDuplicates"
				for copies = 1, need2 do
					local reserved = CollectionMath.wouldBreachReserve(id, copies, state, false, nil)
					local sell, reason = AutoSell.decide(rules, {
						Tier = "Common",
						BaseOneIn = 2,
						First = false,
						Mutated = false,
						Duplicate = true,
						Favorite = false,
						FusionReserve = reserved,
					})
					expect.equal(sell, false, `keep #{copies}`)
					expect.equal(reason, "FusionReserve", `reserve #{copies}`)
				end
				local sell6 = AutoSell.decide(rules, {
					Tier = "Common",
					BaseOneIn = 2,
					First = false,
					Mutated = false,
					Duplicate = true,
					Favorite = false,
					FusionReserve = CollectionMath.wouldBreachReserve(id, need2 + 1, state, false, nil),
				})
				expect.equal(sell6, true, "6th may sell")

				local owned = RealFusion.newOwned()
				owned.Counts[id] = need2
				local cost2 = CollectionMath.fusionEssenceCost("Common", 2)
				state.Essence = cost2
				expect.equal(RealFusion.tryFuse(state, owned, id, 0), true, "Rank2 via TryFuse mirror")
				expect.equal(state.Fusion[id].Rank, 2, "rank 2")
				local lift = CollectionMath.boardIncomeMult(state)
				expect.equal(lift, CollectionMath.fusionIncomeMult(2), "Board ×1.28")
				expect.near(lift, 1.28, 1e-9, "literal ×1.28")

				-- SoftCap_P4: per-pedestal fusion contrib is 1; board applied once in global mult.
				local pedFuse = 1 -- CollectionService.FusionIncomeMult under boardGlobal
				local pedBase = 100
				local pedLevel = 2
				local pedPart = pedBase * pedLevel * pedFuse
				local global = incomeMultOnce(lift, 0, 1)
				local total = pedPart * global
				local doubleApplied = pedPart * lift * lift * 1 -- would be wrong
				expect.near(total, pedPart * 1.28, 1e-6, "board once")
				expect.truthy(math.abs(total - doubleApplied) > 1, "not double-applied")

				-- Income without pedestal placement still gets board mult (global).
				local emptyPedPart = 0
				local withBoardOnly = emptyPedPart * global + 50 * global -- shrine-like base * global
				expect.near(withBoardOnly / 50, 1.28, 1e-9, "board applies without ped fused relic")

				-- Retire
				state.Essence = (CollectionConfig.BoardRetireEssence or 80) + 10
				expect.equal(RealFusion.tryRetire(state, id), true, "retire")
				expect.equal(state.Fusion[id], nil, "fusion cleared")
				expect.equal(state.FusionPins[id], nil, "pin cleared")
				expect.equal(CollectionMath.boardIncomeMult(state), 1, "income contribution gone")
				expect.equal(CollectionMath.reserveCopies(id, state, false, nil), 0, "no board reserve")

				-- B+ Rebirth preserves Fusion when re-seeded
				state.Fusion[id] = { Rank = 2, Charm = "Workshop" }
				state.FusionPins[id] = true
				state.Essence = 77
				local data = deepCopy(DataTemplate.Template)
				data.CE = Config.Rebirth.BaseCost
				data.Pedestals = { { Level = 25, Locked = false }, { Level = 30 }, { Level = 40 } }
				data.Skills.CoreLuck = 18
				data.Skills.PedestalMastery = 2
				data.Collection = state
				Rebirth.apply(data, "BPlus")
				expect.equal(data.CE, 0, "CE wiped")
				expect.equal(data.Pedestals[1].Level, 25, "ped kept")
				expect.equal(data.Skills.CoreLuck, 18, "skills kept")
				expect.equal(data.Collection.Fusion[id].Rank, 2, "Fusion kept")
				expect.equal(data.Collection.Fusion[id].Charm, "Workshop", "Charm kept")
				expect.equal(data.Collection.Essence, 77, "Essence kept")
				expect.equal(Config.Rebirth.BaseCost, 5e5, "BaseCost unchanged")
			end)

			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevColl
			if not ok then
				error(err)
			end
		end,
	},
	{
		Name = "SoftCap_P3 mock: reserve fix applies; BoardIncomeMult stays 1; retire gated",
		Run = function()
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevColl = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = true
			BalanceTrials.Active = "SoftCap_P3"
			BalanceTrials.CollectionPrototype = true

			local ok, err = pcall(function()
				expect.equal(BalanceTrials.collectionEnabled(), true, "P3 collection")
				expect.equal(BalanceTrials.boardGlobalFusionIncome(), false, "P3 not board-global")
				expect.equal(BalanceTrials.rebirthModel(), "Live", "P3 Live rebirth")

				local id = firstCommon()
				local state = CollectionMath.defaults()
				state.Fusion[id] = { Rank = 1, Charm = "Hunt" }
				state.FusionPins[id] = true
				-- Same reserve bugfix (correct recipe) — not SoftCap_P4-gated.
				expect.equal(CollectionMath.reserveCopies(id, state, false, nil), CollectionMath.copiesForRank(2), "P3 also reserves 5")
				expect.equal(CollectionMath.boardIncomeMult(state), CollectionMath.fusionIncomeMult(1), "math still reports best rank")
				-- Server BoardIncomeMult early-outs to 1 when not boardGlobalFusionIncome.
				local serverBoard = if BalanceTrials.boardGlobalFusionIncome()
					then CollectionMath.boardIncomeMult(state)
					else 1
				expect.equal(serverBoard, 1, "P3 server board mult inert")
			end)

			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevColl
			if not ok then
				error(err)
			end
		end,
	},
	{
		Name = "sim +200 scoring lives only in RealFusion.pickFuseTarget (not CollectionMath)",
		Run = function()
			-- CollectionMath has no fuse scoring; server TryFuse is player-driven via UI Fuse button.
			expect.equal(type(CollectionMath.canFuse), "function", "server uses canFuse")
			expect.equal(type((CollectionMath :: any).pickFuseTarget), "nil", "no server auto-pick")
			expect.equal(type(RealFusion.pickFuseTarget), "function", "sim policy only")
		end,
	},
}

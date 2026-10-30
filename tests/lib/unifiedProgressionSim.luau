-- Rev 4 integrated progression simulator (design validation only).
-- SoftCap rarity + candidate upgrades + rebirth models A / B / B+ / C.
-- Fusion uses real CollectionMath board/rank/consume rules (not the old income stub).
-- Does NOT mutate live Config or runtime services.

local CollectionConfig = require("../../src/shared/CollectionConfig")
local CollectionMath = require("../../src/shared/CollectionMath")
local Config = require("../../src/shared/Config")
local Economy = require("../../src/shared/Economy")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local Rebirth = require("../../src/shared/Rebirth")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local SkillConfig = require("../../src/shared/SkillConfig")
local SoftCapRarity = require("./softCapRarity")
local RealFusion = require("./realFusionEconomy")
local relicIncome = require("./relicIncome")

-- CollectionConfig used for BoardRetireEssence in tryBuy.

local Unified = {}

export type Policy = "AfkUpgrader" | "Casual" | "Hunter" | "Optimized"
export type RebirthModel = "A" | "B" | "BPlus" | "C" | "Live"
export type Sampler = "SoftCap" | "SoftAC"

export type Checkpoint = {
	Minute: number,
	Luck: number,
	Band: { [string]: number },
	Unique: number,
	UniqueByTier: { [string]: number },
	TotalFinds: number,
	Dupes: number,
	Mutations: number,
	CE: number,
	IncomePerSec: number,
	CoreLuck: number,
	ScanRank: number,
	EnergyRank: number,
	EnergyII: number,
	MutRes: number,
	PedLevels: { number },
	PedMastery: number,
	Slots: number,
	Rebirths: number,
	Essence: number,
	EssenceSpent: number,
	Fusions: number,
	FormsProgress: number,
	BoardSlots: number,
	ActiveBoard: number,
	FusedOnPedestal: number,
	FusionLift: number, -- SoftCap_P4: board best-rank mult; else pedestal pairing ratio
	BoardRetires: number,
	CharmAscensions: number,
	BestCharmPotency: number,
	EpicCatalysts: number,
	ActivePursuit: string?,
	HuntQuarryHits: number,
	HuntQuarryUsefulHits: number,
	HuntQuarryRetargets: number,
	CollectionOpen: boolean,
	NextUnlockSec: number?,
	LongestDryMin: number,
	UsefulBuysLeft: number,
}

export type RebirthTrace = {
	Index: number, -- 1 = first Rebirth (R1)
	Sec: number,
	Cost: number,
	CeBefore: number,
	IncomeBefore: number,
	IncomeAfter: number,
	CL: number,
	Mastery: number,
	PedMin: number,
	Energy: number,
	MutRes: number,
	Essence: number,
	Board: number,
	Lift: number,
	MaxFusionRank: number,
	FirstGolden: boolean,
	UsefulLeft: number,
}

export type RunResult = {
	Policy: Policy,
	Sampler: Sampler,
	RebirthModel: RebirthModel,
	Seed: number,
	Checkpoints: { Checkpoint },
	FirstRareAt: number?,
	FirstEpicAt: number?,
	FirstRebirthAt: number?,
	RebirthsAt: { number },
	RebirthTrace: { RebirthTrace },
	IncomeBeforeR1: number?, -- CE/sec immediately before first Rebirth apply
	IncomeAfterR1: number?, -- CE/sec immediately after first Rebirth apply
	FirstAffordR1At: number?, -- first second CE >= R1 cost (often ≪ FirstRebirthAt)
	CeAtFirstAfford: number?,
	CeAtR1: number?,
	PedMinAtR1: number?,
	CoreLuckAtR1: number?,
	EnergyAtR1: number?,
	UsefulEmptyAt: number?,
	Cl25At: number?, -- first second CoreLuck hits post-R1 cap
	Mastery5At: number?,
	FirstGoldenAt: number?,
	FirstRank2At: number?,
	FirstRank3At: number?,
	Board2At: number?, -- second board slot unlocked (First Golden SlotBonus)
	FirstCharmAscendAt: number?,
	CharmAscensions: number?,
	Rank3Blockers: { Mutation: number, Copies: number, Essence: number, Other: number }?,
	Final: Checkpoint,
	ApproxNotes: { string },
}

-- Candidate upgrade economy (sim-only; not live SkillConfig).
local CL_MAX = 25
local SCAN_MAX = 12
local ENERGY_MAX = 15
local ENERGY_II_MAX = 10
local PED_MAX = Config.Economy.PedestalMaxLevel or 50
local PED_MASTERY_MAX = 5
local SWIFT_MAX = 6

local frozenBase: { [string]: number } = {}
for _, relic in RelicConfig.Relics do
	frozenBase[relic.Id] = relicIncome.base(relic.Id)
end

local function mulberry32(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

local function coreLuckMult(rank: number): number
	-- 25 ranks spanning roughly old 0..40 Soft A luck: each rank ≈ +1.6 old ranks under ÷12.
	return 10 ^ (rank * 1.6 / 12)
end

local function coreLuckCost(rank: number): number
	-- Soft-C style on a compressed track.
	local flat = 100 * (1.7 ^ rank)
	return math.ceil(flat * ((1 + 0.05 * rank) ^ 1.35) - 1e-9)
end

local function scanInterval(rank: number, maxRank: number?): number
	local maxR = maxRank or SCAN_MAX
	local r = math.clamp(rank, 0, maxR)
	return 4 * (0.25 ^ (r / maxR))
end

local function energyBonus(rank: number, ii: number): number
	return 0.02 * rank + 0.01 * ii
end

local function pedMult(level: number): number
	return Economy.pedestalMultiplier(Config.Economy, level)
end

local function pedUpgradeCost(level: number): number
	return Economy.upgradeCost(Config.Economy, level)
end

local function masteryCost(rank: number): number
	local node = SkillConfig.ById.PedestalMastery
	if node then
		return SkillConfig.cost(node, rank) or math.ceil(180000 * (2.8 ^ rank) - 1e-9)
	end
	return math.ceil(180000 * (2.8 ^ rank) - 1e-9)
end

local function makeSoftACRules()
	local tiers = {}
	for _, tier in RarityConfig.Tiers do
		local denom = tier.Denominator
		if tier.Id == "Epic" then
			denom = 20000
		elseif tier.Id == "Legendary" then
			denom = 500000
		end
		table.insert(tiers, { Id = tier.Id, Denominator = denom })
	end
	return {
		Tiers = tiers,
		ByTier = RollMath.groupByTier(RelicConfig.Relics),
		Mutations = MutationConfig.Mutations,
		MutationChanceByRank = MutationConfig.ChanceByRank,
		FocusTierOrHigherChance = Config.Focus.TierOrHigherChance,
		FrequencyMultiplierByRank = Config.Frequency.MultiplierByRank,
	}
end

local softACRules = makeSoftACRules()

local function tierIndex(tierId: string): number
	return RarityConfig.IndexById[tierId] or 0
end

-- Optional Phase 3/4 proposal knobs (sim-only; never writes live Config).
export type ProposalTune = {
	Id: string?,
	-- Pre-R1 CoreLuck cap under B+ (Phase 3 Studio default 18).
	PreR1ClCap: number?,
	-- Mastery ranks buyable before R1 (Phase 3 Studio default 2).
	PreR1MasteryMax: number?,
	-- Override Rebirth.BaseCost (live 4e8). Phase 3 keeps live; Phase 4 may explore cuts.
	RebirthBaseCost: number?,
	-- Live ScanSpeed max is 12.
	ScanMax: number?,
	-- When true (default with CollectionHud), use real CollectionMath fusion.
	FusionIncome: boolean?,
	-- SoftCap_P4: Board-global best-rank income (default true when FusionIncome).
	BoardGlobalFusion: boolean?,
	-- First N fusions + every Nth thereafter count as meaningful goals (not routine spam).
	FusionMeaningfulEvery: number?,
}

-- PerSecond = legacy 1Hz loop (regression). Event = jump to next scan/hunt/buy/checkpoint.
export type TickMode = "PerSecond" | "Event"

function Unified.run(options: {
	Seed: number,
	Minutes: number?,
	Policy: Policy,
	Sampler: Sampler?,
	RebirthModel: RebirthModel?,
	CollectionHud: boolean?, -- if false, policy never uses Collection (playtest-like)
	Proposal: ProposalTune?,
	TickMode: TickMode?,
}): RunResult
	local minutes = options.Minutes or 180
	local policy = options.Policy
	local sampler = options.Sampler or "SoftCap"
	local rebirthModel = options.RebirthModel or "BPlus"
	local collectionHud = if options.CollectionHud == nil then true else options.CollectionHud
	local proposal = options.Proposal or {}
	local preR1ClCap = proposal.PreR1ClCap or 18
	local preR1MasteryMax = proposal.PreR1MasteryMax or 2
	local scanMax = proposal.ScanMax or SCAN_MAX
	local fusionMeaningfulEvery = proposal.FusionMeaningfulEvery or 8
	local tickMode: TickMode = options.TickMode or "Event"
	-- Playtest-calibrated AFK upgrader: no Collection until HUD exists.
	if policy == "AfkUpgrader" and options.CollectionHud == nil then
		collectionHud = false
	end
	-- Real Fusion when Collection HUD is on (unless explicitly disabled).
	local fusionIncomeOn = if proposal.FusionIncome ~= nil then proposal.FusionIncome == true else collectionHud
	-- SoftCap_P4 default: board-global best-rank income (not per-pedestal).
	local boardGlobalFusion = if proposal.BoardGlobalFusion ~= nil
		then proposal.BoardGlobalFusion == true
		else fusionIncomeOn

	local rng = mulberry32(options.Seed * 9973 + 17)
	SoftCapRarity.invalidateSampler()
	local rebirthSettings = {
		BaseCost = proposal.RebirthBaseCost or Config.Rebirth.BaseCost,
		CostGrowth = Config.Rebirth.CostGrowth,
		IncomeGrowth = Config.Rebirth.IncomeGrowth,
		LuckGrowth = 1.25,
	}

	local ce = 0
	local skills = {
		CoreLuck = 0,
		ScanSpeed = 0,
		Energy = 0,
		EnergyII = 0,
		MutRes = 0,
		Freq = 0,
		Sight = 0,
		Bind = 0,
		Harvest = 0,
		Swift = 0,
	}
	local slots = 3
	local pedLevels = { 1, 1, 1 }
	local pedMastery = 0
	local heldIncome = { 0, 0, 0 } :: { number }
	local heldRelicIds = { nil, nil, nil } :: { string? }
	local rebirths = 0
	local rebirthsAt = {}
	local rebirthTrace: { RebirthTrace } = {}
	local collectionState = CollectionMath.defaults()
	local owned = RealFusion.newOwned()
	local uniqueMutRelics: { [string]: boolean } = {}
	local uniqueMutByType: { [string]: { [string]: boolean } } = {}
	local essenceSpent = 0
	local fusions = 0
	local boardRetires = 0
	local charmAscensions = 0
	local firstCharmAscendAt: number? = nil
	local huntQuarryHits = 0
	local huntQuarryUsefulHits = 0
	local huntQuarryRetargets = 0
	local formsProgress = 0
	local fusionSinceMeaningful = 0
	local incomeBeforeRebirth: number? = nil
	local incomeAfterRebirth: number? = nil
	local firstAffordR1At: number? = nil
	local ceAtFirstAfford: number? = nil
	local ceAtR1: number? = nil
	local pedMinAtR1: number? = nil
	local coreLuckAtR1: number? = nil
	local energyAtR1: number? = nil
	local cl25At: number? = nil
	local mastery5At: number? = nil
	local firstGoldenAt: number? = nil
	local firstRank2At: number? = nil
	local firstRank3At: number? = nil
	local board2At: number? = nil
	local maxFusionRank = 0
	local rank3Blockers = { Mutation = 0, Copies = 0, Essence = 0, Other = 0 }
	local lastRank3BlockSample = -1e9

	local function pedMinNow(): number
		local pedMin = pedLevels[1] or 1
		for i = 1, slots do
			pedMin = math.min(pedMin, pedLevels[i] or 1)
		end
		return pedMin
	end

	local function noteMilestones(sec: number)
		if cl25At == nil and skills.CoreLuck >= CL_MAX then
			cl25At = sec
		end
		if mastery5At == nil and pedMastery >= PED_MASTERY_MAX then
			mastery5At = sec
		end
		if collectionHud then
			if firstGoldenAt == nil and collectionState.MutationGoalsClaimed.FirstGolden then
				firstGoldenAt = sec
			end
			if board2At == nil and RealFusion.boardSlots(collectionState, rebirths) >= 2 then
				board2At = sec
			end
			if firstRank2At == nil and maxFusionRank >= 2 then
				firstRank2At = sec
			end
			if firstRank3At == nil and maxFusionRank >= 3 then
				firstRank3At = sec
			end
		end
	end

	local function sampleRank3Blockers(sec: number)
		if not collectionHud or maxFusionRank < 2 or maxFusionRank >= 3 then
			return
		end
		if sec - lastRank3BlockSample < 60 then
			return
		end
		lastRank3BlockSample = sec
		local focus = CollectionMath.resolveBoardFocusId(collectionState)
		local targetId = focus
		if not targetId then
			local cands = CollectionMath.boardFocusCandidates(collectionState)
			targetId = cands[1]
		end
		if not targetId then
			return
		end
		local relic = RelicConfig.ById[targetId]
		if not relic then
			return
		end
		local entry = collectionState.Fusion[targetId]
		local rank = if entry then entry.Rank else 0
		local _, _, kind = CollectionMath.canFuse({
			TierId = relic.Tier,
			RelicId = targetId,
			CurrentRank = rank,
			OwnedCopies = RealFusion.baseCopies(owned, targetId),
			Essence = collectionState.Essence,
			State = collectionState,
			Rebirths = rebirths,
			HasMutatedCopy = (owned.Mutated[targetId] or 0) > 0,
			EpicCatalystReady = true,
		})
		if kind == "Mutation" then
			rank3Blockers.Mutation += 1
		elseif kind == "Copies" then
			rank3Blockers.Copies += 1
		elseif kind == "Essence" then
			rank3Blockers.Essence += 1
		elseif kind then
			rank3Blockers.Other += 1
		end
	end
	local seen: { [string]: boolean } = {}
	local uniqueByTier: { [string]: number } = {}
	for _, t in RarityConfig.Tiers do
		uniqueByTier[t.Id] = 0
	end
	local uniqueCount = 0
	local totalFinds, dupes, mutations = 0, 0, 0
	local firstRareAt, firstEpicAt = nil, nil
	local usefulEmptyAt = nil
	local lastMeaningful = 0
	local longestDry = 0
	local gates = {
		EnergyII = false,
		AttuneHigh = false, -- CL 16+
		Mastery = false,
		MutDeep = false,
	}

	local checkpoints = {}
	local wantMinutes = { 5, 15, 18, 30, 45, 60, 90, 120, 150, 180 }
	local wantSet = {}
	for _, m in wantMinutes do
		wantSet[m] = true
	end

	local cachedLuck = 0
	local luckDirty = true
	local function markLuckDirty()
		luckDirty = true
	end
	local function luck(): number
		if not luckDirty then
			return cachedLuck
		end
		local core = coreLuckMult(skills.CoreLuck)
		local reb = Rebirth.luckMultiplier(rebirthSettings, rebirths)
		local codex = 1 + math.min(0.5, uniqueCount / 92 * 0.5)
		cachedLuck = core * reb * codex
		luckDirty = false
		return cachedLuck
	end

	local cachedIncome = 0
	local incomeDirty = true
	local function markIncomeDirty()
		incomeDirty = true
	end

	local function masteryMult(): number
		return 1 + 0.04 * pedMastery
	end

	local function incomePerSec(): number
		if not incomeDirty then
			return cachedIncome
		end
		local mm = masteryMult()
		local contrib = table.create(slots)
		for i = 1, slots do
			local base = heldIncome[i] or 0
			local id = heldRelicIds[i]
			local pm = pedMult(pedLevels[i] or 1)
			if fusionIncomeOn and collectionHud then
				contrib[i] = RealFusion.pedestalContribution(collectionState, id, base, pm, mm, boardGlobalFusion)
			else
				contrib[i] = base * pm * mm
			end
		end
		local board = if fusionIncomeOn and collectionHud and boardGlobalFusion
			then RealFusion.boardIncomeMult(collectionState)
			else 1
		local global = (1 + energyBonus(skills.Energy, skills.EnergyII))
			* Rebirth.incomeMultiplier(rebirthSettings, rebirths)
			* board
		cachedIncome = Economy.totalIncome(contrib, global)
		incomeDirty = false
		return cachedIncome
	end

	local function fusionLiftNow(): number
		if not fusionIncomeOn or not collectionHud then
			return 1
		end
		return RealFusion.incomeLiftRatio(
			collectionState,
			heldRelicIds,
			heldIncome,
			pedLevels,
			slots,
			pedMult,
			masteryMult(),
			boardGlobalFusion
		)
	end

	-- Keep income-relevant fused relics on pedestals when they beat the weakest slot.
	local function promoteFusedToPedestals()
		if not fusionIncomeOn or not collectionHud then
			return
		end
		local candidates = {}
		for relicId, entry in collectionState.Fusion do
			if (entry.Rank or 0) > 0 and (owned.Counts[relicId] or 0) > 0 then
				local base = frozenBase[relicId] or 1
				local eff = base * CollectionMath.fusionIncomeMult(entry.Rank)
				table.insert(candidates, { Id = relicId, Base = base, Eff = eff })
			end
		end
		table.sort(candidates, function(a, b)
			return a.Eff > b.Eff
		end)
		for _, cand in candidates do
			local already = false
			for i = 1, slots do
				if heldRelicIds[i] == cand.Id then
					already = true
					break
				end
			end
			if already then
				continue
			end
			local worstI, worstV = 1, (heldIncome[1] or 0) * (if heldRelicIds[1]
				then RealFusion.fusionIncomeMult(collectionState, heldRelicIds[1])
				else 1)
			for i = 1, slots do
				local id = heldRelicIds[i]
				local v = (heldIncome[i] or 0)
					* (if id then RealFusion.fusionIncomeMult(collectionState, id) else 1)
				if v < worstV then
					worstV, worstI = v, i
				end
			end
			if cand.Eff > worstV then
				heldIncome[worstI] = cand.Base
				heldRelicIds[worstI] = cand.Id
				markIncomeDirty()
			end
		end
	end

	local function uniqueAnyMutated(): number
		local n = 0
		for _ in uniqueMutRelics do
			n += 1
		end
		return n
	end

	local function uniqueMutCounts(): { [string]: number }
		local out = {}
		for mutId, set in uniqueMutByType do
			local n = 0
			for _ in set do
				n += 1
			end
			out[mutId] = n
		end
		return out
	end

	local function noteMeaningful(sec: number)
		if lastMeaningful > 0 then
			longestDry = math.max(longestDry, (sec - lastMeaningful) / 60)
		end
		lastMeaningful = sec
	end

	local function clCapNow(): number
		if rebirthModel ~= "BPlus" or gates.AttuneHigh then
			return CL_MAX
		end
		return preR1ClCap
	end

	local function masteryCapNow(): number
		if gates.Mastery then
			return PED_MASTERY_MAX
		end
		return preR1MasteryMax
	end

	local function usefulBuysLeft(): number
		local n = 0
		if skills.CoreLuck < clCapNow() then
			n += 1
		end
		if skills.ScanSpeed < scanMax then
			n += 1
		end
		if skills.Energy < ENERGY_MAX then
			n += 1
		end
		if gates.EnergyII and skills.EnergyII < ENERGY_II_MAX then
			n += 1
		end
		if skills.MutRes < (if gates.MutDeep then 5 else 2) then
			n += 1
		end
		for i = 1, slots do
			if (pedLevels[i] or 1) < PED_MAX then
				n += 1
			end
		end
		if pedMastery < masteryCapNow() then
			n += 1
		end
		if slots < 5 then
			n += 1
		end
		if slots < 6 and rebirths >= 1 then
			n += 1
		end
		-- Collection: legal fuse on a display piece, or unclaimed mutation/board goals.
		if collectionHud and fusionIncomeOn then
			local target = RealFusion.pickFuseTarget(collectionState, owned, rebirths, heldRelicIds)
			if target then
				local entry = collectionState.Fusion[target]
				local isNew = not entry or (entry.Rank or 0) <= 0
				local onPed = false
				for i = 1, slots do
					if heldRelicIds[i] == target then
						onPed = true
						break
					end
				end
				if fusions < 3 or isNew or onPed then
					n += 1
				end
			end
			local goalsLeft = 0
			for _, goal in CollectionConfig.MutationGoals do
				if not collectionState.MutationGoalsClaimed[goal.Id] then
					goalsLeft += 1
				end
			end
			if goalsLeft > 0 then
				n += 1 -- mutation / board unlocks remain collecting goals
			end
		end
		return n
	end

	local function bandPercents(): { [string]: number }
		local L = luck()
		if sampler == "SoftCap" then
			return SoftCapRarity.softCapBandPercents(L)
		end
		return SoftCapRarity.ladderBandPercents(L, 20000, 500000)
	end

	local function huntCharmFamily(): (string?, number?)
		if not collectionHud or not fusionIncomeOn then
			return nil, nil
		end
		local corrupted = CollectionMath.hasUnlockFlag(collectionState, "HuntCharmBonus")
		for i = 1, slots do
			local id = heldRelicIds[i]
			if id then
				local entry = collectionState.Fusion[id]
				if entry and entry.Charm == "Hunt" then
					local relic = RelicConfig.ById[id]
					if relic and relic.Family then
						-- SoftCapRarity expects familyMult > 1 (Frequency-style); Hunt bonus is additive weight.
						local bonus = CollectionMath.huntFamilyBonus("Hunt", corrupted, relic.Tier)
						return relic.Family, 1 + bonus
					end
				end
			end
		end
		return nil, nil
	end

	-- Post-Epic: mirror server suggestHuntQuarry + resolve (useful Codex/mut/Ascend when pick is done).
	local function quarrySuggestOpts(huntFamily: string?): {
		State: any,
		OwnedBase: { [string]: number },
		OwnedMutated: { [string]: number },
		Discovered: { [string]: boolean },
		CodexMutCounts: { [string]: number },
		RelicMeta: { [string]: { Tier: string, Name: string, Family: string? } },
		AscendTargetId: string?,
		AscendMissing: number?,
		HuntFamily: string?,
		SoftPinId: string?,
	}
		local meta: { [string]: { Tier: string, Name: string, Family: string? } } = {}
		local ownedBase: { [string]: number } = {}
		local ownedMut: { [string]: number } = {}
		local discovered: { [string]: boolean } = {}
		local codexMutCounts: { [string]: number } = {}
		for id, relic in RelicConfig.ById do
			meta[id] = { Tier = relic.Tier, Name = relic.Name, Family = relic.Family }
			ownedBase[id] = RealFusion.baseCopies(owned, id)
			ownedMut[id] = owned.Mutated[id] or 0
			discovered[id] = seen[id] == true
			codexMutCounts[id] = if uniqueMutRelics[id] then 1 else 0
		end
		local hint = CollectionMath.bestAscendHint(
			collectionState,
			ownedBase,
			meta,
			CollectionMath.hasUnlockFlag(collectionState, "WorkshopCharmGlobal"),
			if collectionState.ActivePursuit == "EpicLineage" then "Epic" else nil
		)
		return {
			State = collectionState,
			OwnedBase = ownedBase,
			OwnedMutated = ownedMut,
			Discovered = discovered,
			CodexMutCounts = codexMutCounts,
			RelicMeta = meta,
			AscendTargetId = if hint then hint.TargetRelicId else nil,
			AscendMissing = if hint then hint.Missing else nil,
			HuntFamily = huntFamily,
			SoftPinId = RealFusion.softPin(collectionState, owned, rebirths, heldRelicIds),
		}
	end

	local function resolveActiveQuarry(huntFamily: string?): string?
		if not CollectionMath.huntQuarryEligible(collectionState) then
			return nil
		end
		local opts = quarrySuggestOpts(huntFamily)
		local chosenUseful = false
		local chosen = collectionState.HuntQuarryId
		if type(chosen) == "string" and chosen ~= "" then
			local cRelic = RelicConfig.ById[chosen]
			local need = CollectionMath.quarryNeed({
				State = collectionState,
				RelicId = chosen,
				TierId = if cRelic then cRelic.Tier else nil,
				OwnedBase = opts.OwnedBase[chosen] or 0,
				OwnedMutated = opts.OwnedMutated[chosen] or 0,
				AscendTargetId = opts.AscendTargetId,
				AscendMissing = opts.AscendMissing,
				Discovered = opts.Discovered[chosen] == true,
				CodexMutCount = opts.CodexMutCounts[chosen] or 0,
			})
			chosenUseful = need.Useful
		end
		local suggested = CollectionMath.suggestHuntQuarry(opts)
		return CollectionMath.resolveHuntQuarryId(collectionState, opts.SoftPinId, suggested, chosenUseful)
	end

	local function rollOne(sec: number, hunt: boolean)
		local L = luck()
		-- Prefer live Hunt Charm (pedestal + Charm=Hunt); else Frequency skill bias (sim uses Demonic).
		local charmFam: string? = nil
		local charmMult: number? = nil
		if hunt then
			charmFam, charmMult = huntCharmFamily()
		end
		local family = charmFam or (if hunt and skills.Freq > 0 then "Demonic" else nil)
		local famMult = if charmFam and charmMult
			then charmMult
			elseif family then (Config.Frequency.MultiplierByRank[skills.Freq] or 1.5)
			else nil
		if hunt then
			L *= 5 -- Soft A hunt luck factor
		end
		local relicId, tierId
		-- Match server AttuneFocusOverride: Focused Common scans while Attune is active (AFK only).
		local attuneFocus = collectionHud
			and not hunt
			and (collectionState.AttuneScansLeft or 0) > 0
		if attuneFocus then
			collectionState.AttuneScansLeft -= 1
			local commons = {}
			for id, relic in RelicConfig.ById do
				if relic.Tier == "Common" then
					table.insert(commons, id)
				end
			end
			relicId = commons[1 + math.floor(rng() * #commons)]
			tierId = "Common"
		elseif sampler == "SoftCap" then
			local quarryId: string? = nil
			local quarryMult: number? = nil
			if hunt and collectionHud and CollectionMath.huntQuarryEligible(collectionState) then
				quarryId = resolveActiveQuarry(charmFam)
				if quarryId then
					quarryMult = CollectionMath.huntQuarryMult()
				end
			end
			relicId, tierId = SoftCapRarity.roll(L, rng, family, famMult, quarryId, quarryMult)
		else
			local ctx = RollMath.contextFor(softACRules, {
				FullLuck = L,
				Frequency = family,
				FrequencyRank = skills.Freq,
				MutationRank = skills.MutRes,
			})
			local relic, _mut = RollMath.roll(ctx, rng)
			relicId, tierId = relic.Id, relic.Tier
		end
		local mut = SoftCapRarity.rollMutation(skills.MutRes, rng)
		-- Hunt Quarry metrics: raw hits vs useful (recipe/mut/catalyst/Codex) — not every dupe.
		if hunt and sampler == "SoftCap" and collectionHud then
			local qId = resolveActiveQuarry(charmFam)
			if qId and relicId == qId then
				huntQuarryHits += 1
				local qRelic = RelicConfig.ById[qId]
				local ctxQ = quarrySuggestOpts(charmFam)
				local need = CollectionMath.quarryNeed({
					State = collectionState,
					RelicId = qId,
					TierId = if qRelic then qRelic.Tier else nil,
					OwnedBase = RealFusion.baseCopies(owned, qId),
					OwnedMutated = owned.Mutated[qId] or 0,
					AscendTargetId = ctxQ.AscendTargetId,
					AscendMissing = ctxQ.AscendMissing,
					Discovered = seen[qId] == true,
					CodexMutCount = if uniqueMutRelics[qId] then 1 else 0,
				})
				if CollectionMath.quarryCaptureAdvances(need, mut ~= nil) then
					huntQuarryUsefulHits += 1
					noteMeaningful(sec)
				end
			end
		end
		totalFinds += 1
		local first = not seen[relicId]
		RealFusion.addFind(owned, relicId, mut)
		if first then
			seen[relicId] = true
			uniqueCount += 1
			uniqueByTier[tierId] = (uniqueByTier[tierId] or 0) + 1
			markLuckDirty() -- Codex term
			noteMeaningful(sec)
			if tierId == "Rare" and not firstRareAt then
				firstRareAt = sec
			end
			if tierId == "Epic" and not firstEpicAt then
				firstEpicAt = sec
			end
		else
			dupes += 1
			-- Auto-sell dupes when fusion reserve allows (mirrors AutoSell + soft pin / Rank3 mut reserve).
			local keep = collectionHud
				and fusionIncomeOn
				and RealFusion.shouldKeepForReserve(collectionState, owned, relicId, rebirths, heldRelicIds, mut)
			if not keep then
				owned.Counts[relicId] = math.max(0, (owned.Counts[relicId] or 0) - 1)
				if mut then
					owned.Mutated[relicId] = math.max(0, (owned.Mutated[relicId] or 0) - 1)
				end
				local base = frozenBase[relicId] or 1
				ce += base * Config.Economy.SellSeconds * (1 + 0.1 * math.min(skills.Energy, 5))
				if collectionHud then
					collectionState.Essence += RealFusion.essenceFromDupe(collectionState, relicId)
				end
			end
		end
		if mut then
			mutations += 1
			local firstUniqueMut = uniqueMutRelics[relicId] == nil
			if firstUniqueMut then
				uniqueMutRelics[relicId] = true
			end
			-- MutationLedger: first mutated sighting of this relic id this life (server PursuitMutSeen).
			if collectionHud then
				if not collectionState.PursuitMutSeen then
					collectionState.PursuitMutSeen = {}
				end
				local pursuit = CollectionMath.pursuitConfig(collectionState.ActivePursuit)
				if
					pursuit
					and type(pursuit.NewUniqueMutEssence) == "number"
					and not collectionState.PursuitMutSeen[relicId]
				then
					collectionState.PursuitMutSeen[relicId] = true
					collectionState.Essence += math.floor(pursuit.NewUniqueMutEssence)
				end
			end
			uniqueMutByType[mut] = uniqueMutByType[mut] or {}
			uniqueMutByType[mut][relicId] = true
			if collectionHud then
				RealFusion.claimGoals(collectionState, uniqueMutCounts(), uniqueAnyMutated())
				noteMilestones(sec)
			end
		end
		-- Equip if better *effective* income (base×mutation×fusion), so fused display pieces stick.
		local inc = (frozenBase[relicId] or 1) * (if mut then 1.5 else 1)
		local function slotEff(i: number): number
			local base = heldIncome[i] or 0
			local id = heldRelicIds[i]
			if id and fusionIncomeOn and collectionHud then
				base *= RealFusion.fusionIncomeMult(collectionState, id)
			end
			return base
		end
		local newFuse = if fusionIncomeOn and collectionHud
			then RealFusion.fusionIncomeMult(collectionState, relicId)
			else 1
		local newEff = inc * newFuse
		local worstI, worstV = 1, slotEff(1)
		for i = 1, slots do
			local v = slotEff(i)
			if v < worstV then
				worstV, worstI = v, i
			end
		end
		local curId = heldRelicIds[worstI]
		local curFused = curId
			and collectionHud
			and fusionIncomeOn
			and collectionState.Fusion[curId]
			and (collectionState.Fusion[curId].Rank or 0) > 0
		-- Charm/fusion stickiness: keep fused display pieces until a higher-tier find arrives.
		local threshold = worstV
		if curFused and newFuse <= 1 then
			local curTier = tierIndex(RelicConfig.ById[curId].Tier)
			local newTier = tierIndex(tierId)
			if newTier <= curTier then
				threshold = math.huge
			else
				threshold = worstV * 1.05
			end
		end
		if newEff > threshold then
			heldIncome[worstI] = inc
			heldRelicIds[worstI] = relicId
			markIncomeDirty()
		elseif fusionIncomeOn and collectionHud then
			markIncomeDirty()
		end
		promoteFusedToPedestals()
	end

	local function applyRebirth(sec: number)
		local cost = Rebirth.cost(rebirthSettings, rebirths)
		if ce < cost then
			return false
		end
		local incomeBefore = incomePerSec()
		local ceBefore = ce
		local clBefore = skills.CoreLuck
		local mastBefore = pedMastery
		local pedBefore = pedMinNow()
		local energyBefore = skills.Energy
		local mutBefore = skills.MutRes
		local essBefore = collectionState.Essence
		local boardBefore = if collectionHud then RealFusion.activeBoardCount(collectionState) else 0
		local liftBefore = fusionLiftNow()
		local goldenBefore = collectionState.MutationGoalsClaimed.FirstGolden ~= nil
		local usefulBefore = usefulBuysLeft()
		if rebirths == 0 then
			incomeBeforeRebirth = incomeBefore
			ceAtR1 = ce
			pedMinAtR1 = pedBefore
			coreLuckAtR1 = skills.CoreLuck
			energyAtR1 = skills.Energy
		end
		-- Match server: spend is implicit (CE wiped to 0). Do not set ce=cost first — that
		-- destroyed the true balance and made CeAtR1 reporting wrong if read after.
		local fakeData = {
			Rebirths = rebirths,
			CE = ce,
			Pedestals = {},
			Skills = {},
		}
		for i = 1, slots do
			fakeData.Pedestals[i] = { Level = pedLevels[i] or 1 }
		end
		fakeData.Skills.CoreLuck = skills.CoreLuck
		-- Use shared Rebirth.apply for Live vs BPlus semantics.
		local mode = if rebirthModel == "BPlus" then "BPlus" else "Live"
		if rebirthModel == "A" then
			mode = "Live"
		elseif rebirthModel == "B" or rebirthModel == "C" then
			-- B/C are design variants: CE wipe with selective ped/skill resets handled below.
			mode = "Live"
		end
		if rebirthModel == "BPlus" then
			Rebirth.apply(fakeData, "BPlus")
			rebirths = fakeData.Rebirths
			ce = 0
			-- Skills + pedestals preserved (server B+ SoftCap_P4).
			gates.EnergyII = true
			gates.AttuneHigh = true
			gates.Mastery = true
			gates.MutDeep = true
			if collectionHud then
				-- Server: ChooseResonance + Rebirth Pursuit each life (MutationLedger ledger clears).
				collectionState.PendingResonance = true
				collectionState.ActivePursuit = nil
				collectionState.PursuitMutSeen = {}
				local pick = if policy == "Hunter" or policy == "Optimized"
					then "Binder"
					elseif policy == "AfkUpgrader"
					then "Collector"
					else "Seeker"
				collectionState.ResonanceStacks[pick] = (collectionState.ResonanceStacks[pick] or 0) + 1
				-- Rebirth Pursuit: changes each life (not a permanent checklist).
				local pursuit = "FamilyHunt"
				if CollectionMath.hasUnlockFlag(collectionState, "EpicSalvageBoost") then
					pursuit = if policy == "AfkUpgrader" then "MutationLedger" else "EpicLineage"
				elseif policy == "AfkUpgrader" or policy == "Casual" then
					pursuit = "MutationLedger"
				else
					pursuit = "FamilyHunt"
				end
				collectionState.ActivePursuit = pursuit
				collectionState.PendingResonance = false
				noteMeaningful(sec)
			end
		elseif rebirthModel == "B" then
			rebirths += 1
			ce = 0
		elseif rebirthModel == "C" then
			rebirths += 1
			ce = 0
			for i = 1, slots do
				pedLevels[i] = 1
			end
		else
			-- Live / A: production wipe — CE, ped levels, skill ranks.
			Rebirth.apply(fakeData, "Live")
			rebirths = fakeData.Rebirths
			ce = 0
			skills.CoreLuck = 0
			skills.ScanSpeed = 0
			skills.Energy = 0
			skills.EnergyII = 0
			skills.MutRes = 0
			skills.Freq = 0
			skills.Sight = 0
			skills.Bind = 0
			skills.Harvest = 0
			skills.Swift = 0
			for i = 1, slots do
				pedLevels[i] = 1
			end
			pedMastery = 0
		end
		table.insert(rebirthsAt, sec)
		noteMeaningful(sec)
		markIncomeDirty()
		markLuckDirty()
		local incomeAfter = incomePerSec()
		-- Capture post-R1 income only once (later Rebirths must not overwrite).
		if #rebirthsAt == 1 then
			incomeAfterRebirth = incomeAfter
		end
		table.insert(rebirthTrace, {
			Index = #rebirthsAt,
			Sec = sec,
			Cost = cost,
			CeBefore = ceBefore,
			IncomeBefore = incomeBefore,
			IncomeAfter = incomeAfter,
			CL = clBefore,
			Mastery = mastBefore,
			PedMin = pedBefore,
			Energy = energyBefore,
			MutRes = mutBefore,
			Essence = essBefore,
			Board = boardBefore,
			Lift = liftBefore,
			MaxFusionRank = maxFusionRank,
			FirstGolden = goldenBefore,
			UsefulLeft = usefulBefore,
		})
		noteMilestones(sec)
		return true
	end

	local function tryBuy(sec: number)
		-- Policy buy aggressiveness
		local buyChance = if policy == "Casual" then 0.55 elseif policy == "Optimized" then 1 else 0.9
		if policy == "AfkUpgrader" then
			buyChance = 0.95
		end
		if rng() > buyChance then
			return
		end

		local options = {}
		local function add(cost: number, pri: number, apply: () -> ())
			if cost > 0 and ce >= cost then
				table.insert(options, { Cost = cost, Pri = pri, Apply = apply })
			end
		end

		local clCap = clCapNow()
		if skills.CoreLuck < clCap then
			local sig = (skills.CoreLuck + 1) % 5 == 0
			add(coreLuckCost(skills.CoreLuck), if sig then 3 else 8, function()
				skills.CoreLuck += 1
				markLuckDirty()
				if sig then
					noteMeaningful(sec)
				end
			end)
		end
		if skills.ScanSpeed < scanMax then
			local node = SkillConfig.ById.ScanSpeed
			local cost = SkillConfig.cost(node, skills.ScanSpeed) or 250 * (2.2 ^ skills.ScanSpeed)
			add(math.ceil(cost), 4, function()
				skills.ScanSpeed += 1
			end)
		end
		if skills.Energy < ENERGY_MAX then
			local cost = math.ceil(500 * (1.7 ^ skills.Energy) - 1e-9)
			add(cost, 5, function()
				skills.Energy += 1
			end)
		end
		if gates.EnergyII and skills.EnergyII < ENERGY_II_MAX then
			add(math.ceil(2e6 * (1.8 ^ skills.EnergyII) - 1e-9), 6, function()
				skills.EnergyII += 1
				noteMeaningful(sec)
			end)
		end
		local mutCap = if gates.MutDeep then 5 else 2
		if skills.MutRes < mutCap then
			local costs = { 250000, 5000000, 100000000, 2000000000, 40000000000 }
			add(costs[skills.MutRes + 1], 9, function()
				skills.MutRes += 1
				noteMeaningful(sec)
			end)
		end
		if (policy == "Hunter" or policy == "Optimized") and skills.Sight < 5 then
			add(math.ceil(2000 * (2.2 ^ skills.Sight)), 7, function()
				skills.Sight += 1
			end)
		end
		if (policy == "Hunter" or policy == "Optimized") and skills.Bind < 5 then
			add(math.ceil(3000 * (2.4 ^ skills.Bind)), 7, function()
				skills.Bind += 1
			end)
		end
		if (policy == "Hunter" or policy == "Optimized") and skills.Harvest < 5 then
			add(math.ceil(5000 * (2.6 ^ skills.Harvest)), 7, function()
				skills.Harvest += 1
			end)
		end
		if skills.Swift < SWIFT_MAX and policy ~= "AfkUpgrader" then
			add(math.ceil(1000 * (1.9 ^ skills.Swift)), 10, function()
				skills.Swift += 1
			end)
		end
		if skills.Freq < 5 and (policy == "Hunter" or policy == "Optimized" or uniqueCount > 20) then
			local costs = { 20000, 60000, 180000, 540000, 1600000 }
			add(costs[skills.Freq + 1], 8, function()
				skills.Freq += 1
			end)
		end

		for i = 1, slots do
			local lv = pedLevels[i] or 1
			if lv < PED_MAX then
				add(pedUpgradeCost(lv), 2, function()
					pedLevels[i] = lv + 1
				end)
			end
		end
		local mCap = masteryCapNow()
		if pedMastery < mCap then
			add(masteryCost(pedMastery), 6, function()
				pedMastery += 1
				noteMeaningful(sec)
			end)
		end
		if slots < 5 then
			local prices = { [4] = 2500, [5] = 150000 }
			add(prices[slots + 1], 3, function()
				slots += 1
				pedLevels[slots] = 1
				heldIncome[slots] = 0
				heldRelicIds[slots] = nil
				noteMeaningful(sec)
			end)
		elseif slots < 6 and rebirths >= 1 then
			add(25000000, 5, function()
				slots += 1
				pedLevels[slots] = 1
				heldIncome[slots] = 0
				heldRelicIds[slots] = nil
				noteMeaningful(sec)
			end)
		end

		-- Real Collection fuse + SoftCap_P4 Board retire when full and a better target waits.
		if collectionHud and fusionIncomeOn and (policy ~= "Casual" or rng() < 0.35) then
			local target = RealFusion.pickFuseTarget(collectionState, owned, rebirths, heldRelicIds)
			if not target and boardGlobalFusion then
				-- After Lift caps, Retire is for Charm Ascension only (not Common Board churn).
				local liftCapped = RealFusion.boardIncomeMult(collectionState) + 1e-9
					>= (CollectionConfig.FusionIncomeMultByRank[3] or 1.5)
				if not liftCapped then
					-- Only retire when a better *new* fuse is blocked solely by Board capacity.
					local blocked = RealFusion.pickBlockedByBoard(collectionState, owned, rebirths, heldRelicIds)
					local weak = RealFusion.weakestBoardEntry(collectionState)
					local retireCost = CollectionConfig.BoardRetireEssence or 80
					local boardN = RealFusion.activeBoardCount(collectionState)
					if
						blocked
						and weak
						and blocked ~= weak
						and boardN >= 1
						and collectionState.Essence >= retireCost
					then
						local weakMult = RealFusion.fusionIncomeMult(collectionState, weak)
						local blockedRelic = RelicConfig.ById[blocked]
						local blockedTier = if blockedRelic
							then (({ Common = 1, Uncommon = 2, Rare = 3, Epic = 4 })[blockedRelic.Tier] or 5)
							else 1
						if blockedTier >= 2 or weakMult <= CollectionMath.fusionIncomeMult(1) + 1e-9 then
							table.insert(options, {
								Cost = 0,
								Pri = 6,
								Apply = function()
									local ok = RealFusion.tryRetire(collectionState, weak)
									if not ok then
										return
									end
									boardRetires += 1
									essenceSpent += retireCost
									markIncomeDirty()
									noteMeaningful(sec)
								end,
							})
						end
					end
				end
			elseif target then
				local entry = collectionState.Fusion[target]
				local isNew = not entry or (entry.Rank or 0) <= 0
				local liftBefore = RealFusion.boardIncomeMult(collectionState)
				table.insert(options, {
					Cost = 0,
					Pri = if isNew or boardGlobalFusion then 4 else 7,
					Apply = function()
						local before = collectionState.Essence
						local ok = RealFusion.tryFuse(collectionState, owned, target, rebirths)
						if not ok then
							return
						end
						essenceSpent += math.max(0, before - collectionState.Essence)
						fusions += 1
						formsProgress += 1
						local entry = collectionState.Fusion[target]
						local rankNow = if entry then (entry.Rank or 0) else 0
						if rankNow > maxFusionRank then
							maxFusionRank = rankNow
						end
						if not boardGlobalFusion then
							local base = frozenBase[target] or 1
							local eff = base * RealFusion.fusionIncomeMult(collectionState, target)
							local worstI, worstV = 1, heldIncome[1] or 0
							for i = 1, slots do
								local id = heldRelicIds[i]
								local v = heldIncome[i] or 0
								if id then
									v *= RealFusion.fusionIncomeMult(collectionState, id)
								end
								if v < worstV then
									worstV, worstI = v, i
								end
							end
							if eff > worstV then
								heldIncome[worstI] = base
								heldRelicIds[worstI] = target
							end
							promoteFusedToPedestals()
						end
						markIncomeDirty()
						local liftAfter = RealFusion.boardIncomeMult(collectionState)
						local meaningful = fusions <= 3 or isNew or liftAfter > liftBefore + 1e-9
						if not meaningful then
							fusionSinceMeaningful += 1
							meaningful = fusionSinceMeaningful >= fusionMeaningfulEvery
						end
						if meaningful then
							fusionSinceMeaningful = 0
							noteMeaningful(sec)
						end
						noteMilestones(sec)
					end,
				})
			end
		end

		-- SoftCap_P4: Epic Catalyst craft (unlocks Epic Charm Ascension / EpicLineage pursuit).
		if
			collectionHud
			and CollectionMath.hasUnlockFlag(collectionState, "EpicSalvageBoost")
			and (policy ~= "Casual" or rng() < 0.5)
		then
			local catCost = (CollectionConfig.EpicCatalyst and CollectionConfig.EpicCatalyst.Essence) or 90
			local catCopies = (CollectionConfig.EpicCatalyst and CollectionConfig.EpicCatalyst.Copies) or 2
			local existingCats = 0
			for _ in collectionState.EpicCatalysts do
				existingCats += 1
			end
			local bestPotNow = 1
			for relicId, entry in collectionState.Fusion do
				if entry.Charm then
					local relic = RelicConfig.ById[relicId]
					local p = CollectionMath.charmPotency(if relic then relic.Tier else "Common")
					if p > bestPotNow then
						bestPotNow = p
					end
				end
			end
			-- EpicLineage: finish one Ascend-to-Epic before stockpiling catalyst #2+.
			local allowMoreCats = not (
				collectionState.ActivePursuit == "EpicLineage"
				and existingCats >= 1
				and bestPotNow + 1e-9 < (CollectionConfig.CharmPotencyByTier.Epic or 2.1)
			)
			if allowMoreCats and collectionState.Essence >= catCost then
				for id, n in owned.Counts do
					local relic = RelicConfig.ById[id]
					if
						relic
						and relic.Tier == "Epic"
						and not collectionState.EpicCatalysts[id]
						and RealFusion.baseCopies(owned, id) >= catCopies
					then
						table.insert(options, {
							Cost = 0,
							Pri = if collectionState.ActivePursuit == "EpicLineage" then 3 else 7,
							Apply = function()
								if collectionState.Essence < catCost or collectionState.EpicCatalysts[id] then
									return
								end
								if not RealFusion.consumeBaseCopies(owned, id, catCopies) then
									return
								end
								collectionState.Essence -= catCost
								essenceSpent += catCost
								collectionState.EpicCatalysts[id] = true
								RealFusion.claimGoals(collectionState, uniqueMutCounts(), uniqueAnyMutated())
								noteMeaningful(sec)
							end,
						})
						break
					end
				end
			end
		end

		-- SoftCap_P4 Hunt Quarry: retarget to suggested useful chase (Codex/mut/Ascend/catalyst).
		if
			collectionHud
			and boardGlobalFusion
			and CollectionMath.huntQuarryEligible(collectionState)
			and policy ~= "AfkUpgrader"
			and (policy ~= "Casual" or rng() < 0.35)
		then
			local charmFamQ = select(1, huntCharmFamily())
			local optsQ = quarrySuggestOpts(charmFamQ)
			local want = CollectionMath.suggestHuntQuarry(optsQ)
			if want and want ~= collectionState.HuntQuarryId then
				local ready = CollectionMath.huntQuarryRetargetReady(collectionState, sec)
				local wantRelic = RelicConfig.ById[want]
				local needWant = CollectionMath.quarryNeed({
					State = collectionState,
					RelicId = want,
					TierId = if wantRelic then wantRelic.Tier else nil,
					OwnedBase = optsQ.OwnedBase[want] or 0,
					OwnedMutated = optsQ.OwnedMutated[want] or 0,
					AscendTargetId = optsQ.AscendTargetId,
					AscendMissing = optsQ.AscendMissing,
					Discovered = optsQ.Discovered[want] == true,
					CodexMutCount = optsQ.CodexMutCounts[want] or 0,
				})
				-- Only retarget when the new quarry is useful and cooldown allows (not spam).
				if ready and needWant.Useful then
					table.insert(options, {
						Cost = 0,
						Pri = 5,
						Apply = function()
							if collectionState.HuntQuarryId == want then
								return
							end
							local ok = CollectionMath.huntQuarryRetargetReady(collectionState, sec)
							if not ok then
								return
							end
							collectionState.HuntQuarryId = want
							collectionState.HuntQuarrySetAt = sec
							huntQuarryRetargets += 1
							noteMeaningful(sec)
						end,
					})
				end
			end
		end

		-- SoftCap_P4 Phase 7: Ascend Charm lineages after Board Lift caps (not more ×income).
		if
			collectionHud
			and fusionIncomeOn
			and boardGlobalFusion
			and RealFusion.boardIncomeMult(collectionState) + 1e-9 >= (CollectionConfig.FusionIncomeMultByRank[3] or 1.5)
			and (policy ~= "Casual" or rng() < 0.55)
		then
			local meta: { [string]: { Tier: string, Name: string, Family: string? } } = {}
			local ownedBase: { [string]: number } = {}
			for id, relic in RelicConfig.ById do
				meta[id] = { Tier = relic.Tier, Name = relic.Name, Family = relic.Family }
				ownedBase[id] = RealFusion.baseCopies(owned, id)
			end
			local prefer = if collectionState.ActivePursuit == "EpicLineage" then "Epic" else nil
			local hint = CollectionMath.bestAscendHint(
				collectionState,
				ownedBase,
				meta,
				CollectionMath.hasUnlockFlag(collectionState, "WorkshopCharmGlobal"),
				prefer
			)
			if hint and hint.Ready then
				table.insert(options, {
					Cost = 0,
					Pri = 3,
					Apply = function()
						local beforeEss = collectionState.Essence
						local ok = RealFusion.tryAscendCharm(collectionState, owned, rebirths)
						if not ok then
							return
						end
						essenceSpent += math.max(0, beforeEss - collectionState.Essence)
						boardRetires += 1
						fusions += 1
						charmAscensions += 1
						if firstCharmAscendAt == nil then
							firstCharmAscendAt = sec
						end
						markIncomeDirty()
						noteMeaningful(sec)
						noteMilestones(sec)
					end,
				})
			end
		end

		-- SoftCap_P4 midgame: Attune tickets (matches CollectionService + ProgressObjective).
		-- Without this, sims bank Essence forever after Board Lift caps — false "empty midgame".
		if collectionHud and CollectionMath.hasUnlockFlag(collectionState, "AttuneTicketRecipe") then
			local ticketCost = CollectionConfig.AttuneTicketEssenceCost or 75
			local cap = collectionState.AttuneChargeCap or CollectionConfig.MaxAttuneCharges or 3
			local shopThin = usefulBuysLeft() <= 2
			local casualOk = policy ~= "Casual" or rng() < 0.4
			if
				casualOk
				and collectionState.AttuneCharges > 0
				and (collectionState.AttuneScansLeft or 0) <= 0
			then
				table.insert(options, {
					Cost = 0,
					Pri = if shopThin then 5 else 8,
					Apply = function()
						if collectionState.AttuneCharges <= 0 then
							return
						end
						collectionState.AttuneCharges -= 1
						collectionState.AttuneScansLeft += CollectionConfig.AttuneScanCount or 10
						-- Ordinary sink — do not reset LongestDry (not a milestone).
					end,
				})
			end
			local ascendBuffer = 0
			if
				boardGlobalFusion
				and RealFusion.boardIncomeMult(collectionState) + 1e-9 >= (CollectionConfig.FusionIncomeMultByRank[3] or 1.5)
			then
				local catCount = 0
				for _ in collectionState.EpicCatalysts do
					catCount += 1
				end
				local bestPot = 1
				for relicId, entry in collectionState.Fusion do
					if entry.Charm then
						local relic = RelicConfig.ById[relicId]
						local p = CollectionMath.charmPotency(if relic then relic.Tier else "Common")
						if p > bestPot then
							bestPot = p
						end
					end
				end
				-- EpicLineage: bank retire+Epic fuse (~300) until Charm Ascends to Epic.
				if
					collectionState.ActivePursuit == "EpicLineage"
					and catCount > 0
					and bestPot + 1e-9 < (CollectionConfig.CharmPotencyByTier.Epic or 2.1)
				then
					ascendBuffer = (CollectionConfig.BoardRetireEssence or 80)
						+ CollectionMath.fusionEssenceCost("Epic", 1)
				elseif charmAscensions == 0 then
					ascendBuffer = (CollectionConfig.BoardRetireEssence or 80)
						+ CollectionMath.fusionEssenceCost("Uncommon", 1)
				end
			end
			if
				casualOk
				and collectionState.AttuneCharges < cap
				and collectionState.Essence >= ticketCost + 40 + ascendBuffer
				and (shopThin or collectionState.Essence >= ticketCost * 4 + ascendBuffer)
			then
				table.insert(options, {
					Cost = 0,
					Pri = if shopThin then 5 else 9,
					Apply = function()
						if collectionState.Essence < ticketCost + ascendBuffer or collectionState.AttuneCharges >= cap then
							return
						end
						collectionState.Essence -= ticketCost
						essenceSpent += ticketCost
						collectionState.AttuneCharges += 1
						-- Ordinary sink — do not reset LongestDry (not a milestone).
					end,
				})
			end
		end

		if #options == 0 then
			return
		end
		table.sort(options, function(a, b)
			if a.Pri ~= b.Pri then
				return a.Pri < b.Pri
			end
			return a.Cost < b.Cost
		end)
		-- Optimized: cheapest among top priority band; Casual: sometimes skip best
		local pick = options[1]
		if policy == "Casual" and #options > 1 and rng() < 0.35 then
			pick = options[math.min(#options, 1 + math.floor(rng() * 3))]
		end
		if pick.Cost > 0 then
			ce -= pick.Cost
		end
		pick.Apply()
		markIncomeDirty()
		noteMilestones(sec)
	end

	local function snapshot(minute: number): Checkpoint
		promoteFusedToPedestals()
		local left = usefulBuysLeft()
		return {
			Minute = minute,
			Luck = luck(),
			Band = bandPercents(),
			Unique = uniqueCount,
			UniqueByTier = table.clone(uniqueByTier),
			TotalFinds = totalFinds,
			Dupes = dupes,
			Mutations = mutations,
			CE = ce,
			IncomePerSec = incomePerSec(),
			CoreLuck = skills.CoreLuck,
			ScanRank = skills.ScanSpeed,
			EnergyRank = skills.Energy,
			EnergyII = skills.EnergyII,
			MutRes = skills.MutRes,
			PedLevels = table.clone(pedLevels),
			PedMastery = pedMastery,
			Slots = slots,
			Rebirths = rebirths,
			Essence = collectionState.Essence,
			EssenceSpent = essenceSpent,
			Fusions = fusions,
			FormsProgress = formsProgress,
			BoardSlots = if collectionHud then RealFusion.boardSlots(collectionState, rebirths) else 0,
			ActiveBoard = if collectionHud then RealFusion.activeBoardCount(collectionState) else 0,
			FusedOnPedestal = if collectionHud
				then RealFusion.fusedOnPedestalCount(collectionState, heldRelicIds, slots)
				else 0,
			FusionLift = fusionLiftNow(),
			BoardRetires = boardRetires,
			CharmAscensions = charmAscensions,
			BestCharmPotency = (function()
				local best = 1
				if not collectionHud then
					return best
				end
				for relicId, entry in collectionState.Fusion do
					if entry.Charm then
						local relic = RelicConfig.ById[relicId]
						local p = CollectionMath.charmPotency(if relic then relic.Tier else "Common")
						if p > best then
							best = p
						end
					end
				end
				return best
			end)(),
			EpicCatalysts = (function()
				local n = 0
				if collectionHud then
					for _ in collectionState.EpicCatalysts do
						n += 1
					end
				end
				return n
			end)(),
			ActivePursuit = if collectionHud then collectionState.ActivePursuit else nil,
			HuntQuarryHits = huntQuarryHits,
			HuntQuarryUsefulHits = huntQuarryUsefulHits,
			HuntQuarryRetargets = huntQuarryRetargets,
			CollectionOpen = collectionHud,
			NextUnlockSec = nil,
			LongestDryMin = longestDry,
			UsefulBuysLeft = left,
		}
	end

	local totalSec = minutes * 60
	local scanTimer = 0
	local huntTimer = 0
	local buyTimer = 0
	local checkpointTaken: { [number]: boolean } = {}

	local function huntEverySec(): number
		if policy == "AfkUpgrader" then
			return 120
		elseif policy == "Hunter" then
			return 14
		elseif policy == "Optimized" then
			return 20
		elseif policy == "Casual" then
			return 45
		end
		return 90
	end

	local function buyEverySec(): number
		return if policy == "Optimized" then 2 else 3
	end

	local function maybeCheckpoint(sec: number)
		if sec <= 0 or sec % 60 ~= 0 then
			return
		end
		local m = sec // 60
		if wantSet[m] and not checkpointTaken[m] then
			checkpointTaken[m] = true
			table.insert(checkpoints, snapshot(m))
		end
	end

	local function tryRebirth(sec: number)
		local cost = Rebirth.cost(rebirthSettings, rebirths)
		if rebirths == 0 and firstAffordR1At == nil and ce >= cost then
			firstAffordR1At = sec
			ceAtFirstAfford = ce
		end
		local pedDone = true
		for i = 1, slots do
			if (pedLevels[i] or 1) < 25 then
				pedDone = false
			end
		end
		-- Policy gate: R1 is often NOT CE-limited. Afk/Hunter wait for ped L25 (+ Energy 12 for Afk).
		-- B+ keeps ped levels, so after R1 pedDone stays true and later Rebirths can chain on CE alone.
		local wantRebirth = ce >= cost
			and (
				policy == "Optimized"
				or (policy == "AfkUpgrader" and pedDone and skills.Energy >= 12)
				or (policy == "Hunter" and pedDone)
				or (policy == "Casual" and pedDone and skills.CoreLuck >= 10 and rng() < 0.02)
			)
		if wantRebirth then
			if rebirthModel == "B" and usefulBuysLeft() <= 1 and skills.CoreLuck >= 15 then
				applyRebirth(sec)
			elseif rebirthModel ~= "B" or usefulBuysLeft() > 0 or pedDone then
				applyRebirth(sec)
			end
		end
	end

	local function processSecond(sec: number)
		ce += incomePerSec()
		-- Track afford during Event-mode idle jumps too (checked in tryRebirth on buy ticks).
		if rebirths == 0 and firstAffordR1At == nil and ce >= rebirthSettings.BaseCost then
			firstAffordR1At = sec
			ceAtFirstAfford = ce
		end
		scanTimer += 1
		local interval = scanInterval(skills.ScanSpeed, scanMax)
		if scanTimer >= interval then
			scanTimer -= interval
			rollOne(sec, false)
		end

		local huntEvery = huntEverySec()
		huntTimer += 1
		if huntTimer >= huntEvery then
			huntTimer = 0
			local bonus = 1 + math.floor(2 + 0.5 * skills.Harvest)
			if sampler == "SoftAC" then
				bonus = math.min(bonus, 6)
			end
			for _ = 1, bonus do
				rollOne(sec, true)
			end
			if collectionHud then
				-- Match BindService: base hunt drip + Hunt Charm family-match bonus (approx).
				local matchCount = 0
				local huntFam = huntCharmFamily()
				if huntFam then
					-- SoftCap family bias: ~35% of capture relics match when Hunt Charm is pedestaled.
					matchCount = math.floor(bonus * 0.35 + 0.5)
				end
				collectionState.Essence += CollectionMath.huntCaptureEssenceAmount(
					matchCount,
					collectionState.ResonanceStacks.Collector or 0,
					collectionState.ActivePursuit
				)
			end
		end

		buyTimer += 1
		if buyTimer >= buyEverySec() then
			buyTimer = 0
			tryBuy(sec)
			tryRebirth(sec)
			if usefulEmptyAt == nil and usefulBuysLeft() == 0 and rebirths == 0 then
				usefulEmptyAt = sec
			end
		end
		sampleRank3Blockers(sec)

		maybeCheckpoint(sec)
	end

	local function stepsUntil(timer: number, threshold: number): number
		if threshold <= 0 then
			return 1
		end
		local need = threshold - timer
		if need <= 1e-12 then
			return 1
		end
		return math.max(1, math.ceil(need - 1e-12))
	end

	if tickMode == "PerSecond" then
		for sec = 1, totalSec do
			processSecond(sec)
		end
	else
		-- Event-driven: jump over idle seconds; same per-second event order when a second is processed.
		local sec = 0
		while sec < totalSec do
			local interval = scanInterval(skills.ScanSpeed, scanMax)
			local huntEvery = huntEverySec()
			local buyEvery = buyEverySec()
			local toScan = stepsUntil(scanTimer, interval)
			local toHunt = stepsUntil(huntTimer, huntEvery)
			local toBuy = stepsUntil(buyTimer, buyEvery)
			local nextMinute = (sec // 60 + 1) * 60
			local toCheckpoint = math.max(1, nextMinute - sec)
			local dt = math.min(toScan, toHunt, toBuy, toCheckpoint, totalSec - sec)
			if dt < 1 then
				dt = 1
			end
			-- Idle income for (dt - 1) seconds, then full processSecond on the event second.
			if dt > 1 then
				local idle = dt - 1
				ce += incomePerSec() * idle
				scanTimer += idle
				huntTimer += idle
				buyTimer += idle
				sec += idle
				if rebirths == 0 and firstAffordR1At == nil and ce >= rebirthSettings.BaseCost then
					firstAffordR1At = sec
					ceAtFirstAfford = ce
				end
			end
			sec += 1
			processSecond(sec)
		end
	end

	-- Ensure final checkpoint
	local lastMin = minutes
	local hasLast = false
	for _, cp in checkpoints do
		if cp.Minute == lastMin then
			hasLast = true
		end
	end
	if not hasLast then
		table.insert(checkpoints, snapshot(lastMin))
	end

	return {
		Policy = policy,
		Sampler = sampler,
		RebirthModel = rebirthModel,
		Seed = options.Seed,
		Checkpoints = checkpoints,
		FirstRareAt = firstRareAt,
		FirstEpicAt = firstEpicAt,
		FirstRebirthAt = rebirthsAt[1],
		RebirthsAt = rebirthsAt,
		RebirthTrace = rebirthTrace,
		IncomeBeforeR1 = incomeBeforeRebirth,
		IncomeAfterR1 = incomeAfterRebirth,
		FirstAffordR1At = firstAffordR1At,
		CeAtFirstAfford = ceAtFirstAfford,
		CeAtR1 = ceAtR1,
		PedMinAtR1 = pedMinAtR1,
		CoreLuckAtR1 = coreLuckAtR1,
		EnergyAtR1 = energyAtR1,
		UsefulEmptyAt = usefulEmptyAt,
		Cl25At = cl25At,
		Mastery5At = mastery5At,
		FirstGoldenAt = firstGoldenAt,
		FirstRank2At = firstRank2At,
		FirstRank3At = firstRank3At,
		Board2At = board2At,
		FirstCharmAscendAt = firstCharmAscendAt,
		CharmAscensions = charmAscensions,
		Rank3Blockers = rank3Blockers,
		Final = checkpoints[#checkpoints],
		ApproxNotes = {
			"IncomePerSec / IncomeBeforeR1 are CE/sec, not CE balance.",
			"R1 timing is policy-gated (ped L25, Energy) more often than CE-gated; see FirstAffordR1At.",
			"Pedestal income uses frozen live RelicIncome bases (not SoftCap-retuned CE/s).",
			"Hunt uses simplified cadence + Soft A ×5 luck; not full BindService signal graph.",
			"SoftCap_P4 Fusion: board-global best-rank income (matches EconomyService × CollectionMath.boardIncomeMult).",
			"BPlus Rebirth: CE=0 only; skills/pedestals/Fusion kept (matches Rebirth.apply BPlus).",
			"Codex luck approximated as unique/92 * 0.5 capped.",
			"Core Luck 25-rank curve is sim-candidate (10^(rank*1.6/12)), not live SkillConfig.",
			"Paired seeds share salt; Combined vs NoHUD still diverge RNG via keep/sell + luck path.",
			"Phase 6: mutated Board Rank2 copies reserved; FirstRank3At tracked; no drop-rate buffs.",
			"Phase 7: Charm lineage ascent (tier potency) after Board Lift ×1.50; Retire→Fuse; income cap unchanged.",
		},
	}
end

function Unified.percentile(sorted: { number }, p: number): number?
	if #sorted == 0 then
		return nil
	end
	local idx = math.clamp(math.ceil(#sorted * p), 1, #sorted)
	return sorted[idx]
end

function Unified.aggregate(results: { RunResult }, minute: number): {
	N: number,
	Luck: { P10: number?, P50: number?, P90: number? },
	Unique: { P10: number?, P50: number?, P90: number? },
	Income: { P10: number?, P50: number?, P90: number? },
	CE: { P10: number?, P50: number?, P90: number? },
	RarePct: { P10: number?, P50: number?, P90: number? },
	EpicPct: { P10: number?, P50: number?, P90: number? },
	Rebirths: { P10: number?, P50: number?, P90: number? },
	Dupes: { P10: number?, P50: number?, P90: number? },
	CoreLuck: { P10: number?, P50: number?, P90: number? },
	UsefulLeft: { P10: number?, P50: number?, P90: number? },
	Fusions: { P10: number?, P50: number?, P90: number? },
	ActiveBoard: { P10: number?, P50: number?, P90: number? },
	FusionLift: { P10: number?, P50: number?, P90: number? },
	PedMastery: { P10: number?, P50: number?, P90: number? },
}
	local buckets = {
		Luck = {},
		Unique = {},
		Income = {},
		CE = {},
		RarePct = {},
		EpicPct = {},
		Rebirths = {},
		Dupes = {},
		CoreLuck = {},
		UsefulLeft = {},
		Fusions = {},
		ActiveBoard = {},
		FusionLift = {},
		PedMastery = {},
	}
	for _, r in results do
		for _, cp in r.Checkpoints do
			if cp.Minute == minute then
				table.insert(buckets.Luck, cp.Luck)
				table.insert(buckets.Unique, cp.Unique)
				table.insert(buckets.Income, cp.IncomePerSec)
				table.insert(buckets.CE, cp.CE)
				table.insert(buckets.RarePct, cp.Band.Rare or 0)
				table.insert(buckets.EpicPct, cp.Band.Epic or 0)
				table.insert(buckets.Rebirths, cp.Rebirths)
				table.insert(buckets.Dupes, cp.Dupes)
				table.insert(buckets.CoreLuck, cp.CoreLuck)
				table.insert(buckets.UsefulLeft, cp.UsefulBuysLeft)
				table.insert(buckets.Fusions, cp.Fusions)
				table.insert(buckets.ActiveBoard, cp.ActiveBoard)
				table.insert(buckets.FusionLift, cp.FusionLift)
				table.insert(buckets.PedMastery, cp.PedMastery)
			end
		end
	end
	local function stats(arr: { number })
		table.sort(arr)
		return {
			P10 = Unified.percentile(arr, 0.10),
			P50 = Unified.percentile(arr, 0.50),
			P90 = Unified.percentile(arr, 0.90),
		}
	end
	return {
		N = #buckets.Luck,
		Luck = stats(buckets.Luck),
		Unique = stats(buckets.Unique),
		Income = stats(buckets.Income),
		CE = stats(buckets.CE),
		RarePct = stats(buckets.RarePct),
		EpicPct = stats(buckets.EpicPct),
		Rebirths = stats(buckets.Rebirths),
		Dupes = stats(buckets.Dupes),
		CoreLuck = stats(buckets.CoreLuck),
		UsefulLeft = stats(buckets.UsefulLeft),
		Fusions = stats(buckets.Fusions),
		ActiveBoard = stats(buckets.ActiveBoard),
		FusionLift = stats(buckets.FusionLift),
		PedMastery = stats(buckets.PedMastery),
	}
end

return Unified

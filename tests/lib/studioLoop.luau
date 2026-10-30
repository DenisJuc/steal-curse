-- Continuous Studio progression: soft A+C + collection sinks + mutation goals.
-- Exact-tier counts vs Epic+; meaningful vs routine; Essence spend tracking.

local Config = require("../../src/shared/Config")
local CollectionConfig = require("../../src/shared/CollectionConfig")
local CollectionMath = require("../../src/shared/CollectionMath")
local CodexConfig = require("../../src/shared/CodexConfig")
local Economy = require("../../src/shared/Economy")
local Formulas = require("../../src/shared/Formulas")
local ItemConfig = require("../../src/shared/ItemConfig")
local MutationConfig = require("../../src/shared/MutationConfig")
local RarityConfig = require("../../src/shared/RarityConfig")
local Rebirth = require("../../src/shared/Rebirth")
local RelicConfig = require("../../src/shared/RelicConfig")
local RollMath = require("../../src/shared/RollMath")
local ShowcaseConfig = require("../../src/shared/ShowcaseConfig")
local SkillConfig = require("../../src/shared/SkillConfig")
local relicIncome = require("./relicIncome")
local ProgressionSweep = require("./progressionSweep")

local StudioLoop = {}

local EPIC_I = RarityConfig.IndexById.Epic
local LEG_I = RarityConfig.IndexById.Legendary
local ESSENTIAL_MAX = RarityConfig.IndexById[CodexConfig.EssentialMaxTier]
local SELL_MAX = RarityConfig.IndexById.Rare

local frozenBase = {}
for _, relic in RelicConfig.Relics do
	frozenBase[relic.Id] = relicIncome.base(relic.Id)
end

local essentialPool = 0
for _, relic in RelicConfig.Relics do
	if (RarityConfig.IndexById[relic.Tier] or 0) <= ESSENTIAL_MAX then
		essentialPool += 1
	end
end

local function makeRules(candidate)
	local tiers = {}
	for _, tier in RarityConfig.Tiers do
		local denom = tier.Denominator
		if tier.Id == "Epic" then
			denom = candidate.EpicDenom
		elseif tier.Id == "Legendary" then
			denom = candidate.LegendaryDenom
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

local function codexLuck(essentialUnique: number): number
	local frac = essentialUnique / math.max(1, essentialPool)
	local luck = 0
	for _, entry in CodexConfig.Essential do
		if frac + 1e-12 >= entry.Fraction then
			luck += entry.Luck
		end
	end
	return math.min(luck, Config.Luck.CodexMaxBonus)
end

local function showcaseLuck(level: number): number
	if level <= 0 then
		return 0
	end
	local row = ShowcaseConfig.Levels[math.min(level, ShowcaseConfig.MaxLevel)]
	return row and row.Luck or 0
end

local function countKeys(map): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

export type EssenceSpend = {
	Fusion: number,
	Catalyst: number,
	AttuneTicket: number,
	TargetedAttune: number,
	MutationFocus: number,
	FamilyAttune: number,
	CharmRespec: number,
	CapUpgrade: number,
}

export type Checkpoint = {
	Minute: number,
	EpicExact: number,
	EpicPlus: number,
	UniqueEpicExact: number,
	UniqueEpicPlus: number,
	LegendaryExact: number,
	UniqueLegendary: number,
	Mutations: number,
	UniqueMutatedRelics: number,
	Goals: number,
	GoalsTotal: number,
	Essence: number,
	EssenceEarned: number,
	EssenceSpent: number,
	FusionRanks: number,
	Charms: number,
	ActiveCharms: number,
	BoardSlots: number,
	FusedRelics: number,
	Rank1: number,
	Rank2: number,
	Rank3: number,
	CharmChanges: number,
	EpicCatalysts: number,
	-- Corrected event taxonomy (see docs):
	UniqueMechanics: number,
	FirstMilestones: number,
	BuildDecisions: number,
	Ordinary: number,
	LongestNewGapMin: number,
	Luck: number,
	Income: number,
	Rebirths: number,
	CoreLuck: number,
	MutationRank: number,
	Scan: number,
	AttuneCharges: number,
	ResonancePicks: number,
	SpendFusion: number,
	SpendCatalyst: number,
	SpendAttune: number,
	SpendTargeted: number,
	SpendMutFocus: number,
	SpendFamily: number,
	SpendRespec: number,
	SpendCap: number,
	DeadMinutes: number,
}

-- SpendPolicy:
--   Optimal   — uses all sinks when unlocked (default playtest bot)
--   FusionOnly — fusion + catalysts only (skips Attune/Focus/respec loops)
--   Hoard      — first fusion only, then banks Essence
function StudioLoop.run(options: {
	Seed: number,
	Hours: number,
	Candidate: ProgressionSweep.Candidate,
	LuckGrowth: number,
	SoftK: number,
	SoftPower: number?,
	SpendPolicy: ("Optimal" | "FusionOnly" | "Hoard")?,
}): {
	Checkpoints: { Checkpoint },
	RebirthsAt: { number },
	FirstFusionMin: number?,
	FirstGoalMin: number?,
	RosterEpicExact: number,
	RosterEpicPlus: number,
	EssenceSpend: EssenceSpend,
	Final: Checkpoint?,
}
	local candidate = options.Candidate
	local rules = makeRules(candidate)
	local rebirthSettings = {
		BaseCost = Config.Rebirth.BaseCost,
		CostGrowth = Config.Rebirth.CostGrowth,
		IncomeGrowth = Config.Rebirth.IncomeGrowth,
		LuckGrowth = options.LuckGrowth,
	}
	local softPower = options.SoftPower or 1.35
	local spendPolicy = options.SpendPolicy or "Optimal"
	local nodes = SkillConfig.ById
	local goalsTotal = #CollectionConfig.MutationGoals

	local rngState = (options.Seed * 7919 + 12345) % 2147483647
	local function nextNumber(): number
		rngState = (rngState * 48271) % 2147483647
		return rngState / 2147483647
	end

	local ce = 0
	local rebirths = 0
	local skills = {
		CoreLuck = 0,
		ScanSpeed = 0,
		EnergyConduction = 0,
		MutationResonance = 0,
	}
	local levels = { 1, 1, 1 }
	local held = {}
	local counts: { [string]: number } = {}
	local mutatedCounts: { [string]: number } = {}
	local seen: { [string]: boolean } = {}
	local essentialSeen = {}
	local essentialUnique = 0
	local uniqueCount = 0
	local showcaseLevel = 0
	local potionLeft = 0
	local epicExact, epicPlus, legExact = 0, 0, 0
	local uniqueEpicExact: { [string]: boolean } = {}
	local uniqueEpicPlus: { [string]: boolean } = {}
	local uniqueLeg: { [string]: boolean } = {}
	local mutations = 0
	local mutatedRelics: { [string]: boolean } = {}
	local mutByType: { [string]: number } = {}
	local goalsClaimedMap: { [string]: boolean } = {}
	local goalsClaimed = 0
	local firstGoalMin = nil
	local firstFusionMin = nil
	local essence, essenceEarned, essenceSpent = 0, 0, 0
	local spend: EssenceSpend = {
		Fusion = 0,
		Catalyst = 0,
		AttuneTicket = 0,
		TargetedAttune = 0,
		MutationFocus = 0,
		FamilyAttune = 0,
		CharmRespec = 0,
		CapUpgrade = 0,
	}
	local fusionRanks, charms, charmChanges = 0, 0, 0
	local fusion: { [string]: { Rank: number, Charm: string? } } = {}
	local epicCatalysts: { [string]: boolean } = {}
	local attuneCharges = 0
	local attuneCap = CollectionConfig.MaxAttuneCharges
	local uniqueMechanics = 0
	local firstMilestones = 0
	local buildDecisions = 0
	local ordinary = 0
	local resonancePicks = 0
	local mechanicsSeen: { [string]: boolean } = {}
	local resonanceStacks = { Collector = 0, Binder = 0, Seeker = 0 }
	local rebirthsAt = {}
	local ctxKey = ""
	local ctx = nil
	local scanTimer = 0
	local offeringTimer = 0
	local lastTargetedAttune = -9999
	local lastMutationFocus = -9999
	local lastFamilyAttune = -9999
	local lastCharmRespec = -9999
	local lastAttuneActivate = -9999
	local mutationFocusLeft = 0
	local lastNewObjective = 0
	local longestNewGap = 0
	local deadAccum = 0
	local sawFirstEpic, sawFirstLeg, sawFirstRank3 = false, false, false

	local function collectionState()
		return {
			Essence = essence,
			Fusion = fusion,
			FusionPins = {},
			ResonanceStacks = resonanceStacks,
			PendingResonance = false,
			MutationGoalsClaimed = goalsClaimedMap,
			AttuneCharges = attuneCharges,
			AttuneScansLeft = 0,
			AttuneChargeCap = attuneCap,
			LastDailyAttuneDay = 0,
			QuickBindReadyAt = 0,
			FreeSignalAt = 0,
			EpicCatalysts = epicCatalysts,
			TargetedAttuneTier = nil,
			FamilyAttune = nil,
			MutationFocusScansLeft = mutationFocusLeft,
		}
	end

	-- New objective = unique mechanic unlock, first-time milestone, or build decision.
	-- Ordinary mutation drops / duplicate finds / pedestal buys do NOT reset this clock.
	local function noteNewObjective(second: number)
		if lastNewObjective > 0 then
			local gapMin = (second - lastNewObjective) / 60
			if gapMin > longestNewGap then
				longestNewGap = gapMin
			end
			if gapMin > 5 then
				deadAccum += gapMin - 5
			end
		end
		lastNewObjective = second
	end

	local function unlockMechanic(id: string, second: number)
		if mechanicsSeen[id] then
			return
		end
		mechanicsSeen[id] = true
		uniqueMechanics += 1
		noteNewObjective(second)
	end

	local function noteMilestone(second: number)
		firstMilestones += 1
		noteNewObjective(second)
	end

	local function noteBuild(second: number)
		buildDecisions += 1
		noteNewObjective(second)
	end

	local function noteOrdinary()
		ordinary += 1
	end

	local function spendEssence(bucket: string, amount: number)
		essence -= amount
		essenceSpent += amount
		spend[bucket] = (spend[bucket] or 0) + amount
	end

	local function luckMult(): number
		local core = Formulas.coreLuck(skills.CoreLuck, candidate.LuckDivisor)
		local reb = Rebirth.luckMultiplier(rebirthSettings, rebirths)
		local potion = if potionLeft > 0 then Config.Luck.MaxConsumable else 1
		return core * reb * (1 + codexLuck(essentialUnique)) * (1 + showcaseLuck(showcaseLevel)) * potion
	end
	local function context()
		local key = `{luckMult()}|{skills.MutationResonance}`
		if key ~= ctxKey or not ctx then
			ctx = RollMath.contextFor(rules, {
				FullLuck = luckMult(),
				MutationRank = skills.MutationResonance,
			})
			ctxKey = key
		end
		return ctx
	end
	local function incomePerSec(): number
		local mults = {}
		for i, level in levels do
			mults[i] = Economy.pedestalMultiplier(Config.Economy, level)
		end
		table.sort(mults, function(a, b)
			return a > b
		end)
		local contrib = {}
		for i, m in mults do
			local income = held[i] or 0
			-- Apply fused income mult when that base is on a pedestal (approx via held value match).
			table.insert(contrib, income * m)
		end
		local showIncome = 0
		if showcaseLevel > 0 then
			local row = ShowcaseConfig.Levels[math.min(showcaseLevel, ShowcaseConfig.MaxLevel)]
			showIncome = row and row.Income or 0
		end
		local fuseMult = 1
		for _, entry in fusion do
			fuseMult *= CollectionMath.fusionIncomeMult(entry.Rank)
		end
		-- Soften stacked board mults — use average of fused ranks instead of product explosion.
		local fusedN = countKeys(fusion)
		if fusedN > 0 then
			local sum = 0
			for _, entry in fusion do
				sum += CollectionMath.fusionIncomeMult(entry.Rank)
			end
			fuseMult = sum / fusedN
		else
			fuseMult = 1
		end
		return Economy.totalIncome(
			contrib,
			(1 + SkillConfig.incomeBonus(skills.EnergyConduction) + showIncome)
				* Rebirth.incomeMultiplier(rebirthSettings, rebirths)
				* fuseMult
		)
	end

	local function grantEssence(amount: number, second: number)
		if amount <= 0 then
			return
		end
		essence += amount
		essenceEarned += amount
	end

	local function claimGoals(second: number)
		local uniqueMut = countKeys(mutatedRelics)
		local catalysts = countKeys(epicCatalysts)
		for _, goal in CollectionConfig.MutationGoals do
			if goalsClaimedMap[goal.Id] then
				continue
			end
			local progress = 0
			local required = goal.UniqueRequired or goal.EpicCatalystsRequired or 1
			if goal.EpicCatalystsRequired then
				progress = catalysts
			elseif goal.AnyMutation then
				progress = uniqueMut
			elseif goal.MutationId then
				progress = mutByType[goal.MutationId] or 0
			end
			if progress >= required then
				goalsClaimedMap[goal.Id] = true
				goalsClaimed += 1
				if goal.Unlock == "AttuneTicketRecipe" then
					attuneCharges += 1
				end
				if not firstGoalMin then
					firstGoalMin = second / 60
				end
				noteMilestone(second)
				if goal.Unlock then
					unlockMechanic(goal.Unlock, second)
				end
				if goal.SlotBonus then
					unlockMechanic(`SlotBonus:{goal.Id}`, second)
				end
			end
		end
	end

	local function trySpendEssence(second: number)
		if spendPolicy == "Hoard" and firstFusionMin then
			return
		end
		local state = collectionState()
		local allowRepeatSinks = spendPolicy == "Optimal"
		local allowCatalyst = spendPolicy ~= "Hoard"

		-- Prefer upgrading existing board entries before filling new slots.
		local candidates = {}
		for id, entry in fusion do
			table.insert(candidates, { Id = id, Rank = entry.Rank, Priority = 0 })
		end
		for id, n in counts do
			if not fusion[id] then
				table.insert(candidates, { Id = id, Rank = 0, Priority = 1 })
			end
		end
		table.sort(candidates, function(a, b)
			if a.Priority ~= b.Priority then
				return a.Priority < b.Priority
			end
			return a.Rank > b.Rank
		end)

		for _, cand in candidates do
			local id = cand.Id
			local relic = RelicConfig.ById[id]
			if not relic then
				continue
			end
			local entry = fusion[id] or { Rank = 0, Charm = nil }
			local n = counts[id] or 0
			local catalystReady = epicCatalysts[id] == true or entry.Rank > 0
			local ok = CollectionMath.canFuse({
				TierId = relic.Tier,
				RelicId = id,
				CurrentRank = entry.Rank,
				OwnedCopies = n,
				Essence = essence,
				State = state,
				Rebirths = rebirths,
				HasMutatedCopy = (mutatedCounts[id] or 0) > 0,
				EpicCatalystReady = catalystReady,
			})
			if ok then
				local nextRank = entry.Rank + 1
				local cost = CollectionMath.fusionEssenceCost(relic.Tier, nextRank)
				local consume = CollectionMath.consumeForRank(nextRank)
				spendEssence("Fusion", cost)
				counts[id] = n - consume
				entry.Rank = nextRank
				fusionRanks += 1
				local isFirstFusion = firstFusionMin == nil
				if isFirstFusion then
					firstFusionMin = second / 60
					noteMilestone(second)
					unlockMechanic("FusionBoard", second)
				else
					noteOrdinary()
				end
				if entry.Rank == 1 and not entry.Charm then
					if goalsClaimedMap.FirstGolden and nextNumber() < 0.35 then
						entry.Charm = "Workshop"
					elseif nextNumber() < 0.55 then
						entry.Charm = "Hunt"
					else
						entry.Charm = "Shrine"
					end
					charms += 1
					noteBuild(second)
				elseif entry.Rank == 3 and not sawFirstRank3 then
					sawFirstRank3 = true
					noteMilestone(second)
				end
				fusion[id] = entry
				return
			end
		end

		if allowCatalyst and goalsClaimedMap.FirstBloodmoon then
			for id, n in counts do
				local relic = RelicConfig.ById[id]
				if
					relic
					and relic.Tier == "Epic"
					and not epicCatalysts[id]
					and n >= CollectionConfig.EpicCatalyst.Copies
					and essence >= CollectionConfig.EpicCatalyst.Essence
				then
					spendEssence("Catalyst", CollectionConfig.EpicCatalyst.Essence)
					counts[id] = n - CollectionConfig.EpicCatalyst.Copies
					epicCatalysts[id] = true
					claimGoals(second)
					if countKeys(epicCatalysts) == 1 then
						noteMilestone(second)
						unlockMechanic("EpicCatalystCraft", second)
					else
						noteOrdinary()
					end
					return
				end
			end
		end

		if not allowRepeatSinks then
			return
		end

		-- Activate a charge periodically (creates a reason to recraft).
		if attuneCharges > 0 and second - lastAttuneActivate >= 300 then
			attuneCharges -= 1
			lastAttuneActivate = second
			noteOrdinary()
		end

		-- Craft Attune: initial fill, or refill shortly after an activate.
		if
			goalsClaimedMap.ThreeMutated
			and attuneCharges < attuneCap
			and essence >= CollectionConfig.AttuneTicketEssenceCost + 40
			and (attuneCharges == 0 or (lastAttuneActivate > 0 and second - lastAttuneActivate < 90))
		then
			spendEssence("AttuneTicket", CollectionConfig.AttuneTicketEssenceCost)
			attuneCharges += 1
			noteOrdinary()
			return
		end

		-- Fat-bank sinks: spend when Essence piles up (realistic player clearing a surplus).
		if
			goalsClaimedMap.FiveMutated
			and essence >= 250
			and second - lastTargetedAttune >= 240
		then
			spendEssence("TargetedAttune", CollectionConfig.TargetedAttuneEssence)
			lastTargetedAttune = second
			noteOrdinary()
			return
		end

		if
			goalsClaimedMap.FifteenMutated
			and mutationFocusLeft <= 0
			and essence >= 280
			and second - lastMutationFocus >= 200
		then
			spendEssence("MutationFocus", CollectionConfig.MutationFocusEssence)
			mutationFocusLeft = CollectionConfig.MutationFocusScans
			lastMutationFocus = second
			noteOrdinary()
			return
		end

		if
			goalsClaimedMap.FirstDivine
			and essence >= 320
			and second - lastFamilyAttune >= 360
		then
			spendEssence("FamilyAttune", CollectionConfig.FamilyAttuneEssence)
			lastFamilyAttune = second
			noteOrdinary()
			return
		end

		if
			goalsClaimedMap.ThreeMutated
			and attuneCap < (CollectionConfig.MaxAttuneChargesHardCap or 8)
			and essence >= CollectionConfig.AttuneChargeUpgradeEssence + 150
		then
			spendEssence("CapUpgrade", CollectionConfig.AttuneChargeUpgradeEssence)
			attuneCap += 1
			if attuneCap == CollectionConfig.MaxAttuneCharges + 1 then
				noteMilestone(second)
			else
				noteOrdinary()
			end
			return
		end

		-- Occasional respec (build change), not a metronome.
		if
			goalsClaimedMap.TenMutated
			and essence >= CollectionConfig.CharmRespecEssence + 150
			and second - lastCharmRespec >= 900
			and charmChanges < 3
		then
			for id, entry in fusion do
				if entry.Charm then
					spendEssence("CharmRespec", CollectionConfig.CharmRespecEssence)
					entry.Charm = if entry.Charm == "Hunt" then "Shrine" else "Hunt"
					fusion[id] = entry
					charmChanges += 1
					lastCharmRespec = second
					noteBuild(second)
					return
				end
			end
		end

		if goalsClaimedMap.FirstBloodmoon then
			for id, n in counts do
				local relic = RelicConfig.ById[id]
				local keep = if epicCatalysts[id] then 1 else CollectionConfig.EpicCatalyst.Copies
				if relic and relic.Tier == "Epic" and n > keep then
					counts[id] = n - 1
					local amount = CollectionMath.essenceFromSale("Epic", resonanceStacks, false)
					amount = math.floor(amount * (CollectionConfig.EpicSalvageEssenceMult or 1.5) + 1e-9)
					grantEssence(amount, second)
					noteOrdinary()
					return
				end
			end
		end
	end

	local function grant(relicId: string, tierId: string, mutationId: string?, second: number)
		local tierI = RarityConfig.IndexById[tierId] or 1
		local income = frozenBase[relicId] or 0
		counts[relicId] = (counts[relicId] or 0) + 1
		if tierI == EPIC_I then
			epicExact += 1
			uniqueEpicExact[relicId] = true
			if not sawFirstEpic then
				sawFirstEpic = true
				noteMilestone(second)
			end
		end
		if tierI >= EPIC_I then
			epicPlus += 1
			uniqueEpicPlus[relicId] = true
		end
		if tierI == LEG_I then
			legExact += 1
			uniqueLeg[relicId] = true
			if not sawFirstLeg then
				sawFirstLeg = true
				noteMilestone(second)
			end
		end
		if mutationId then
			mutations += 1
			local firstMutRelic = mutatedRelics[relicId] ~= true
			mutatedRelics[relicId] = true
			mutatedCounts[relicId] = (mutatedCounts[relicId] or 0) + 1
			mutByType[mutationId] = (mutByType[mutationId] or 0) + 1
			claimGoals(second)
			-- Ordinary mutation drops are not new objectives (goals fire via claimGoals).
			if firstMutRelic then
				noteOrdinary()
			end
		end

		local displayedFloor = if #held >= #levels then held[#levels] else -1
		local wasSeen = seen[relicId] == true
		local state = collectionState()
		local reserve = CollectionMath.reserveCopies(relicId, state, false)
		if reserve <= 0 and not fusion[relicId] then
			local slots = CollectionMath.fusionSlots(state, rebirths)
			if CollectionMath.fusedCount(state) < slots and tierId == "Common" then
				local need = CollectionMath.copiesForRank(1)
				if (counts[relicId] or 0) <= need then
					reserve = need
				end
			elseif fusion[relicId] then
				reserve = CollectionMath.copiesForRank((fusion[relicId].Rank or 0) + 1)
			end
		end
		local keepForFusion = (counts[relicId] or 0) <= math.max(1, reserve)
		if wasSeen and tierI <= SELL_MAX and income <= displayedFloor and not keepForFusion then
			if CollectionMath.autoEssenceAllowed(tierId) then
				local workshop = fusion[relicId] and fusion[relicId].Charm == "Workshop"
				grantEssence(CollectionMath.essenceFromSale(tierId, resonanceStacks, workshop), second)
			end
			ce += Economy.sellValue(Config.Economy, income, 0)
		else
			if not wasSeen then
				seen[relicId] = true
				uniqueCount += 1
				if tierI <= ESSENTIAL_MAX and not essentialSeen[relicId] then
					essentialSeen[relicId] = true
					essentialUnique += 1
					ctxKey = ""
					-- Essential Codex progress is ordinary until a milestone claim (tracked elsewhere).
					noteOrdinary()
				end
			end
			local index = #held + 1
			for i, v in held do
				if income > v then
					index = i
					break
				end
			end
			table.insert(held, index, income)
			while #held > Config.Plots.MaxPedestals do
				table.remove(held)
			end
		end
	end

	local function coreCost(rank: number): number
		return Formulas.coreLuckCostSoft(rank, candidate.LuckCostBase, candidate.LuckCostGrowth, options.SoftK, softPower)
	end

	local function rankDist(): (number, number, number, number)
		local r1, r2, r3, active = 0, 0, 0, 0
		for _, entry in fusion do
			if entry.Rank >= 3 then
				r3 += 1
			elseif entry.Rank >= 2 then
				r2 += 1
			elseif entry.Rank >= 1 then
				r1 += 1
			end
			if entry.Charm then
				active += 1
			end
		end
		return r1, r2, r3, active
	end

	local checkpoints = { 15, 30, 60, 90, 120, 180 }
	local nextCp = 1
	local results = {}
	local totalSeconds = math.floor(options.Hours * 3600)

	for second = 1, totalSeconds do
		if potionLeft > 0 then
			potionLeft -= 1
			if potionLeft <= 0 then
				ctxKey = ""
			end
		end
		scanTimer += 1
		local interval = SkillConfig.scanInterval(skills.ScanSpeed)
		while scanTimer >= interval do
			scanTimer -= interval
			local relic, mutationId = RollMath.roll(context(), nextNumber)
			if mutationFocusLeft > 0 then
				mutationFocusLeft -= 1
			end
			grant(relic.Id, relic.Tier, mutationId, second)
		end
		offeringTimer += 1
		if offeringTimer >= 600 then
			offeringTimer = 0
			if nextNumber() < 0.35 then
				potionLeft = math.min(ItemConfig.MaxBuffSeconds, potionLeft + 600)
				ctxKey = ""
			end
		end
		ce += incomePerSec()
		trySpendEssence(second)

		local rebirthCost = Rebirth.cost(rebirthSettings, rebirths)
		if ce >= rebirthCost then
			rebirths += 1
			table.insert(rebirthsAt, second)
			ce = 0
			for i in levels do
				levels[i] = 1
			end
			for id in skills do
				skills[id] = 0
			end
			ctxKey = ""
			-- Each Rebirth is a milestone; Resonance pick is a build decision with stack unlocks.
			noteMilestone(second)
			unlockMechanic(`RebirthSlotBonus`, second)
			local pick = if nextNumber() < 0.4 then "Collector" elseif nextNumber() < 0.5 then "Binder" else "Seeker"
			resonanceStacks[pick] = (resonanceStacks[pick] or 0) + 1
			resonancePicks += 1
			noteBuild(second)
			local unlocks = CollectionMath.resonanceUnlocked(pick, resonanceStacks[pick])
			for _, uid in unlocks do
				unlockMechanic(uid, second)
			end
			if table.find(unlocks, "PostRebirthAttune") then
				attuneCharges += 1
			end
		end

		local saving = rebirthCost - ce <= incomePerSec() * 600
		if not saving then
			for _ = 1, 400 do
				local optionsBuy = {}
				local nextSlot = #levels + 1
				local slotPrice = Config.Economy.SlotPrices[nextSlot]
				if slotPrice and nextSlot <= Config.Plots.MaxPedestals then
					table.insert(optionsBuy, {
						Cost = slotPrice,
						Sig = true,
						Buy = function()
							table.insert(levels, 1)
						end,
					})
				end
				local lowest, lowestIndex = math.huge, nil
				for index, level in levels do
					if level < Config.Economy.PedestalMaxLevel and level < lowest then
						lowest, lowestIndex = level, index
					end
				end
				if lowestIndex and #held >= 1 then
					local idx = lowestIndex
					table.insert(optionsBuy, {
						Cost = Economy.upgradeCost(Config.Economy, lowest),
						Sig = false,
						Buy = function()
							levels[idx] += 1
						end,
					})
				end
				local wantMutation = uniqueCount >= 8 or rebirths >= 1 or epicExact >= 1
				if wantMutation and skills.MutationResonance < nodes.MutationResonance.MaxRank then
					local cost = SkillConfig.cost(nodes.MutationResonance, skills.MutationResonance)
					if cost then
						table.insert(optionsBuy, {
							Cost = cost,
							Sig = true,
							Buy = function()
								skills.MutationResonance += 1
								ctxKey = ""
							end,
						})
					end
				end
				if skills.CoreLuck < nodes.CoreLuck.MaxRank then
					table.insert(optionsBuy, {
						Cost = coreCost(skills.CoreLuck),
						Sig = (skills.CoreLuck + 1) % 5 == 0,
						Buy = function()
							skills.CoreLuck += 1
							ctxKey = ""
						end,
					})
				end
				local sc = SkillConfig.cost(nodes.ScanSpeed, skills.ScanSpeed)
				if sc then
					table.insert(optionsBuy, {
						Cost = sc,
						Sig = true,
						Buy = function()
							skills.ScanSpeed += 1
						end,
					})
				end
				local ec = SkillConfig.cost(nodes.EnergyConduction, skills.EnergyConduction)
				if ec then
					table.insert(optionsBuy, {
						Cost = ec,
						Sig = false,
						Buy = function()
							skills.EnergyConduction += 1
						end,
					})
				end
				if showcaseLevel == 0 and ShowcaseConfig.Showcases[1] then
					local price = ShowcaseConfig.Showcases[1].Unlock.Price
					if type(price) == "number" then
						table.insert(optionsBuy, {
							Cost = price,
							Sig = true,
							Buy = function()
								showcaseLevel = 1
								ctxKey = ""
							end,
						})
					end
				elseif showcaseLevel > 0 and showcaseLevel < ShowcaseConfig.MaxLevel then
					local nextLevel = ShowcaseConfig.Levels[showcaseLevel + 1]
					if nextLevel and nextLevel.Cost then
						table.insert(optionsBuy, {
							Cost = nextLevel.Cost,
							Sig = true,
							Buy = function()
								showcaseLevel += 1
								ctxKey = ""
							end,
						})
					end
				end
				local cheapest = nil
				for _, opt in optionsBuy do
					if opt.Cost <= ce and (not cheapest or opt.Cost < cheapest.Cost) then
						cheapest = opt
					end
				end
				if not cheapest then
					break
				end
				if wantMutation and skills.MutationResonance < math.min(3, nodes.MutationResonance.MaxRank) then
					local mcost = SkillConfig.cost(nodes.MutationResonance, skills.MutationResonance)
					if mcost and mcost <= ce then
						for _, opt in optionsBuy do
							if opt.Cost == mcost then
								cheapest = opt
								break
							end
						end
					end
				end
				ce -= cheapest.Cost
				cheapest.Buy()
				-- Pedestal / CoreLuck / Scan buys are ordinary progression, not new objectives.
				noteOrdinary()
				if cheapest.Sig and skills.MutationResonance == 1 and not mechanicsSeen.MutationResonanceSkill then
					unlockMechanic("MutationResonanceSkill", second)
				end
			end
		end

		local minute = checkpoints[nextCp]
		if minute and second == minute * 60 then
			nextCp += 1
			local r1, r2, r3, active = rankDist()
			local state = collectionState()
			-- Close out gap to checkpoint if still running without a new objective.
			local gapNow = if lastNewObjective > 0 then (second - lastNewObjective) / 60 else minute
			local longest = math.max(longestNewGap, gapNow)
			table.insert(results, {
				Minute = minute,
				EpicExact = epicExact,
				EpicPlus = epicPlus,
				UniqueEpicExact = countKeys(uniqueEpicExact),
				UniqueEpicPlus = countKeys(uniqueEpicPlus),
				LegendaryExact = legExact,
				UniqueLegendary = countKeys(uniqueLeg),
				Mutations = mutations,
				UniqueMutatedRelics = countKeys(mutatedRelics),
				Goals = goalsClaimed,
				GoalsTotal = goalsTotal,
				Essence = essence,
				EssenceEarned = essenceEarned,
				EssenceSpent = essenceSpent,
				FusionRanks = fusionRanks,
				Charms = charms,
				ActiveCharms = active,
				BoardSlots = CollectionMath.fusionSlots(state, rebirths),
				FusedRelics = countKeys(fusion),
				Rank1 = r1,
				Rank2 = r2,
				Rank3 = r3,
				CharmChanges = charmChanges,
				EpicCatalysts = countKeys(epicCatalysts),
				UniqueMechanics = uniqueMechanics,
				FirstMilestones = firstMilestones,
				BuildDecisions = buildDecisions,
				Ordinary = ordinary,
				LongestNewGapMin = longest,
				Luck = luckMult(),
				Income = incomePerSec(),
				Rebirths = rebirths,
				CoreLuck = skills.CoreLuck,
				MutationRank = skills.MutationResonance,
				Scan = interval,
				AttuneCharges = attuneCharges,
				ResonancePicks = resonancePicks,
				SpendFusion = spend.Fusion,
				SpendCatalyst = spend.Catalyst,
				SpendAttune = spend.AttuneTicket,
				SpendTargeted = spend.TargetedAttune,
				SpendMutFocus = spend.MutationFocus,
				SpendFamily = spend.FamilyAttune,
				SpendRespec = spend.CharmRespec,
				SpendCap = spend.CapUpgrade,
				DeadMinutes = deadAccum,
			})
		end
	end

	local rosterEpic, rosterPlus = 0, 0
	for _, r in RelicConfig.Relics do
		if r.Tier == "Epic" then
			rosterEpic += 1
		end
		if (RarityConfig.IndexById[r.Tier] or 0) >= EPIC_I then
			rosterPlus += 1
		end
	end

	return {
		Checkpoints = results,
		RebirthsAt = rebirthsAt,
		FirstFusionMin = firstFusionMin,
		FirstGoalMin = firstGoalMin,
		RosterEpicExact = rosterEpic,
		RosterEpicPlus = rosterPlus,
		EssenceSpend = spend,
		Final = results[#results],
	}
end

return StudioLoop

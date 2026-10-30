-- Shared Collection/Fusion helpers for progression sims.
-- Mirrors CollectionMath + CollectionService.TryFuse / BoardIncomeMult / GrantEssenceFromSale.
-- SoftCap_P4: board-global best-rank income; SoftCap_P3: per-pedestal fusion mult.

local CollectionConfig = require("../../src/shared/CollectionConfig")
local CollectionMath = require("../../src/shared/CollectionMath")
local RelicConfig = require("../../src/shared/RelicConfig")

local RealFusion = {}

export type Owned = {
	Counts: { [string]: number },
	Mutated: { [string]: number }, -- mutated copies (subset of Counts)
}

function RealFusion.newOwned(): Owned
	return { Counts = {}, Mutated = {} }
end

function RealFusion.addFind(owned: Owned, relicId: string, mutation: string?)
	owned.Counts[relicId] = (owned.Counts[relicId] or 0) + 1
	if mutation then
		owned.Mutated[relicId] = (owned.Mutated[relicId] or 0) + 1
	end
end

function RealFusion.baseCopies(owned: Owned, relicId: string): number
	local have = owned.Counts[relicId] or 0
	local mut = owned.Mutated[relicId] or 0
	return math.max(0, have - mut)
end

-- Server removeBaseCopies: only non-mutated, non-locked inventory copies.
function RealFusion.consumeBaseCopies(owned: Owned, relicId: string, n: number): boolean
	if RealFusion.baseCopies(owned, relicId) < n then
		return false
	end
	owned.Counts[relicId] = (owned.Counts[relicId] or 0) - n
	return true
end

function RealFusion.essenceFromDupe(state: CollectionMath.CollectionState, relicId: string): number
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return 0
	end
	-- Mirror server: Rare- auto-essence; Epic+ only after First Bloodmoon (Salvage path).
	local epicSalvage = relic.Tier == "Epic" and CollectionMath.hasUnlockFlag(state, "EpicSalvageBoost")
	if not CollectionMath.autoEssenceAllowed(relic.Tier) and not epicSalvage then
		return 0
	end
	local entry = state.Fusion[relicId]
	local workshop = entry and entry.Charm == "Workshop"
	local workshopTier = if workshop then relic.Tier else nil
	local amount = CollectionMath.essenceFromSale(relic.Tier, state.ResonanceStacks, workshop == true, workshopTier)
	if epicSalvage then
		amount = math.floor(amount * (CollectionConfig.EpicSalvageEssenceMult or 1.5) + 1e-9)
	end
	local pursuit = CollectionMath.pursuitConfig(state.ActivePursuit)
	if
		pursuit
		and type(pursuit.EpicDupeEssenceMult) == "number"
		and relic.Tier == "Epic"
		and pursuit.EpicDupeEssenceMult > 1
	then
		amount = math.floor(amount * pursuit.EpicDupeEssenceMult + 1e-9)
	end
	return amount
end

-- SoftCap_P4 Phase 7: Retire weaker Charm lineage → Fuse higher-tier same-role target.
function RealFusion.tryAscendCharm(
	state: CollectionMath.CollectionState,
	owned: Owned,
	rebirths: number
): (boolean, string?)
	local meta: { [string]: { Tier: string, Name: string, Family: string? } } = {}
	local ownedBase: { [string]: number } = {}
	for id, relic in RelicConfig.ById do
		meta[id] = { Tier = relic.Tier, Name = relic.Name, Family = relic.Family }
		ownedBase[id] = RealFusion.baseCopies(owned, id)
	end
	local workshop = CollectionMath.hasUnlockFlag(state, "WorkshopCharmGlobal")
	local prefer = if state.ActivePursuit == "EpicLineage" then "Epic" else nil
	local hint = CollectionMath.bestAscendHint(state, ownedBase, meta, workshop, prefer)
	if not hint or not hint.Ready then
		return false, nil
	end
	local charmId = hint.Charm
	if not RealFusion.tryRetire(state, hint.CurrentRelicId) then
		return false, "retire failed"
	end
	local ok, msg = RealFusion.tryFuse(state, owned, hint.TargetRelicId, rebirths)
	if not ok then
		return false, msg
	end
	local entry = state.Fusion[hint.TargetRelicId]
	if entry then
		entry.Charm = charmId
	end
	return true, charmId
end

function RealFusion.fusionIncomeMult(state: CollectionMath.CollectionState, relicId: string): number
	local entry = state.Fusion[relicId]
	if not entry or (entry.Rank or 0) <= 0 then
		return 1
	end
	return CollectionMath.fusionIncomeMult(entry.Rank)
end

function RealFusion.boardIncomeMult(state: CollectionMath.CollectionState): number
	return CollectionMath.boardIncomeMult(state)
end

-- SoftCap_P4: pedestal contribution has no per-slot fusion (board mult applied once globally).
function RealFusion.pedestalContribution(
	state: CollectionMath.CollectionState,
	relicId: string?,
	baseIncome: number,
	pedLevelMult: number,
	masteryMult: number,
	boardGlobal: boolean?
): number
	if not relicId or baseIncome <= 0 then
		return 0
	end
	local fuse = if boardGlobal then 1 elseif state then RealFusion.fusionIncomeMult(state, relicId) else 1
	return baseIncome * pedLevelMult * fuse * masteryMult
end

-- SoftCap_P4: FusionLift = boardIncomeMult (best rank). Legacy: pedestal pairing ratio.
function RealFusion.incomeLiftRatio(
	state: CollectionMath.CollectionState,
	heldRelicIds: { string? },
	heldBase: { number },
	pedLevels: { number },
	slots: number,
	pedMultFn: (number) -> number,
	masteryMult: number,
	boardGlobal: boolean?
): number
	if boardGlobal then
		return CollectionMath.boardIncomeMult(state)
	end
	local withF, withoutF = 0, 0
	for i = 1, slots do
		local id = heldRelicIds[i]
		local base = heldBase[i] or 0
		if id and base > 0 then
			local pm = pedMultFn(pedLevels[i] or 1) * masteryMult
			withoutF += base * pm
			withF += base * pm * RealFusion.fusionIncomeMult(state, id)
		end
	end
	if withoutF <= 0 then
		return 1
	end
	return withF / withoutF
end

function RealFusion.tryRetire(state: CollectionMath.CollectionState, relicId: string): (boolean, string)
	local entry = state.Fusion[relicId]
	if not entry or (entry.Rank or 0) <= 0 then
		return false, "Not on Board."
	end
	local cost = CollectionConfig.BoardRetireEssence or 80
	if state.Essence < cost then
		return false, "Need Essence."
	end
	state.Essence -= cost
	state.Fusion[relicId] = nil
	state.FusionPins[relicId] = nil
	if state.BoardFocusId == relicId then
		state.BoardFocusId = nil
	end
	return true, "Retired"
end

-- Weakest board entry by income mult (retire candidate when a better fuse is blocked by Board).
function RealFusion.weakestBoardEntry(state: CollectionMath.CollectionState): string?
	local worstId: string? = nil
	local worstMult = 1e9
	for relicId, entry in state.Fusion do
		local m = CollectionMath.fusionIncomeMult(entry.Rank or 0)
		if m < worstMult then
			worstMult = m
			worstId = relicId
		end
	end
	return worstId
end

-- Relic that is fuse-ready except for Board capacity (new entry blocked).
function RealFusion.pickBlockedByBoard(
	state: CollectionMath.CollectionState,
	owned: Owned,
	rebirths: number,
	heldRelicIds: { string? }?
): string?
	local onPed: { [string]: boolean } = {}
	if heldRelicIds then
		for _, id in heldRelicIds do
			if id then
				onPed[id] = true
			end
		end
	end
	local bestId: string? = nil
	local bestScore = -1e9
	for relicId, count in owned.Counts do
		local relic = RelicConfig.ById[relicId]
		if not relic then
			continue
		end
		local entry = state.Fusion[relicId]
		if entry and (entry.Rank or 0) > 0 then
			continue -- already on board; upgrades don't need retire
		end
		local baseOwned = RealFusion.baseCopies(owned, relicId)
		local ok, _, kind = CollectionMath.canFuse({
			TierId = relic.Tier,
			RelicId = relicId,
			CurrentRank = 0,
			OwnedCopies = baseOwned,
			Essence = state.Essence,
			State = state,
			Rebirths = rebirths,
			HasMutatedCopy = (owned.Mutated[relicId] or 0) > 0,
			EpicCatalystReady = state.EpicCatalysts[relicId] == true,
		})
		if ok or kind ~= "Board" then
			continue
		end
		-- Board-blocked: verify copies/essence would pass without board.
		local ok2 = CollectionMath.canFuse({
			TierId = relic.Tier,
			CurrentRank = 0,
			OwnedCopies = baseOwned,
			Essence = state.Essence,
			-- no State → no board check
			HasMutatedCopy = (owned.Mutated[relicId] or 0) > 0,
			EpicCatalystReady = state.EpicCatalysts[relicId] == true,
		})
		if not ok2 then
			continue
		end
		if baseOwned < CollectionMath.consumeForRank(1) then
			continue
		end
		local tierI = ({ Common = 1, Uncommon = 2, Rare = 3, Epic = 4 })[relic.Tier] or 5
		local score = tierI * 20 + (if onPed[relicId] then 100 else 0)
		if score > bestScore then
			bestScore = score
			bestId = relicId
		end
	end
	return bestId
end

function RealFusion.tryFuse(
	state: CollectionMath.CollectionState,
	owned: Owned,
	relicId: string,
	rebirths: number
): (boolean, string)
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return false, "Unknown relic."
	end
	local entry = state.Fusion[relicId] or { Rank = 0, Charm = nil }
	-- Server OwnedCopies counts base (non-mutated) only — match that here.
	local baseOwned = RealFusion.baseCopies(owned, relicId)
	local ok, reason = CollectionMath.canFuse({
		TierId = relic.Tier,
		RelicId = relicId,
		RelicName = relic.Name,
		CurrentRank = entry.Rank,
		OwnedCopies = baseOwned,
		Essence = state.Essence,
		State = state,
		Rebirths = rebirths,
		HasMutatedCopy = (owned.Mutated[relicId] or 0) > 0,
		EpicCatalystReady = state.EpicCatalysts[relicId] == true or entry.Rank > 0,
	})
	if not ok then
		return false, reason
	end
	local nextRank = entry.Rank + 1
	local cost = CollectionMath.fusionEssenceCost(relic.Tier, nextRank)
	local consume = CollectionMath.consumeForRank(nextRank)
	if not RealFusion.consumeBaseCopies(owned, relicId, consume) then
		return false, "Could not consume copies."
	end
	state.Essence -= cost
	entry.Rank = nextRank
	state.Fusion[relicId] = entry
	state.FusionPins[relicId] = true
	if CollectionMath.needsMutatedCopyForNextRank(nextRank) then
		local resolved = CollectionMath.resolveBoardFocusId(state)
		if state.BoardFocusId == nil or resolved == nil then
			state.BoardFocusId = relicId
		end
	elseif nextRank >= (CollectionConfig.MaxFusionRank or 3) and state.BoardFocusId == relicId then
		state.BoardFocusId = nil
	end
	-- Match live: each Board Charm is unique; suggest Hunt → Workshop → Shrine.
	if nextRank == 1 and not entry.Charm then
		local workshop = CollectionMath.hasUnlockFlag(state, "WorkshopCharmGlobal")
		entry.Charm = CollectionMath.suggestBoardCharm(state, workshop)
	end
	return true, `Fusion rank {nextRank}`
end

function RealFusion.claimGoals(
	state: CollectionMath.CollectionState,
	uniqueMutatedByMutation: { [string]: number },
	uniqueAnyMutated: number
)
	local now = 1
	for _, goal in CollectionConfig.MutationGoals do
		if state.MutationGoalsClaimed[goal.Id] then
			continue
		end
		local progress = 0
		local required = goal.UniqueRequired or goal.EpicCatalystsRequired or 1
		if goal.EpicCatalystsRequired then
			local n = 0
			for _ in state.EpicCatalysts do
				n += 1
			end
			progress = n
		elseif goal.AnyMutation then
			progress = uniqueAnyMutated
		elseif goal.MutationId then
			progress = uniqueMutatedByMutation[goal.MutationId] or 0
		end
		if progress >= required then
			state.MutationGoalsClaimed[goal.Id] = now
			if goal.Unlock == "AttuneTicketRecipe" then
				state.AttuneCharges += 1
			end
		end
	end
end

-- Prefer pedestal relics (income applies), then in-place upgrades, then new board Commons.
-- Avoid filling the board with off-pedestal Commons that never affect pedestal income.
function RealFusion.pickFuseTarget(
	state: CollectionMath.CollectionState,
	owned: Owned,
	rebirths: number,
	heldRelicIds: { string? }?
): string?
	local onPed: { [string]: boolean } = {}
	if heldRelicIds then
		for _, id in heldRelicIds do
			if id then
				onPed[id] = true
			end
		end
	end
	local slots = CollectionMath.fusionSlots(state, rebirths)
	local used = CollectionMath.fusedCount(state)
	local freeSlots = slots - used

	local bestId: string? = nil
	local bestScore = -1e9
	for relicId, count in owned.Counts do
		if count <= 0 then
			continue
		end
		local relic = RelicConfig.ById[relicId]
		if not relic then
			continue
		end
		local entry = state.Fusion[relicId] or { Rank = 0, Charm = nil }
		local baseOwned = RealFusion.baseCopies(owned, relicId)
		if baseOwned <= 0 then
			continue
		end
		local ok = CollectionMath.canFuse({
			TierId = relic.Tier,
			RelicId = relicId,
			CurrentRank = entry.Rank,
			OwnedCopies = baseOwned,
			Essence = state.Essence,
			State = state,
			Rebirths = rebirths,
			HasMutatedCopy = (owned.Mutated[relicId] or 0) > 0,
			EpicCatalystReady = state.EpicCatalysts[relicId] == true or entry.Rank > 0,
		})
		if not ok then
			continue
		end
		-- Must have enough base copies to consume (server rule).
		local nextRank = entry.Rank + 1
		if baseOwned < CollectionMath.consumeForRank(nextRank) then
			continue
		end
		local isNew = (entry.Rank or 0) <= 0
		local tierI = ({ Common = 1, Uncommon = 2, Rare = 3, Epic = 4 })[relic.Tier] or 5
		-- SoftCap_P4: best-rank Lift still wins when it rises; free slots are Charm lineages
		-- (Workshop Essence / Hunt family / Shrine) — not wasted because income does not stack.
		local score = 30 + tierI * 10
		if entry.Rank > 0 then
			score += 60 + entry.Rank * 12
			local curBest = CollectionMath.boardIncomeMult(state)
			local nextMult = CollectionMath.fusionIncomeMult(entry.Rank + 1)
			if nextMult > curBest + 1e-9 then
				score += 200
			end
		elseif freeSlots > 0 then
			-- Fill unlocked Board slots for orthogonal Charms (esp. Workshop after First Golden).
			score += 90
			if CollectionMath.hasUnlockFlag(state, "WorkshopCharmGlobal") then
				score += 25
			end
		end
		if onPed[relicId] then
			score += 40
		end
		score += math.min(count, 8)
		if score > bestScore then
			bestScore = score
			bestId = relicId
		end
	end
	return bestId
end

function RealFusion.softPin(
	state: CollectionMath.CollectionState,
	owned: Owned,
	rebirths: number,
	_heldRelicIds: { string? }?
): string?
	-- Match server SoftPinTarget: free-slot Common/Uncommon, or Phase 7 Ascend target when Lift capped.
	local baseById: { [string]: number } = {}
	local tiers: { [string]: string } = {}
	for relicId in owned.Counts do
		local relic = RelicConfig.ById[relicId]
		if relic then
			baseById[relicId] = RealFusion.baseCopies(owned, relicId)
			tiers[relicId] = relic.Tier
		end
	end
	for relicId in state.Fusion do
		local relic = RelicConfig.ById[relicId]
		if relic then
			tiers[relicId] = relic.Tier
			baseById[relicId] = baseById[relicId] or 0
		end
	end
	return CollectionMath.softPinTarget(state, baseById, tiers, rebirths)
end

function RealFusion.shouldKeepForReserve(
	state: CollectionMath.CollectionState,
	owned: Owned,
	relicId: string,
	rebirths: number,
	heldRelicIds: { string? }?,
	mutation: string?
): boolean
	if mutation ~= nil then
		local need = CollectionMath.mutatedCopiesToReserve(state, relicId)
		if need <= 0 then
			return false
		end
		return (owned.Mutated[relicId] or 0) <= need
	end
	local soft = RealFusion.softPin(state, owned, rebirths, heldRelicIds)
	-- Server reserve checks base inventory count only.
	return CollectionMath.wouldBreachReserve(relicId, RealFusion.baseCopies(owned, relicId), state, false, soft)
end

-- SoftCap_P4 sell-all mirror: protect first N base + first M mutated per relic.
function RealFusion.reserveSlots(
	state: CollectionMath.CollectionState,
	owned: Owned,
	rebirths: number,
	heldRelicIds: { string? }?
): { Base: { [string]: number }, Mutated: { [string]: number } }
	local soft = RealFusion.softPin(state, owned, rebirths, heldRelicIds)
	local base: { [string]: number } = {}
	local mut: { [string]: number } = {}
	for relicId in owned.Counts do
		base[relicId] = CollectionMath.reserveCopies(relicId, state, false, soft)
		mut[relicId] = CollectionMath.mutatedCopiesToReserve(state, relicId)
	end
	return { Base = base, Mutated = mut }
end

function RealFusion.activeBoardCount(state: CollectionMath.CollectionState): number
	return CollectionMath.fusedCount(state)
end

function RealFusion.boardSlots(state: CollectionMath.CollectionState, rebirths: number): number
	return CollectionMath.fusionSlots(state, rebirths)
end

function RealFusion.fusedOnPedestalCount(state: CollectionMath.CollectionState, heldRelicIds: { string? }, slots: number): number
	local n = 0
	for i = 1, slots do
		local id = heldRelicIds[i]
		if id and state.Fusion[id] and (state.Fusion[id].Rank or 0) > 0 then
			n += 1
		end
	end
	return n
end

return RealFusion

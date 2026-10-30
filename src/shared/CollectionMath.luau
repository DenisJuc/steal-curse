-- Pure collection math (Essence, fusion eligibility, Charm/Resonance effects).
-- No Roblox APIs — Lune tests and server share this.

local CollectionConfig
if script ~= nil then
	CollectionConfig = require(script.Parent.CollectionConfig)
else
	-- Lune file require (no `script` Instance).
	CollectionConfig = require("./CollectionConfig")
end

local CollectionMath = {}

export type FusionEntry = {
	Rank: number,
	Charm: string?,
}

export type CollectionState = {
	Essence: number,
	Fusion: { [string]: FusionEntry },
	FusionPins: { [string]: boolean },
	-- SoftCap_P4: which Rank-2 Board relic NEXT prioritizes for Rank 3 (not a buff).
	BoardFocusId: string?,
	ResonanceStacks: { [string]: number },
	PendingResonance: boolean,
	MutationGoalsClaimed: { [string]: number },
	AttuneCharges: number,
	AttuneScansLeft: number,
	AttuneChargeCap: number,
	LastDailyAttuneDay: number,
	QuickBindReadyAt: number,
	FreeSignalAt: number,
	-- Relic ids that completed an Epic Catalyst craft (unlocks Epic board fusion for that id).
	EpicCatalysts: { [string]: boolean },
	TargetedAttuneTier: string?,
	FamilyAttune: string?,
	MutationFocusScansLeft: number,
	-- SoftCap_P4 Phase 7.1: pursuit for the current Rebirth life (nil until chosen with Resonance).
	ActivePursuit: string?,
	-- Relic ids that already paid MutationLedger Essence this life (cleared on Rebirth).
	PursuitMutSeen: { [string]: boolean },
	-- SoftCap: player-chosen hunt target (exact SoftCap bias on binds after first Board fuse).
	HuntQuarryId: string?,
	-- Workspace time when HuntQuarryId was last set (retarget cooldown).
	HuntQuarrySetAt: number?,
}

function CollectionMath.defaults(): CollectionState
	return {
		Essence = 0,
		Fusion = {},
		FusionPins = {},
		BoardFocusId = nil,
		ResonanceStacks = {
			Collector = 0,
			Binder = 0,
			Seeker = 0,
		},
		PendingResonance = false,
		MutationGoalsClaimed = {},
		AttuneCharges = 0,
		AttuneScansLeft = 0,
		AttuneChargeCap = CollectionConfig.MaxAttuneCharges,
		LastDailyAttuneDay = 0,
		QuickBindReadyAt = 0,
		FreeSignalAt = 0,
		EpicCatalysts = {},
		TargetedAttuneTier = nil,
		FamilyAttune = nil,
		MutationFocusScansLeft = 0,
		ActivePursuit = nil,
		PursuitMutSeen = {},
		HuntQuarryId = nil,
		HuntQuarrySetAt = nil,
	}
end

function CollectionMath.essenceForTier(tierId: string): number
	return CollectionConfig.EssenceByTier[tierId] or 1
end

function CollectionMath.collectorEssenceMult(stacks: number): number
	local row = CollectionConfig.Resonances.Collector
	return 1 + (row.EssenceMultPerStack or 0) * math.max(0, stacks)
end

function CollectionMath.charmPotency(tierId: string?): number
	local table_ = CollectionConfig.CharmPotencyByTier
	if type(table_) ~= "table" then
		return 1
	end
	local p = table_[tierId or "Common"]
	if type(p) == "number" and p > 0 then
		return p
	end
	return 1
end

function CollectionMath.workshopEssenceBonus(workshopTierId: string?): number
	local base = CollectionConfig.Charms.Workshop.EssenceBonus or 0
	return base * CollectionMath.charmPotency(workshopTierId)
end

function CollectionMath.shrinePulseSeconds(shrineTierId: string?): number
	local base = (CollectionConfig.Charms.Shrine and CollectionConfig.Charms.Shrine.PulseSeconds) or 60
	local minSec = (CollectionConfig.Charms.Shrine and CollectionConfig.Charms.Shrine.MinPulseSeconds) or 20
	local pot = CollectionMath.charmPotency(shrineTierId)
	return math.max(minSec, base / math.max(1e-6, pot))
end

function CollectionMath.essenceFromSale(
	tierId: string,
	resonanceStacks: { [string]: number }?,
	workshopBonus: boolean?,
	workshopTierId: string?
): number
	local base = CollectionMath.essenceForTier(tierId)
	local stacks = if resonanceStacks then (resonanceStacks.Collector or 0) else 0
	local mult = CollectionMath.collectorEssenceMult(stacks)
	local amount = math.floor(base * mult + 1e-9)
	if workshopBonus then
		-- Potency uses the Workshop lineage tier. Always grant ≥+1 so Common Workshop isn't floored to zero.
		local bonusFrac = CollectionMath.workshopEssenceBonus(workshopTierId or tierId)
		local add = math.max(1, math.floor(base * bonusFrac + 1e-9))
		amount += add
	end
	return amount
end

function CollectionMath.pursuitConfig(pursuitId: string?): any?
	if type(pursuitId) ~= "string" then
		return nil
	end
	local table_ = CollectionConfig.RebirthPursuits
	if type(table_) ~= "table" then
		return nil
	end
	return table_[pursuitId]
end

function CollectionMath.pursuitAvailable(pursuitId: string, hasUnlock: (string) -> boolean): boolean
	local row = CollectionMath.pursuitConfig(pursuitId)
	if not row then
		return false
	end
	if type(row.RequiresUnlock) == "string" and row.RequiresUnlock ~= "" then
		return hasUnlock(row.RequiresUnlock)
	end
	return true
end

function CollectionMath.huntCaptureEssenceAmount(familyMatchCount: number, resonanceCollectorStacks: number, pursuitId: string?): number
	local base = CollectionConfig.HuntCaptureEssence or 1
	local perMatch = CollectionConfig.HuntFamilyMatchEssence or 0
	local pursuit = CollectionMath.pursuitConfig(pursuitId)
	if pursuit and type(pursuit.HuntMatchEssenceBonus) == "number" then
		perMatch += pursuit.HuntMatchEssenceBonus
	end
	local matches = math.max(0, math.floor(familyMatchCount))
	local raw = base + matches * perMatch
	local mult = CollectionMath.collectorEssenceMult(resonanceCollectorStacks or 0)
	return math.floor(raw * mult + 1e-9)
end

function CollectionMath.fusionEssenceCost(tierId: string, nextRank: number?): number
	local base = CollectionConfig.FusionEssenceCostByTier[tierId] or 25
	local rank = math.clamp(math.floor(nextRank or 1), 1, CollectionConfig.MaxFusionRank)
	local mult = CollectionConfig.FusionRankCostMult[rank] or 1
	return math.ceil(base * mult - 1e-9)
end

local TIER_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Celestial = 7,
	Cosmic = 8,
}

function CollectionMath.autoEssenceAllowed(tierId: string): boolean
	local maxId = CollectionConfig.AutoEssenceMaxTier or "Rare"
	local tierI = TIER_ORDER[tierId] or 0
	local maxI = TIER_ORDER[maxId] or 0
	return tierI > 0 and tierI <= maxI
end

function CollectionMath.fusionIncomeMult(rank: number): number
	return CollectionConfig.FusionIncomeMultByRank[rank] or 1
end

-- SoftCap_P4: single global income factor from the Board = best fused rank (never a product).
-- Empty Board → 1. Retired entries are absent from state.Fusion and do not contribute.
function CollectionMath.boardIncomeMult(state: CollectionState): number
	local best = 1
	for _, entry in state.Fusion do
		local rank = entry and entry.Rank or 0
		if rank > 0 then
			local m = CollectionMath.fusionIncomeMult(rank)
			if m > best then
				best = m
			end
		end
	end
	return best
end

-- Board income if this Fusion entry were removed (Retire preview).
function CollectionMath.boardIncomeMultWithout(state: CollectionState, relicId: string): number
	local best = 1
	for id, entry in state.Fusion do
		if id ~= relicId then
			local rank = entry and entry.Rank or 0
			if rank > 0 then
				local m = CollectionMath.fusionIncomeMult(rank)
				if m > best then
					best = m
				end
			end
		end
	end
	return best
end

export type RetirePreview = {
	RelicId: string,
	Rank: number,
	CharmId: string?,
	Cost: number,
	IncomeBefore: number,
	IncomeAfter: number,
	DropsBoardLift: boolean,
	IsSoleHighest: boolean,
}

-- Exact losses from retiring a Board lineage (rank, Charm, Essence, Board ×income).
function CollectionMath.previewRetire(state: CollectionState, relicId: string): RetirePreview?
	local entry = state.Fusion[relicId]
	if not entry or (entry.Rank or 0) <= 0 then
		return nil
	end
	local rank = entry.Rank or 0
	local before = CollectionMath.boardIncomeMult(state)
	local after = CollectionMath.boardIncomeMultWithout(state, relicId)
	local entryMult = CollectionMath.fusionIncomeMult(rank)
	local isSoleHighest = entryMult + 1e-9 >= before and after + 1e-9 < before
	return {
		RelicId = relicId,
		Rank = rank,
		CharmId = entry.Charm,
		Cost = CollectionConfig.BoardRetireEssence or 80,
		IncomeBefore = before,
		IncomeAfter = after,
		DropsBoardLift = after + 1e-9 < before,
		IsSoleHighest = isSoleHighest,
	}
end

function CollectionMath.copiesForRank(nextRank: number): number
	return CollectionConfig.CopiesForRank[nextRank] or CollectionConfig.CopiesForRank[1] or 3
end

function CollectionMath.consumeForRank(nextRank: number): number
	return CollectionConfig.FusionConsumeByRank[nextRank] or 2
end

function CollectionMath.fusedCount(state: CollectionState): number
	local n = 0
	for _ in state.Fusion do
		n += 1
	end
	return n
end

-- Concurrent board slots from start + claimed goal SlotBonus (+ Rebirth 1 bonus).
function CollectionMath.fusionSlots(state: CollectionState, rebirths: number?): number
	local slots = CollectionConfig.StartingFusionSlots or 1
	for _, goal in CollectionConfig.MutationGoals do
		if state.MutationGoalsClaimed[goal.Id] and type(goal.SlotBonus) == "number" then
			slots += goal.SlotBonus
		end
	end
	if (rebirths or 0) >= 1 then
		slots += 1
	end
	return math.clamp(slots, 1, CollectionConfig.MaxFusionSlots or 5)
end

export type BoardUnlockStep = {
	Id: string,
	Kind: "Start" | "Goal" | "Rebirth",
	Name: string,
	Summary: string,
	GoalId: string?,
}

-- Order slots are granted (matches fusionSlots stacking). One step per slot capacity.
function CollectionMath.boardUnlockLadder(): { BoardUnlockStep }
	local ladder: { BoardUnlockStep } = {
		{
			Id = "Start",
			Kind = "Start",
			Name = "Starter slot",
			Summary = "Your first fused relic occupies this slot.",
			GoalId = nil,
		},
	}
	for _, goal in CollectionConfig.MutationGoals do
		local bonus = goal.SlotBonus
		if type(bonus) == "number" and bonus > 0 then
			for _ = 1, bonus do
				table.insert(ladder, {
					Id = goal.Id,
					Kind = "Goal",
					Name = goal.Name,
					Summary = goal.Summary or "Unlocks a fusion board slot.",
					GoalId = goal.Id,
				})
			end
		end
	end
	table.insert(ladder, {
		Id = "Rebirth1",
		Kind = "Rebirth",
		Name = "First Rebirth",
		Summary = "Rebirth once to open another fusion board slot.",
		GoalId = nil,
	})
	return ladder
end

-- UI view of every board slot up to MaxFusionSlots (occupied filled by caller).
function CollectionMath.boardSlotMeta(
	state: CollectionState,
	rebirths: number,
	goalProgress: { { Id: string, Progress: number, Required: number, Name: string?, Summary: string? } }?
): {
	{
		Index: number,
		Unlocked: boolean,
		UnlockId: string,
		UnlockKind: string,
		UnlockName: string,
		UnlockSummary: string,
		Progress: number?,
		Required: number?,
	}
}
	local ladder = CollectionMath.boardUnlockLadder()
	local unlocked = CollectionMath.fusionSlots(state, rebirths)
	local maxSlots = CollectionConfig.MaxFusionSlots or 5
	local progressById: { [string]: { Progress: number, Required: number } } = {}
	if goalProgress then
		for _, g in goalProgress do
			if type(g.Id) == "string" then
				progressById[g.Id] = { Progress = g.Progress or 0, Required = g.Required or 1 }
			end
		end
	end
	-- Also pull from MutationGoals + claimed for progress display on locked slots.
	local out = {}
	for i = 1, maxSlots do
		local step = ladder[i]
		if not step then
			break
		end
		local isUnlocked = i <= unlocked
		local prog: number? = nil
		local req: number? = nil
		if not isUnlocked then
			if step.Kind == "Rebirth" then
				prog = if rebirths >= 1 then 1 else 0
				req = 1
			elseif step.Kind == "Goal" and step.GoalId then
				local row = progressById[step.GoalId]
				if row then
					prog, req = row.Progress, row.Required
				else
					prog, req = 0, 1
				end
			elseif step.Kind == "Start" then
				prog, req = 1, 1
			end
		end
		table.insert(out, {
			Index = i,
			Unlocked = isUnlocked,
			UnlockId = step.Id,
			UnlockKind = step.Kind,
			UnlockName = step.Name,
			UnlockSummary = step.Summary,
			Progress = prog,
			Required = req,
		})
	end
	return out
end

function CollectionMath.hasUnlockFlag(state: CollectionState, unlockId: string): boolean
	for _, goal in CollectionConfig.MutationGoals do
		if goal.Unlock == unlockId and state.MutationGoalsClaimed[goal.Id] then
			return true
		end
	end
	for resonanceId, stacks in state.ResonanceStacks do
		for _, id in CollectionMath.resonanceUnlocked(resonanceId, stacks) do
			if id == unlockId then
				return true
			end
		end
	end
	return false
end

export type FuseBlockKind = "Max" | "Board" | "Catalyst" | "Copies" | "Mutation" | "Essence" | "Ok"

-- Server eligibility. Rank upgrades (CurrentRank > 0) never consume a new board slot.
-- Returns ok, player-facing reason, machine-readable block kind.
function CollectionMath.canFuse(options: {
	TierId: string,
	RelicId: string?,
	RelicName: string?,
	CurrentRank: number,
	OwnedCopies: number,
	Essence: number,
	State: CollectionState?,
	Rebirths: number?,
	HasMutatedCopy: boolean?,
	EpicCatalystReady: boolean?,
}): (boolean, string, FuseBlockKind)
	local nextRank = options.CurrentRank + 1
	local name = options.RelicName or "this relic"
	if options.CurrentRank >= CollectionConfig.MaxFusionRank then
		return false, "Already at max fusion rank.", "Max"
	end
	local state = options.State
	-- Only *new* board entries need a free slot. Upgrading an occupied slot is always in-place.
	if state and options.CurrentRank <= 0 then
		local slots = CollectionMath.fusionSlots(state, options.Rebirths)
		if CollectionMath.fusedCount(state) >= slots then
			return false, `Board full — unlock another slot before fusing a new relic.`, "Board"
		end
	end
	if options.TierId == "Epic" or (TIER_ORDER[options.TierId] or 0) >= 4 then
		-- Epic+ first fuse needs a catalyst for that relic (or prior fusion entry).
		if options.CurrentRank <= 0 and not options.EpicCatalystReady then
			return false, "Craft an Epic Catalyst for this relic first.", "Catalyst"
		end
	end
	local need = CollectionMath.copiesForRank(nextRank)
	if options.OwnedCopies < need then
		local missing = need - options.OwnedCopies
		return false, `Need {missing} more {name} (have {options.OwnedCopies}/{need}).`, "Copies"
	end
	if nextRank >= 3 and CollectionConfig.Rank3NeedsMutation and not options.HasMutatedCopy then
		return false, `Missing mutated {name}.`, "Mutation"
	end
	local cost = CollectionMath.fusionEssenceCost(options.TierId, nextRank)
	if options.Essence < cost then
		return false, `Need {cost} Essence (have {math.floor(options.Essence)}).`, "Essence"
	end
	return true, "", "Ok"
end

-- How many copies auto-sell / Sell-all must leave for fusion progress.
-- softPinRelicId: optional single Common/Uncommon the player is closest to first-fusing
-- (chosen by CollectionService when the board still has a free slot).
--
-- Priority:
--   1) Board entry with 0 < Rank < Max → copiesForRank(next) (Rank1→2 needs 5).
--      Before FusionPins/favorites so auto-pin after fuse cannot short-circuit to 3.
--   2) Max-rank Board entries → 0 (no next recipe).
--   3) Favorites / manual FusionPins → FusionReserveCopies (3).
--   4) Pre-fuse soft-pin → copiesForRank(1) (= 3 with current recipe).
-- Retired/unpinned relics with no Board entry fall through to 0.
function CollectionMath.reserveCopies(
	relicId: string,
	state: CollectionState,
	isFavorite: boolean,
	softPinRelicId: string?
): number
	local entry = state.Fusion[relicId]
	local rank = if entry then (entry.Rank or 0) else 0
	local maxRank = CollectionConfig.MaxFusionRank
	if rank > 0 and rank < maxRank then
		-- Board mid-rank: protect the actual next-rank recipe (not flat pin size).
		return CollectionMath.copiesForRank(rank + 1)
	end
	if rank >= maxRank then
		-- Already maxed — no next-rank stockpile.
		return 0
	end
	-- Pre-fusion: favorites and manual pins use the flat reserve size.
	if isFavorite then
		return CollectionConfig.FusionReserveCopies
	end
	if state.FusionPins[relicId] then
		return CollectionConfig.FusionReserveCopies
	end
	if softPinRelicId and softPinRelicId == relicId then
		return CollectionMath.copiesForRank(1)
	end
	return 0
end

function CollectionMath.wouldBreachReserve(
	relicId: string,
	ownedCopies: number,
	state: CollectionState,
	isFavorite: boolean,
	softPinRelicId: string?
): boolean
	local reserve = CollectionMath.reserveCopies(relicId, state, isFavorite, softPinRelicId)
	if reserve <= 0 then
		return false
	end
	return ownedCopies <= reserve
end

-- True when the next fuse on this Board entry requires a mutated copy (Rank 2→3).
function CollectionMath.needsMutatedCopyForNextRank(currentRank: number): boolean
	local nextRank = math.floor(currentRank) + 1
	local maxRank = CollectionConfig.MaxFusionRank or 3
	if nextRank < 3 or nextRank > maxRank then
		return false
	end
	return CollectionConfig.Rank3NeedsMutation == true
end

-- How many mutated copies AutoSell/Sell-all must leave (0 or 1).
function CollectionMath.mutatedCopiesToReserve(state: CollectionState, relicId: string): number
	local entry = state.Fusion[relicId]
	if not entry or (entry.Rank or 0) <= 0 then
		return 0
	end
	if not CollectionMath.needsMutatedCopyForNextRank(entry.Rank) then
		return 0
	end
	return 1
end

-- Board Rank-2 relics that still need Rank 3 (mutation recipe).
function CollectionMath.boardFocusCandidates(state: CollectionState): { string }
	local out = {}
	for relicId, entry in state.Fusion do
		local rank = entry.Rank or 0
		if rank > 0 and CollectionMath.needsMutatedCopyForNextRank(rank) then
			table.insert(out, relicId)
		end
	end
	table.sort(out)
	return out
end

function CollectionMath.resolveBoardFocusId(state: CollectionState): string?
	local focus = state.BoardFocusId
	if type(focus) == "string" and focus ~= "" then
		local entry = state.Fusion[focus]
		if entry and CollectionMath.needsMutatedCopyForNextRank(entry.Rank or 0) then
			return focus
		end
	end
	local candidates = CollectionMath.boardFocusCandidates(state)
	if #candidates == 1 then
		return candidates[1]
	end
	if #candidates > 1 then
		for _, id in candidates do
			if state.FusionPins[id] then
				return id
			end
		end
		return candidates[1]
	end
	return nil
end

-- After First Bloodmoon: soft-pin one Epic toward Catalyst craft (3 base copies).
-- Without this, AutoSell dumps every Epic dupe and EpicLineage / Ascend-to-Epic never start.
function CollectionMath.epicCatalystSoftPin(
	state: CollectionState,
	ownedById: { [string]: number },
	tierById: { [string]: string }
): string?
	if not CollectionMath.hasUnlockFlag(state, "EpicSalvageBoost") then
		return nil
	end
	local need = (CollectionConfig.EpicCatalyst and CollectionConfig.EpicCatalyst.Copies) or 3
	local bestId: string? = nil
	local bestScore = -1
	for relicId, owned in ownedById do
		if owned <= 0 then
			continue
		end
		if tierById[relicId] ~= "Epic" then
			continue
		end
		if state.EpicCatalysts and state.EpicCatalysts[relicId] then
			continue
		end
		local entry = state.Fusion[relicId]
		if entry and (entry.Rank or 0) > 0 then
			continue
		end
		local score = math.min(owned, need)
		if score > bestScore then
			bestScore = score
			bestId = relicId
		end
	end
	return bestId
end

-- Pick one stockpile target for AutoSell / Sell-all.
-- ownedById: relicId → base copy count. Returns nil when nothing should be reserved.
function CollectionMath.softPinTarget(
	state: CollectionState,
	ownedById: { [string]: number },
	tierById: { [string]: string },
	rebirths: number
): string?
	local slots = CollectionMath.fusionSlots(state, rebirths)
	local fused = CollectionMath.fusedCount(state)
	local liftCap = CollectionConfig.FusionIncomeMultByRank[3] or 1.5
	local liftCapped = CollectionMath.boardIncomeMult(state) + 1e-9 >= liftCap

	local function ascendPin(preferTier: string?): string?
		if fused < slots or not liftCapped then
			return nil
		end
		local meta: { [string]: { Tier: string, Name: string, Family: string? } } = {}
		for relicId, tier in tierById do
			meta[relicId] = { Tier = tier, Name = relicId, Family = nil }
		end
		for relicId in state.Fusion do
			if not meta[relicId] and tierById[relicId] then
				meta[relicId] = { Tier = tierById[relicId], Name = relicId, Family = nil }
			end
		end
		local workshop = CollectionMath.hasUnlockFlag(state, "WorkshopCharmGlobal")
		local hint = CollectionMath.bestAscendHint(state, ownedById, meta, workshop, preferTier)
		return if hint then hint.TargetRelicId else nil
	end

	-- SoftCap_P4 Phase 7.1 EpicLineage: Ascend-to-Epic (needs catalyst) → Catalyst stock → Common fill.
	if state.ActivePursuit == "EpicLineage" then
		if fused >= slots and liftCapped then
			local meta: { [string]: { Tier: string, Name: string, Family: string? } } = {}
			for relicId, tier in tierById do
				meta[relicId] = { Tier = tier, Name = relicId, Family = nil }
			end
			for relicId in state.Fusion do
				if not meta[relicId] and tierById[relicId] then
					meta[relicId] = { Tier = tierById[relicId], Name = relicId, Family = nil }
				end
			end
			local hint = CollectionMath.bestAscendHint(
				state,
				ownedById,
				meta,
				CollectionMath.hasUnlockFlag(state, "WorkshopCharmGlobal"),
				"Epic"
			)
			if hint and hint.TargetTier == "Epic" then
				return hint.TargetRelicId
			end
		end
		local epicPin = CollectionMath.epicCatalystSoftPin(state, ownedById, tierById)
		if epicPin then
			return epicPin
		end
	end

	-- SoftCap_P4 Phase 7: Board full + Lift capped → reserve Ascend lineage stockpile.
	local ascend = ascendPin(nil)
	if ascend then
		return ascend
	end
	if fused >= slots then
		-- Board full but Lift not capped (or no Ascend target): protect Epic Catalyst progress.
		return CollectionMath.epicCatalystSoftPin(state, ownedById, tierById)
	end
	local need = CollectionMath.copiesForRank(1)
	local bestId: string? = nil
	local bestOwned = 0
	for relicId, owned in ownedById do
		if owned <= 0 then
			continue
		end
		local entry = state.Fusion[relicId]
		if entry and entry.Rank > 0 then
			continue
		end
		local tier = tierById[relicId]
		if tier ~= "Common" and tier ~= "Uncommon" then
			continue
		end
		-- Prefer closest to ready (cap score at `need` so ready recipes stay protected).
		local score = math.min(owned, need)
		if score > bestOwned then
			bestOwned = score
			bestId = relicId
		end
	end
	if bestId then
		return bestId
	end
	return CollectionMath.epicCatalystSoftPin(state, ownedById, tierById)
end

function CollectionMath.resonanceUnlocked(resonanceId: string, stacks: number): { string }
	local row = CollectionConfig.Resonances[resonanceId]
	if not row then
		return {}
	end
	local out = {}
	for _, unlock in row.Unlocks or {} do
		if stacks >= unlock.Stacks then
			table.insert(out, unlock.Id)
		end
	end
	return out
end

function CollectionMath.binderHoldBonus(stacks: number): number
	local row = CollectionConfig.Resonances.Binder
	return (row.HoldSecondsPerStack or 0) * math.max(0, stacks)
end

function CollectionMath.seekerSightBonus(stacks: number): number
	local row = CollectionConfig.Resonances.Seeker
	return (row.SightRangePerStack or 0) * math.max(0, stacks)
end

function CollectionMath.huntFamilyBonus(charmId: string?, corruptedBonus: boolean?, tierId: string?): number
	if charmId ~= "Hunt" then
		return 0
	end
	local bonus = (CollectionConfig.Charms.Hunt.HuntFamilyWeightBonus or 0) * CollectionMath.charmPotency(tierId)
	if corruptedBonus then
		bonus += 0.10
	end
	return bonus
end

-- SoftCap: hunt-only SoftCap bias toward one exact relic (not AFK).
-- Always eligible when SoftCap Collection is on (service gate). Pre-Board uses soft-pin
-- first-fuse chase; post-Board uses recipe / Codex / Ascend targets.
function CollectionMath.huntQuarryEligible(_state: CollectionState): boolean
	return true
end

function CollectionMath.huntQuarryMult(): number
	return CollectionConfig.HuntQuarryMult or 7
end

export type QuarryNeed = {
	Kind: "Mutation" | "Catalyst" | "FuseCopies" | "Ascend" | "Discover" | "MutCodex" | "None",
	Useful: boolean,
	Missing: number,
	Detail: string,
}

-- Is hunting this relic still useful — not just another Essence dupe?
function CollectionMath.quarryNeed(options: {
	State: CollectionState,
	RelicId: string,
	TierId: string?,
	OwnedBase: number,
	OwnedMutated: number,
	AscendTargetId: string?,
	AscendMissing: number?,
	Discovered: boolean?,
	CodexMutCount: number?,
}): QuarryNeed
	local state = options.State
	local relicId = options.RelicId
	local owned = math.max(0, math.floor(options.OwnedBase))
	local mutOwned = math.max(0, math.floor(options.OwnedMutated))
	local tier = options.TierId or ""
	local entry = state.Fusion[relicId]
	local rank = if entry then (entry.Rank or 0) else 0

	-- Undiscovered: first find advances Codex (persists across Rebirths).
	if options.Discovered == false then
		return {
			Kind = "Discover",
			Useful = true,
			Missing = 1,
			Detail = "Undiscovered — first find advances Codex",
		}
	end

	-- Rank 2→3: mutated copy is the scarce objective.
	if rank > 0 and CollectionMath.needsMutatedCopyForNextRank(rank) and mutOwned <= 0 then
		return {
			Kind = "Mutation",
			Useful = true,
			Missing = 1,
			Detail = "Need a mutated copy for Rank 3",
		}
	end

	-- Board relic never seen mutated in Codex → Mutation Goals / Ledger progress.
	local codexMuts = options.CodexMutCount
	if rank > 0 and type(codexMuts) == "number" and codexMuts <= 0 then
		return {
			Kind = "MutCodex",
			Useful = true,
			Missing = 1,
			Detail = "First mutated form — Mutation Goals / Codex",
		}
	end

	-- Epic catalyst craft (before first Board fuse of this id).
	local epicTier = CollectionMath.tierRank(tier) >= (CollectionMath.tierRank("Epic"))
	if epicTier and rank <= 0 and not (state.EpicCatalysts and state.EpicCatalysts[relicId]) then
		local need = (CollectionConfig.EpicCatalyst and CollectionConfig.EpicCatalyst.Copies) or 2
		local missing = math.max(0, need - owned)
		if missing > 0 then
			return {
				Kind = "Catalyst",
				Useful = true,
				Missing = missing,
				Detail = `Need {missing} more for Epic Catalyst ({owned}/{need})`,
			}
		end
		return {
			Kind = "Catalyst",
			Useful = true,
			Missing = 0,
			Detail = "Ready to craft Epic Catalyst",
		}
	end

	-- Mid-rank Board upgrade copies.
	if rank > 0 and rank < (CollectionConfig.MaxFusionRank or 3) then
		local need = CollectionMath.copiesForRank(rank + 1)
		local missing = math.max(0, need - owned)
		if missing > 0 then
			return {
				Kind = "FuseCopies",
				Useful = true,
				Missing = missing,
				Detail = `Need {missing} more for Rank {rank + 1} ({owned}/{need})`,
			}
		end
	end

	-- First fuse / Ascend stockpile (exact Ascend target or pre-Board recipe).
	local ascendMissing = options.AscendMissing or 0
	if options.AscendTargetId == relicId and ascendMissing > 0 then
		return {
			Kind = "Ascend",
			Useful = true,
			Missing = ascendMissing,
			Detail = `Need {ascendMissing} more to Ascend Charm lineage`,
		}
	end
	if options.AscendTargetId == relicId and ascendMissing <= 0 and owned >= CollectionMath.copiesForRank(1) then
		return {
			Kind = "Ascend",
			Useful = true,
			Missing = 0,
			Detail = "Ready to Ascend Charm lineage (Retire → Fuse)",
		}
	end
	if rank <= 0 then
		local need = CollectionMath.copiesForRank(1)
		if epicTier and state.EpicCatalysts and state.EpicCatalysts[relicId] then
			local missing = math.max(0, need - owned)
			if missing > 0 then
				return {
					Kind = "FuseCopies",
					Useful = true,
					Missing = missing,
					Detail = `Need {missing} more to fuse Epic ({owned}/{need})`,
				}
			end
		elseif not epicTier then
			local missing = math.max(0, need - owned)
			-- Soft-pin / first-fuse: useful from 0 copies (Hunt can start the stockpile).
			if missing > 0 then
				return {
					Kind = "FuseCopies",
					Useful = true,
					Missing = missing,
					Detail = `Need {missing} more to fuse ({owned}/{need})`,
				}
			end
		end
	end

	return {
		Kind = "None",
		Useful = false,
		Missing = 0,
		Detail = "Quarry dupe — Essence / keep only (no Board recipe waiting)",
	}
end

-- Post-Epic: pick a useful chase when the player's quarry is done (Codex / mut / Ascend / catalyst).
function CollectionMath.suggestHuntQuarry(options: {
	State: CollectionState,
	OwnedBase: { [string]: number },
	OwnedMutated: { [string]: number },
	Discovered: { [string]: boolean },
	CodexMutCounts: { [string]: number },
	RelicMeta: { [string]: { Tier: string, Name: string, Family: string? } },
	AscendTargetId: string?,
	AscendMissing: number?,
	HuntFamily: string?,
	SoftPinId: string?,
}): string?
	local state = options.State
	if not CollectionMath.huntQuarryEligible(state) then
		return nil
	end

	local function needFor(relicId: string): QuarryNeed
		local meta = options.RelicMeta[relicId]
		return CollectionMath.quarryNeed({
			State = state,
			RelicId = relicId,
			TierId = if meta then meta.Tier else nil,
			OwnedBase = options.OwnedBase[relicId] or 0,
			OwnedMutated = options.OwnedMutated[relicId] or 0,
			AscendTargetId = options.AscendTargetId,
			AscendMissing = options.AscendMissing,
			Discovered = options.Discovered[relicId] == true,
			CodexMutCount = options.CodexMutCounts[relicId] or 0,
		})
	end

	local function score(relicId: string): number
		local need = needFor(relicId)
		if not need.Useful then
			return -1e9
		end
		local meta = options.RelicMeta[relicId]
		local tierR = CollectionMath.tierRank(if meta then meta.Tier else nil)
		local s = 0
		if need.Kind == "Ascend" then
			s = 500 + (if need.Missing == 0 then 40 else 20)
		elseif need.Kind == "Mutation" then
			s = 480
		elseif need.Kind == "Catalyst" then
			s = 450 + math.min(options.OwnedBase[relicId] or 0, 3) * 10
		elseif need.Kind == "FuseCopies" then
			s = 400
		elseif need.Kind == "MutCodex" then
			s = 360 + tierR * 5
		elseif need.Kind == "Discover" then
			s = 300 + tierR * 15
			if options.HuntFamily and meta and meta.Family == options.HuntFamily then
				s += 40
			end
		end
		s += math.min(options.OwnedBase[relicId] or 0, 5)
		-- Early game: soft-pin Common beats rare Discover / Codex chases.
		if options.SoftPinId == relicId then
			s += 120
			if tierR <= 1 then
				s += 40
			end
		elseif tierR <= 1 and need.Kind == "FuseCopies" then
			s += 50
		end
		return s
	end

	local bestId: string? = nil
	local bestScore = -1e9

	-- Prefer explicit Ascend target when stocked / incomplete.
	if options.AscendTargetId then
		local s = score(options.AscendTargetId)
		if s > bestScore then
			bestScore = s
			bestId = options.AscendTargetId
		end
	end

	for relicId in options.RelicMeta do
		local s = score(relicId)
		if s > bestScore then
			bestScore = s
			bestId = relicId
		end
	end

	if bestId then
		return bestId
	end
	if type(options.SoftPinId) == "string" and options.SoftPinId ~= "" then
		return options.SoftPinId
	end
	return nil
end

-- Active SoftCap quarry id: keep player choice while useful, else suggested useful chase.
function CollectionMath.resolveHuntQuarryId(
	state: CollectionState,
	softPinRelicId: string?,
	suggestedId: string?,
	chosenUseful: boolean?
): string?
	if not CollectionMath.huntQuarryEligible(state) then
		return nil
	end
	local chosen = state.HuntQuarryId
	if type(chosen) == "string" and chosen ~= "" then
		if chosenUseful == true then
			return chosen
		end
		-- Choice exhausted — steer binds at the next useful objective (UI still shows both).
		if type(suggestedId) == "string" and suggestedId ~= "" then
			return suggestedId
		end
		return chosen
	end
	if type(suggestedId) == "string" and suggestedId ~= "" then
		return suggestedId
	end
	if type(softPinRelicId) == "string" and softPinRelicId ~= "" then
		return softPinRelicId
	end
	return nil
end

-- Did this quarry capture actually advance the objective (not a Ready-state or Essence-only dupe)?
-- Mut kinds need a mutated hit; stockpile kinds need Missing > 0; Ready prompts are UI-only.
function CollectionMath.quarryCaptureAdvances(need: QuarryNeed, hasMutationHit: boolean): boolean
	if not need.Useful then
		return false
	end
	if need.Kind == "Mutation" or need.Kind == "MutCodex" then
		return hasMutationHit == true
	end
	if need.Kind == "Discover" then
		return true
	end
	-- Catalyst / FuseCopies / Ascend: only stockpile hits while still short.
	return (need.Missing or 0) > 0
end

function CollectionMath.huntQuarryRetargetReady(state: CollectionState, now: number): (boolean, number)
	local cd = CollectionConfig.HuntQuarryRetargetSeconds or 3
	local setAt = state.HuntQuarrySetAt
	if type(setAt) ~= "number" or setAt <= 0 then
		return true, 0
	end
	local left = math.max(0, cd - (now - setAt))
	return left <= 1e-9, left
end

local TIER_RANK = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Celestial = 7,
	Cosmic = 8,
}

function CollectionMath.tierRank(tierId: string?): number
	return TIER_RANK[tierId or ""] or 0
end

export type AscendHint = {
	Charm: string,
	CurrentRelicId: string,
	CurrentName: string,
	CurrentTier: string,
	CurrentPotency: number,
	TargetRelicId: string,
	TargetName: string,
	TargetTier: string,
	TargetPotency: number,
	Owned: number,
	Need: number,
	Missing: number,
	EssenceCost: number,
	RetireCost: number,
	Ready: boolean,
}

-- Post-×1.50: best Retire→Fuse upgrade that raises a Board Charm's tier potency.
-- ownedBaseCounts: relicId → non-mutated copy count (server/sim).
-- relicMeta: relicId → { Tier, Name } (or use RelicConfig in callers — kept pure via args).
function CollectionMath.bestAscendHint(
	state: CollectionState,
	ownedBaseCounts: { [string]: number },
	relicMeta: { [string]: { Tier: string, Name: string, Family: string? } },
	workshopUnlocked: boolean?,
	preferTier: string?
): AscendHint?
	if CollectionMath.boardIncomeMult(state) + 1e-9 < (CollectionConfig.FusionIncomeMultByRank[3] or 1.5) then
		return nil
	end
	local retireCost = CollectionConfig.BoardRetireEssence or 80
	local bestRank = 0
	local bestRankHolders = 0
	for _, entry in state.Fusion do
		local r = entry.Rank or 0
		if r > bestRank then
			bestRank = r
			bestRankHolders = 1
		elseif r == bestRank and r > 0 then
			bestRankHolders += 1
		end
	end
	local best: AscendHint? = nil
	local bestScore = -1e9
	for charmId, _ in CollectionConfig.Charms do
		if charmId == "Workshop" and not workshopUnlocked then
			continue
		end
		local ownerId = CollectionMath.boardCharmOwner(state, charmId)
		if not ownerId then
			continue
		end
		local ownerEntry = state.Fusion[ownerId]
		-- Never Retire the sole Lift source (would drop Board income below ×1.50).
		if ownerEntry and (ownerEntry.Rank or 0) >= bestRank and bestRankHolders <= 1 then
			continue
		end
		local ownerMeta = relicMeta[ownerId]
		if not ownerMeta then
			continue
		end
		local curPot = CollectionMath.charmPotency(ownerMeta.Tier)
		for targetId, meta in relicMeta do
			if state.Fusion[targetId] then
				continue
			end
			if CollectionMath.tierRank(meta.Tier) <= CollectionMath.tierRank(ownerMeta.Tier) then
				continue
			end
			-- Epic+ first fuse needs a catalyst (same gate as canFuse).
			if CollectionMath.tierRank(meta.Tier) >= (TIER_RANK.Epic or 4) then
				if not state.EpicCatalysts or not state.EpicCatalysts[targetId] then
					continue
				end
			end
			local need = CollectionMath.copiesForRank(1)
			local owned = ownedBaseCounts[targetId] or 0
			local cost = CollectionMath.fusionEssenceCost(meta.Tier, 1)
			local nextPot = CollectionMath.charmPotency(meta.Tier)
			local ready = owned >= need and state.Essence + 1e-9 >= (retireCost + cost)
			local score = (nextPot - curPot) * 100 + CollectionMath.tierRank(meta.Tier) * 10
			if charmId == "Hunt" then
				score += 15
				-- Prefer keeping the hunt family; switching families is allowed but scored lower.
				if ownerMeta.Family and meta.Family and meta.Family == ownerMeta.Family then
					score += 25
				end
			elseif charmId == "Workshop" then
				-- Prefer denser tiers: Rare Workshop loses to drop rate at low luck (see phase7AscendValue).
				score += 8
				local essSale = CollectionMath.essenceFromSale(meta.Tier, nil, true, meta.Tier)
				local denseness = ({ Common = 5, Uncommon = 4, Rare = 2, Epic = 1 })[meta.Tier] or 1
				score += essSale * denseness
			end
			if ready then
				score += 40
			end
			score += math.min(owned, need) * 3
			if preferTier and meta.Tier == preferTier then
				score += 55
			end
			if score > bestScore then
				bestScore = score
				best = {
					Charm = charmId,
					CurrentRelicId = ownerId,
					CurrentName = ownerMeta.Name,
					CurrentTier = ownerMeta.Tier,
					CurrentPotency = curPot,
					TargetRelicId = targetId,
					TargetName = meta.Name,
					TargetTier = meta.Tier,
					TargetPotency = nextPot,
					Owned = owned,
					Need = need,
					Missing = math.max(0, need - owned),
					EssenceCost = cost,
					RetireCost = retireCost,
					Ready = ready,
				}
			end
		end
	end
	return best
end

-- SoftCap_P4 Board specialization: which relic already holds this Charm (nil if free).
function CollectionMath.boardCharmOwner(state: CollectionState, charmId: string): string?
	for relicId, entry in state.Fusion do
		if entry.Charm == charmId then
			return relicId
		end
	end
	return nil
end

-- Hunt / Workshop stacking is pure power; uniqueness forces Hunt vs Workshop vs Shrine roles.
function CollectionMath.canAssignBoardCharm(state: CollectionState, charmId: string, relicId: string): (boolean, string?)
	local owner = CollectionMath.boardCharmOwner(state, charmId)
	if owner and owner ~= relicId then
		return false, owner
	end
	return true, nil
end

-- Next unset Charm for a new Board entry (Hunt → Workshop if unlocked → Shrine).
function CollectionMath.suggestBoardCharm(state: CollectionState, workshopUnlocked: boolean): string
	if not CollectionMath.boardCharmOwner(state, "Hunt") then
		return "Hunt"
	end
	if workshopUnlocked and not CollectionMath.boardCharmOwner(state, "Workshop") then
		return "Workshop"
	end
	if not CollectionMath.boardCharmOwner(state, "Shrine") then
		return "Shrine"
	end
	-- All taken (shouldn't happen with 3 slots); fall back to Hunt.
	return "Hunt"
end

function CollectionMath.sanitize(raw: any): CollectionState
	local base = CollectionMath.defaults()
	if type(raw) ~= "table" then
		return base
	end
	base.Essence = if type(raw.Essence) == "number" and raw.Essence == raw.Essence and raw.Essence >= 0
		then math.floor(raw.Essence)
		else 0
	base.PendingResonance = raw.PendingResonance == true
	base.AttuneCharges = if type(raw.AttuneCharges) == "number" and raw.AttuneCharges >= 0
		then math.floor(raw.AttuneCharges)
		else 0
	base.AttuneScansLeft = if type(raw.AttuneScansLeft) == "number" and raw.AttuneScansLeft >= 0
		then math.floor(raw.AttuneScansLeft)
		else 0
	base.AttuneChargeCap = if type(raw.AttuneChargeCap) == "number" and raw.AttuneChargeCap >= 1
		then math.clamp(math.floor(raw.AttuneChargeCap), 1, CollectionConfig.MaxAttuneChargesHardCap or 8)
		else CollectionConfig.MaxAttuneCharges
	base.LastDailyAttuneDay = if type(raw.LastDailyAttuneDay) == "number" then math.floor(raw.LastDailyAttuneDay) else 0
	base.QuickBindReadyAt = if type(raw.QuickBindReadyAt) == "number" then raw.QuickBindReadyAt else 0
	base.FreeSignalAt = if type(raw.FreeSignalAt) == "number" then raw.FreeSignalAt else 0
	if type(raw.TargetedAttuneTier) == "string" then
		base.TargetedAttuneTier = raw.TargetedAttuneTier
	end
	if type(raw.FamilyAttune) == "string" then
		base.FamilyAttune = raw.FamilyAttune
	end
	base.MutationFocusScansLeft = if type(raw.MutationFocusScansLeft) == "number" and raw.MutationFocusScansLeft >= 0
		then math.floor(raw.MutationFocusScansLeft)
		else 0
	if type(raw.ActivePursuit) == "string" and CollectionMath.pursuitConfig(raw.ActivePursuit) then
		base.ActivePursuit = raw.ActivePursuit
	else
		base.ActivePursuit = nil
	end
	if type(raw.PursuitMutSeen) == "table" then
		for id, on in raw.PursuitMutSeen do
			if type(id) == "string" and on then
				base.PursuitMutSeen[id] = true
			end
		end
	end
	if type(raw.HuntQuarryId) == "string" and raw.HuntQuarryId ~= "" then
		base.HuntQuarryId = raw.HuntQuarryId
	else
		base.HuntQuarryId = nil
	end
	base.HuntQuarrySetAt = if type(raw.HuntQuarrySetAt) == "number" and raw.HuntQuarrySetAt > 0
		then raw.HuntQuarrySetAt
		else nil
	if type(raw.FusionPins) == "table" then
		for id, on in raw.FusionPins do
			if type(id) == "string" and on then
				base.FusionPins[id] = true
			end
		end
	end
	if type(raw.BoardFocusId) == "string" and raw.BoardFocusId ~= "" then
		base.BoardFocusId = raw.BoardFocusId
	else
		base.BoardFocusId = nil
	end
	if type(raw.EpicCatalysts) == "table" then
		for id, on in raw.EpicCatalysts do
			if type(id) == "string" and on then
				base.EpicCatalysts[id] = true
			end
		end
	end
	if type(raw.Fusion) == "table" then
		for id, entry in raw.Fusion do
			if type(id) == "string" and type(entry) == "table" then
				local rank = tonumber(entry.Rank) or 0
				rank = math.clamp(math.floor(rank), 0, CollectionConfig.MaxFusionRank)
				local charm = entry.Charm
				if charm ~= "Hunt" and charm ~= "Workshop" and charm ~= "Shrine" then
					charm = nil
				end
				if rank > 0 then
					base.Fusion[id] = { Rank = rank, Charm = charm }
				end
			end
		end
	end
	if type(raw.ResonanceStacks) == "table" then
		for _, id in { "Collector", "Binder", "Seeker" } do
			local n = tonumber(raw.ResonanceStacks[id]) or 0
			base.ResonanceStacks[id] = math.max(0, math.floor(n))
		end
	end
	if type(raw.MutationGoalsClaimed) == "table" then
		for id, at in raw.MutationGoalsClaimed do
			if type(id) == "string" and type(at) == "number" then
				base.MutationGoalsClaimed[id] = at
			end
		end
	end
	return base
end

-- Progress helpers for UI / sim: what the player should chase next.
export type GoalProgress = {
	Id: string,
	Name: string,
	Summary: string,
	Progress: number,
	Required: number,
	Claimed: boolean,
	Unlock: string?,
}

function CollectionMath.goalProgress(
	state: CollectionState,
	counts: {
		UniqueMutated: number,
		ByMutation: { [string]: number },
		EpicCatalysts: number,
	}
): { GoalProgress }
	local out = {}
	for _, goal in CollectionConfig.MutationGoals do
		local required = goal.UniqueRequired or goal.EpicCatalystsRequired or 1
		local progress = 0
		if goal.EpicCatalystsRequired then
			progress = counts.EpicCatalysts
		elseif goal.AnyMutation then
			progress = counts.UniqueMutated
		elseif goal.MutationId then
			progress = counts.ByMutation[goal.MutationId] or 0
		end
		table.insert(out, {
			Id = goal.Id,
			Name = goal.Name,
			Summary = goal.Summary or "",
			Progress = progress,
			Required = required,
			Claimed = state.MutationGoalsClaimed[goal.Id] ~= nil,
			Unlock = goal.Unlock,
		})
	end
	return out
end

function CollectionMath.nextUnclaimedGoals(
	state: CollectionState,
	counts: {
		UniqueMutated: number,
		ByMutation: { [string]: number },
		EpicCatalysts: number,
	},
	limit: number?
): { GoalProgress }
	local lim = limit or 3
	local nextGoals = {}
	for _, row in CollectionMath.goalProgress(state, counts) do
		if not row.Claimed then
			table.insert(nextGoals, row)
			if #nextGoals >= lim then
				break
			end
		end
	end
	return nextGoals
end

return CollectionMath

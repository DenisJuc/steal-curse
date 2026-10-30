-- Phase 2 collection prototype. Active only when BalanceTrials.collectionEnabled().
-- Remotes: CollectionAction (Get / Fuse / SetCharm / Pin / ChooseResonance / ClaimGoal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoSell = require(ReplicatedStorage.Shared.AutoSell)
local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
local CollectionConfig = require(ReplicatedStorage.Shared.CollectionConfig)
local CollectionMath = require(ReplicatedStorage.Shared.CollectionMath)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local ProgressObjective = require(ReplicatedStorage.Shared.ProgressObjective)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local GameEvents = require(script.Parent.GameEvents)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CollectionAction = Remotes:FindFirstChild("CollectionAction") :: RemoteFunction?
if not CollectionAction then
	CollectionAction = Instance.new("RemoteFunction")
	CollectionAction.Name = "CollectionAction"
	CollectionAction.Parent = Remotes
end
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local CollectionService = {}

local function enabled(): boolean
	return BalanceTrials.collectionEnabled()
end

-- How many CE shop buys (skills + pedestal levels/slots) the player can afford right now.
local function affordableShopBuys(player: Player, data: any): number
	local buys = 0
	local budget = data.CE or 0
	local rebirths = data.Rebirths or 0
	for _, node in SkillConfig.Nodes do
		if not BalanceTrials.skillNodeEnabled(node.Id) then
			continue
		end
		local rank = data.Skills[node.Id] or 0
		local cap = if node.Id == "CoreLuck"
			then BalanceTrials.coreLuckMaxRank(rebirths)
			elseif node.Id == "PedestalMastery"
			then BalanceTrials.pedestalMasteryMaxRank(rebirths)
			else node.MaxRank
		if rank >= cap then
			continue
		end
		local override = if node.Id == "CoreLuck" then BalanceTrials.coreLuckCostOverride() else nil
		local n = SkillConfig.affordable(node, rank, budget, 1, override)
		if n > 0 then
			buys += 1
		end
	end
	local eco = Config.Economy
	for _, pedestal in data.Pedestals do
		local level = pedestal.Level or 1
		if level < eco.PedestalMaxLevel then
			local cost = Economy.upgradeCost(eco, level)
			if cost and budget + 1e-9 >= cost then
				buys += 1
			end
		end
	end
	local slot = #data.Pedestals + 1
	local slotPrice = eco.SlotPrices and eco.SlotPrices[slot]
	if type(slotPrice) == "number" and budget + 1e-9 >= slotPrice then
		buys += 1
	end
	return buys
end

local function collection(data: any): CollectionMath.CollectionState
	data.Collection = CollectionMath.sanitize(data.Collection)
	return data.Collection
end

function CollectionService.Enabled(): boolean
	return enabled()
end

function CollectionService.Get(player: Player): CollectionMath.CollectionState?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	return collection(data)
end

function CollectionService.OwnedCopies(player: Player, relicId: string): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local n = 0
	for _, item in data.Inventory do
		if item.Id == relicId and item.Mutation == nil then
			n += 1
		end
	end
	return n
end

function CollectionService.OwnedMutatedCopies(player: Player, relicId: string): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local n = 0
	for _, item in data.Inventory do
		if item.Id == relicId and item.Mutation ~= nil then
			n += 1
		end
	end
	return n
end

function CollectionService.SoftPinTarget(player: Player): string?
	if not enabled() then
		return nil
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = collection(data)
	local ownedById: { [string]: number } = {}
	local tierById: { [string]: string } = {}
	for _, item in data.Inventory do
		if type(item.Id) == "string" and item.Mutation == nil then
			ownedById[item.Id] = (ownedById[item.Id] or 0) + 1
			local relic = RelicConfig.ById[item.Id]
			if relic then
				tierById[item.Id] = relic.Tier
			end
		end
	end
	-- Board lineages need tiers even when all base copies were consumed.
	for relicId in state.Fusion do
		local relic = RelicConfig.ById[relicId]
		if relic then
			tierById[relicId] = relic.Tier
			ownedById[relicId] = ownedById[relicId] or 0
		end
	end
	return CollectionMath.softPinTarget(state, ownedById, tierById, data.Rebirths or 0)
end

function CollectionService.IsFusionReserved(player: Player, relicId: string, mutationId: string?): boolean
	if not enabled() then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local state = collection(data)
	local fav = data.Favorites[AutoSell.favoriteKey(relicId, mutationId)] == true
	if mutationId ~= nil then
		if fav then
			return true
		end
		-- SoftCap_P4 / Phase 6: keep ≥1 mutated copy when Board Rank 2→3 needs mutation.
		local needMut = CollectionMath.mutatedCopiesToReserve(state, relicId)
		if needMut <= 0 then
			return false
		end
		local mutOwned = CollectionService.OwnedMutatedCopies(player, relicId)
		return mutOwned <= needMut
	end
	local owned = CollectionService.OwnedCopies(player, relicId)
	local soft = CollectionService.SoftPinTarget(player)
	return CollectionMath.wouldBreachReserve(relicId, owned, state, fav, soft)
end

-- Sell-all: protect exactly N base / M mutated UIDs per relic (recipe reserves), not "all or none".
function CollectionService.FusionReserveByUid(player: Player): { [number]: boolean }
	local out: { [number]: boolean } = {}
	if not enabled() then
		return out
	end
	local data = DataService.Get(player)
	if not data then
		return out
	end
	local state = collection(data)
	local soft = CollectionService.SoftPinTarget(player)
	local baseSlotsLeft: { [string]: number } = {}
	local mutSlotsLeft: { [string]: number } = {}
	local seenBase: { [string]: boolean } = {}
	for _, item in data.Inventory do
		local id = item.Id
		if type(id) ~= "string" then
			continue
		end
		if item.Mutation == nil and not seenBase[id] then
			seenBase[id] = true
			local favBase = data.Favorites[AutoSell.favoriteKey(id, nil)] == true
			baseSlotsLeft[id] = CollectionMath.reserveCopies(id, state, favBase, soft)
		end
		if mutSlotsLeft[id] == nil then
			mutSlotsLeft[id] = CollectionMath.mutatedCopiesToReserve(state, id)
		end
	end
	for _, item in data.Inventory do
		local uid = item.Uid
		if type(uid) ~= "number" then
			continue
		end
		local fav = data.Favorites[AutoSell.favoriteKey(item.Id, item.Mutation)] == true
		if fav then
			out[uid] = true
		elseif item.Mutation ~= nil then
			local left = mutSlotsLeft[item.Id] or 0
			if left > 0 then
				out[uid] = true
				mutSlotsLeft[item.Id] = left - 1
			else
				out[uid] = false
			end
		else
			local left = baseSlotsLeft[item.Id] or 0
			if left > 0 then
				out[uid] = true
				baseSlotsLeft[item.Id] = left - 1
			else
				out[uid] = false
			end
		end
	end
	return out
end

function CollectionService.GrantEssence(player: Player, amount: number)
	if not enabled() or amount <= 0 then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = collection(data)
	state.Essence += amount
	player:SetAttribute("Essence", state.Essence)
	local Analytics = require(script.Parent.PlaytestAnalyticsService)
	Analytics.RecordEssenceEarn(player, amount)
end

function CollectionService.HasUnlock(player: Player, unlockId: string): boolean
	if not enabled() then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	return CollectionMath.hasUnlockFlag(collection(data), unlockId)
end

function CollectionService.GrantEssenceFromSale(player: Player, relicId: string)
	if not enabled() then
		return
	end
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = collection(data)
	-- Rare- auto-essence; Epic pays Essence only after First Bloodmoon (matches Salvage boost unlock).
	local epicSalvage = relic.Tier == "Epic" and CollectionService.HasUnlock(player, "EpicSalvageBoost")
	if not CollectionMath.autoEssenceAllowed(relic.Tier) and not epicSalvage then
		return
	end
	local entry = state.Fusion[relicId]
	local workshop = entry and entry.Charm == "Workshop"
	local workshopTier = if workshop then relic.Tier else nil
	local amount = CollectionMath.essenceFromSale(relic.Tier, state.ResonanceStacks, workshop, workshopTier)
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
	CollectionService.GrantEssence(player, amount)
end

-- familyMatchCount: capture relics whose Family matches the pedestaled Hunt Charm (0 if none).
function CollectionService.GrantHuntEssence(player: Player, familyMatchCount: number?)
	if not enabled() then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = collection(data)
	local amount = CollectionMath.huntCaptureEssenceAmount(
		familyMatchCount or 0,
		state.ResonanceStacks.Collector or 0,
		state.ActivePursuit
	)
	if amount > 0 then
		CollectionService.GrantEssence(player, amount)
	end
end

-- MutationLedger pursuit: +Essence the first time each relic id is seen mutated this life.
function CollectionService.GrantPursuitMutEssence(player: Player, relicId: string, _isFirstUniqueMut: boolean?)
	if not enabled() then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = collection(data)
	local pursuit = CollectionMath.pursuitConfig(state.ActivePursuit)
	if not pursuit or type(pursuit.NewUniqueMutEssence) ~= "number" then
		return
	end
	if type(relicId) ~= "string" or relicId == "" then
		return
	end
	if not state.PursuitMutSeen then
		state.PursuitMutSeen = {}
	end
	if state.PursuitMutSeen[relicId] then
		return
	end
	state.PursuitMutSeen[relicId] = true
	local amount = math.floor(pursuit.NewUniqueMutEssence)
	if amount > 0 then
		CollectionService.GrantEssence(player, amount)
	end
end

function CollectionService.FusionIncomeMult(player: Player, relicId: string): number
	if not enabled() then
		return 1
	end
	-- SoftCap_P4: income is Board-global (BoardIncomeMult). Per-pedestal fusion would double-count.
	if BalanceTrials.boardGlobalFusionIncome() then
		return 1
	end
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local entry = collection(data).Fusion[relicId]
	if not entry then
		return 1
	end
	return CollectionMath.fusionIncomeMult(entry.Rank)
end

-- SoftCap_P4: best Board FusionIncomeMultByRank (non-stacking). Production / P3 → 1.
function CollectionService.BoardIncomeMult(player: Player): number
	if not BalanceTrials.boardGlobalFusionIncome() then
		return 1
	end
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	return CollectionMath.boardIncomeMult(collection(data))
end

function CollectionService.HuntFamilyBonus(player: Player): (string?, number)
	if not enabled() then
		return nil, 0
	end
	local data = DataService.Get(player)
	if not data then
		return nil, 0
	end
	local state = collection(data)
	local corruptedBonus = CollectionMath.hasUnlockFlag(state, "HuntCharmBonus")
	-- Sum pedestal Hunt Charms: first matching family wins for simplicity (v1).
	for _, pedestal in data.Pedestals do
		if pedestal.Uid then
			for _, item in data.Inventory do
				if item.Uid == pedestal.Uid then
					local entry = state.Fusion[item.Id]
					if entry and entry.Charm == "Hunt" then
						local relic = RelicConfig.ById[item.Id]
						if relic then
							return relic.Family, CollectionMath.huntFamilyBonus("Hunt", corruptedBonus, relic.Tier)
						end
					end
				end
			end
		end
	end
	return nil, 0
end

local function codexMutCountFor(data: any, relicId: string): number
	local muts = data.CodexMutations and data.CodexMutations[relicId]
	if type(muts) ~= "table" then
		return 0
	end
	local n = 0
	for _ in muts do
		n += 1
	end
	return n
end

local function quarrySuggestContext(player: Player, data: any, state: CollectionMath.CollectionState): {
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
	local ownedBase: { [string]: number } = {}
	local ownedMut: { [string]: number } = {}
	local discovered: { [string]: boolean } = {}
	local codexMutCounts: { [string]: number } = {}
	local meta: { [string]: { Tier: string, Name: string, Family: string? } } = {}
	for id, row in RelicConfig.ById do
		ownedBase[id] = CollectionService.OwnedCopies(player, id)
		ownedMut[id] = CollectionService.OwnedMutatedCopies(player, id)
		discovered[id] = data.Discovered[id] == true
		codexMutCounts[id] = codexMutCountFor(data, id)
		meta[id] = { Tier = row.Tier, Name = row.Name, Family = row.Family }
	end
	local prefer = if state.ActivePursuit == "EpicLineage" then "Epic" else nil
	local hint = CollectionMath.bestAscendHint(
		state,
		ownedBase,
		meta,
		CollectionMath.hasUnlockFlag(state, "WorkshopCharmGlobal"),
		prefer
	)
	local huntFamily: string? = select(1, CollectionService.HuntFamilyBonus(player))
	return {
		OwnedBase = ownedBase,
		OwnedMutated = ownedMut,
		Discovered = discovered,
		CodexMutCounts = codexMutCounts,
		RelicMeta = meta,
		AscendTargetId = if hint then hint.TargetRelicId else nil,
		AscendMissing = if hint then hint.Missing else nil,
		HuntFamily = huntFamily,
		SoftPinId = CollectionService.SoftPinTarget(player),
	}
end

-- Snapshot fields: Active = SoftCap bias target; Chosen = player's saved pick (may differ when auto-steering).
local function quarryUiFields(player: Player, state: CollectionMath.CollectionState): {
	HuntQuarryId: string?,
	HuntQuarryName: string?,
	HuntQuarryChosen: string?,
	HuntQuarryChosenName: string?,
	HuntQuarryAutoSteer: boolean,
	HuntQuarryNeedDetail: string?,
	HuntQuarryUseful: boolean,
	HuntQuarryNeedKind: string?,
}
	local activeId = select(1, CollectionService.HuntQuarry(player))
	local chosenId = state.HuntQuarryId
	local activeRelic = if activeId then RelicConfig.ById[activeId] else nil
	local chosenRelic = if type(chosenId) == "string" and chosenId ~= "" then RelicConfig.ById[chosenId] else nil
	local autoSteer = type(chosenId) == "string"
		and chosenId ~= ""
		and type(activeId) == "string"
		and activeId ~= ""
		and chosenId ~= activeId
	local need = if activeId then CollectionService.QuarryNeedFor(player, activeId) else nil
	return {
		HuntQuarryId = activeId,
		HuntQuarryName = if activeRelic then activeRelic.Name else nil,
		HuntQuarryChosen = chosenId,
		HuntQuarryChosenName = if chosenRelic then chosenRelic.Name else nil,
		HuntQuarryAutoSteer = autoSteer == true,
		HuntQuarryNeedDetail = if need then need.Detail else nil,
		HuntQuarryUseful = need ~= nil and need.Useful == true,
		HuntQuarryNeedKind = if need then need.Kind else nil,
	}
end

-- SoftCap Studio: exact-relic SoftCap bias on binds (never AFK / never Ladder).
-- Pre-Board: soft-pin first-fuse chase. Post-Board: recipe / Codex / Ascend.
-- When the player's chosen quarry is exhausted, steers binds at the next useful chase.
function CollectionService.HuntQuarry(player: Player): (string?, number)
	if not enabled() then
		return nil, 0
	end
	-- Core Loop presentation: no quarry bias (Scan-first UX; code kept for later).
	if BalanceTrials.coreLoopPresentation() then
		return nil, 0
	end
	if BalanceTrials.raritySampler() ~= "SoftCap" then
		return nil, 0
	end
	if not BalanceTrials.boardGlobalFusionIncome() then
		return nil, 0
	end
	local data = DataService.Get(player)
	if not data then
		return nil, 0
	end
	local state = collection(data)
	if not CollectionMath.huntQuarryEligible(state) then
		return nil, 0
	end
	local ctx = quarrySuggestContext(player, data, state)
	local suggested = CollectionMath.suggestHuntQuarry({
		State = state,
		OwnedBase = ctx.OwnedBase,
		OwnedMutated = ctx.OwnedMutated,
		Discovered = ctx.Discovered,
		CodexMutCounts = ctx.CodexMutCounts,
		RelicMeta = ctx.RelicMeta,
		AscendTargetId = ctx.AscendTargetId,
		AscendMissing = ctx.AscendMissing,
		HuntFamily = ctx.HuntFamily,
		SoftPinId = ctx.SoftPinId,
	})
	local chosenUseful = false
	if type(state.HuntQuarryId) == "string" and state.HuntQuarryId ~= "" then
		local needChosen = CollectionMath.quarryNeed({
			State = state,
			RelicId = state.HuntQuarryId,
			TierId = if RelicConfig.ById[state.HuntQuarryId] then RelicConfig.ById[state.HuntQuarryId].Tier else nil,
			OwnedBase = ctx.OwnedBase[state.HuntQuarryId] or 0,
			OwnedMutated = ctx.OwnedMutated[state.HuntQuarryId] or 0,
			AscendTargetId = ctx.AscendTargetId,
			AscendMissing = ctx.AscendMissing,
			Discovered = ctx.Discovered[state.HuntQuarryId] == true,
			CodexMutCount = ctx.CodexMutCounts[state.HuntQuarryId] or 0,
		})
		chosenUseful = needChosen.Useful
		-- Don't trap binds on Rank3 mut wait when a copy-stockpile chase is available.
		if
			chosenUseful
			and (needChosen.Kind == "Mutation" or needChosen.Kind == "MutCodex")
			and type(suggested) == "string"
			and suggested ~= ""
			and suggested ~= state.HuntQuarryId
		then
			local sugRelic = RelicConfig.ById[suggested]
			local needSug = CollectionMath.quarryNeed({
				State = state,
				RelicId = suggested,
				TierId = if sugRelic then sugRelic.Tier else nil,
				OwnedBase = ctx.OwnedBase[suggested] or 0,
				OwnedMutated = ctx.OwnedMutated[suggested] or 0,
				AscendTargetId = ctx.AscendTargetId,
				AscendMissing = ctx.AscendMissing,
				Discovered = ctx.Discovered[suggested] == true,
				CodexMutCount = ctx.CodexMutCounts[suggested] or 0,
			})
			if
				needSug.Useful
				and (
					needSug.Kind == "FuseCopies"
					or needSug.Kind == "Catalyst"
					or needSug.Kind == "Discover"
					or needSug.Kind == "Ascend"
				)
			then
				chosenUseful = false
			end
		end
	end
	local quarryId = CollectionMath.resolveHuntQuarryId(state, ctx.SoftPinId, suggested, chosenUseful)
	if not quarryId or not RelicConfig.ById[quarryId] then
		return nil, 0
	end
	return quarryId, CollectionMath.huntQuarryMult()
end

function CollectionService.QuarryNeedFor(player: Player, relicId: string): CollectionMath.QuarryNeed?
	if not enabled() or type(relicId) ~= "string" or relicId == "" then
		return nil
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = collection(data)
	local relic = RelicConfig.ById[relicId]
	local ascendTarget: string? = nil
	local ascendMissing: number? = nil
	if BalanceTrials.boardGlobalFusionIncome() and CollectionMath.huntQuarryEligible(state) then
		local ctx = quarrySuggestContext(player, data, state)
		ascendTarget = ctx.AscendTargetId
		ascendMissing = ctx.AscendMissing
	end
	return CollectionMath.quarryNeed({
		State = state,
		RelicId = relicId,
		TierId = if relic then relic.Tier else nil,
		OwnedBase = CollectionService.OwnedCopies(player, relicId),
		OwnedMutated = CollectionService.OwnedMutatedCopies(player, relicId),
		AscendTargetId = ascendTarget,
		AscendMissing = ascendMissing,
		Discovered = data.Discovered[relicId] == true,
		CodexMutCount = codexMutCountFor(data, relicId),
	})
end

function CollectionService.SetHuntQuarry(player: Player, relicId: string): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if BalanceTrials.raritySampler() ~= "SoftCap" or not BalanceTrials.boardGlobalFusionIncome() then
		return false, "Hunt Quarry is a SoftCap Studio feature."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	local now = workspace:GetServerTimeNow()
	if relicId == "" or relicId == "Clear" then
		state.HuntQuarryId = nil
		state.HuntQuarrySetAt = now
		DataService.RequestSave(player)
		GameEvents.Fire("CollectionChanged", player)
		return true, "Hunt Quarry cleared — soft-pin / suggested chase used if any."
	end
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return false, "Unknown relic."
	end
	-- SoftCap Studio: allow pinning undiscovered Codex targets (Discover quarry).
	if state.HuntQuarryId == relicId then
		local need = CollectionService.QuarryNeedFor(player, relicId)
		local detail = if need then need.Detail else "already set"
		return true, `Hunt Quarry already {relic.Name} — {detail}`
	end
	local ready, left = CollectionMath.huntQuarryRetargetReady(state, now)
	if not ready then
		return false, `Wait {math.ceil(left)}s before changing Hunt Quarry.`
	end
	state.HuntQuarryId = relicId
	state.HuntQuarrySetAt = now
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	local need = CollectionService.QuarryNeedFor(player, relicId)
	if need and need.Useful then
		return true, `Hunt Quarry set: {relic.Name} — {need.Detail}. Binds bias this relic. AFK unchanged.`
	end
	return true,
		`Hunt Quarry saved: {relic.Name} (no recipe waiting). Binds will auto-chase the next useful Codex/mut/Ascend target until you pick again. AFK unchanged.`
end

function CollectionService.BinderHoldBonus(player: Player): number
	if not enabled() then
		return 0
	end
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return CollectionMath.binderHoldBonus(collection(data).ResonanceStacks.Binder or 0)
end

function CollectionService.SeekerSightBonus(player: Player): number
	if not enabled() then
		return 0
	end
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	return CollectionMath.seekerSightBonus(collection(data).ResonanceStacks.Seeker or 0)
end

local function removeBaseCopies(data: any, relicId: string, count: number): boolean
	local removed = 0
	local kept = {}
	local onPedestal = {}
	for _, pedestal in data.Pedestals do
		if pedestal.Uid then
			onPedestal[pedestal.Uid] = true
		end
	end
	for _, item in data.Inventory do
		if
			removed < count
			and item.Id == relicId
			and item.Mutation == nil
			and not onPedestal[item.Uid]
			and item.Locked ~= true
		then
			removed += 1
		else
			table.insert(kept, item)
		end
	end
	if removed < count then
		return false
	end
	data.Inventory = kept
	return true
end

function CollectionService.TryFuse(player: Player, relicId: string): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return false, "Unknown relic."
	end
	local state = collection(data)
	local entry = state.Fusion[relicId] or { Rank = 0, Charm = nil }
	local owned = CollectionService.OwnedCopies(player, relicId)
	local mutated = CollectionService.OwnedMutatedCopies(player, relicId)
	local catalystReady = state.EpicCatalysts[relicId] == true or entry.Rank > 0
	local ok, reason = CollectionMath.canFuse({
		TierId = relic.Tier,
		RelicId = relicId,
		CurrentRank = entry.Rank,
		OwnedCopies = owned,
		Essence = state.Essence,
		State = state,
		Rebirths = data.Rebirths or 0,
		HasMutatedCopy = mutated > 0,
		EpicCatalystReady = catalystReady,
	})
	if not ok then
		return false, reason
	end
	local nextRank = entry.Rank + 1
	local cost = CollectionMath.fusionEssenceCost(relic.Tier, nextRank)
	local consume = CollectionMath.consumeForRank(nextRank)
	if not removeBaseCopies(data, relicId, consume) then
		return false, "Could not consume copies."
	end
	state.Essence -= cost
	entry.Rank = nextRank
	state.Fusion[relicId] = entry
	state.FusionPins[relicId] = true
	if CollectionMath.needsMutatedCopyForNextRank(nextRank) then
		-- Newly Rank 2: default Focus when unset or previous focus invalid.
		local resolved = CollectionMath.resolveBoardFocusId(state)
		if state.BoardFocusId == nil or resolved == nil then
			state.BoardFocusId = relicId
		end
	elseif nextRank >= (CollectionConfig.MaxFusionRank or 3) and state.BoardFocusId == relicId then
		state.BoardFocusId = nil
	end
	player:SetAttribute("Essence", state.Essence)
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	if BalanceTrials.boardGlobalFusionIncome() then
		local MultiplierService = require(script.Parent.MultiplierService)
		MultiplierService.Refresh(player)
		local EconomyService = require(script.Parent.EconomyService)
		EconomyService.Mirror(player)
	end
	if entry.Rank == 1 and not entry.Charm then
		Notify:FireClient(player, "Fused! Choose a Charm in Collection.", "Milestone")
		return true, "Fusion rank 1 — choose a Charm."
	end
	local lift = if BalanceTrials.boardGlobalFusionIncome()
		then CollectionMath.boardIncomeMult(state)
		else CollectionMath.fusionIncomeMult(entry.Rank)
	Notify:FireClient(
		player,
		`Fusion Rank {entry.Rank} — Board income ×{string.format("%.2f", lift)}`,
		"Milestone"
	)
	return true, `Fusion rank {entry.Rank}.`
end

-- SoftCap_P4: retire a Board entry — clears Fusion rank/Charm, frees one slot. No refund of copies.
function CollectionService.TryRetireBoard(player: Player, relicId: string): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not BalanceTrials.boardGlobalFusionIncome() then
		return false, "Board retire is not available in this build."
	end
	if type(relicId) ~= "string" or relicId == "" then
		return false, "Pick a fused relic to retire."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	local entry = state.Fusion[relicId]
	if not entry or (entry.Rank or 0) <= 0 then
		return false, "That relic is not on the Board."
	end
	local preview = CollectionMath.previewRetire(state, relicId)
	local cost = if preview then preview.Cost else (CollectionConfig.BoardRetireEssence or 80)
	if state.Essence < cost then
		return false, `Need {cost} Essence to retire (have {math.floor(state.Essence)}).`
	end
	local before = if preview then preview.IncomeBefore else CollectionMath.boardIncomeMult(state)
	local rank = if preview then preview.Rank else (entry.Rank or 0)
	local charmId = if preview then preview.CharmId else entry.Charm
	state.Essence -= cost
	state.Fusion[relicId] = nil
	state.FusionPins[relicId] = nil
	if state.BoardFocusId == relicId then
		state.BoardFocusId = nil
	end
	player:SetAttribute("Essence", state.Essence)
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	local MultiplierService = require(script.Parent.MultiplierService)
	MultiplierService.Refresh(player)
	local EconomyService = require(script.Parent.EconomyService)
	EconomyService.Mirror(player)
	local after = CollectionMath.boardIncomeMult(state)
	local charmName = if charmId and CollectionConfig.Charms[charmId]
		then CollectionConfig.Charms[charmId].Name
		else (charmId or "none")
	return true,
		`Retired Rank {rank} / {charmName} (−{cost} Essence). Board income ×{string.format("%.2f", before)} → ×{string.format("%.2f", after)}. Slot freed.`
end

-- Prioritize one Rank-2 Board relic for NEXT / UI (no drop-rate change). Only meaningful when 2+ candidates.
function CollectionService.SetBoardFocus(player: Player, relicId: string): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	local entry = state.Fusion[relicId]
	if not entry or (entry.Rank or 0) <= 0 then
		return false, "That relic is not on the Board."
	end
	if not CollectionMath.needsMutatedCopyForNextRank(entry.Rank) then
		return false, "Only Rank 2 Board relics can be prioritized for Rank 3."
	end
	local candidates = CollectionMath.boardFocusCandidates(state)
	if #candidates < 2 then
		state.BoardFocusId = relicId
	else
		state.BoardFocusId = relicId
	end
	-- SoftCap_P4: Rank3 focus sets Hunt Quarry (bypasses retarget CD — intentional Rank3 chase).
	local quarryNote = ""
	if
		BalanceTrials.raritySampler() == "SoftCap"
		and BalanceTrials.boardGlobalFusionIncome()
		and CollectionMath.huntQuarryEligible(state)
	then
		state.HuntQuarryId = relicId
		state.HuntQuarrySetAt = workspace:GetServerTimeNow()
		quarryNote = " Hunt Quarry set — binds bias this relic for Rank 3."
	end
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	if #candidates < 2 then
		return true, `Rank 3 target set.{quarryNote}`
	end
	return true, `Prioritized for NEXT.{quarryNote}`
end

function CollectionService.SetCharm(player: Player, relicId: string, charmId: string): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionConfig.Charms[charmId] then
		return false, "Unknown Charm."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	local entry = state.Fusion[relicId]
	if not entry or entry.Rank < 1 then
		return false, "Fuse this relic first."
	end
	if charmId == "Workshop" and not CollectionService.HasUnlock(player, "WorkshopCharmGlobal") then
		return false, "Unlock Workshop Charm via First Golden mutation goal."
	end
	if entry.Charm then
		if entry.Charm == charmId then
			return true, "Charm already equipped."
		end
		if not CollectionService.HasUnlock(player, "CharmRespec") then
			return false, "Charm already chosen. Unlock Charm respec later."
		end
		local cost = CollectionConfig.CharmRespecEssence
		if state.Essence < cost then
			return false, `Need {cost} Essence to respec.`
		end
		state.Essence -= cost
		player:SetAttribute("Essence", state.Essence)
	end
	-- One of each Charm on the Board — Hunt / Workshop / Shrine roles, not stacked power.
	local okCharm, owner = CollectionMath.canAssignBoardCharm(state, charmId, relicId)
	if not okCharm and owner then
		local other = RelicConfig.ById[owner]
		local otherName = if other then other.Name else owner
		return false, `{CollectionConfig.Charms[charmId].Name} is already on {otherName}. Each Board Charm is unique — pick a different specialty.`
	end
	entry.Charm = charmId
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	local relic = RelicConfig.ById[relicId]
	local pot = CollectionMath.charmPotency(if relic then relic.Tier else "Common")
	local tip = if charmId == "Hunt"
		then ` Equip it on a pedestal — family bias scales with lineage tier (now ×{string.format("%.2f", pot)} potency).`
		elseif charmId == "Workshop"
		then ` Duplicates of this relic yield +{string.format("%.0f", CollectionMath.workshopEssenceBonus(if relic then relic.Tier else "Common") * 100)}% Essence at this tier.`
		elseif charmId == "Shrine"
		then ` Equip it on a pedestal — pulse every {string.format("%.0f", CollectionMath.shrinePulseSeconds(if relic then relic.Tier else "Common"))}s (faster on higher tiers).`
		else ""
	return true, `{CollectionConfig.Charms[charmId].Name} chosen.{tip}`
end

function CollectionService.CraftEpicCatalyst(player: Player, relicId: string): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionService.HasUnlock(player, "EpicSalvageBoost") then
		return false, "Complete First Bloodmoon first."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local relic = RelicConfig.ById[relicId]
	if not relic or relic.Tier ~= "Epic" then
		return false, "Epic Catalyst needs an exact Epic relic."
	end
	local state = collection(data)
	if state.EpicCatalysts[relicId] then
		return false, "Catalyst already crafted for this relic."
	end
	local need = CollectionConfig.EpicCatalyst.Copies
	local cost = CollectionConfig.EpicCatalyst.Essence
	if CollectionService.OwnedCopies(player, relicId) < need then
		return false, `Need {need} base copies.`
	end
	if state.Essence < cost then
		return false, `Need {cost} Essence.`
	end
	if not removeBaseCopies(data, relicId, need) then
		return false, "Could not consume copies."
	end
	state.Essence -= cost
	state.EpicCatalysts[relicId] = true
	player:SetAttribute("Essence", state.Essence)
	CollectionService.TryClaimMutationGoals(player)
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	return true, "Epic Catalyst ready — fuse this relic onto the board."
end

function CollectionService.CraftTargetedAttune(player: Player, tierId: string): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionService.HasUnlock(player, "TargetedAttune") then
		return false, "Complete Five Unique Mutated first."
	end
	local cost = CollectionConfig.TargetedAttuneEssence
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	if state.Essence < cost then
		return false, `Need {cost} Essence.`
	end
	if type(tierId) ~= "string" or tierId == "" then
		return false, "Pick a Focus tier."
	end
	state.Essence -= cost
	state.TargetedAttuneTier = tierId
	state.AttuneScansLeft += CollectionConfig.TargetedAttuneScans
	player:SetAttribute("Essence", state.Essence)
	player:SetAttribute("AttuneScansLeft", state.AttuneScansLeft)
	player:SetAttribute("RarityFocus", tierId)
	data.Settings.RarityFocus = tierId
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	local RollService = require(script.Parent.RollService)
	RollService.RefreshAttributes(player)
	return true, `Targeted Attune: {CollectionConfig.TargetedAttuneScans} Focused {tierId} scans.`
end

function CollectionService.SetFamilyAttune(player: Player, familyId: string): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionService.HasUnlock(player, "FamilyAttune") then
		return false, "Complete First Divine first."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	local cost = CollectionConfig.FamilyAttuneEssence or 0
	if cost > 0 and state.Essence < cost then
		return false, `Need {cost} Essence.`
	end
	if cost > 0 then
		state.Essence -= cost
		player:SetAttribute("Essence", state.Essence)
	end
	state.FamilyAttune = familyId
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	return true, `Family Attune set: {familyId}.`
end

function CollectionService.CraftMutationFocus(player: Player): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionService.HasUnlock(player, "MutationFocus") then
		return false, "Complete Fifteen Unique Mutated first."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	local cost = CollectionConfig.MutationFocusEssence
	if state.Essence < cost then
		return false, `Need {cost} Essence.`
	end
	if state.MutationFocusScansLeft > 0 then
		return false, "Mutation Focus already active."
	end
	state.Essence -= cost
	state.MutationFocusScansLeft = CollectionConfig.MutationFocusScans
	player:SetAttribute("Essence", state.Essence)
	player:SetAttribute("MutationFocusScansLeft", state.MutationFocusScansLeft)
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	return true, `Mutation Focus: next {CollectionConfig.MutationFocusScans} scans.`
end

function CollectionService.ConsumeMutationFocus(player: Player): boolean
	if not enabled() then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local state = collection(data)
	if state.MutationFocusScansLeft <= 0 then
		return false
	end
	state.MutationFocusScansLeft -= 1
	player:SetAttribute("MutationFocusScansLeft", state.MutationFocusScansLeft)
	return true
end

function CollectionService.UpgradeAttuneCap(player: Player): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionService.HasUnlock(player, "AttuneTicketRecipe") then
		return false, "Unlock Attune tickets first."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	local hard = CollectionConfig.MaxAttuneChargesHardCap or 8
	if state.AttuneChargeCap >= hard then
		return false, "Attune charge cap maxed."
	end
	local cost = CollectionConfig.AttuneChargeUpgradeEssence
	if state.Essence < cost then
		return false, `Need {cost} Essence.`
	end
	state.Essence -= cost
	state.AttuneChargeCap += 1
	player:SetAttribute("Essence", state.Essence)
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	return true, `Attune charge cap is now {state.AttuneChargeCap}.`
end

function CollectionService.SetPin(player: Player, relicId: string, on: boolean): boolean
	if not enabled() then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local state = collection(data)
	state.FusionPins[relicId] = if on then true else nil
	DataService.RequestSave(player)
	return true
end

function CollectionService.ChooseResonance(player: Player, resonanceId: string, pursuitId: string?): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionConfig.Resonances[resonanceId] then
		return false, "Unknown Resonance."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	if not state.PendingResonance then
		return false, "No Resonance choice pending."
	end
	local pursuit = if type(pursuitId) == "string" and pursuitId ~= "" then pursuitId else "FamilyHunt"
	if not CollectionMath.pursuitConfig(pursuit) then
		return false, "Unknown Rebirth Pursuit."
	end
	if not CollectionMath.pursuitAvailable(pursuit, function(unlockId)
		return CollectionService.HasUnlock(player, unlockId)
	end) then
		return false, "That Pursuit is locked — pick Family Hunt or Mutation Ledger."
	end
	state.ResonanceStacks[resonanceId] = (state.ResonanceStacks[resonanceId] or 0) + 1
	state.PendingResonance = false
	state.ActivePursuit = pursuit
	local stacks = state.ResonanceStacks[resonanceId]
	local unlocks = CollectionMath.resonanceUnlocked(resonanceId, stacks)
	if table.find(unlocks, "PostRebirthAttune") and stacks == 3 then
		state.AttuneScansLeft += CollectionConfig.AttuneScanCount
		player:SetAttribute("AttuneScansLeft", state.AttuneScansLeft)
	end
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	local pursuitRow = CollectionMath.pursuitConfig(pursuit)
	local extra = if #unlocks > 0 then ` Unlocked: {table.concat(unlocks, ", ")}.` else ""
	local pursuitName = if pursuitRow then pursuitRow.Name else pursuit
	return true, `{CollectionConfig.Resonances[resonanceId].Name} ×{stacks}. This life: {pursuitName}.{extra}`
end

function CollectionService.OnRebirth(player: Player)
	if not enabled() then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = collection(data)
	-- Core Loop presentation: skip Resonance / Pursuit prompts (Collection UX hidden).
	if BalanceTrials.coreLoopPresentation() then
		state.PendingResonance = false
		state.ActivePursuit = nil
		DataService.RequestSave(player)
		return
	end
	state.PendingResonance = true
	state.ActivePursuit = nil
	state.PursuitMutSeen = {}
	if CollectionService.HasUnlock(player, "PostRebirthAttune") then
		state.AttuneScansLeft += CollectionConfig.AttuneScanCount
		Notify:FireClient(player, `Seeker Attune: next {CollectionConfig.AttuneScanCount} scans Focus Common.`, "Jade")
	end
	Notify:FireClient(player, "Choose Resonance + this life's Pursuit in Collection Advanced.", "Jade")
	DataService.RequestSave(player)
end

function CollectionService.TrySalvage(player: Player, relicId: string, mutationId: string?): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionService.HasUnlock(player, "SalvageFocus") then
		return false, "Need Collector Resonance ×2 (Salvage Focus)."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local fav = data.Favorites[AutoSell.favoriteKey(relicId, mutationId)] == true
	if fav then
		return false, "Favourites can't be salvaged."
	end
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return false, "Unknown relic."
	end
	local SellService = require(script.Parent.SellService)
	local soldCount = SellService.Sell(player, relicId, mutationId, 1)
	if soldCount < 1 then
		return false, "Nothing to salvage."
	end
	-- Sell already ran GrantEssenceFromSale (Rare- auto; Epic after First Bloodmoon).
	-- Salvage only tops up tiers that sale still skips (Legendary+ / pre-Bloodmoon Epic).
	local state = collection(data)
	local amount = CollectionMath.essenceFromSale(relic.Tier, state.ResonanceStacks, false)
	local epicBoosted = CollectionService.HasUnlock(player, "EpicSalvageBoost") and relic.Tier == "Epic"
	if epicBoosted then
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
	if CollectionMath.autoEssenceAllowed(relic.Tier) or epicBoosted then
		-- Already paid via Sell → GrantEssenceFromSale.
		return true, `Salvaged for {amount} Essence.`
	end
	CollectionService.GrantEssence(player, amount)
	return true, `Salvaged for {amount} Essence.`
end

function CollectionService.CraftAttune(player: Player): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	if not CollectionService.HasUnlock(player, "AttuneTicketRecipe") then
		return false, "Complete Three Unique Mutated first."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	local cap = state.AttuneChargeCap or CollectionConfig.MaxAttuneCharges
	if state.AttuneCharges >= cap then
		return false, "Attune charge cap reached."
	end
	local cost = CollectionConfig.AttuneTicketEssenceCost
	if state.Essence < cost then
		return false, `Need {cost} Essence.`
	end
	-- SoftCap_P4 Phase 7: bank Essence for a Ready Ascend Retire→Fuse before Attune spam.
	if BalanceTrials.boardGlobalFusionIncome() then
		local hint = buildAscendHint(player, state)
		if hint and (hint.Owned or 0) >= (hint.Need or 3) then
			local need = (hint.RetireCost or 0) + (hint.EssenceCost or 0)
			if state.Essence - cost + 1e-9 < need then
				return false, `Keep {need} Essence to ascend {hint.Charm} ({hint.TargetName}).`
			end
		end
	end
	state.Essence -= cost
	state.AttuneCharges += 1
	player:SetAttribute("Essence", state.Essence)
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	return true, "Crafted 1 Attune ticket."
end

function CollectionService.ActivateAttune(player: Player): (boolean, string)
	if not enabled() then
		return false, "Collection prototype is off."
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Data loading."
	end
	local state = collection(data)
	if state.AttuneCharges <= 0 then
		return false, "No Attune charges."
	end
	state.AttuneCharges -= 1
	state.AttuneScansLeft += CollectionConfig.AttuneScanCount
	state.TargetedAttuneTier = nil
	data.Settings.RarityFocus = "Common"
	player:SetAttribute("RarityFocus", "Common")
	player:SetAttribute("AttuneScansLeft", state.AttuneScansLeft)
	DataService.RequestSave(player)
	GameEvents.Fire("CollectionChanged", player)
	local RollService = require(script.Parent.RollService)
	RollService.RefreshAttributes(player)
	return true, `Attune active: {CollectionConfig.AttuneScanCount} Focused Common scans.`
end

-- Called after each AFK/scan roll while Attune is active.
function CollectionService.ConsumeAttuneScan(player: Player): string?
	if not enabled() then
		return nil
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = collection(data)
	if state.AttuneScansLeft <= 0 then
		return nil
	end
	state.AttuneScansLeft -= 1
	player:SetAttribute("AttuneScansLeft", state.AttuneScansLeft)
	local tier = state.TargetedAttuneTier or "Common"
	if state.AttuneScansLeft <= 0 then
		state.TargetedAttuneTier = nil
	end
	return tier
end

function CollectionService.AttuneFocusOverride(player: Player): string?
	if not enabled() then
		return nil
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = collection(data)
	if state.AttuneScansLeft > 0 then
		return state.TargetedAttuneTier or "Common"
	end
	return nil
end

function CollectionService.FamilyAttuneBonus(player: Player): string?
	if not enabled() or not CollectionService.HasUnlock(player, "FamilyAttune") then
		return nil
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	return collection(data).FamilyAttune
end

function CollectionService.TryQuickBind(player: Player): boolean
	if not enabled() or not CollectionService.HasUnlock(player, "QuickBind") then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local state = collection(data)
	local now = workspace:GetServerTimeNow()
	if now < (state.QuickBindReadyAt or 0) then
		return false
	end
	state.QuickBindReadyAt = now + CollectionConfig.QuickBindCooldownSeconds
	player:SetAttribute("QuickBindActive", true)
	return true
end

function CollectionService.QuickBindHoldFactor(player: Player): number
	if player:GetAttribute("QuickBindActive") == true then
		player:SetAttribute("QuickBindActive", nil)
		return CollectionConfig.QuickBindHoldFactor
	end
	return 1
end

function CollectionService.TryFreeSignal(player: Player)
	if not enabled() or not CollectionService.HasUnlock(player, "FreeSignal") then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = collection(data)
	local now = workspace:GetServerTimeNow()
	if now < (state.FreeSignalAt or 0) then
		return
	end
	local SignalService = require(script.Parent.SignalService)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local point = SignalService.RandomPoint(root.Position, 40, 120, Random.new())
	if point and SignalService.SpawnAt(player, point.Position) then
		state.FreeSignalAt = now + CollectionConfig.FreeSignalEverySeconds
		Notify:FireClient(player, "Binder Free Signal nearby.", "Jade")
	end
end

function CollectionService.ShrinePulseDue(player: Player): boolean
	if not enabled() then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		return false
	end
	local state = collection(data)
	-- Config: pedestal pulse — Shrine Charm only fires when that fused relic is equipped.
	for _, pedestal in data.Pedestals do
		if pedestal.Uid then
			for _, item in data.Inventory do
				if item.Uid == pedestal.Uid then
					local entry = state.Fusion[item.Id]
					if entry and entry.Charm == "Shrine" then
						return true
					end
				end
			end
		end
	end
	return false
end

-- SoftCap_P4 Phase 7: Shrine pulse interval from pedestaled Shrine lineage tier.
function CollectionService.ShrinePulseSeconds(player: Player): number
	local base = (CollectionConfig.Charms.Shrine and CollectionConfig.Charms.Shrine.PulseSeconds) or 60
	if not enabled() then
		return base
	end
	local data = DataService.Get(player)
	if not data then
		return base
	end
	local state = collection(data)
	for _, pedestal in data.Pedestals do
		if pedestal.Uid then
			for _, item in data.Inventory do
				if item.Uid == pedestal.Uid then
					local entry = state.Fusion[item.Id]
					if entry and entry.Charm == "Shrine" then
						local relic = RelicConfig.ById[item.Id]
						return CollectionMath.shrinePulseSeconds(if relic then relic.Tier else "Common")
					end
				end
			end
		end
	end
	return base
end

local function buildAscendHint(player: Player, state: any): any?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local ownedBase: { [string]: number } = {}
	local meta: { [string]: { Tier: string, Name: string, Family: string? } } = {}
	for relicId, relic in RelicConfig.ById do
		meta[relicId] = { Tier = relic.Tier, Name = relic.Name, Family = relic.Family }
		ownedBase[relicId] = CollectionService.OwnedCopies(player, relicId)
	end
	-- Ensure Board owners are in meta even if somehow missing.
	for relicId in state.Fusion do
		local relic = RelicConfig.ById[relicId]
		if relic and not meta[relicId] then
			meta[relicId] = { Tier = relic.Tier, Name = relic.Name, Family = relic.Family }
		end
	end
	local workshop = CollectionMath.hasUnlockFlag(state, "WorkshopCharmGlobal")
	local preferTier = if state.ActivePursuit == "EpicLineage" then "Epic" else nil
	return CollectionMath.bestAscendHint(state, ownedBase, meta, workshop, preferTier)
end

function CollectionService.TryDailyAttune(player: Player)
	if not enabled() or not CollectionService.HasUnlock(player, "DailyAttune") then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = collection(data)
	local day = math.floor(workspace:GetServerTimeNow() / 86400)
	if state.LastDailyAttuneDay == day then
		return
	end
	local cap = state.AttuneChargeCap or CollectionConfig.MaxAttuneCharges
	if state.AttuneCharges >= cap then
		return
	end
	state.LastDailyAttuneDay = day
	state.AttuneCharges += 1
	Notify:FireClient(player, "Daily Collector Attune ticket.", "Jade")
	GameEvents.Fire("CollectionChanged", player)
end

function CollectionService.TryClaimMutationGoals(player: Player)
	if not enabled() then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = collection(data)
	local uniqueMutated = 0
	local byMutation: { [string]: number } = {}
	for _, mutations in data.CodexMutations do
		if type(mutations) == "table" then
			local any = false
			for mutId in mutations do
				any = true
				byMutation[mutId] = (byMutation[mutId] or 0) + 1
			end
			if any then
				uniqueMutated += 1
			end
		end
	end
	local catalysts = 0
	for _ in state.EpicCatalysts do
		catalysts += 1
	end
	local now = workspace:GetServerTimeNow()
	for _, goal in CollectionConfig.MutationGoals do
		if state.MutationGoalsClaimed[goal.Id] then
			continue
		end
		local progress = 0
		local required = goal.UniqueRequired or goal.EpicCatalystsRequired or 1
		if goal.EpicCatalystsRequired then
			progress = catalysts
		elseif goal.AnyMutation then
			progress = uniqueMutated
		elseif goal.MutationId then
			progress = byMutation[goal.MutationId] or 0
		end
		if progress >= required then
			state.MutationGoalsClaimed[goal.Id] = now
			if goal.Unlock == "AttuneTicketRecipe" then
				state.AttuneCharges += 1
			end
			Notify:FireClient(player, `{goal.Name} unlocked — {goal.Summary}`, "Milestone")
			GameEvents.Fire("CollectionChanged", player)
		end
	end
end

local function fusionCard(player: Player, relicId: string, state: CollectionMath.CollectionState, rebirths: number, essence: number): any?
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return nil
	end
	local entry = state.Fusion[relicId] or { Rank = 0, Charm = nil }
	local owned = CollectionService.OwnedCopies(player, relicId)
	local nextRank = entry.Rank + 1
	if entry.Rank >= CollectionConfig.MaxFusionRank then
		return nil
	end
	local need = CollectionMath.copiesForRank(nextRank)
	local cost = CollectionMath.fusionEssenceCost(relic.Tier, nextRank)
	local nextMult = CollectionMath.fusionIncomeMult(nextRank)
	local curMult = if entry.Rank > 0 then CollectionMath.fusionIncomeMult(entry.Rank) else 1
	local mutated = CollectionService.OwnedMutatedCopies(player, relicId)
	local ready, reason, blockKind = CollectionMath.canFuse({
		TierId = relic.Tier,
		RelicId = relicId,
		RelicName = relic.Name,
		CurrentRank = entry.Rank,
		OwnedCopies = owned,
		Essence = essence,
		State = state,
		Rebirths = rebirths,
		HasMutatedCopy = mutated > 0,
		EpicCatalystReady = state.EpicCatalysts[relicId] == true or entry.Rank > 0,
	})
	local missing = math.max(0, need - owned)
	local onBoard = entry.Rank > 0
	return {
		Id = relicId,
		Name = relic.Name,
		Tier = relic.Tier,
		Rank = entry.Rank,
		NextRank = nextRank,
		Owned = owned,
		Need = need,
		Missing = missing,
		Cost = cost,
		Consume = CollectionMath.consumeForRank(nextRank),
		IncomeMult = nextMult,
		CurrentIncomeMult = curMult,
		NextIncomeMult = nextMult,
		Ready = ready == true,
		BlockReason = if ready then nil else reason,
		BlockKind = blockKind,
		OnBoard = onBoard,
		Pinned = state.FusionPins[relicId] == true,
		SoftPin = false,
		Charm = entry.Charm,
		NeedsMutation = nextRank >= 3 and CollectionConfig.Rank3NeedsMutation == true,
		HasMutated = mutated > 0,
		MutatedOwned = mutated,
		BoardFocus = state.BoardFocusId == relicId,
	}
end

-- Fuse-ready relics + Charm picks waiting (shared by Snapshot UI and HUD mirror).
function CollectionService.ListFuseReady(player: Player, cap: number?): ({ any }, { string })
	local data = DataService.Get(player)
	if not data or not enabled() then
		return {}, {}
	end
	local state = collection(data)
	local limit = math.max(1, cap or 8)
	local charmNeeded = {}
	for relicId, entry in state.Fusion do
		if entry.Rank >= 1 and not entry.Charm then
			table.insert(charmNeeded, relicId)
		end
	end
	local fuseCandidates = {}
	local seenIds: { [string]: boolean } = {}
	for _, item in data.Inventory do
		local relicId = item.Id
		if type(relicId) == "string" and not seenIds[relicId] then
			seenIds[relicId] = true
			local card = fusionCard(player, relicId, state, data.Rebirths or 0, state.Essence)
			if card and card.Ready then
				table.insert(fuseCandidates, card)
				if #fuseCandidates >= limit then
					break
				end
			end
		end
	end
	return fuseCandidates, charmNeeded
end

-- Progress targets for the Fusion UI (ready + closest-to-ready), sorted for beginners.
function CollectionService.ListFusionProgress(player: Player, cap: number?): { any }
	local data = DataService.Get(player)
	if not data or not enabled() then
		return {}
	end
	local state = collection(data)
	local soft = CollectionService.SoftPinTarget(player)
	local cards = {}
	local seenIds: { [string]: boolean } = {}
	for _, item in data.Inventory do
		local relicId = item.Id
		if type(relicId) == "string" and not seenIds[relicId] then
			seenIds[relicId] = true
			local card = fusionCard(player, relicId, state, data.Rebirths or 0, state.Essence)
			if card and card.Owned > 0 then
				card.SoftPin = soft == relicId
				table.insert(cards, card)
			end
		end
	end
	-- Also include already-fused relics for board upgrades even if copies are low.
	for relicId, entry in state.Fusion do
		if not seenIds[relicId] and entry.Rank > 0 and entry.Rank < CollectionConfig.MaxFusionRank then
			local card = fusionCard(player, relicId, state, data.Rebirths or 0, state.Essence)
			if card then
				card.SoftPin = soft == relicId
				table.insert(cards, card)
			end
		end
	end
	table.sort(cards, function(a, b)
		if a.Ready ~= b.Ready then
			return a.Ready
		end
		local pa = a.Owned / math.max(1, a.Need)
		local pb = b.Owned / math.max(1, b.Need)
		if pa ~= pb then
			return pa > pb
		end
		return a.Cost < b.Cost
	end)
	local limit = math.max(1, cap or 12)
	if #cards > limit then
		local trimmed = {}
		for i = 1, limit do
			trimmed[i] = cards[i]
		end
		return trimmed
	end
	return cards
end

function CollectionService.Snapshot(player: Player): any
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = collection(data)
	local uniqueMutated = 0
	local byMutation: { [string]: number } = {}
	for _, mutations in data.CodexMutations do
		if type(mutations) == "table" then
			local any = false
			for mutId in mutations do
				any = true
				byMutation[mutId] = (byMutation[mutId] or 0) + 1
			end
			if any then
				uniqueMutated += 1
			end
		end
	end
	local catalysts = 0
	for _ in state.EpicCatalysts do
		catalysts += 1
	end
	local progressCounts = {
		UniqueMutated = uniqueMutated,
		ByMutation = byMutation,
		EpicCatalysts = catalysts,
	}
	local unlocked = {}
	for _, goal in CollectionConfig.MutationGoals do
		if state.MutationGoalsClaimed[goal.Id] and goal.Unlock then
			table.insert(unlocked, goal.Unlock)
		end
	end
	for resonanceId, stacks in state.ResonanceStacks do
		for _, id in CollectionMath.resonanceUnlocked(resonanceId, stacks) do
			table.insert(unlocked, id)
		end
	end
	local fuseCandidates, charmNeeded = CollectionService.ListFuseReady(player, 8)
	local progress = CollectionService.ListFusionProgress(player, 12)
	local softPin = CollectionService.SoftPinTarget(player)
	local slots = CollectionMath.fusionSlots(state, data.Rebirths or 0)
	local fusedCount = CollectionMath.fusedCount(state)
	local goalProg = CollectionMath.goalProgress(state, progressCounts)
	local nextGoals = CollectionMath.nextUnclaimedGoals(state, progressCounts, 8)
	-- Pedestal occupancy by relic id (income / Hunt charm need the fused relic equipped).
	local onPedestal: { [string]: boolean } = {}
	for _, ped in data.Pedestals do
		if ped.Uid then
			for _, item in data.Inventory do
				if item.Uid == ped.Uid and type(item.Id) == "string" then
					onPedestal[item.Id] = true
				end
			end
		end
	end
	local boardFocusId = CollectionMath.resolveBoardFocusId(state)
	if boardFocusId and state.BoardFocusId ~= boardFocusId and #CollectionMath.boardFocusCandidates(state) == 1 then
		state.BoardFocusId = boardFocusId
	end
	for _, card in progress do
		card.OnPedestal = onPedestal[card.Id] == true
		card.BoardFocus = boardFocusId == card.Id
	end
	local board = {}
	for relicId, entry in state.Fusion do
		local relic = RelicConfig.ById[relicId]
		local charmId = entry.Charm
		local charmInfo = if charmId then CollectionConfig.Charms[charmId] else nil
		local nextRank = entry.Rank + 1
		local upgrade = if entry.Rank < CollectionConfig.MaxFusionRank
			then fusionCard(player, relicId, state, data.Rebirths or 0, state.Essence)
			else nil
		local bonuses = {}
		if BalanceTrials.boardGlobalFusionIncome() then
			table.insert(
				bonuses,
				`Board income uses best rank (this entry ×{string.format("%.2f", CollectionMath.fusionIncomeMult(entry.Rank))})`
			)
		else
			table.insert(bonuses, `Pedestal income ×{string.format("%.2f", CollectionMath.fusionIncomeMult(entry.Rank))} when equipped`)
		end
		local charmPot = if charmInfo and relic then CollectionMath.charmPotency(relic.Tier) else 1
		if charmInfo then
			table.insert(bonuses, charmInfo.Summary)
			if charmPot > 1 + 1e-9 then
				table.insert(bonuses, `Lineage potency ×{string.format("%.2f", charmPot)} ({relic and relic.Tier or "Common"})`)
			else
				table.insert(bonuses, "Common lineage — Retire + fuse a rarer relic to ascend this Charm")
			end
		elseif entry.Rank >= 1 then
			table.insert(bonuses, "Charm not chosen yet — pick one on the Fusion tab")
		end
		local mutOwned = CollectionService.OwnedMutatedCopies(player, relicId)
		local needsMut = CollectionMath.needsMutatedCopyForNextRank(entry.Rank)
		table.insert(board, {
			Id = relicId,
			Name = if relic then relic.Name else relicId,
			Tier = if relic then relic.Tier else "Common",
			Family = if relic then relic.Family else nil,
			Rank = entry.Rank,
			Charm = charmId,
			CharmName = if charmInfo then charmInfo.Name else nil,
			CharmSummary = if charmInfo then charmInfo.Summary else nil,
			CharmPotency = charmPot,
			IncomeMult = CollectionMath.fusionIncomeMult(entry.Rank),
			NextIncomeMult = if nextRank <= CollectionConfig.MaxFusionRank
				then CollectionMath.fusionIncomeMult(nextRank)
				else CollectionMath.fusionIncomeMult(entry.Rank),
			OnPedestal = onPedestal[relicId] == true,
			Bonuses = bonuses,
			Upgrade = upgrade,
			MaxRank = entry.Rank >= CollectionConfig.MaxFusionRank,
			NeedsMutation = needsMut,
			HasMutated = mutOwned > 0,
			MutatedOwned = mutOwned,
			BoardFocus = boardFocusId == relicId,
			CanSetBoardFocus = needsMut and #CollectionMath.boardFocusCandidates(state) >= 2,
		})
	end
	table.sort(board, function(a, b)
		return a.Rank > b.Rank
	end)
	local slotMeta = CollectionMath.boardSlotMeta(state, data.Rebirths or 0, nextGoals)
	-- Attach occupied relics into unlocked slots (order: highest rank first, then empty).
	local boardSlots = {}
	local occ = 1
	for _, meta in slotMeta do
		local occupied = nil
		if meta.Unlocked and occ <= #board then
			occupied = board[occ]
			occ += 1
		end
		table.insert(boardSlots, {
			Index = meta.Index,
			Unlocked = meta.Unlocked,
			UnlockId = meta.UnlockId,
			UnlockKind = meta.UnlockKind,
			UnlockName = meta.UnlockName,
			UnlockSummary = meta.UnlockSummary,
			Progress = meta.Progress,
			Required = meta.Required,
			Occupied = occupied,
		})
	end
	local boardCharms = {}
	for charmId in CollectionConfig.Charms do
		local ownerId = CollectionMath.boardCharmOwner(state, charmId)
		if ownerId then
			local ownerRelic = RelicConfig.ById[ownerId]
			boardCharms[charmId] = {
				Id = ownerId,
				Name = if ownerRelic then ownerRelic.Name else ownerId,
			}
		end
	end
	local workshopUnlocked = CollectionMath.hasUnlockFlag(state, "WorkshopCharmGlobal")
	local charmNeededCards = {}
	for _, relicId in charmNeeded do
		local relic = RelicConfig.ById[relicId]
		local entry = state.Fusion[relicId]
		table.insert(charmNeededCards, {
			Id = relicId,
			Name = if relic then relic.Name else relicId,
			Tier = if relic then relic.Tier else "Common",
			Rank = if entry then entry.Rank else 1,
			SuggestedCharm = CollectionMath.suggestBoardCharm(state, workshopUnlocked),
			BoardCharms = boardCharms,
		})
	end
	local slotHint = if fusedCount >= slots
		then `Board full ({fusedCount}/{slots}). Upgrade fused relics in place. New fusions need another slot (First Golden goal — no Rebirth required).`
		else `Board {fusedCount}/{slots} — fuse a new relic into a free slot.`
	local boardIncomeMult = if BalanceTrials.boardGlobalFusionIncome()
		then CollectionMath.boardIncomeMult(state)
		else 1
	local ascendHint = if BalanceTrials.boardGlobalFusionIncome() then buildAscendHint(player, state) else nil
	local pursuitRow = CollectionMath.pursuitConfig(state.ActivePursuit)
	local qUi = quarryUiFields(player, state)
	local quarryEligible = CollectionMath.huntQuarryEligible(state)
		and BalanceTrials.raritySampler() == "SoftCap"
		and BalanceTrials.boardGlobalFusionIncome()
	local nextObjective = ProgressObjective.pick({
		Enabled = enabled(),
		PendingResonance = state.PendingResonance == true,
		CharmNeededCount = #charmNeeded,
		FuseReadyCount = #fuseCandidates,
		BoardIncomeMult = boardIncomeMult,
		BoardGlobalIncome = BalanceTrials.boardGlobalFusionIncome(),
		FusedCount = fusedCount,
		FusionSlots = slots,
		BoardFocusId = boardFocusId,
		Progress = progress,
		NextGoals = CollectionMath.nextUnclaimedGoals(state, progressCounts, 3),
		CE = data.CE,
		RebirthCost = Rebirth.cost(BalanceTrials.rebirthSettings(Config.Rebirth), data.Rebirths or 0),
		Rebirths = data.Rebirths or 0,
		IncomePerSec = EconomyService.GetIncomePerSec(player),
		AffordableShopBuys = affordableShopBuys(player, data),
		Essence = state.Essence,
		HasAttuneRecipe = CollectionService.HasUnlock(player, "AttuneTicketRecipe"),
		AttuneCharges = state.AttuneCharges,
		AttuneScansLeft = state.AttuneScansLeft,
		AttuneTicketCost = CollectionConfig.AttuneTicketEssenceCost,
		AscendHint = ascendHint,
		ActivePursuit = state.ActivePursuit,
		PursuitName = if pursuitRow then pursuitRow.Name else nil,
		PursuitSummary = if pursuitRow then pursuitRow.Summary else nil,
		HuntQuarryEligible = quarryEligible,
		HuntQuarryId = qUi.HuntQuarryId,
		HuntQuarryName = qUi.HuntQuarryName,
		HuntQuarryChosen = qUi.HuntQuarryChosen,
		HuntQuarryChosenName = qUi.HuntQuarryChosenName,
		HuntQuarryAutoSteer = qUi.HuntQuarryAutoSteer,
		HuntQuarryNeedDetail = qUi.HuntQuarryNeedDetail,
		HuntQuarryUseful = qUi.HuntQuarryUseful,
	})
	local pursuitOptions = {}
	for id, row in CollectionConfig.RebirthPursuits or {} do
		local locked = type(row.RequiresUnlock) == "string"
			and row.RequiresUnlock ~= ""
			and not CollectionService.HasUnlock(player, row.RequiresUnlock)
		table.insert(pursuitOptions, {
			Id = id,
			Name = row.Name,
			Summary = row.Summary,
			Locked = locked == true,
		})
	end
	return {
		Enabled = enabled(),
		Essence = state.Essence,
		BoardFocusId = boardFocusId,
		BoardFocusCandidates = CollectionMath.boardFocusCandidates(state),
		Fusion = state.Fusion,
		FusionPins = state.FusionPins,
		FusionSlots = slots,
		FusedCount = fusedCount,
		Board = board,
		BoardSlots = boardSlots,
		BoardRules = if BalanceTrials.boardGlobalFusionIncome()
			then {
				"Fusing a relic places it on the Board (uses 1 slot).",
				"Income ×rank is Board-global: highest fused rank only (does not stack).",
				"Income stays active even if that relic is not on a pedestal.",
				"Hunt Charm still needs the fused relic on a pedestal.",
				"Workshop Essence and Shrine QoL apply from the Board entry.",
				"After Board Lift ×1.50: Retire a non-Lift Charm lineage and Fuse a rarer relic to ascend Charm power (income cap unchanged).",
				`Retire frees a slot for {CollectionConfig.BoardRetireEssence or 80} Essence (clears that Fusion rank/Charm).`,
			}
			else {
				"Fusing a relic places it on the Board (uses 1 slot).",
				"There is no remove/swap — upgrades improve that relic in place.",
				"Income bonus applies when the fused relic is on a pedestal.",
				"Hunt Charm needs the fused relic on a pedestal; Workshop/Shrine apply from the Board entry.",
			},
		BoardGlobalIncome = BalanceTrials.boardGlobalFusionIncome(),
		BoardIncomeMult = boardIncomeMult,
		NextObjective = nextObjective,
		CE = data.CE,
		RebirthCost = Rebirth.cost(BalanceTrials.rebirthSettings(Config.Rebirth), data.Rebirths or 0),
		Rebirths = data.Rebirths or 0,
		IncomePerSec = EconomyService.GetIncomePerSec(player),
		AffordableShopBuys = affordableShopBuys(player, data),
		BoardRetireEssence = CollectionConfig.BoardRetireEssence or 80,
		BoardRetireEnabled = BalanceTrials.boardGlobalFusionIncome(),
		BoardHint = slotHint,
		SoftPinRelicId = softPin,
		Progress = progress,
		ResonanceStacks = state.ResonanceStacks,
		PendingResonance = state.PendingResonance,
		MutationGoalsClaimed = state.MutationGoalsClaimed,
		GoalProgress = goalProg,
		NextGoals = CollectionMath.nextUnclaimedGoals(state, progressCounts, 3),
		UnlockedAbilities = unlocked,
		FuseCandidates = fuseCandidates,
		CharmNeeded = charmNeeded,
		CharmNeededCards = charmNeededCards,
		BoardCharms = boardCharms,
		FuseReadyCount = #fuseCandidates,
		CharmNeededCount = #charmNeeded,
		HasFusedOnce = fusedCount > 0,
		AttuneCharges = state.AttuneCharges,
		AttuneScansLeft = state.AttuneScansLeft,
		AttuneChargeCap = state.AttuneChargeCap,
		EpicCatalysts = state.EpicCatalysts,
		TargetedAttuneTier = state.TargetedAttuneTier,
		FamilyAttune = state.FamilyAttune,
		Charms = CollectionConfig.Charms,
		Resonances = CollectionConfig.Resonances,
		Goals = CollectionConfig.MutationGoals,
		HasSalvage = CollectionService.HasUnlock(player, "SalvageFocus"),
		HasAttuneRecipe = CollectionService.HasUnlock(player, "AttuneTicketRecipe"),
		HasTargetedAttune = CollectionService.HasUnlock(player, "TargetedAttune"),
		HasCharmRespec = CollectionService.HasUnlock(player, "CharmRespec"),
		HasEpicCatalyst = CollectionService.HasUnlock(player, "EpicSalvageBoost"),
		HasFamilyAttune = CollectionService.HasUnlock(player, "FamilyAttune"),
		HasMutationFocus = CollectionService.HasUnlock(player, "MutationFocus"),
		MutationFocusScansLeft = state.MutationFocusScansLeft,
		HasQuickBind = CollectionService.HasUnlock(player, "QuickBind"),
		HasMutationTint = CollectionService.HasUnlock(player, "MutationTint"),
		ShrineCharm = CollectionService.ShrinePulseDue(player),
		ShrineCharmPulseSec = CollectionService.ShrinePulseSeconds(player),
		AscendHint = ascendHint,
		ActivePursuit = state.ActivePursuit,
		PursuitName = if pursuitRow then pursuitRow.Name else nil,
		PursuitSummary = if pursuitRow then pursuitRow.Summary else nil,
		PursuitOptions = pursuitOptions,
		RebirthPursuits = CollectionConfig.RebirthPursuits,
		HuntQuarryId = qUi.HuntQuarryId,
		HuntQuarryName = qUi.HuntQuarryName,
		HuntQuarryChosen = qUi.HuntQuarryChosen,
		HuntQuarryChosenName = qUi.HuntQuarryChosenName,
		HuntQuarryAutoSteer = qUi.HuntQuarryAutoSteer,
		HuntQuarryEligible = quarryEligible,
		HuntQuarryMult = CollectionMath.huntQuarryMult(),
		HuntQuarryNeedDetail = qUi.HuntQuarryNeedDetail,
		HuntQuarryUseful = qUi.HuntQuarryUseful,
		HuntQuarryNeedKind = qUi.HuntQuarryNeedKind,
		HuntQuarryRetargetSeconds = CollectionConfig.HuntQuarryRetargetSeconds or 3,
	}
end

local function trackCollection(player: Player, system: string, item: string, ok: boolean, msg: string?, kind: string?, price: number?, currency: string?)
	local Analytics = require(script.Parent.PlaytestAnalyticsService)
	Analytics.RecordClientActivity(player, "CollectionUI")
	Analytics.RecordPurchase(player, {
		System = system,
		Item = item,
		Price = price or 0,
		Currency = currency or "Essence",
		Ok = ok,
		Reason = msg,
		Kind = kind or (if ok then "Specialization" else "Failed"),
	})
	if ok then
		Analytics.RecordUnlockUsed(player, `{system}:{item}`)
	end
end

local function onAction(player: Player, action: any, a: any, b: any)
	if not DataService.Get(player) then
		return nil
	end
	if action == "Get" then
		CollectionService.TryDailyAttune(player)
		local Analytics = require(script.Parent.PlaytestAnalyticsService)
		Analytics.RecordClientActivity(player, "CollectionUI")
		return CollectionService.Snapshot(player)
	elseif action == "Open" then
		local Analytics = require(script.Parent.PlaytestAnalyticsService)
		Analytics.RecordClientActivity(player, "CollectionUI")
		Analytics.RecordCollectionFunnel(player, "CollectionOpen")
		return CollectionService.Snapshot(player)
	elseif action == "Close" then
		local Analytics = require(script.Parent.PlaytestAnalyticsService)
		Analytics.RecordCollectionFunnel(player, "CollectionClose")
		return true
	elseif action == "InspectRecipes" then
		local Analytics = require(script.Parent.PlaytestAnalyticsService)
		Analytics.RecordClientActivity(player, "CollectionUI")
		Analytics.RecordCollectionFunnel(player, "RecipeInspect", tostring(a or ""))
		return CollectionService.Snapshot(player)
	elseif action == "Fuse" then
		local relicId = tostring(a or "")
		local before = CollectionService.Get(player)
		local rankBefore = if before and before.Fusion[relicId] then before.Fusion[relicId].Rank else 0
		local relic = RelicConfig.ById[relicId]
		local price = if relic then CollectionMath.fusionEssenceCost(relic.Tier, rankBefore + 1) else 0
		local Analytics = require(script.Parent.PlaytestAnalyticsService)
		Analytics.RecordClientActivity(player, "CollectionUI")
		Analytics.RecordCollectionFunnel(player, "FuseAttempt", relicId)
		local ok, msg = CollectionService.TryFuse(player, relicId)
		local after = CollectionService.Get(player)
		local rankAfter = if after and after.Fusion[relicId] then after.Fusion[relicId].Rank else rankBefore
		Analytics.RecordPurchase(player, {
			System = "Fusion",
			Item = relicId,
			RankBefore = rankBefore,
			RankAfter = rankAfter,
			Price = if ok then price else 0,
			Currency = "Essence",
			Ok = ok,
			Reason = msg,
			Kind = if not ok then "Failed" elseif rankBefore == 0 then "Unlock" else "Routine",
		})
		if ok then
			Analytics.RecordCollectionFunnel(player, "FuseComplete", `{relicId}:r{rankAfter}`)
		else
			Analytics.RecordCollectionFunnel(player, "FuseFailed", `{relicId}:{msg or "failed"}`)
		end
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "SetCharm" then
		local ok, msg = CollectionService.SetCharm(player, tostring(a or ""), tostring(b or ""))
		-- Idempotent re-clicks must not look like new successes in analytics or UI funnels.
		local already = msg == "Charm already equipped."
		if not already then
			trackCollection(player, "Charm", `{a}:{b}`, ok, msg, if ok then "Specialization" else "Failed")
			local Analytics = require(script.Parent.PlaytestAnalyticsService)
			if ok then
				Analytics.RecordCollectionFunnel(player, "CharmEquip", `{a}:{b}`)
			else
				Analytics.RecordCollectionFunnel(player, "CharmFailed", `{a}:{b}:{msg or "failed"}`)
			end
		end
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player), AlreadyEquipped = already }
	elseif action == "RetireBoard" then
		local ok, msg = CollectionService.TryRetireBoard(player, tostring(a or ""))
		trackCollection(
			player,
			"RetireBoard",
			tostring(a or ""),
			ok,
			msg,
			if ok then "Specialization" else "Failed",
			if ok then (CollectionConfig.BoardRetireEssence or 80) else 0,
			"Essence"
		)
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "Pin" then
		CollectionService.SetPin(player, tostring(a or ""), b == true)
		return CollectionService.Snapshot(player)
	elseif action == "SetHuntQuarry" then
		local ok, msg = CollectionService.SetHuntQuarry(player, tostring(a or ""))
		trackCollection(player, "HuntQuarry", tostring(a or ""), ok, msg, if ok then "Decision" else "Failed")
		return { Ok = ok, Message = msg }
	elseif action == "SetBoardFocus" then
		local ok, msg = CollectionService.SetBoardFocus(player, tostring(a or ""))
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "ChooseResonance" then
		local ok, msg = CollectionService.ChooseResonance(player, tostring(a or ""), if b ~= nil then tostring(b) else nil)
		trackCollection(player, "Resonance", tostring(a or ""), ok, msg, if ok then "Specialization" else "Failed")
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "Salvage" then
		local mut = if type(b) == "string" and b ~= "" then b else nil
		local ok, msg = CollectionService.TrySalvage(player, tostring(a or ""), mut)
		trackCollection(player, "Salvage", tostring(a or ""), ok, msg, if ok then "Routine" else "Failed")
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "CraftAttune" then
		local ok, msg = CollectionService.CraftAttune(player)
		trackCollection(
			player,
			"Attune",
			"Craft",
			ok,
			msg,
			if ok then "Routine" else "Failed",
			CollectionConfig.AttuneTicketEssenceCost,
			"Essence"
		)
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "ActivateAttune" then
		local ok, msg = CollectionService.ActivateAttune(player)
		trackCollection(player, "Attune", "Activate", ok, msg, if ok then "Specialization" else "Failed")
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "CraftEpicCatalyst" then
		local ok, msg = CollectionService.CraftEpicCatalyst(player, tostring(a or ""))
		trackCollection(
			player,
			"EpicCatalyst",
			tostring(a or ""),
			ok,
			msg,
			if ok then "Unlock" else "Failed",
			CollectionConfig.EpicCatalyst.Essence,
			"Essence"
		)
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "CraftTargetedAttune" then
		local ok, msg = CollectionService.CraftTargetedAttune(player, tostring(a or "Common"))
		trackCollection(
			player,
			"TargetedAttune",
			tostring(a or "Common"),
			ok,
			msg,
			if ok then "Specialization" else "Failed",
			CollectionConfig.TargetedAttuneEssence,
			"Essence"
		)
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "SetFamilyAttune" then
		local ok, msg = CollectionService.SetFamilyAttune(player, tostring(a or ""))
		trackCollection(
			player,
			"FamilyAttune",
			tostring(a or ""),
			ok,
			msg,
			if ok then "Specialization" else "Failed",
			CollectionConfig.FamilyAttuneEssence,
			"Essence"
		)
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "UpgradeAttuneCap" then
		local ok, msg = CollectionService.UpgradeAttuneCap(player)
		trackCollection(
			player,
			"AttuneCap",
			"Upgrade",
			ok,
			msg,
			if ok then "Unlock" else "Failed",
			CollectionConfig.AttuneChargeUpgradeEssence,
			"Essence"
		)
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "CraftMutationFocus" then
		local ok, msg = CollectionService.CraftMutationFocus(player)
		trackCollection(
			player,
			"MutationFocus",
			"Craft",
			ok,
			msg,
			if ok then "Specialization" else "Failed",
			CollectionConfig.MutationFocusEssence,
			"Essence"
		)
		return { Ok = ok, Message = msg, State = CollectionService.Snapshot(player) }
	elseif action == "QuickBind" then
		local ok = CollectionService.TryQuickBind(player)
		trackCollection(player, "QuickBind", "Use", ok, if ok then "Quick Bind ready." else "On cooldown or locked.")
		return {
			Ok = ok,
			Message = if ok then "Quick Bind ready." else "On cooldown or locked.",
			State = CollectionService.Snapshot(player),
		}
	end
	return nil
end

local function mirror(player: Player)
	local state = CollectionService.Get(player)
	if not state then
		return
	end
	local on = enabled()
	player:SetAttribute("Essence", if on then state.Essence else nil)
	player:SetAttribute(
		"SeekerSightBonus",
		if on then CollectionMath.seekerSightBonus(state.ResonanceStacks.Seeker or 0) else nil
	)
	player:SetAttribute("PendingResonance", if on and state.PendingResonance then true else nil)
	player:SetAttribute("AttuneScansLeft", if on then state.AttuneScansLeft else nil)
	player:SetAttribute(
		"MutationTint",
		if on and CollectionService.HasUnlock(player, "MutationTint") then true else nil
	)
	player:SetAttribute("ShrineCharm", if on and CollectionService.ShrinePulseDue(player) then true else nil)
	player:SetAttribute(
		"ShrineCharmPulseSec",
		if on and CollectionService.ShrinePulseDue(player) then CollectionService.ShrinePulseSeconds(player) else nil
	)
	if on then
		local ready, charmNeed = CollectionService.ListFuseReady(player, 8)
		local readyCount = #ready
		local prevReady = player:GetAttribute("FuseReadyCount")
		player:SetAttribute("FuseReadyCount", readyCount)
		player:SetAttribute("CharmNeededCount", #charmNeed)
		local boardMult = CollectionService.BoardIncomeMult(player)
		player:SetAttribute("BoardIncomeMult", boardMult)
		local data = DataService.Get(player)
		local progress = CollectionService.ListFusionProgress(player, 8)
		local nextGoals = {}
		local fusedCount = CollectionMath.fusedCount(state)
		local slots = if data then CollectionMath.fusionSlots(state, data.Rebirths or 0) else 1
		if data then
			local uniqueMutated = 0
			local byMutation: { [string]: number } = {}
			for _, mutations in data.CodexMutations do
				if type(mutations) == "table" then
					local any = false
					for mutId in mutations do
						any = true
						byMutation[mutId] = (byMutation[mutId] or 0) + 1
					end
					if any then
						uniqueMutated += 1
					end
				end
			end
			local catalysts = 0
			for _ in state.EpicCatalysts do
				catalysts += 1
			end
			nextGoals = CollectionMath.nextUnclaimedGoals(state, {
				UniqueMutated = uniqueMutated,
				ByMutation = byMutation,
				EpicCatalysts = catalysts,
			}, 3)
		end
		local focusId = CollectionMath.resolveBoardFocusId(state)
		player:SetAttribute("BoardFocusId", focusId)
		local ascendHintHud = if BalanceTrials.boardGlobalFusionIncome() then buildAscendHint(player, state) else nil
		local pursuitHud = CollectionMath.pursuitConfig(state.ActivePursuit)
		local qUiHud = quarryUiFields(player, state)
		local coreLoop = BalanceTrials.coreLoopPresentation()
		local quarryEligibleHud = not coreLoop
			and CollectionMath.huntQuarryEligible(state)
			and BalanceTrials.raritySampler() == "SoftCap"
			and BalanceTrials.boardGlobalFusionIncome()
		local discoveredCount = 0
		if data and type(data.Discovered) == "table" then
			for _ in data.Discovered do
				discoveredCount += 1
			end
		end
		local obj = ProgressObjective.pick({
			Enabled = true,
			CoreLoopPresentation = coreLoop,
			DiscoveredCount = discoveredCount,
			CodexTotal = #RelicConfig.Relics,
			PendingResonance = if coreLoop then false else state.PendingResonance == true,
			CharmNeededCount = if coreLoop then 0 else #charmNeed,
			FuseReadyCount = if coreLoop then 0 else readyCount,
			BoardIncomeMult = boardMult,
			BoardGlobalIncome = BalanceTrials.boardGlobalFusionIncome(),
			FusedCount = fusedCount,
			FusionSlots = slots,
			BoardFocusId = if coreLoop then nil else focusId,
			Progress = if coreLoop then {} else progress,
			NextGoals = if coreLoop then {} else nextGoals,
			CE = if data then data.CE else nil,
			RebirthCost = if data
				then Rebirth.cost(BalanceTrials.rebirthSettings(Config.Rebirth), data.Rebirths or 0)
				else nil,
			Rebirths = if data then data.Rebirths or 0 else nil,
			IncomePerSec = EconomyService.GetIncomePerSec(player),
			AffordableShopBuys = if data then affordableShopBuys(player, data) else nil,
			Essence = state.Essence,
			HasAttuneRecipe = CollectionService.HasUnlock(player, "AttuneTicketRecipe"),
			AttuneCharges = state.AttuneCharges,
			AttuneScansLeft = state.AttuneScansLeft,
			AttuneTicketCost = CollectionConfig.AttuneTicketEssenceCost,
			AscendHint = if coreLoop then nil else ascendHintHud,
			ActivePursuit = if coreLoop then nil else state.ActivePursuit,
			PursuitName = if pursuitHud and not coreLoop then pursuitHud.Name else nil,
			PursuitSummary = if pursuitHud and not coreLoop then pursuitHud.Summary else nil,
			HuntQuarryEligible = quarryEligibleHud,
			HuntQuarryId = if coreLoop then nil else qUiHud.HuntQuarryId,
			HuntQuarryName = if coreLoop then nil else qUiHud.HuntQuarryName,
			HuntQuarryChosen = if coreLoop then nil else qUiHud.HuntQuarryChosen,
			HuntQuarryChosenName = if coreLoop then nil else qUiHud.HuntQuarryChosenName,
			HuntQuarryAutoSteer = if coreLoop then false else qUiHud.HuntQuarryAutoSteer,
			HuntQuarryNeedDetail = if coreLoop then nil else qUiHud.HuntQuarryNeedDetail,
			HuntQuarryUseful = if coreLoop then false else qUiHud.HuntQuarryUseful,
		})
		player:SetAttribute("NextObjectiveText", if obj then obj.Text else nil)
		player:SetAttribute("HuntQuarryId", if coreLoop then nil else qUiHud.HuntQuarryId)
		player:SetAttribute("HuntQuarryName", if coreLoop then nil else qUiHud.HuntQuarryName)
		player:SetAttribute("HuntQuarryChosen", if coreLoop then nil else qUiHud.HuntQuarryChosen)
		player:SetAttribute("HuntQuarryAutoSteer", if coreLoop then nil else qUiHud.HuntQuarryAutoSteer)
		player:SetAttribute("HuntQuarryNeedDetail", if coreLoop then nil else qUiHud.HuntQuarryNeedDetail)
		player:SetAttribute("HuntQuarryUseful", if coreLoop then nil else qUiHud.HuntQuarryUseful == true)
		player:SetAttribute("NextObjectiveDetail", if obj and obj.Detail then obj.Detail else nil)
		-- Hide Collection chip noise in Core Loop (Fusion ready / Charm prompts).
		if coreLoop then
			player:SetAttribute("FuseReadyCount", 0)
			player:SetAttribute("CharmNeededCount", 0)
		end
		if readyCount > 0 and (type(prevReady) ~= "number" or prevReady <= 0) then
			local Analytics = require(script.Parent.PlaytestAnalyticsService)
			local firstId = if ready[1] then ready[1].Id else nil
			Analytics.RecordCollectionFunnel(player, "FusionReady", firstId)
		end
	else
		player:SetAttribute("FuseReadyCount", nil)
		player:SetAttribute("CharmNeededCount", nil)
		player:SetAttribute("BoardIncomeMult", nil)
		player:SetAttribute("NextObjectiveText", nil)
		player:SetAttribute("NextObjectiveDetail", nil)
		player:SetAttribute("HuntQuarryId", nil)
		player:SetAttribute("HuntQuarryName", nil)
		player:SetAttribute("HuntQuarryChosen", nil)
		player:SetAttribute("HuntQuarryAutoSteer", nil)
		player:SetAttribute("HuntQuarryNeedDetail", nil)
		player:SetAttribute("HuntQuarryUseful", nil)
	end
end

function CollectionService.Init()
	RemoteGuard.Function(CollectionAction :: RemoteFunction, onAction, "Collection")
	GameEvents.On("Rebirthed", function(player: Player)
		CollectionService.OnRebirth(player)
		mirror(player)
	end)
	GameEvents.On("Discovery", function(player: Player)
		CollectionService.TryClaimMutationGoals(player)
	end)
	GameEvents.On("CollectionChanged", function(player: Player)
		mirror(player)
	end)
	DataService.OnPlayerLoaded(function(player)
		CollectionService.TryDailyAttune(player)
		mirror(player)
	end)
end

return CollectionService

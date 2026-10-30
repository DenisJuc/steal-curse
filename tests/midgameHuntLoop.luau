-- Hunt value validate: realistic Hunt shares vs FuseReady completion (not HUD %).
-- SoftCap_P5_Size frozen. Run: lune run tests/midgameHuntLoop

local BalanceTrials = require("../src/shared/BalanceTrials")
local CollectionConfig = require("../src/shared/CollectionConfig")
local CollectionMath = require("../src/shared/CollectionMath")
local ProgressObjective = require("../src/shared/ProgressObjective")
local RelicConfig = require("../src/shared/RelicConfig")
local SoftCapRarity = require("../src/shared/SoftCapRarity")
local SimRuntime = require("./lib/simRuntime")

BalanceTrials.AllowNonStudioActive = true
BalanceTrials.Active = "SoftCap_P5_Size"
BalanceTrials.CollectionPrototype = true
SoftCapRarity.syncFromTrials()
SoftCapRarity.invalidateSampler()

local RPM = 49
local QUARRY_MULT = CollectionConfig.HuntQuarryMult or 7
local SEED0 = 20261018
local HORIZONS_M = { 20, 60, 180 }
local HUNT_SHARES = { 0.01, 0.10, 0.20 }

local function rngFrom(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2 ^ 31
		return state / 2 ^ 31
	end
end

local function pickRelic(sampler, rng): (string, string)
	local target = rng() * sampler.Total
	local id, tier = sampler.Ids[#sampler.Ids], sampler.Tiers[#sampler.Tiers]
	local acc = 0
	for i = 1, #sampler.Weights do
		acc += sampler.Weights[i]
		if target < acc then
			return sampler.Ids[i], sampler.Tiers[i]
		end
	end
	return id, tier
end

local function runPolicy(minutes: number, seeds: number, huntShare: number)
	local rewards = math.floor(RPM * minutes)
	local agg = {
		unique = 0,
		huntAttempts = 0,
		usefulHits = 0,
		targetCopiesHunt = 0,
		targetCopiesScan = 0,
		minToTargetedHunt = 0,
		minToFuseReady = 0,
		minToFirstFuse = 0,
		minToRank2Ready = 0,
		completions = 0, -- first fuse + Rank2 fuse events
		huntObjTicks = 0,
		goalTicks = 0,
		boardMult = 0,
	}
	local nTargeted, nFuseReady, nFirstFuse, nRank2 = 0, 0, 0, 0

	for seed = 1, seeds do
		local rng = rngFrom(SEED0 + seed * 7919 + minutes * 17 + math.floor(huntShare * 1000))
		local discovered: { [string]: boolean } = {}
		local owned: { [string]: number } = {}
		local state = CollectionMath.defaults()
		state.FusionSlots = 2
		local softPin: string? = nil
		local targetedAt: number? = nil
		local fuseReadyAt: number? = nil
		local firstFuseAt: number? = nil
		local rank2ReadyAt: number? = nil
		local usefulHits = 0
		local huntAttempts = 0
		local targetHunt = 0
		local targetScan = 0
		local completions = 0
		local huntObjTicks = 0
		local goalTicks = 0
		local unique = 0

		local function luckAt(rewardIndex: number): number
			local m = rewardIndex / RPM
			return math.clamp(1 + 55 * math.log(1 + m / 12) / math.log(10), 1, 160)
		end

		local function relicMeta()
			local meta = {}
			for _, relic in RelicConfig.Relics do
				meta[relic.Id] = { Tier = relic.Tier, Name = relic.Name, Family = relic.Family }
			end
			return meta
		end

		for i = 1, rewards do
			local L = luckAt(i)
			local hunting = rng() < huntShare

			-- Soft-pin densest Common (realistic early target; not omniscient rare chase).
			do
				local bestId, bestN = nil, 0
				for rid, n in owned do
					local r = RelicConfig.ById[rid]
					if r and r.Tier == "Common" and n > bestN then
						bestId, bestN = rid, n
					end
				end
				softPin = bestId
			end

			local quarryId: string? = nil
			local suggested = CollectionMath.suggestHuntQuarry({
				State = state,
				OwnedBase = owned,
				OwnedMutated = {},
				Discovered = discovered,
				CodexMutCounts = {},
				RelicMeta = relicMeta(),
				SoftPinId = softPin,
			})
			if not state.HuntQuarryId then
				for rid, entry in state.Fusion do
					if (entry.Rank or 0) == 1 then
						state.HuntQuarryId = rid
						break
					end
				end
			end
			local chosenUseful = false
			local codexMut = {}
			for rid in state.Fusion do
				codexMut[rid] = 1 -- Board mut already "seen" so FuseCopies is the chase
			end
			if state.HuntQuarryId then
				local needC = CollectionMath.quarryNeed({
					State = state,
					RelicId = state.HuntQuarryId,
					TierId = if RelicConfig.ById[state.HuntQuarryId] then RelicConfig.ById[state.HuntQuarryId].Tier else nil,
					OwnedBase = owned[state.HuntQuarryId] or 0,
					OwnedMutated = 0,
					Discovered = discovered[state.HuntQuarryId] == true,
					CodexMutCount = codexMut[state.HuntQuarryId] or 0,
				})
				chosenUseful = needC.Useful == true
				-- Match server: don't trap on Mutation when FuseCopies suggest exists.
				if
					chosenUseful
					and (needC.Kind == "Mutation" or needC.Kind == "MutCodex")
					and type(suggested) == "string"
					and suggested ~= state.HuntQuarryId
				then
					chosenUseful = false
				end
				if not chosenUseful then
					state.HuntQuarryId = suggested
				end
			end
			quarryId = CollectionMath.resolveHuntQuarryId(state, softPin, suggested, chosenUseful)
			if quarryId and not targetedAt then
				local needQ = CollectionMath.quarryNeed({
					State = state,
					RelicId = quarryId,
					TierId = if RelicConfig.ById[quarryId] then RelicConfig.ById[quarryId].Tier else nil,
					OwnedBase = owned[quarryId] or 0,
					OwnedMutated = 0,
					Discovered = discovered[quarryId] == true,
					CodexMutCount = codexMut[quarryId] or 0,
				})
				if needQ.Useful then
					targetedAt = i / RPM
					nTargeted += 1
				end
			end

			if hunting then
				huntAttempts += 1
			end

			local sampler = if hunting and quarryId
				then SoftCapRarity.samplerFor(L, nil, nil, quarryId, QUARRY_MULT)
				else SoftCapRarity.samplerFor(L)
			local id, tier = pickRelic(sampler, rng)

			if quarryId and id == quarryId then
				if hunting then
					targetHunt += 1
					local need = CollectionMath.quarryNeed({
						State = state,
						RelicId = quarryId,
						TierId = tier,
						OwnedBase = owned[quarryId] or 0,
						OwnedMutated = 0,
						Discovered = discovered[quarryId] == true,
						CodexMutCount = if state.Fusion[quarryId] then 1 else 0,
					})
					if CollectionMath.quarryCaptureAdvances(need, false) then
						usefulHits += 1
					end
				else
					targetScan += 1
				end
			end

			if not discovered[id] then
				discovered[id] = true
				unique += 1
			end
			owned[id] = (owned[id] or 0) + 1

			-- FuseReady: 3 copies of soft-pin Common (Essence/UI not modeled — copy stockpile ETA).
			if not fuseReadyAt and softPin and (owned[softPin] or 0) >= CollectionMath.copiesForRank(1) and not state.Fusion[softPin] then
				fuseReadyAt = i / RPM
				nFuseReady += 1
			end

			-- Fuse when READY + ~45s Collection delay (not an 18s omniscient fusion loop).
			local function tryFuse(rid: string, nextRank: number): boolean
				local entry = state.Fusion[rid]
				local cur = if entry then (entry.Rank or 0) else 0
				if cur ~= nextRank - 1 then
					return false
				end
				local need = CollectionMath.copiesForRank(nextRank)
				local have = owned[rid] or 0
				if have < need then
					return false
				end
				if nextRank == 1 then
					state.Fusion[rid] = { Rank = 1, Charm = "Hunt" }
				else
					entry.Rank = nextRank
				end
				owned[rid] = have - CollectionMath.consumeForRank(nextRank)
				state.HuntQuarryId = rid
				completions += 1
				return true
			end

			if not firstFuseAt then
				if softPin and fuseReadyAt and (i / RPM) >= fuseReadyAt + 0.75 then
					if tryFuse(softPin, 1) then
						firstFuseAt = i / RPM
						nFirstFuse += 1
					end
				end
			else
				-- Rank 2 on first Board relic (FuseCopies — not Mutation).
				for rid, entry in state.Fusion do
					if (entry.Rank or 0) == 1 then
						local need = CollectionMath.copiesForRank(2)
						local have = owned[rid] or 0
						if not rank2ReadyAt and have >= need then
							rank2ReadyAt = i / RPM
							nRank2 += 1
						end
						if rank2ReadyAt and (i / RPM) >= rank2ReadyAt + 0.75 then
							if tryFuse(rid, 2) then
								-- Leave Rank3 mut chase (not modeled) — retarget slot-2 Common.
								state.HuntQuarryId = nil
							end
						end
					end
				end
				-- Slot 2: next densest unfused Common → ongoing FuseReady pursuits.
				if CollectionMath.fusedCount(state) < (state.FusionSlots or 2) then
					local pin2, n2 = nil, 0
					for rid, n in owned do
						local r = RelicConfig.ById[rid]
						if r and r.Tier == "Common" and not state.Fusion[rid] and n > n2 then
							pin2, n2 = rid, n
						end
					end
					if pin2 then
						state.HuntQuarryId = pin2
						local need1 = CollectionMath.copiesForRank(1)
						if n2 >= need1 then
							-- Stagger slot-2 fuse so Hunt stockpile window is measurable.
							local ready2 = i / RPM
							if (owned[pin2] or 0) >= need1 then
								-- fuse next tick windows via delay marker on state
								if type((state :: any)._slot2ReadyAt) ~= "number" then
									(state :: any)._slot2ReadyAt = ready2
								end
								if (i / RPM) >= ((state :: any)._slot2ReadyAt :: number) + 0.75 then
									if tryFuse(pin2, 1) then
										(state :: any)._slot2ReadyAt = nil
									end
								end
							end
						end
					end
				else
					-- Both slots filled: Rank2 upgrades on remaining Rank1.
					for rid, entry in state.Fusion do
						if (entry.Rank or 0) == 1 then
							local need = CollectionMath.copiesForRank(2)
							local have = owned[rid] or 0
							if have >= need then
								tryFuse(rid, 2)
							end
						end
					end
				end
			end

			if i % math.max(1, math.floor(RPM * 2)) == 0 then
				goalTicks += 1
				local progress = {}
				for rid, entry in state.Fusion do
					local relic = RelicConfig.ById[rid]
					local need = CollectionMath.copiesForRank((entry.Rank or 1) + 1)
					local have = owned[rid] or 0
					table.insert(progress, {
						Id = rid,
						Name = if relic then relic.Name else rid,
						Rank = entry.Rank,
						NextRank = (entry.Rank or 0) + 1,
						Owned = have,
						Need = need,
						Missing = math.max(0, need - have),
						Cost = 29,
						Ready = have >= need and (entry.Rank or 0) == 1,
						OnBoard = true,
					})
				end
				if softPin and not state.Fusion[softPin] then
					local relic = RelicConfig.ById[softPin]
					local have = owned[softPin] or 0
					local need = CollectionMath.copiesForRank(1)
					table.insert(progress, {
						Id = softPin,
						Name = if relic then relic.Name else softPin,
						Rank = 0,
						NextRank = 1,
						Owned = have,
						Need = need,
						Missing = math.max(0, need - have),
						Cost = 16,
						Ready = have >= need,
						SoftPin = true,
						OnBoard = false,
					})
				end
				local qName = if quarryId and RelicConfig.ById[quarryId] then RelicConfig.ById[quarryId].Name else nil
				local qNeed = if quarryId
					then CollectionMath.quarryNeed({
						State = state,
						RelicId = quarryId,
						TierId = if RelicConfig.ById[quarryId] then RelicConfig.ById[quarryId].Tier else nil,
						OwnedBase = owned[quarryId] or 0,
						OwnedMutated = 0,
						Discovered = discovered[quarryId] == true,
						CodexMutCount = if state.Fusion[quarryId] then 1 else 0,
					})
					else nil
				local obj = ProgressObjective.pick({
					Enabled = true,
					FusedCount = CollectionMath.fusedCount(state),
					FusionSlots = state.FusionSlots,
					BoardGlobalIncome = true,
					BoardIncomeMult = CollectionMath.boardIncomeMult(state),
					Progress = progress,
					HuntQuarryEligible = true,
					HuntQuarryId = quarryId,
					HuntQuarryName = qName,
					HuntQuarryUseful = qNeed ~= nil and qNeed.Useful == true,
					HuntQuarryNeedDetail = if qNeed then qNeed.Detail else nil,
				})
				if obj and obj.Kind == "HuntQuarry" then
					huntObjTicks += 1
				end
			end
		end

		agg.unique += unique
		agg.huntAttempts += huntAttempts
		agg.usefulHits += usefulHits
		agg.targetCopiesHunt += targetHunt
		agg.targetCopiesScan += targetScan
		agg.minToTargetedHunt += targetedAt or minutes
		agg.minToFuseReady += fuseReadyAt or minutes
		agg.minToFirstFuse += firstFuseAt or minutes
		agg.minToRank2Ready += rank2ReadyAt or minutes
		agg.completions += completions
		agg.huntObjTicks += huntObjTicks
		agg.goalTicks += goalTicks
		agg.boardMult += CollectionMath.boardIncomeMult(state)
	end

	local function avg(key: string): number
		return (agg :: any)[key] / seeds
	end
	local hours = minutes / 60
	return {
		Minutes = minutes,
		HuntShare = huntShare,
		Seeds = seeds,
		Unique = avg("unique"),
		HuntAttempts = avg("huntAttempts"),
		UsefulHits = avg("usefulHits"),
		TargetHunt = avg("targetCopiesHunt"),
		TargetScan = avg("targetCopiesScan"),
		MinToTargetedHunt = avg("minToTargetedHunt"),
		MinToFuseReady = avg("minToFuseReady"),
		MinToFirstFuse = avg("minToFirstFuse"),
		MinToRank2Ready = avg("minToRank2Ready"),
		CompletionsPerHour = avg("completions") / hours,
		HuntObjShare = if avg("goalTicks") > 0 then avg("huntObjTicks") / (agg.goalTicks / seeds) else 0,
		BoardMult = avg("boardMult"),
		PctTargeted = nTargeted / seeds,
		PctFuseReady = nFuseReady / seeds,
		PctFirstFuse = nFirstFuse / seeds,
		PctRank2Ready = nRank2 / seeds,
		HuntHitRate = if avg("huntAttempts") > 0 then avg("targetCopiesHunt") / avg("huntAttempts") else 0,
		ScanHitRate = if (rewards - avg("huntAttempts")) > 0
			then avg("targetCopiesScan") / math.max(1, rewards - avg("huntAttempts"))
			else 0,
	}
end

local timer = SimRuntime.start("midgameHuntLoop")
print("=== Hunt value (SoftCap_P5_Size) — completion, not HUD% ===")
print(`RPM={RPM} QuarryMult={QUARRY_MULT} shares=1%/10%/20%\n`)

assert(CollectionMath.huntQuarryEligible(CollectionMath.defaults()) == true, "always eligible")
assert(QUARRY_MULT >= 6, "meaningful quarry mult")

for _, minutes in HORIZONS_M do
	local seeds = if minutes <= 20 then 28 elseif minutes <= 60 then 18 else 12
	print(`--- {minutes}m ×{seeds} seeds ---`)
	local scanOnly = runPolicy(minutes, seeds, 0)
	print(string.format(
		"  Scan 0%%   fuseReady=%.2fm  firstFuse=%.2fm  rank2Ready=%.2fm  complete/h=%.2f  unique=%.1f  board×%.2f",
		scanOnly.MinToFuseReady,
		scanOnly.MinToFirstFuse,
		scanOnly.MinToRank2Ready,
		scanOnly.CompletionsPerHour,
		scanOnly.Unique,
		scanOnly.BoardMult
	))
	for _, share in HUNT_SHARES do
		local r = runPolicy(minutes, seeds, share)
		local frSpeed = if r.MinToFuseReady > 0 then scanOnly.MinToFuseReady / r.MinToFuseReady else 0
		print(string.format(
			"  Hunt %2.0f%%  targeted@%.2fm  attempts=%.0f  useful=%.1f  tgtH=%.1f tgtS=%.1f  hitRate H/S=%.1f%%/%.1f%%",
			share * 100,
			r.MinToTargetedHunt,
			r.HuntAttempts,
			r.UsefulHits,
			r.TargetHunt,
			r.TargetScan,
			r.HuntHitRate * 100,
			r.ScanHitRate * 100
		))
		print(string.format(
			"           fuseReady=%.2fm (×%.2f vs Scan)  firstFuse=%.2fm  rank2Ready=%.2fm  complete/h=%.2f  huntHUD=%.0f%%  unique=%.1f",
			r.MinToFuseReady,
			frSpeed,
			r.MinToFirstFuse,
			r.MinToRank2Ready,
			r.CompletionsPerHour,
			r.HuntObjShare * 100,
			r.Unique
		))
	end
	print()
end

SimRuntime.mark(timer, "done")
print(SimRuntime.report(timer))
print("Done.")

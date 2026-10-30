-- Single next gameplay objective from authoritative Collection/Rebirth facts.
-- Pure: Lune + server Snapshot + HUD mirror. No fake quests or timers.

local CollectionConfig = require("./CollectionConfig")
local CollectionMath = require("./CollectionMath")

local ProgressObjective = {}

export type Objective = {
	Id: string,
	Kind: string,
	Text: string,
	Detail: string?,
	RelicId: string?,
}

export type Input = {
	Enabled: boolean?,
	PendingResonance: boolean?,
	CharmNeededCount: number?,
	FuseReadyCount: number?,
	BoardIncomeMult: number?,
	BoardGlobalIncome: boolean?,
	FusedCount: number?,
	FusionSlots: number?,
	BoardFocusId: string?,
	-- Progress cards from ListFusionProgress / Snapshot.Progress
	Progress: {
		{
			Id: string,
			Name: string,
			Rank: number,
			NextRank: number,
			Owned: number,
			Need: number,
			Missing: number,
			Cost: number,
			Ready: boolean,
			BlockKind: string?,
			BlockReason: string?,
			OnBoard: boolean?,
			CurrentIncomeMult: number?,
			NextIncomeMult: number?,
			SoftPin: boolean?,
			HasMutated: boolean?,
			NeedsMutation: boolean?,
			Charm: string?,
			OnPedestal: boolean?,
		}
	}?,
	NextGoals: {
		{
			Id: string,
			Name: string,
			Summary: string,
			Progress: number,
			Required: number,
			Claimed: boolean?,
		}
	}?,
	-- Optional economy / rebirth context
	CE: number?,
	RebirthCost: number?,
	Rebirths: number?,
	-- Pedestal income CE/sec (honest ETA toward Rebirth).
	IncomePerSec: number?,
	-- 0 = no affordable skill/pedestal shop buys left (upgrades exhausted).
	AffordableShopBuys: number?,
	-- Midgame Collection sinks (Attune after ThreeMutated)
	Essence: number?,
	HasAttuneRecipe: boolean?,
	AttuneCharges: number?,
	AttuneScansLeft: number?,
	AttuneTicketCost: number?,
	-- SoftCap_P4 Phase 7: Retire→Fuse higher-tier Charm lineage after Board Lift caps
	AscendHint: {
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
	}?,
	-- SoftCap_P4 Phase 7.1: Rebirth Pursuit for this life
	ActivePursuit: string?,
	PursuitName: string?,
	PursuitSummary: string?,
	-- SoftCap Hunt Quarry (exact-relic chase on binds; soft-pin pre-Board + recipes)
	HuntQuarryEligible: boolean?,
	HuntQuarryId: string?,
	HuntQuarryName: string?,
	HuntQuarryChosen: string?,
	HuntQuarryChosenName: string?,
	HuntQuarryAutoSteer: boolean?,
	HuntQuarryNeedDetail: string?,
	HuntQuarryUseful: boolean?,
	-- Studio Core Loop: seal / index / equip / upgrades / Rebirth only (hide Fusion/Quarry/Attune).
	CoreLoopPresentation: boolean?,
	DiscoveredCount: number?,
	CodexTotal: number?,
}

local function liftLine(input: Input): string?
	if input.BoardGlobalIncome and type(input.BoardIncomeMult) == "number" and (input.FusedCount or 0) > 0 then
		local cur = input.BoardIncomeMult
		local nextM = nil
		for _, card in input.Progress or {} do
			local onBoard = card.OnBoard == true or (card.Rank or 0) > 0
			if onBoard and card.NextIncomeMult and card.NextIncomeMult > cur + 1e-9 then
				nextM = card.NextIncomeMult
				break
			end
		end
		if nextM then
			return `Board income ×{string.format("%.2f", cur)} → next ×{string.format("%.2f", nextM)}`
		end
		return `Board income ×{string.format("%.2f", cur)}`
	end
	return nil
end

local function pickCoreLoop(input: Input): Objective?
	-- Rebirth ready
	if type(input.CE) == "number" and type(input.RebirthCost) == "number" and input.CE + 1e-9 >= input.RebirthCost then
		local n = (input.Rebirths or 0) + 1
		return {
			Id = "Rebirth",
			Kind = "Rebirth",
			Text = `Rebirth {n} ready — permanent income & luck`,
			Detail = "Open Rebirth. Keep sealing after — rarer curses pay more on pedestals.",
		}
	end

	-- Shop still has affordable buys
	if type(input.AffordableShopBuys) == "number" and input.AffordableShopBuys > 0 then
		return {
			Id = "Upgrades",
			Kind = "Upgrade",
			Text = "Buy Luck & pedestal upgrades",
			Detail = "Spend Cursed Energy on Core Luck and pedestals — then seal again.",
		}
	end

	-- Saving toward Rebirth (CE shop quiet)
	if type(input.CE) == "number" and type(input.RebirthCost) == "number" then
		local frac = input.CE / math.max(1, input.RebirthCost)
		if frac >= 0.15 then
			local need = math.max(0, input.RebirthCost - input.CE)
			local rate = if type(input.IncomePerSec) == "number" then input.IncomePerSec else 0
			local eta = if rate > 1e-9 then need / rate else math.huge
			local etaText = if eta == math.huge then "…" else `{math.max(1, math.ceil(eta / 60))}m`
			return {
				Id = "RebirthSave",
				Kind = "RebirthSave",
				Text = `Save for Rebirth ({string.format("%.0f", frac * 100)}%)`,
				Detail = `~{etaText} at current income · Keep sealing and equipping stronger finds.`,
			}
		end
	end

	local discovered = input.DiscoveredCount or 0
	local total = input.CodexTotal or 0
	if total > 0 and discovered < total then
		return {
			Id = "Index",
			Kind = "Scan",
			Text = `Seal curses — Index {discovered}/{total}`,
			Detail = "Equip strong finds on pedestals. Rarer seals boost income; Luck improves odds.",
		}
	end

	return {
		Id = "Seal",
		Kind = "Scan",
		Text = "Keep sealing — chase rarer curses",
		Detail = "Equip better relics. Buy Luck when you can. Rebirth when it becomes the goal.",
	}
end

function ProgressObjective.pick(input: Input): Objective?
	if not input.Enabled then
		return nil
	end

	if input.CoreLoopPresentation == true then
		return pickCoreLoop(input)
	end

	if input.PendingResonance then
		return {
			Id = "Resonance",
			Kind = "Resonance",
			Text = "Choose Resonance + this life's Pursuit",
			Detail = "Collector / Binder / Seeker stack permanently. Pursuit (Family Hunt / Mutation Ledger / Epic Lineage) sets this life's Collection goal.",
		}
	end

	if (input.CharmNeededCount or 0) > 0 then
		return {
			Id = "Charm",
			Kind = "Charm",
			Text = "USE — pick a Charm for your fused relic",
			Detail = "Hunt: pedestal → family hunt bias. Workshop: dupe Essence (no pedestal). Shrine: pedestal → spirit pulse. One of each on the Board.",
		}
	end

	local focusId = input.BoardFocusId

	-- Prefer ready fuse on BoardFocusId, then any ready.
	local function readyObjective(card: any): Objective
		local isUpgrade = (card.Rank or 0) > 0
		local nextMult = card.NextIncomeMult or CollectionMath.fusionIncomeMult(card.NextRank or 1)
		local detail = `{card.Owned}/{card.Need} copies · {card.Cost} Essence`
		if card.NeedsMutation then
			detail ..= if card.HasMutated then " · Mutated: yes" else " · Mutated: need 1"
		end
		return {
			Id = if isUpgrade then "FuseUpgrade" else "FuseNew",
			Kind = "FuseReady",
			Text = if isUpgrade
				then `Upgrade {card.Name} to Rank {card.NextRank} (×{string.format("%.2f", nextMult)})`
				else `Fuse {card.Name} — first Board entry`,
			Detail = detail,
			RelicId = card.Id,
		}
	end
	if focusId then
		for _, card in input.Progress or {} do
			if card.Id == focusId and card.Ready then
				return readyObjective(card)
			end
		end
	end
	for _, card in input.Progress or {} do
		if card.Ready then
			return readyObjective(card)
		end
	end

	-- After FuseReady: one visible Hunt goal when Quarry has a useful chase (binds ×mult).
	local function huntQuarryObjective(extraDetail: string?): Objective?
		if
			input.HuntQuarryEligible ~= true
			or type(input.HuntQuarryName) ~= "string"
			or input.HuntQuarryUseful ~= true
		then
			return nil
		end
		local mult = CollectionConfig.HuntQuarryMult or 7
		local chosen = type(input.HuntQuarryChosen) == "string" and input.HuntQuarryChosen ~= ""
		local autoSteer = input.HuntQuarryAutoSteer == true
			or (
				chosen
				and type(input.HuntQuarryId) == "string"
				and input.HuntQuarryChosen ~= input.HuntQuarryId
			)
		local chosenName = if type(input.HuntQuarryChosenName) == "string" and input.HuntQuarryChosenName ~= ""
			then input.HuntQuarryChosenName
			else input.HuntQuarryChosen
		local why = extraDetail or input.HuntQuarryNeedDetail or "advances Board / Codex"
		local suffix = if autoSteer
			then ` · Auto-steer (your pick {chosenName or "?"} done) · AFK Scan unchanged`
			elseif chosen then " · Your pick · AFK Scan unchanged"
			else " · Auto chase · AFK Scan unchanged"
		return {
			Id = "HuntQuarry",
			Kind = "HuntQuarry",
			Text = `Hunt {input.HuntQuarryName} — wild binds ×{string.format("%.1f", mult)}`,
			Detail = `{why}{suffix}`,
			RelicId = input.HuntQuarryId,
		}
	end
	do
		local hq = huntQuarryObjective(nil)
		if hq then
			return hq
		end
	end

	local function rebirthSaveObjective(minFraction: number): Objective?
		if input.AffordableShopBuys ~= 0 then
			return nil
		end
		if type(input.CE) ~= "number" or type(input.RebirthCost) ~= "number" then
			return nil
		end
		if input.CE + 1e-9 >= input.RebirthCost then
			return nil
		end
		if input.CE + 1e-9 < input.RebirthCost * minFraction then
			return nil
		end
		local need = math.max(0, input.RebirthCost - input.CE)
		local rate = if type(input.IncomePerSec) == "number" then input.IncomePerSec else 0
		local eta = if rate > 1e-9 then need / rate else math.huge
		local etaText = if eta == math.huge
			then "raise pedestal CE/s to estimate time"
			elseif eta < 60
			then `~{math.max(1, math.ceil(eta))}s at current income`
			elseif eta < 3600
			then `~{math.ceil(eta / 60)} min at current income`
			else `~{string.format("%.1f", eta / 3600)} h at current income`
		local function short(n: number): string
			if n >= 1e9 then
				return string.format("%.2fB", n / 1e9)
			elseif n >= 1e6 then
				return string.format("%.1fM", n / 1e6)
			elseif n >= 1e3 then
				return string.format("%.1fK", n / 1e3)
			end
			return string.format("%.0f", n)
		end
		return {
			Id = "RebirthSave",
			Kind = "RebirthSave",
			Text = `Save for Rebirth — {short(input.CE)} / {short(input.RebirthCost)} CE`,
			Detail = `{etaText} · shop upgrades maxed · cost stays {short(input.RebirthCost)} CE`,
		}
	end

	local freeSlots = math.max(0, (input.FusionSlots or 1) - (input.FusedCount or 0))

	local function attuneObjective(): Objective?
		if input.HasAttuneRecipe ~= true then
			return nil
		end
		local cost = input.AttuneTicketCost or CollectionConfig.AttuneTicketEssenceCost or 75
		if (input.AttuneScansLeft or 0) > 0 then
			return {
				Id = "AttuneActive",
				Kind = "Attune",
				Text = "Attune active — keep scanning for Focused Commons",
				Detail = `{input.AttuneScansLeft} Focused scans left · feed Board copies / Rank upgrades`,
			}
		elseif (input.AttuneCharges or 0) > 0 then
			return {
				Id = "AttuneUse",
				Kind = "Attune",
				Text = "Use Attune (Collection Advanced) for Focused Commons",
				Detail = `{input.AttuneCharges} ticket(s) ready · midgame copy hunt while the CE shop is thin`,
			}
		elseif type(input.Essence) == "number" and input.Essence + 1e-9 >= cost then
			return {
				Id = "AttuneCraft",
				Kind = "Attune",
				Text = "Craft an Attune ticket — Focused Common scans",
				Detail = `{cost} Essence · Collection Advanced · spend Essence when upgrades run out`,
			}
		end
		return nil
	end

	-- Free Board slots → Charm lineages. Prefer Hunt Quarry when it already targets that
	-- stockpile (active play); otherwise keep fuse-when-ready copy chase.
	if freeSlots > 0 then
		local bestNew: any = nil
		local bestNewScore = -1e9
		for _, card in input.Progress or {} do
			if card.Ready then
				continue
			end
			local isNew = not card.OnBoard or (card.Rank or 0) <= 0
			if not isNew or (card.Owned or 0) < 2 then
				continue
			end
			if card.BlockKind == "Board" then
				continue
			end
			local score = (card.Owned / math.max(1, card.Need)) * 100 + (if card.SoftPin then 20 else 0)
			if score > bestNewScore then
				bestNewScore = score
				bestNew = card
			end
		end
		if bestNew then
			local detail = bestNew.BlockReason
				or `Need {bestNew.Missing or 0} more {bestNew.Name} ({bestNew.Owned}/{bestNew.Need}) · {bestNew.Cost} Essence · Empty Board slot → Charm (Workshop Essence / Hunt / Shrine)`
			return {
				Id = "FuseProgress",
				Kind = "FuseProgress",
				Text = `Fill Board slot: fuse {bestNew.Name} for a Charm`,
				Detail = detail,
				RelicId = bestNew.Id,
			}
		end
	end

	local function ascendObjective(): Objective?
		local h = input.AscendHint
		if type(h) ~= "table" or type(h.Charm) ~= "string" then
			return nil
		end
		if not input.BoardGlobalIncome then
			return nil
		end
		local cap = CollectionConfig.FusionIncomeMultByRank[3] or 1.5
		if (input.BoardIncomeMult or 0) + 1e-9 < cap then
			return nil
		end
		if h.Ready == true then
			return {
				Id = "CharmAscendReady",
				Kind = "CharmAscend",
				Text = `Ascend {h.Charm}: Retire {h.CurrentName} → Fuse {h.TargetName}`,
				Detail = `{h.CurrentTier} potency ×{string.format("%.2f", h.CurrentPotency)} → {h.TargetTier} ×{string.format("%.2f", h.TargetPotency)} · −{h.RetireCost}+{h.EssenceCost} Essence (Board income stays ×{string.format("%.2f", cap)})`,
				RelicId = h.TargetRelicId,
			}
		end
		if (h.Owned or 0) >= 1 or (h.Missing or 99) <= 2 then
			return {
				Id = "CharmAscendHunt",
				Kind = "CharmAscend",
				Text = `Collect {h.TargetTier} {h.TargetName} to ascend {h.Charm}`,
				Detail = `{h.Owned}/{h.Need} copies · Retire {h.CurrentName} (−{h.RetireCost} Ess) · {h.Charm} potency ×{string.format("%.2f", h.CurrentPotency)}→×{string.format("%.2f", h.TargetPotency)}`,
				RelicId = h.TargetRelicId,
			}
		end
		return nil
	end

	-- SoftCap_P4 Phase 7: after Board Lift caps, ascending Charm lineages beats Rank3 busywork.
	do
		local asc = ascendObjective()
		if asc then
			return asc
		end
	end

	-- Full Board + Rank3 mutation wait: Attune is the actionable midgame spend (not passive CE).
	if freeSlots <= 0 then
		local mutDrought = false
		for _, card in input.Progress or {} do
			if card.OnBoard and (card.BlockKind == "Mutation" or (card.NeedsMutation and not card.HasMutated)) then
				mutDrought = true
				break
			end
		end
		if mutDrought then
			local att = attuneObjective()
			if att then
				return att
			end
		end
	end

	-- Closest incomplete fuse (prefer BoardFocusId / Rank3 Board upgrade / soft-pin).
	local best: any = nil
	local bestScore = -1e9
	for _, card in input.Progress or {} do
		if card.Ready then
			continue
		end
		local frac = card.Owned / math.max(1, card.Need)
		local score = frac * 100
		if card.OnBoard then
			score += 40
		end
		if focusId and card.Id == focusId then
			score += 80
		end
		if card.OnBoard and (card.Rank or 0) == 2 then
			score += 30
		end
		if card.SoftPin then
			score += 25
		end
		if card.BlockKind == "Essence" then
			score += 15
		end
		if card.BlockKind == "Mutation" then
			score += 20
		end
		if score > bestScore then
			bestScore = score
			best = card
		end
	end
	if best then
		local nextMult = best.NextIncomeMult or CollectionMath.fusionIncomeMult(best.NextRank or 1)
		local detail = best.BlockReason
		if not detail then
			if best.BlockKind == "Mutation" or (best.NeedsMutation and not best.HasMutated) then
				detail = `Need a mutated {best.Name} · {best.Owned}/{best.Need} base · {best.Cost} Essence → ×{string.format("%.2f", nextMult)}`
				if best.Charm == "Hunt" and best.OnPedestal ~= true then
					detail ..= " · Hunt Charm: equip this relic on a pedestal for family bias + match Essence"
				elseif best.Charm == "Hunt" then
					detail ..= " · Hunt Charm active — hunt this family for bias + Essence"
				end
			elseif (best.Missing or 0) > 0 then
				detail = `Need {best.Missing} more {best.Name} ({best.Owned}/{best.Need}) · {best.Cost} Essence`
			elseif best.BlockKind == "Essence" then
				detail = `Need {best.Cost} Essence · {best.Owned}/{best.Need} copies`
			elseif best.BlockKind == "Board" then
				detail = "Board full — upgrade in place or unlock a slot (First Golden)"
			else
				detail = `{best.Owned}/{best.Need} copies · {best.Cost} Essence`
			end
		end
		local text = if best.OnBoard and (best.Rank or 0) == 2
			then `Rank 3 on {best.Name} (×{string.format("%.2f", nextMult)})`
			elseif best.OnBoard
			then `Get Rank {best.NextRank} on {best.Name}`
			else `Collect for first fuse: {best.Name}`
		return {
			Id = "FuseProgress",
			Kind = "FuseProgress",
			Text = text,
			Detail = detail,
			RelicId = best.Id,
		}
	end

	-- Mutation / board-slot goals
	if type(input.NextGoals) == "table" and #input.NextGoals > 0 then
		local g = input.NextGoals[1]
		local left = math.max(0, (g.Required or 1) - (g.Progress or 0))
		return {
			Id = g.Id,
			Kind = "MutationGoal",
			Text = `{g.Name} ({g.Progress}/{g.Required})`,
			Detail = if left > 0 then `{g.Summary} — {left} more` else g.Summary,
		}
	end

	-- Rebirth when affordable (meaningful unlock beat)
	if type(input.CE) == "number" and type(input.RebirthCost) == "number" and input.CE + 1e-9 >= input.RebirthCost then
		local n = (input.Rebirths or 0) + 1
		return {
			Id = "Rebirth",
			Kind = "Rebirth",
			Text = `Rebirth {n} ready — permanent income & luck`,
			Detail = "Open Rebirth. SoftCap keeps skills, pedestals, and Fusion (B+).",
		}
	end

	-- Midgame: Attune sink when CE shop is quiet (no fuse cards / goals left).
	do
		local att = attuneObjective()
		if att then
			return att
		end
	end

	-- SoftCap_P4 Phase 7.1: active Rebirth Pursuit keeps post-R1 sessions directed.
	if type(input.ActivePursuit) == "string" and type(input.PursuitName) == "string" then
		return {
			Id = "Pursuit",
			Kind = "Pursuit",
			Text = `This life: {input.PursuitName}`,
			Detail = input.PursuitSummary
				or "Finish this Pursuit before the next Rebirth — or switch goals next life.",
		}
	end

	-- Empty early game (no soft-pin progress cards yet)
	if (input.FusedCount or 0) <= 0 then
		local huntHint = if input.HuntQuarryEligible == true
			then "Hunt the wild for your pinned Common (binds bias it), or Scan — then Fuse."
			else "Auto-sell keeps your closest fusion target. Open Collection when READY."
		return {
			Id = "FirstFuse",
			Kind = "Scan",
			Text = "Get 3 copies of one Common, then Fuse",
			Detail = huntHint,
		}
	end

	-- CE shop exhausted + no other goals: honest Rebirth savings (400M unchanged; ETA from income).
	do
		local save = rebirthSaveObjective(0)
		if save then
			return save
		end
	end

	return {
		Id = "Explore",
		Kind = "Explore",
		Text = "Hunt rarer lineages to ascend Board Charms (Retire → Fuse)",
		Detail = liftLine(input)
			or "Board income is capped — higher-tier Hunt/Workshop/Shrine lineages still get stronger. Wild captures grant Collection Essence.",
	}
end

function ProgressObjective.boardStatusLine(input: Input): string
	local lift = liftLine(input)
	local slots = `{input.FusedCount or 0}/{input.FusionSlots or CollectionConfig.StartingFusionSlots or 1}`
	if lift then
		return `{lift} · Board {slots}`
	end
	return `Board {slots}`
end

return ProgressObjective

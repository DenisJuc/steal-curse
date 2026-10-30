-- Client reward presentation classification (pure). Does not change server grants or odds.
-- Routine Common/Uncommon Normal duplicates collapse into one currency summary.
-- Exceptional finds (new base, new mutation, new size, Huge/Titanic, Epic+) stay individual.

local SizeConfig = if script ~= nil then require(script.Parent.SizeConfig) else require("./SizeConfig")

local RewardPresentation = {}

export type Kind = "Routine" | "Notable" | "Exceptional"

export type Result = {
	Uid: number?,
	Id: string,
	Mutation: string?,
	Size: string?,
	Source: string?,
	First: boolean?,
	NewVariant: boolean?,
	NewSize: boolean?,
	Sold: number?,
	SoldReason: string?,
	Tier: string?, -- optional; when omitted, callers pass tier via relicTier()
}

export type Classified = {
	Result: Result,
	Kind: Kind,
	Reason: string,
}

export type FeedPlan = {
	Exceptional: { Result },
	Notable: { Result },
	RoutineCount: number,
	RoutineSoldCount: number,
	RoutineSoldCE: number,
	RoutineKeptCount: number,
	-- One summary line for all routines (nil when RoutineCount == 0).
	RoutineSummaryTitle: string?,
	RoutineSummarySubtitle: string?,
}

local EPIC_PLUS = {
	Epic = true,
	Legendary = true,
	Mythic = true,
	Celestial = true,
	Cosmic = true,
}

function RewardPresentation.isOrdinaryDupe(result: Result, tier: string?): boolean
	if result.First or result.NewVariant or result.NewSize or result.Mutation then
		return false
	end
	if SizeConfig.normalize(result.Size) then
		return false
	end
	return tier == "Common" or tier == "Uncommon"
end

function RewardPresentation.classify(result: Result, tier: string?): Classified
	local sizeId = SizeConfig.normalize(result.Size)
	if result.First == true then
		return { Result = result, Kind = "Exceptional", Reason = "NewBase" }
	end
	if result.NewSize == true or sizeId == "Titanic" then
		return { Result = result, Kind = "Exceptional", Reason = if sizeId == "Titanic" then "Titanic" else "NewSize" }
	end
	if result.NewVariant == true then
		return { Result = result, Kind = "Exceptional", Reason = "NewMutation" }
	end
	if sizeId == "Huge" then
		return { Result = result, Kind = "Exceptional", Reason = "Huge" }
	end
	if tier and EPIC_PLUS[tier] then
		return { Result = result, Kind = "Exceptional", Reason = "HighRarity" }
	end
	if result.Mutation ~= nil then
		return { Result = result, Kind = "Notable", Reason = "MutationDupe" }
	end
	if tier == "Rare" then
		return { Result = result, Kind = "Notable", Reason = "Rare" }
	end
	if RewardPresentation.isOrdinaryDupe(result, tier) then
		return { Result = result, Kind = "Routine", Reason = "OrdinaryDupe" }
	end
	return { Result = result, Kind = "Notable", Reason = "Other" }
end

function RewardPresentation.worthKeeping(result: Result, tier: string?, incomeMult: number?): string
	local sizeId = SizeConfig.normalize(result.Size)
	if result.First then
		return "New Codex entry — kept for your collection"
	end
	if result.NewSize and sizeId then
		return `First {sizeId} stamp — keep 1 · pedestal income ×{incomeMult or SizeConfig.incomeMult(sizeId)}`
	end
	if sizeId == "Titanic" then
		return `Titanic — keep 1 · pedestal income ×{incomeMult or SizeConfig.IncomeMult.Titanic}`
	end
	if sizeId == "Huge" then
		return `Huge — keep 1 · pedestal income ×{incomeMult or SizeConfig.IncomeMult.Huge}`
	end
	if result.NewVariant and result.Mutation then
		return `New {result.Mutation} mutation — Codex variant`
	end
	if result.Mutation then
		return `{result.Mutation} variant — higher pedestal income`
	end
	if tier and EPIC_PLUS[tier] then
		return `{tier} find — strong pedestal income`
	end
	if tier == "Rare" then
		return "Rare find — worth a pedestal check"
	end
	return ""
end

-- Collapse a batch into feed slots: routines → 1 summary; exceptionals + notables listed.
function RewardPresentation.planFeed(results: { Result }, tierOf: (Result) -> string?): FeedPlan
	local exceptional = {}
	local notable = {}
	local routineCount, soldCount, soldCE, kept = 0, 0, 0, 0
	for _, result in results do
		local tier = tierOf(result) or result.Tier
		local c = RewardPresentation.classify(result, tier)
		if c.Kind == "Routine" then
			routineCount += 1
			if type(result.Sold) == "number" and result.Sold > 0 then
				soldCount += 1
				soldCE += result.Sold
			else
				kept += 1
			end
		elseif c.Kind == "Exceptional" then
			table.insert(exceptional, result)
		else
			table.insert(notable, result)
		end
	end
	local title: string? = nil
	local subtitle: string? = nil
	if routineCount > 0 then
		if soldCount > 0 and kept > 0 then
			title = `· {routineCount} common finds`
			subtitle = `+{math.floor(soldCE + 0.5)} CE sold · {kept} kept`
		elseif soldCount > 0 then
			title = `· +{math.floor(soldCE + 0.5)} CE`
			subtitle = `{soldCount} common duplicate{if soldCount == 1 then "" else "s"} sold`
		else
			title = `· {routineCount} common kept`
			subtitle = "duplicates — backpack / auto-sell"
		end
	end
	return {
		Exceptional = exceptional,
		Notable = notable,
		RoutineCount = routineCount,
		RoutineSoldCount = soldCount,
		RoutineSoldCE = soldCE,
		RoutineKeptCount = kept,
		RoutineSummaryTitle = title,
		RoutineSummarySubtitle = subtitle,
	}
end

-- Counts for automated before/after validation (no UI).
function RewardPresentation.countKinds(results: { Result }, tierOf: (Result) -> string?): { Routine: number, Notable: number, Exceptional: number, FeedLines: number }
	local plan = RewardPresentation.planFeed(results, tierOf)
	local feedLines = #plan.Exceptional + #plan.Notable + (if plan.RoutineCount > 0 then 1 else 0)
	return {
		Routine = plan.RoutineCount,
		Notable = #plan.Notable,
		Exceptional = #plan.Exceptional,
		FeedLines = feedLines,
	}
end

return RewardPresentation

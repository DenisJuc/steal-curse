-- Opt-in balance trial configs.
--
-- Production (published servers): ALWAYS live defaults — Studio trial fields are ignored.
-- Roblox Studio: auto-enables StudioTrialId + StudioCollectionPrototype via RunService:IsStudio().
--
-- Disable Studio auto-trial anytime:
--   BalanceTrials.StudioAutoDisabled = true
--
-- Phase 5 Studio default: SoftCap_P5_Size (SoftenD bands + Balanced_Studio size rates).
-- SoftCap_P5_Bands = SoftenD + Baseline sizes (size control). SoftCap_P4 = Phase-4 control.
--
-- Lune / unit tests: not Studio → live defaults. Set AllowNonStudioActive=true to exercise candidates.

local Formulas = if script ~= nil then require(script.Parent.Formulas) else require("./Formulas")
local SkillConfig = if script ~= nil then require(script.Parent.SkillConfig) else require("./SkillConfig")

local BalanceTrials = {}

export type HuntTune = {
	BonusFloor: number,
	BonusFactor: number,
	ReferenceScanSeconds: number?,
	HuntLuckFactor: number,
	MaxBonusRolls: number?,
}

export type RaritySampler = "Ladder" | "SoftCap"

export type Phase3Upgrade = {
	-- Core Luck / Attunement purchase caps (SkillConfig.MaxRank stays 100 for save compat).
	CoreLuckPreR1Max: number,
	CoreLuckPostR1Max: number,
	-- Pedestal Mastery ranks buyable pre/post R1 (node MaxRank = 5).
	PedestalMasteryPreR1Max: number,
	PedestalMasteryPostR1Max: number,
}

export type RebirthModel = "Live" | "BPlus"

export type Candidate = {
	Id: string,
	Label: string,
	EpicDenom: number,
	LegendaryDenom: number,
	LuckDivisor: number,
	LuckCostGrowth: number,
	LuckCostBase: number,
	LuckGrowth: number?,
	SoftLuckCostK: number?,
	SoftLuckCostPower: number?,
	Hunt: HuntTune,
	-- nil / "Ladder" = Soft A+C tier ladder; "SoftCap" = Rev 4 SoftCap (Studio only).
	Sampler: RaritySampler?,
	Phase3: Phase3Upgrade?,
	-- nil / "Live" = production Rebirth reset; "BPlus" = SoftCap_P4 CE-only reset.
	RebirthModel: RebirthModel?,
	-- SoftCap_P4: Fusion income from Board (best rank), not per-pedestal.
	BoardGlobalFusionIncome: boolean?,
	-- SoftCap band profile id (SoftCapRarity). nil / omit = "Default" (P4 bands).
	SoftCapProfile: string?,
	-- SizeConfig probability profile. nil / omit = "Baseline".
	SizeProfile: string?,
}

export type CostOverride = {
	Base: number,
	Growth: number,
	SoftK: number?,
	SoftPower: number?,
}

-- Manual override (normally nil). In Studio, nil → use StudioTrialId. Outside Studio, ignored.
BalanceTrials.Active = nil :: string?

-- Manual collection flag; in Studio auto mode, StudioCollectionPrototype is used instead.
BalanceTrials.CollectionPrototype = false

-- SoftCap_P5_Size = SoftenD bands + Balanced_Studio size rates (Studio experiment).
-- SoftCap_P5_Bands = SoftenD + Baseline sizes. SoftCap_P4 = Phase-4 control.
BalanceTrials.StudioTrialId = "SoftCap_P5_Size"
BalanceTrials.StudioCollectionPrototype = true
-- Kill switch: force live defaults even inside Studio.
BalanceTrials.StudioAutoDisabled = false

-- Launch decision (2026-10-30): published servers run the same trial as Studio (StudioTrialId,
-- collection, core-loop presentation), since every human playtest was on it. false = live
-- servers fall back to the old Ladder defaults. Debug commands, playtest analytics and mock
-- saves stay Studio-only (they check RunService:IsStudio() themselves). Lune never ships it.
BalanceTrials.ShipTrial = true

-- Studio Core Loop presentation: SoftCap rarity/size + Collection saves stay on, but Fusion Board,
-- Charms, Hunt Quarry objectives, Attune/Resonance/Pursuits are hidden from the player-facing UX.
-- Implementations remain; flip false to restore the full Collection Studio surface.
BalanceTrials.StudioCoreLoopPresentation = true

-- Unit tests only: allow Active/CollectionPrototype outside Studio (Lune). Never set in game code.
BalanceTrials.AllowNonStudioActive = false

local SOFT_AC_HUNT = {
	BonusFloor = 2,
	BonusFactor = 0.08,
	ReferenceScanSeconds = 4,
	HuntLuckFactor = 5,
	MaxBonusRolls = 6,
}

local PHASE3 = {
	CoreLuckPreR1Max = 18,
	CoreLuckPostR1Max = 25,
	PedestalMasteryPreR1Max = 2,
	PedestalMasteryPostR1Max = 5,
}

local function softAcCandidate(
	id: string,
	label: string,
	sampler: RaritySampler,
	phase3: Phase3Upgrade?,
	extras: {
		RebirthModel: RebirthModel?,
		BoardGlobalFusionIncome: boolean?,
		SoftCapProfile: string?,
		SizeProfile: string?,
	}?
): Candidate
	return {
		Id = id,
		Label = label,
		EpicDenom = 20000,
		LegendaryDenom = 500000,
		LuckDivisor = 12,
		LuckCostGrowth = 1.7,
		LuckCostBase = 100,
		LuckGrowth = 1.25,
		SoftLuckCostK = 0.05,
		SoftLuckCostPower = 1.35,
		Hunt = SOFT_AC_HUNT,
		Sampler = sampler,
		Phase3 = phase3,
		RebirthModel = if extras then extras.RebirthModel else nil,
		BoardGlobalFusionIncome = if extras then extras.BoardGlobalFusionIncome else nil,
		SoftCapProfile = if extras then extras.SoftCapProfile else nil,
		SizeProfile = if extras then extras.SizeProfile else nil,
	}
end

BalanceTrials.Candidates = {
	SoftAC_E20k = softAcCandidate(
		"SoftAC_E20k",
		"Soft A+C ladder control (Epic 20k, LG1.25 + soft k=0.05, hunt reform)",
		"Ladder",
		nil
	),
	E20k_L12_C17_HR = softAcCandidate(
		"E20k_L12_C17_HR",
		"Epic 20k Soft A+C (alias of SoftAC_E20k)",
		"Ladder",
		nil
	),
	SoftCap_Rev4 = softAcCandidate(
		"SoftCap_Rev4",
		"SoftCap rarity (Rev 4) — Phase 2 control (no Phase 3 upgrade caps)",
		"SoftCap",
		nil
	),
	SoftCap_P3 = softAcCandidate(
		"SoftCap_P3",
		"SoftCap + Phase 3 upgrades (CL18 pre-R1, Pedestal Mastery 2/5) — Studio control",
		"SoftCap",
		PHASE3
	),
	SoftCap_P4 = softAcCandidate(
		"SoftCap_P4",
		"SoftCap + Phase3 + B+ Rebirth + board-global Fusion income — Studio control",
		"SoftCap",
		PHASE3,
		{ RebirthModel = "BPlus", BoardGlobalFusionIncome = true, SizeProfile = "Baseline" }
	),
	SoftCap_P5_Bands = softAcCandidate(
		"SoftCap_P5_Bands",
		"SoftCap_P4 + SoftenD bands + Baseline size rates — size control",
		"SoftCap",
		PHASE3,
		{
			RebirthModel = "BPlus",
			BoardGlobalFusionIncome = true,
			SoftCapProfile = "SoftenD",
			SizeProfile = "Baseline",
		}
	),
	SoftCap_P5_Size = softAcCandidate(
		"SoftCap_P5_Size",
		"SoftCap_P5 SoftenD bands + Balanced_Studio size rates (Common Huge, Unc Tit) — Studio",
		"SoftCap",
		PHASE3,
		{
			RebirthModel = "BPlus",
			BoardGlobalFusionIncome = true,
			SoftCapProfile = "SoftenD",
			SizeProfile = "Balanced_Studio",
		}
	),
} :: { [string]: Candidate }

-- SoftCapRarity profile id for the active trial (Default when unset / Ladder).
function BalanceTrials.softCapProfile(): string
	local trial = BalanceTrials.current()
	if trial and type(trial.SoftCapProfile) == "string" and trial.SoftCapProfile ~= "" then
		return trial.SoftCapProfile
	end
	return "Default"
end

-- SizeConfig probability profile (Baseline when unset).
function BalanceTrials.sizeProfile(): string
	local trial = BalanceTrials.current()
	if trial and type(trial.SizeProfile) == "string" and trial.SizeProfile ~= "" then
		return trial.SizeProfile
	end
	return "Baseline"
end

function BalanceTrials.isStudio(): boolean
	local ok, RunService = pcall(function()
		return game:GetService("RunService")
	end)
	if not ok or RunService == nil then
		return false
	end
	local okStudio, inStudio = pcall(function()
		return RunService:IsStudio()
	end)
	return okStudio == true and inStudio == true
end

-- Where the trial applies: Studio, or a real Roblox server/client when ShipTrial is on.
local function trialEnvironment(): boolean
	if BalanceTrials.isStudio() then
		return true
	end
	return BalanceTrials.ShipTrial == true and game ~= nil and script ~= nil
end

local function resolvedTrialId(): string?
	if BalanceTrials.AllowNonStudioActive then
		local id = BalanceTrials.Active
		if type(id) == "string" and id ~= "" then
			return id
		end
		return nil
	end
	if not trialEnvironment() then
		return nil
	end
	if BalanceTrials.StudioAutoDisabled then
		return nil
	end
	if type(BalanceTrials.Active) == "string" and BalanceTrials.Active ~= "" then
		return BalanceTrials.Active
	end
	if type(BalanceTrials.StudioTrialId) == "string" and BalanceTrials.StudioTrialId ~= "" then
		return BalanceTrials.StudioTrialId
	end
	return nil
end

function BalanceTrials.current(): Candidate?
	local id = resolvedTrialId()
	if not id then
		return nil
	end
	return BalanceTrials.Candidates[id]
end

function BalanceTrials.raritySampler(): RaritySampler
	local trial = BalanceTrials.current()
	if trial and trial.Sampler == "SoftCap" then
		return "SoftCap"
	end
	return "Ladder"
end

function BalanceTrials.phase3(): Phase3Upgrade?
	local trial = BalanceTrials.current()
	if trial and trial.Phase3 then
		return trial.Phase3
	end
	return nil
end

-- Production / SoftCap_P3 → "Live". SoftCap_P4 → "BPlus".
function BalanceTrials.rebirthModel(): RebirthModel
	local trial = BalanceTrials.current()
	if trial and trial.RebirthModel == "BPlus" then
		return "BPlus"
	end
	return "Live"
end

-- SoftCap_P4: Fusion income from best Board rank (global). SoftCap_P3 keeps pedestal-only.
function BalanceTrials.boardGlobalFusionIncome(): boolean
	local trial = BalanceTrials.current()
	return trial ~= nil and trial.BoardGlobalFusionIncome == true and BalanceTrials.collectionEnabled()
end

function BalanceTrials.collectionEnabled(): boolean
	if BalanceTrials.AllowNonStudioActive then
		return BalanceTrials.current() ~= nil and BalanceTrials.CollectionPrototype == true
	end
	if not trialEnvironment() or BalanceTrials.StudioAutoDisabled then
		return false
	end
	if BalanceTrials.current() == nil then
		return false
	end
	if type(BalanceTrials.Active) == "string" and BalanceTrials.Active ~= "" then
		return BalanceTrials.CollectionPrototype == true
	end
	return BalanceTrials.StudioCollectionPrototype == true
end

-- Hide advanced Collection UX while keeping SoftCap / saves / size systems alive.
function BalanceTrials.coreLoopPresentation(): boolean
	if not BalanceTrials.StudioCoreLoopPresentation then
		return false
	end
	if BalanceTrials.AllowNonStudioActive then
		return BalanceTrials.collectionEnabled()
	end
	if not trialEnvironment() or BalanceTrials.StudioAutoDisabled then
		return false
	end
	return BalanceTrials.collectionEnabled()
end

function BalanceTrials.pedestalMasteryEnabled(): boolean
	return BalanceTrials.phase3() ~= nil
end

-- Effective Core Luck purchase cap for the current trial (live = SkillConfig MaxRank).
function BalanceTrials.coreLuckMaxRank(rebirths: number?): number
	local live = SkillConfig.ById.CoreLuck.MaxRank
	local p3 = BalanceTrials.phase3()
	if not p3 then
		return live
	end
	if (rebirths or 0) >= 1 then
		return math.min(live, p3.CoreLuckPostR1Max)
	end
	return math.min(live, p3.CoreLuckPreR1Max)
end

function BalanceTrials.pedestalMasteryMaxRank(rebirths: number?): number
	local p3 = BalanceTrials.phase3()
	if not p3 then
		return 0
	end
	local nodeMax = SkillConfig.ById.PedestalMastery and SkillConfig.ById.PedestalMastery.MaxRank or 5
	if (rebirths or 0) >= 1 then
		return math.min(nodeMax, p3.PedestalMasteryPostR1Max)
	end
	return math.min(nodeMax, p3.PedestalMasteryPreR1Max)
end

function BalanceTrials.pedestalMasteryIncomeMult(rank: number): number
	if not BalanceTrials.pedestalMasteryEnabled() then
		return 1
	end
	local per = SkillConfig.Effects.IncomePerMasteryRank or 0.04
	return 1 + per * math.max(0, rank)
end

-- Skill tree visibility / purchase gate for trial-only nodes.
function BalanceTrials.skillNodeEnabled(nodeId: string): boolean
	if nodeId == "PedestalMastery" then
		return BalanceTrials.pedestalMasteryEnabled()
	end
	return true
end

function BalanceTrials.skillMaxRank(nodeId: string, rebirths: number?): number
	local node = SkillConfig.ById[nodeId]
	if not node then
		return 0
	end
	if nodeId == "CoreLuck" then
		return BalanceTrials.coreLuckMaxRank(rebirths)
	end
	if nodeId == "PedestalMastery" then
		return BalanceTrials.pedestalMasteryMaxRank(rebirths)
	end
	return node.MaxRank
end

function BalanceTrials.tierDenominator(tierId: string, liveDenom: number): number
	local trial = BalanceTrials.current()
	if not trial then
		return liveDenom
	end
	if tierId == "Epic" then
		return trial.EpicDenom
	end
	if tierId == "Legendary" then
		return trial.LegendaryDenom
	end
	return liveDenom
end

function BalanceTrials.rebirthSettings(live: {
	BaseCost: number,
	CostGrowth: number,
	IncomeGrowth: number,
	LuckGrowth: number,
}): typeof(live)
	local trial = BalanceTrials.current()
	if not trial or not trial.LuckGrowth then
		return live
	end
	-- Phase 3/4: keep live BaseCost (400M) — do not cut from Fusion stub lifts.
	return {
		BaseCost = live.BaseCost,
		CostGrowth = live.CostGrowth,
		IncomeGrowth = live.IncomeGrowth,
		LuckGrowth = trial.LuckGrowth,
	}
end

function BalanceTrials.coreLuckCostOverride(): CostOverride?
	local trial = BalanceTrials.current()
	if not trial then
		return nil
	end
	return {
		Base = trial.LuckCostBase,
		Growth = trial.LuckCostGrowth,
		SoftK = trial.SoftLuckCostK,
		SoftPower = trial.SoftLuckCostPower,
	}
end

function BalanceTrials.coreLuckCost(rank: number, liveBase: number?, liveGrowth: number?): number
	local override = BalanceTrials.coreLuckCostOverride()
	if not override then
		return Formulas.coreLuckCost(rank, liveBase, liveGrowth)
	end
	if override.SoftK then
		return Formulas.coreLuckCostSoft(rank, override.Base, override.Growth, override.SoftK, override.SoftPower)
	end
	return Formulas.coreLuckCost(rank, override.Base, override.Growth)
end

function BalanceTrials.logStartup()
	local inStudio = BalanceTrials.isStudio()
	local trial = BalanceTrials.current()
	local collection = BalanceTrials.collectionEnabled()
	if not trial then
		local reason = if not inStudio
			then "not Studio (production/live path)"
			elseif BalanceTrials.StudioAutoDisabled then "StudioAutoDisabled=true"
			else "no trial id"
		print(`[BalanceTrials] LIVE defaults — {reason}`)
		print(`[BalanceTrials] RaritySampler=Ladder (live)`)
		return
	end
	local h = trial.Hunt
	local maxBonus = h.MaxBonusRolls
	local maxTotal = if maxBonus then 1 + maxBonus else nil
	local sampler = BalanceTrials.raritySampler()
	print(`[BalanceTrials] ACTIVE={trial.Id}`)
	print(`[BalanceTrials] RaritySampler={sampler}`)
	print(
		string.format(
			"[BalanceTrials] CollectionPrototype=%s | StudioAuto=%s | EpicDenom=%d | LuckGrowth=%s | Hunt floor=%s factor=%s refScan=%s huntLuck=x%s MaxBonusRolls=%s maxTotalRolls=%s",
			tostring(collection),
			tostring(inStudio and not BalanceTrials.StudioAutoDisabled),
			trial.EpicDenom,
			tostring(trial.LuckGrowth),
			tostring(h.BonusFloor),
			tostring(h.BonusFactor),
			tostring(h.ReferenceScanSeconds),
			tostring(h.HuntLuckFactor),
			tostring(maxBonus),
			tostring(maxTotal)
		)
	)
	local p3 = trial.Phase3
	if p3 then
		print(
			string.format(
				"[BalanceTrials] Phase3: CoreLuck preR1=%d postR1=%d | PedestalMastery preR1=%d postR1=%d | Rebirth BaseCost=LIVE",
				p3.CoreLuckPreR1Max,
				p3.CoreLuckPostR1Max,
				p3.PedestalMasteryPreR1Max,
				p3.PedestalMasteryPostR1Max
			)
		)
	end
	print(
		string.format(
			"[BalanceTrials] RebirthModel=%s | BoardGlobalFusionIncome=%s | CoreLoopPresentation=%s",
			BalanceTrials.rebirthModel(),
			tostring(BalanceTrials.boardGlobalFusionIncome()),
			tostring(BalanceTrials.coreLoopPresentation())
		)
	)
	if sampler == "SoftCap" then
		print(
			`[BalanceTrials] SoftCap Index odds = 1/p_i; SoftCapProfile={BalanceTrials.softCapProfile()}; SizeProfile={BalanceTrials.sizeProfile()}; SoftCap_P5_Size = Studio size trial; SoftCap_P5_Bands = size control; SoftCap_P4 = Phase4 control`
		)
	end
end

return BalanceTrials

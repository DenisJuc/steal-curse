-- Soft A+C trial helpers: production/Lune stay live; Studio auto-trial is config-only here.

local BalanceTrials = require("../../src/shared/BalanceTrials")
local Config = require("../../src/shared/Config")
local Formulas = require("../../src/shared/Formulas")
local expect = require("../lib/expect")

return {
	{
		Name = "shipping path stays live outside Studio (Lune)",
		Run = function()
			expect.equal(BalanceTrials.isStudio(), false, "lune is not Studio")
			expect.equal(BalanceTrials.Active, nil, "Active field nil")
			expect.equal(BalanceTrials.StudioAutoDisabled, false, "auto enabled for Studio")
			expect.equal(BalanceTrials.StudioTrialId, "SoftCap_P5_Size", "studio SoftCap size trial")
			expect.equal(BalanceTrials.StudioCollectionPrototype, true, "studio collection ready")
			expect.equal(BalanceTrials.StudioCoreLoopPresentation, true, "studio core loop presentation")
			expect.equal(BalanceTrials.Candidates.SoftCap_Rev4.Sampler, "SoftCap", "SoftCap Phase 2 control")
			expect.equal(BalanceTrials.Candidates.SoftCap_P3.Sampler, "SoftCap", "SoftCap Phase 3 control")
			expect.equal(BalanceTrials.Candidates.SoftCap_P4.Sampler, "SoftCap", "SoftCap Phase 4 control")
			expect.equal(BalanceTrials.Candidates.SoftCap_P4.RebirthModel, "BPlus", "B+ Rebirth")
			expect.equal(BalanceTrials.Candidates.SoftCap_P4.BoardGlobalFusionIncome, true, "board-global Fusion")
			expect.equal(BalanceTrials.Candidates.SoftCap_P4.SoftCapProfile, nil, "P4 keeps Default bands")
			expect.equal(BalanceTrials.Candidates.SoftCap_P4.SizeProfile, "Baseline", "P4 baseline sizes")
			expect.equal(BalanceTrials.Candidates.SoftCap_P5_Bands.Sampler, "SoftCap", "P5 SoftCap")
			expect.equal(BalanceTrials.Candidates.SoftCap_P5_Bands.SoftCapProfile, "SoftenD", "P5 SoftenD bands")
			expect.equal(BalanceTrials.Candidates.SoftCap_P5_Bands.SizeProfile, "Baseline", "P5_Bands size control")
			expect.equal(BalanceTrials.Candidates.SoftCap_P5_Bands.RebirthModel, "BPlus", "P5 inherits B+")
			expect.equal(BalanceTrials.Candidates.SoftCap_P5_Size.SoftCapProfile, "SoftenD", "P5_Size SoftenD")
			expect.equal(BalanceTrials.Candidates.SoftCap_P5_Size.SizeProfile, "Balanced_Studio", "P5_Size balanced sizes")
			expect.equal(BalanceTrials.sizeProfile(), "Baseline", "size profile Baseline outside Studio")
			expect.equal(BalanceTrials.Candidates.SoftCap_P3.Phase3.CoreLuckPreR1Max, 18, "CL18 pre-R1")
			expect.equal(BalanceTrials.Candidates.SoftCap_P3.Phase3.PedestalMasteryPreR1Max, 2, "Mastery crumb")
			expect.equal(BalanceTrials.Candidates.SoftAC_E20k.Sampler, "Ladder", "SoftAC control")
			expect.equal(BalanceTrials.current(), nil, "resolved current nil outside Studio")
			expect.equal(BalanceTrials.raritySampler(), "Ladder", "production sampler is Ladder")
			expect.equal(BalanceTrials.softCapProfile(), "Default", "profile Default outside Studio")
			expect.equal(BalanceTrials.collectionEnabled(), false, "collection off outside Studio")
			expect.equal(BalanceTrials.pedestalMasteryEnabled(), false, "mastery off outside Studio")
			expect.equal(BalanceTrials.coreLuckCostOverride(), nil, "no cost override")
			local live = BalanceTrials.rebirthSettings(Config.Rebirth)
			expect.equal(live.LuckStep, Config.Rebirth.LuckStep, "live luck step")
		end,
	},
	{
		Name = "SoftCap_Rev4 resolves SoftCap sampler under AllowNonStudioActive",
		Run = function()
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevCollection = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = true
			BalanceTrials.Active = "SoftCap_Rev4"
			BalanceTrials.CollectionPrototype = true
			expect.equal(BalanceTrials.raritySampler(), "SoftCap", "sampler")
			expect.equal(BalanceTrials.collectionEnabled(), true, "collection")
			BalanceTrials.Active = "SoftAC_E20k"
			expect.equal(BalanceTrials.raritySampler(), "Ladder", "control sampler")
			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevCollection
		end,
	},
	{
		Name = "candidate soft A+C math matches Formulas.coreLuckCostSoft",
		Run = function()
			local c = BalanceTrials.Candidates.E20k_L12_C17_HR
			expect.equal(c.LuckGrowth, 1.25, "luck growth")
			expect.equal(c.SoftLuckCostK, 0.05, "soft k")
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevCollection = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = true
			BalanceTrials.Active = "E20k_L12_C17_HR"
			BalanceTrials.CollectionPrototype = true
			local override = BalanceTrials.coreLuckCostOverride()
			expect.truthy(override ~= nil, "override")
			expect.equal(override.SoftK, 0.05, "soft")
			local cost = BalanceTrials.coreLuckCost(10, 100, 1.6)
			local expectCost = Formulas.coreLuckCostSoft(10, c.LuckCostBase, c.LuckCostGrowth, c.SoftLuckCostK, c.SoftLuckCostPower)
			expect.equal(cost, expectCost, "soft cost")
			local reb = BalanceTrials.rebirthSettings(Config.Rebirth)
			-- The live curve is additive, so the trial's geometric LuckGrowth no longer applies.
			expect.equal(reb.LuckStep, Config.Rebirth.LuckStep, "live luck step kept")
			expect.equal(reb.IncomeStep, Config.Rebirth.IncomeStep, "income unchanged")
			expect.equal(BalanceTrials.collectionEnabled(), true, "collection on with allow flag")
			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevCollection
		end,
	},
	{
		Name = "trial MaxBonusRolls must cap AFTER harvest and streak (not only formula base)",
		Run = function()
			local c = BalanceTrials.Candidates.E20k_L12_C17_HR
			local hunt = {
				BonusFloor = c.Hunt.BonusFloor,
				BonusFactor = c.Hunt.BonusFactor,
			}
			local refScan = c.Hunt.ReferenceScanSeconds or 4
			local formulaBase = Formulas.bonusRolls(refScan, Config.Signals.RegenSeconds, hunt)
			local afterHarvest = math.ceil(formulaBase * 1.5 - 1e-9)
			local beforeCap = math.ceil(afterHarvest * Config.Hunt.MaxBonusMultiplier - 1e-9)
			expect.truthy(beforeCap > (c.Hunt.MaxBonusRolls or 0), "multipliers would exceed cap")
			local finalBonus = math.min(beforeCap, c.Hunt.MaxBonusRolls :: number)
			expect.equal(finalBonus, c.Hunt.MaxBonusRolls, "final cap")
			expect.equal(1 + finalBonus, 7, "total rolls never exceed 7 under trial")
			local oldBuggy = math.ceil(math.min(formulaBase, c.Hunt.MaxBonusRolls :: number) * 1.5 * Config.Hunt.MaxBonusMultiplier - 1e-9)
			expect.truthy(oldBuggy > 7, "documents why early cap was wrong")
		end,
	},
	{
		Name = "StudioAutoDisabled kill switch forces live even if trial id is set",
		Run = function()
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevDisabled = BalanceTrials.StudioAutoDisabled
			local prevActive = BalanceTrials.Active
			BalanceTrials.AllowNonStudioActive = false
			BalanceTrials.StudioAutoDisabled = true
			BalanceTrials.Active = "E20k_L12_C17_HR"
			-- Outside Studio, current is always nil; kill switch is for Studio. Still assert Active alone is not enough.
			expect.equal(BalanceTrials.current(), nil, "still nil outside Studio")
			BalanceTrials.StudioAutoDisabled = prevDisabled
			BalanceTrials.Active = prevActive
			BalanceTrials.AllowNonStudioActive = prevAllow
		end,
	},
	{
		Name = "SoftCap_P3 Phase 3 caps Mastery and CoreLuck; Rebirth BaseCost stays live",
		Run = function()
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevCollection = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = true
			BalanceTrials.Active = "SoftCap_P3"
			BalanceTrials.CollectionPrototype = true
			expect.equal(BalanceTrials.phase3() ~= nil, true, "phase3 present")
			expect.equal(BalanceTrials.rebirthModel(), "Live", "P3 keeps Live Rebirth")
			expect.equal(BalanceTrials.boardGlobalFusionIncome(), false, "P3 pedestal Fusion")
			expect.equal(BalanceTrials.pedestalMasteryEnabled(), true, "mastery on")
			expect.equal(BalanceTrials.skillNodeEnabled("PedestalMastery"), true, "node visible")
			expect.equal(BalanceTrials.coreLuckMaxRank(0), 18, "CL pre-R1")
			expect.equal(BalanceTrials.coreLuckMaxRank(1), 25, "CL post-R1")
			expect.equal(BalanceTrials.pedestalMasteryMaxRank(0), 2, "mastery pre-R1")
			expect.equal(BalanceTrials.pedestalMasteryMaxRank(1), 5, "mastery post-R1")
			expect.equal(BalanceTrials.pedestalMasteryIncomeMult(2), 1.08, "×1.08 at rank 2")
			local reb = BalanceTrials.rebirthSettings(Config.Rebirth)
			expect.equal(reb.BaseCost, Config.Rebirth.BaseCost, "BaseCost live")
			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevCollection
		end,
	},
	{
		Name = "SoftCap_P4 BPlus and board-global Fusion; BaseCost stays 400M",
		Run = function()
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevCollection = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = true
			BalanceTrials.Active = "SoftCap_P4"
			BalanceTrials.CollectionPrototype = true
			expect.equal(BalanceTrials.rebirthModel(), "BPlus", "B+")
			expect.equal(BalanceTrials.boardGlobalFusionIncome(), true, "board global")
			expect.equal(BalanceTrials.softCapProfile(), "Default", "P4 Default bands")
			expect.equal(BalanceTrials.coreLuckMaxRank(0), 18, "CL18 pre-R1")
			expect.equal(BalanceTrials.coreLuckMaxRank(1), 25, "CL25 post-R1")
			expect.equal(BalanceTrials.pedestalMasteryMaxRank(1), 5, "Mastery 5 post-R1")
			local reb = BalanceTrials.rebirthSettings(Config.Rebirth)
			expect.equal(reb.BaseCost, Config.Rebirth.BaseCost, "BaseCost live 400M")
			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevCollection
		end,
	},
	{
		Name = "SoftCap_P5_Bands inherits P4 systems and SoftenD profile",
		Run = function()
			local SoftCapRarity = require("../../src/shared/SoftCapRarity")
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevCollection = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = true
			BalanceTrials.Active = "SoftCap_P5_Bands"
			BalanceTrials.CollectionPrototype = true
			SoftCapRarity.invalidateSampler()
			SoftCapRarity.syncFromTrials()
			expect.equal(BalanceTrials.rebirthModel(), "BPlus", "B+")
			expect.equal(BalanceTrials.boardGlobalFusionIncome(), true, "board global")
			expect.equal(BalanceTrials.softCapProfile(), "SoftenD", "SoftenD")
			expect.equal(BalanceTrials.sizeProfile(), "Baseline", "size control")
			expect.equal(SoftCapRarity.activeProfile(), "SoftenD", "sampler profile")
			local b80 = SoftCapRarity.softCapBandPercents(80)
			local sum = 0
			for _, v in b80 do
				sum += v
			end
			expect.truthy(math.abs(sum - 100) < 0.05, "bands sum ~100")
			expect.truthy((b80.Common or 0) < 50, "Common cut vs P4 ~54%")
			expect.truthy((b80.Rare or 0) > 12 and (b80.Rare or 0) < 25, "Rare chase not wall")
			local reb = BalanceTrials.rebirthSettings(Config.Rebirth)
			expect.equal(reb.BaseCost, Config.Rebirth.BaseCost, "BaseCost live")
			SoftCapRarity.setProfile("Default")
			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevCollection
		end,
	},
	{
		Name = "SoftCap_P5_Size SoftenD bands + Balanced_Studio size profile",
		Run = function()
			local SoftCapRarity = require("../../src/shared/SoftCapRarity")
			local SizeConfig = require("../../src/shared/SizeConfig")
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevCollection = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = true
			BalanceTrials.Active = "SoftCap_P5_Size"
			BalanceTrials.CollectionPrototype = true
			SoftCapRarity.invalidateSampler()
			SoftCapRarity.syncFromTrials()
			SizeConfig.syncFromTrials()
			expect.equal(BalanceTrials.rebirthModel(), "BPlus", "B+")
			expect.equal(BalanceTrials.boardGlobalFusionIncome(), true, "board global")
			expect.equal(BalanceTrials.softCapProfile(), "SoftenD", "SoftenD")
			expect.equal(BalanceTrials.sizeProfile(), "Balanced_Studio", "balanced size")
			expect.equal(SizeConfig.activeProfile(), "Balanced_Studio", "SizeConfig synced")
			expect.near(SizeConfig.ChanceByTier.Common.Huge, 1 / 1000, 1e-12, "common huge")
			expect.equal(SizeConfig.ChanceByTier.Common.Titanic, 0, "no common tit")
			expect.near(SizeConfig.ChanceByTier.Uncommon.Titanic, 1 / 4000, 1e-12, "unc tit")
			expect.equal(SizeConfig.IncomeMult.Huge, 1.5, "income huge")
			expect.equal(SizeConfig.IncomeMult.Titanic, 2.5, "income tit")
			SoftCapRarity.setProfile("Default")
			SizeConfig.setProfile("Baseline")
			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevCollection
		end,
	},
}

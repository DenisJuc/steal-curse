-- SoftCap Studio size stamps (Normal / Huge / Titanic) + size probability profiles.

local expect = require("../lib/expect")
local BalanceTrials = require("../../src/shared/BalanceTrials")
local SizeConfig = require("../../src/shared/SizeConfig")
local RelicIncome = require("../lib/relicIncome")
local RelicConfig = require("../../src/shared/RelicConfig")

local function withTrial(trialId: string?, collection: boolean, body: () -> ())
	local prevAllow = BalanceTrials.AllowNonStudioActive
	local prevActive = BalanceTrials.Active
	local prevCollection = BalanceTrials.CollectionPrototype
	BalanceTrials.AllowNonStudioActive = true
	BalanceTrials.Active = trialId
	BalanceTrials.CollectionPrototype = collection
	SizeConfig.syncFromTrials()
	local ok, err = pcall(body)
	BalanceTrials.AllowNonStudioActive = prevAllow
	BalanceTrials.Active = prevActive
	BalanceTrials.CollectionPrototype = prevCollection
	SizeConfig.syncFromTrials()
	if not ok then
		error(err)
	end
end

local function nearProb(actual: number, expected: number, label: string)
	expect.near(actual, expected, 1e-12, label)
end

return {
	{
		Name = "normalize and rank treat nil as Normal",
		Run = function()
			expect.equal(SizeConfig.normalize(nil), nil, "nil")
			expect.equal(SizeConfig.normalize("Normal"), nil, "Normal string")
			expect.equal(SizeConfig.normalize("Huge"), "Huge", "Huge")
			expect.equal(SizeConfig.normalize("Titanic"), "Titanic", "Titanic")
			expect.equal(SizeConfig.rank(nil), 0, "rank normal")
			expect.equal(SizeConfig.rank("Huge"), 1, "rank huge")
			expect.equal(SizeConfig.rank("Titanic"), 2, "rank titanic")
			expect.equal(SizeConfig.scaleOf(nil), 1, "scale normal")
			expect.truthy(SizeConfig.scaleOf("Huge") > 1, "huge larger")
			expect.truthy(SizeConfig.scaleOf("Titanic") > SizeConfig.scaleOf("Huge"), "titanic largest")
		end,
	},
	{
		Name = "income mult stays ×1.5 / ×2.5 across size profiles",
		Run = function()
			expect.equal(SizeConfig.IncomeMult.Huge, 1.5, "huge power")
			expect.equal(SizeConfig.IncomeMult.Titanic, 2.5, "titanic power")
			local relic = RelicConfig.Relics[1]
			expect.truthy(relic ~= nil, "has relic")
			local base = RelicIncome.of(relic.Id)
			local huge = RelicIncome.of(relic.Id, nil, "Huge")
			local titanic = RelicIncome.of(relic.Id, nil, "Titanic")
			expect.near(huge / base, 1.5, 1e-9, "huge mult")
			expect.near(titanic / base, 2.5, 1e-9, "titanic mult")
			withTrial("SoftCap_P5_Size", true, function()
				expect.equal(SizeConfig.IncomeMult.Huge, 1.5, "P5_Size huge power")
				expect.equal(SizeConfig.IncomeMult.Titanic, 2.5, "P5_Size titanic power")
				expect.near(RelicIncome.of(relic.Id, nil, "Huge") / base, 1.5, 1e-9, "P5_Size income")
			end)
		end,
	},
	{
		Name = "Baseline profile: Commons never size; SoftCap roll returns sizes",
		Run = function()
			withTrial("SoftCap_P5_Bands", true, function()
				expect.equal(BalanceTrials.sizeProfile(), "Baseline", "bands = baseline size")
				expect.equal(SizeConfig.activeProfile(), "Baseline", "active")
				nearProb(SizeConfig.ChanceByTier.Common.Huge, 0, "common huge off")
				nearProb(SizeConfig.ChanceByTier.Common.Titanic, 0, "common titanic off")
				nearProb(SizeConfig.ChanceByTier.Uncommon.Titanic, 0, "unc titanic off")
				expect.equal(SizeConfig.enabled(), true, "enabled")
				expect.equal(SizeConfig.roll("Common", function()
					return 0
				end), nil, "common never sizes")
				local titanic = SizeConfig.roll("Rare", function()
					return 0
				end)
				expect.equal(titanic, "Titanic", "r=0 picks Titanic")
				local pT = SizeConfig.ChanceByTier.Rare.Titanic
				expect.equal(SizeConfig.roll("Rare", function()
					return pT
				end), "Huge", "after Titanic band comes Huge")
				expect.equal(SizeConfig.roll("Rare", function()
					return 0.99
				end), nil, "high roll stays Normal")
			end)
		end,
	},
	{
		Name = "Balanced_Studio rates: Common Huge, Unc Tit, no Common Tit; Mythic+ unchanged",
		Run = function()
			withTrial("SoftCap_P5_Size", true, function()
				expect.equal(BalanceTrials.sizeProfile(), "Balanced_Studio", "size profile")
				expect.equal(SizeConfig.activeProfile(), "Balanced_Studio", "active")
				local c = SizeConfig.ChanceByTier
				nearProb(c.Common.Huge, 1 / 1000, "common huge")
				nearProb(c.Common.Titanic, 0, "no common titanic")
				nearProb(c.Uncommon.Huge, 1 / 420, "unc huge")
				nearProb(c.Uncommon.Titanic, 1 / 4000, "unc titanic")
				nearProb(c.Rare.Huge, 1 / 170, "rare huge")
				nearProb(c.Rare.Titanic, 1 / 2400, "rare titanic")
				nearProb(c.Epic.Huge, 1 / 95, "epic huge")
				nearProb(c.Epic.Titanic, 1 / 800, "epic titanic")
				nearProb(c.Legendary.Huge, 1 / 75, "leg huge")
				nearProb(c.Legendary.Titanic, 1 / 520, "leg titanic")
				-- Mythic+ preserved from Baseline
				local base = SizeConfig.Profiles.Baseline
				nearProb(c.Mythic.Huge, base.Mythic.Huge, "mythic huge")
				nearProb(c.Mythic.Titanic, base.Mythic.Titanic, "mythic tit")
				nearProb(c.Celestial.Huge, base.Celestial.Huge, "cel huge")
				nearProb(c.Celestial.Titanic, base.Celestial.Titanic, "cel tit")
				nearProb(c.Cosmic.Huge, base.Cosmic.Huge, "cos huge")
				nearProb(c.Cosmic.Titanic, base.Cosmic.Titanic, "cos tit")
				-- Normalization: Huge+Tit ≤ 1 per tier
				for tier, row in c do
					local sum = (row.Huge or 0) + (row.Titanic or 0)
					expect.truthy(sum <= 1 + 1e-12, `{tier} size mass ≤ 1`)
					expect.truthy(sum >= 0, `{tier} non-neg`)
				end
			end)
		end,
	},
	{
		Name = "Balanced_Studio: Common Huge and Uncommon Titanic can roll",
		Run = function()
			withTrial("SoftCap_P5_Size", true, function()
				expect.equal(SizeConfig.roll("Common", function()
					return 0
				end), "Huge", "common huge at r=0")
				expect.equal(SizeConfig.roll("Common", function()
					return 1 / 1000
				end), nil, "common after huge band is Normal")
				expect.equal(SizeConfig.roll("Common", function()
					return 0.5
				end), nil, "common never Titanic")
				expect.equal(SizeConfig.roll("Uncommon", function()
					return 0
				end), "Titanic", "unc titanic at r=0")
				local pT = SizeConfig.ChanceByTier.Uncommon.Titanic
				expect.equal(SizeConfig.roll("Uncommon", function()
					return pT
				end), "Huge", "unc huge after tit band")
			end)
		end,
	},
	{
		Name = "SoftCap_P4 stays Baseline sizes; SoftCap_P5_Bands size control",
		Run = function()
			withTrial("SoftCap_P4", true, function()
				expect.equal(BalanceTrials.sizeProfile(), "Baseline", "P4 baseline size")
				nearProb(SizeConfig.ChanceByTier.Common.Huge, 0, "P4 no common huge")
			end)
			withTrial("SoftCap_P5_Bands", true, function()
				expect.equal(BalanceTrials.softCapProfile(), "SoftenD", "bands SoftenD")
				expect.equal(BalanceTrials.sizeProfile(), "Baseline", "bands baseline size")
			end)
			withTrial("SoftCap_P5_Size", true, function()
				expect.equal(BalanceTrials.softCapProfile(), "SoftenD", "size trial SoftenD")
				expect.equal(BalanceTrials.sizeProfile(), "Balanced_Studio", "size trial balanced")
			end)
		end,
	},
	{
		Name = "disabled outside SoftCap Studio collection (production unchanged)",
		Run = function()
			local prevAllow = BalanceTrials.AllowNonStudioActive
			local prevActive = BalanceTrials.Active
			local prevCollection = BalanceTrials.CollectionPrototype
			BalanceTrials.AllowNonStudioActive = false
			BalanceTrials.Active = nil
			BalanceTrials.CollectionPrototype = false
			local ok, err = pcall(function()
				expect.equal(SizeConfig.enabled(), false, "off in live/Lune default")
				expect.equal(SizeConfig.roll("Legendary", function()
					return 0
				end), nil, "no size when disabled")
				expect.equal(BalanceTrials.sizeProfile(), "Baseline", "live size profile idle")
			end)
			BalanceTrials.AllowNonStudioActive = prevAllow
			BalanceTrials.Active = prevActive
			BalanceTrials.CollectionPrototype = prevCollection
			SizeConfig.syncFromTrials()
			if not ok then
				error(err)
			end
		end,
	},
	{
		Name = "sized stamp identity survives normalize for save/equip paths",
		Run = function()
			-- Grant/equip/save use Size string fields; normalize is the gate.
			expect.equal(SizeConfig.normalize("Huge"), "Huge", "huge persist")
			expect.equal(SizeConfig.normalize("Titanic"), "Titanic", "tit persist")
			expect.equal(SizeConfig.incomeMult("Huge"), 1.5, "equip income huge")
			expect.equal(SizeConfig.incomeMult("Titanic"), 2.5, "equip income tit")
			expect.equal(SizeConfig.scaleOf("Huge"), SizeConfig.Scale.Huge, "display scale")
		end,
	},
}

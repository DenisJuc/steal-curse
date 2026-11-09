-- Rebirth (Shared/Rebirth, Config.Rebirth): cost curve, permanent multipliers, and what resets.

local Config = require("../../src/shared/Config")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local Rebirth = require("../../src/shared/Rebirth")
local expect = require("../lib/expect")

local settings = Config.Rebirth

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

return {
	{
		Name = "cost grows by CostGrowth per Rebirth; each Rebirth adds the same income and luck for good",
		Run = function()
			expect.equal(Rebirth.cost(settings, 0), settings.BaseCost, "first Rebirth")
			for n = 1, 6 do
				expect.near(Rebirth.cost(settings, n) / Rebirth.cost(settings, n - 1), settings.CostGrowth, 1e-9, `cost {n}`)
			end
			expect.equal(Rebirth.incomeMultiplier(settings, 0), 1, "no Rebirth: x1 income")
			expect.equal(Rebirth.luckMultiplier(settings, 0), 1, "no Rebirth: x1 luck")
			expect.near(Rebirth.incomeMultiplier(settings, 2), 1 + 2 * settings.IncomeStep, 1e-12, "two Rebirths income")
			expect.near(Rebirth.luckMultiplier(settings, 2), 1 + 2 * settings.LuckStep, 1e-12, "two Rebirths luck")
			expect.truthy(settings.IncomeStep > 0 and settings.LuckStep > 0, "Rebirth always helps")
			-- Additive: each Rebirth is worth relatively less than the one before.
			local gain1 = Rebirth.incomeMultiplier(settings, 1) / Rebirth.incomeMultiplier(settings, 0)
			local gain5 = Rebirth.incomeMultiplier(settings, 5) / Rebirth.incomeMultiplier(settings, 4)
			expect.truthy(gain5 < gain1, "later Rebirths give a smaller boost")
			-- The older geometric settings still work (sims use them).
			local geometric = { BaseCost = 1, CostGrowth = 2, IncomeGrowth = 2, LuckGrowth = 1.5 }
			expect.equal(Rebirth.incomeMultiplier(geometric, 3), 8, "geometric income")
			expect.near(Rebirth.luckMultiplier(geometric, 2), 2.25, 1e-12, "geometric luck")
		end,
	},
	{
		Name = "apply resets CE, pedestal levels and skill ranks and keeps everything else",
		Run = function()
			local data = deepCopy(DataTemplate.Template)
			data.CE = 5e8
			data.LifetimeCE = 9e8
			data.Pedestals = {
				{ Level = 30, Locked = true, Uid = 7 },
				{ Level = 12, Locked = false },
				{ Level = 1, Locked = false },
				{ Level = 50, Locked = false, Uid = 9 },
			}
			data.Skills.CoreLuck = 24
			data.Skills.ScanSpeed = 9
			data.Inventory = { { Uid = 7, Id = "SenzoBean", At = 1, Source = "Scan" } }
			data.Discovered = { SenzoBean = 1 }
			Rebirth.apply(data)
			expect.equal(data.Rebirths, 1, "one Rebirth")
			expect.equal(data.CE, 0, "CE reset")
			expect.equal(data.LifetimeCE, 9e8, "lifetime CE kept")
			expect.equal(#data.Pedestals, 4, "bought slots kept")
			for index, pedestal in data.Pedestals do
				expect.equal(pedestal.Level, 1, `pedestal {index} level reset`)
			end
			expect.equal(data.Pedestals[1].Uid, 7, "displayed relic kept")
			expect.equal(data.Pedestals[1].Locked, true, "lock kept")
			for id, rank in data.Skills do
				expect.equal(rank, 0, `{id} rank reset`)
			end
			expect.equal(#data.Inventory, 1, "relics kept")
			expect.equal(data.Discovered.SenzoBean, 1, "Codex kept")
			Rebirth.apply(data)
			expect.equal(data.Rebirths, 2, "counts up")
		end,
	},
	{
		Name = "saved data starts with no Rebirths",
		Run = function()
			expect.equal(DataTemplate.Template.Rebirths, 0, "template")
			expect.equal(Config.Save.StoreName, "PlayerData_v2", "fresh DataStore for the new economy")
		end,
	},
	{
		Name = "BPlus apply resets CE only and preserves skills pedestals Collection",
		Run = function()
			local data = deepCopy(DataTemplate.Template)
			data.CE = 5e8
			data.Pedestals = {
				{ Level = 30, Locked = true, Uid = 7 },
				{ Level = 12, Locked = false },
			}
			data.Skills.CoreLuck = 18
			data.Skills.PedestalMastery = 2
			data.Collection.Essence = 40
			data.Collection.Fusion = { Zabimaru = { Rank = 1, Charm = "Hunt" } }
			data.Inventory = { { Uid = 7, Id = "SenzoBean", At = 1, Source = "Scan" } }
			data.Discovered = { SenzoBean = 1 }
			Rebirth.apply(data, "BPlus")
			expect.equal(data.Rebirths, 1, "one Rebirth")
			expect.equal(data.CE, 0, "CE reset")
			expect.equal(data.Pedestals[1].Level, 30, "pedestal kept")
			expect.equal(data.Pedestals[2].Level, 12, "pedestal 2 kept")
			expect.equal(data.Skills.CoreLuck, 18, "CoreLuck kept")
			expect.equal(data.Skills.PedestalMastery, 2, "Mastery kept")
			expect.equal(data.Collection.Essence, 40, "Essence kept")
			expect.equal(data.Collection.Fusion.Zabimaru.Rank, 1, "Fusion kept")
			expect.equal(data.Discovered.SenzoBean, 1, "Codex kept")
			Rebirth.apply(data, "BPlus")
			expect.equal(data.Rebirths, 2, "counts up once per apply")
			expect.equal(data.Skills.CoreLuck, 18, "no skill wipe on R2")
			expect.near(Rebirth.incomeMultiplier(settings, 2), 1 + 2 * settings.IncomeStep, 1e-12, "perm income")
		end,
	},
	{
		Name = "Live apply still resets skills and pedestals (production path)",
		Run = function()
			local data = deepCopy(DataTemplate.Template)
			data.CE = 5e8
			data.Pedestals = { { Level = 20 } }
			data.Skills.CoreLuck = 10
			Rebirth.apply(data, "Live")
			expect.equal(data.Pedestals[1].Level, 1, "ped reset")
			expect.equal(data.Skills.CoreLuck, 0, "skill reset")
		end,
	},
}

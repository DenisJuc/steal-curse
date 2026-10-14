-- Skill tree (GDD 6.6): every node, its cost curve, rank-0 effects and validated bulk buying.

local Config = require("../../src/shared/Config")
local DataTemplate = require("../../src/server/Data/DataTemplate")
local Formulas = require("../../src/shared/Formulas")
local MutationConfig = require("../../src/shared/MutationConfig")
local SkillConfig = require("../../src/shared/SkillConfig")
local expect = require("../lib/expect")

local nodes = SkillConfig.ById

return {
	{
		Name = "every node has a branch, a cost for each rank, and a saved rank in the data template",
		Run = function()
			local branches = {}
			for _, branch in SkillConfig.Branches do
				branches[branch.Id] = true
			end
			local count = 0
			for _, node in SkillConfig.Nodes do
				count += 1
				expect.truthy(branches[node.Branch], `{node.Id} has an unknown branch`)
				expect.truthy(node.MaxRank >= 1, `{node.Id} max rank`)
				for rank = 0, node.MaxRank - 1 do
					local cost = SkillConfig.cost(node, rank)
					expect.truthy(cost and cost > 0, `{node.Id} rank {rank} has no cost`)
				end
				expect.equal(SkillConfig.cost(node, node.MaxRank), nil, `{node.Id} maxed cost`)
				expect.equal(DataTemplate.Template.Skills[node.Id], 0, `{node.Id} missing from DataTemplate.Skills`)
			end
			for id in DataTemplate.Template.Skills do
				expect.truthy(nodes[id], `DataTemplate.Skills.{id} is not a skill node`)
			end
			expect.equal(count, 11, "GDD 6.6 nodes + Swift Step")
		end,
	},
	{
		Name = "cost curves follow the GDD",
		Run = function()
			expect.equal(nodes.CoreLuck.MaxRank, Config.Luck.CoreLuckMaxRank, "Core Luck max rank")
			for rank = 0, nodes.CoreLuck.MaxRank - 1 do
				expect.equal(SkillConfig.cost(nodes.CoreLuck, rank), Formulas.coreLuckCost(rank), `Core Luck rank {rank}`)
			end
			local merchant = { 2000, 5000, 12500, 31250, 78125 }
			for rank, cost in merchant do
				expect.equal(SkillConfig.cost(nodes.SpiritMerchant, rank - 1), cost, `Spirit Merchant rank {rank}`)
			end
			local focus = { 20000, 60000, 180000, 540000, 1600000 }
			for rank, cost in focus do
				expect.equal(SkillConfig.cost(nodes.FrequencyFocus, rank - 1), cost, `Frequency Focus rank {rank}`)
			end
			expect.equal(SkillConfig.cost(nodes.ScanSpeed, 0), 250, "Scan Speed first rank")
			expect.equal(SkillConfig.cost(nodes.EnergyConduction, 0), 500, "Energy Conduction first rank")
			expect.equal(SkillConfig.cost(nodes.SpiritReservoir, 0), 1000000, "Spirit Reservoir rank 1")
			expect.equal(SkillConfig.cost(nodes.SpiritReservoir, 1), 50000000, "Spirit Reservoir rank 2")
			expect.equal(SkillConfig.cost(nodes.CoreLuck, 0), 100, "Core Luck first rank")
			expect.equal(SkillConfig.cost(nodes.CoreLuck, 10), math.ceil(100 * 1.6 ^ 10 - 1e-9), "Core Luck rank 11")
			-- Costs never go down from one rank to the next.
			for _, node in SkillConfig.Nodes do
				for rank = 1, node.MaxRank - 1 do
					local previous = SkillConfig.cost(node, rank - 1) :: number
					expect.truthy((SkillConfig.cost(node, rank) :: number) >= previous, `{node.Id} cost drops at {rank}`)
				end
			end
		end,
	},
	{
		Name = "rank 0 effects equal the base game values, max ranks match their systems",
		Run = function()
			expect.equal(SkillConfig.scanInterval(0), Config.Scan.BaseIntervalSeconds, "scan interval")
			expect.near(SkillConfig.scanInterval(nodes.ScanSpeed.MaxRank), Config.Luck.FastestScanSeconds, 1e-9, "fastest scan")
			expect.equal(SkillConfig.sightRange(0), Config.SpiritSight.RevealRange, "reveal range")
			expect.equal(SkillConfig.pulseCooldown(0), Config.SpiritSight.PulseCooldownSeconds, "pulse cooldown")
			expect.equal(SkillConfig.holdSeconds(0), Config.Bind.HoldSeconds, "hold to bind")
			expect.equal(SkillConfig.offlineCapSeconds(0), Config.Offline.CapSeconds, "offline cap")
			expect.equal(SkillConfig.offlineCapSeconds(2), 4 * 3600, "offline cap at max")
			expect.equal(SkillConfig.incomeBonus(0), 0, "income bonus")
			expect.equal(SkillConfig.sellBonus(0), 0, "sell bonus")
			expect.equal(SkillConfig.harvestMultiplier(0), 1, "harvest")
			expect.equal(SkillConfig.walkSpeed(0), Config.World.WalkSpeed, "walk speed")
			expect.near(SkillConfig.walkSpeed(nodes.SwiftStep.MaxRank), 56, 1e-9, "Swift Step max")
			expect.equal(nodes.MutationResonance.MaxRank, MutationConfig.MaxRank, "mutation ranks")
			expect.equal(nodes.FrequencyFocus.MaxRank, #Config.Frequency.MultiplierByRank, "frequency ranks")
			expect.near(SkillConfig.incomeBonus(nodes.EnergyConduction.MaxRank), 0.40, 1e-9, "Energy Conduction max")
			expect.near(SkillConfig.sellBonus(nodes.SpiritMerchant.MaxRank), 0.50, 1e-9, "Spirit Merchant max")
		end,
	},
	{
		Name = "effects improve every rank and stay positive at max",
		Run = function()
			for rank = 1, nodes.ScanSpeed.MaxRank do
				expect.truthy(SkillConfig.scanInterval(rank) < SkillConfig.scanInterval(rank - 1), `scan rank {rank}`)
			end
			expect.truthy(SkillConfig.pulseCooldown(nodes.SpiritSight.MaxRank) > 0, "pulse cooldown stays positive")
			expect.truthy(SkillConfig.holdSeconds(nodes.BindingEfficiency.MaxRank) >= Config.Bind.DebugMinHoldSeconds, "hold")
			expect.truthy(SkillConfig.sightRange(nodes.SpiritSight.MaxRank) > SkillConfig.sightRange(0), "sight range")
			for rank = 1, nodes.SwiftStep.MaxRank do
				expect.truthy(SkillConfig.walkSpeed(rank) > SkillConfig.walkSpeed(rank - 1), `walk speed rank {rank}`)
			end
			-- Resonant Harvest raises bonus finds by whole relics (rounded up).
			local base = Formulas.bonusRolls(Config.Scan.BaseIntervalSeconds, Config.Signals.RegenSeconds, Config.Hunt)
			local boosted = math.ceil(base * SkillConfig.harvestMultiplier(nodes.ResonantHarvest.MaxRank) - 1e-9)
			expect.truthy(boosted > base, "harvest adds bonus finds")
		end,
	},
	{
		Name = "bulk buy checks every intermediate cost and never overshoots",
		Run = function()
			local node = nodes.CoreLuck
			local three = 0
			for rank = 0, 2 do
				three += SkillConfig.cost(node, rank) :: number
			end
			local ranks, total = SkillConfig.affordable(node, 0, three, 10)
			expect.equal(ranks, 3, "exact budget buys three")
			expect.equal(total, three, "total spent")
			ranks = SkillConfig.affordable(node, 0, three - 1, 10)
			expect.equal(ranks, 2, "one CE short buys two")
			ranks = SkillConfig.affordable(node, 0, math.huge, 10)
			expect.equal(ranks, 10, "limit respected")
			ranks = SkillConfig.affordable(node, 95, math.huge, node.MaxRank)
			expect.equal(ranks, 5, "stops at max rank")
			ranks, total = SkillConfig.affordable(node, node.MaxRank, math.huge, 10)
			expect.equal(ranks, 0, "maxed buys nothing")
			expect.equal(total, 0, "maxed spends nothing")
			ranks = SkillConfig.affordable(nodes.SpiritReservoir, 0, 1000000 + 49999999, 2)
			expect.equal(ranks, 1, "no partial purchase")
		end,
	},
}

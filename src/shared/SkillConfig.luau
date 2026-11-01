-- Skill tree (GDD 6.6): three branches plus the Mutation Resonance node, all bought with CE (no
-- skill points). Pure data + math so the server, the menu and Lune tests share every number.
-- Cost of a node = CE to go from rank n to n + 1: Costs[n + 1] when listed, otherwise
-- ceil(CostBase x CostGrowth^n). Effects at rank 0 equal the game's base values (Config), which a
-- Lune test checks.

local SkillConfig = {}

export type Node = {
	Id: string,
	Branch: string,
	Name: string,
	MaxRank: number,
	Costs: { number }?,
	CostBase: number?,
	CostGrowth: number?,
	Summary: string,
	-- Tree layout (SkillTreePanel): column 1-3 and row of the node in its branch's tree.
	Pos: { number },
	-- The node above it on the path: it unlocks once that node has rank 1 (nil = branch root).
	Requires: string?,
	-- IconAssets key drawn on the node, and an optional letter badge over it.
	Icon: string,
	Badge: string?,
}

SkillConfig.Branches = {
	{ Id = "Resonance", Name = "Resonance", Blurb = "Luck, scan speed, frequency and mutations" },
	{ Id = "Sanctuary", Name = "Sanctuary", Blurb = "Shrine income, selling and offline time" },
	{ Id = "BindingArts", Name = "Binding Arts", Blurb = "Hunting: Spirit Sight, binding, bonus finds and walk speed" },
}

SkillConfig.Nodes = {
	{
		Id = "CoreLuck",
		Pos = { 2, 1 },
		Icon = "Luck",
		Branch = "Resonance",
		Name = "Core Luck",
		MaxRank = 100,
		-- Costs grow faster than luck (x10 luck costs about x100 CE), so luck can't run away.
		CostBase = 100,
		CostGrowth = 1.6,
		Summary = "Multiplies your luck: x10 every 10 ranks (rank 100 = 10 billion x).",
	},
	{
		Id = "ScanSpeed",
		Pos = { 1, 2 },
		Requires = "CoreLuck",
		Icon = "PotionHaste",
		Branch = "Resonance",
		Name = "Scan Speed",
		MaxRank = 12,
		CostBase = 250,
		CostGrowth = 2.2,
		Summary = "Your Spirit Resonator scans faster: 4 s down to 1 s.",
	},
	{
		Id = "FrequencyFocus",
		Pos = { 3, 2 },
		Requires = "CoreLuck",
		Icon = "Pulse",
		Branch = "Resonance",
		Name = "Frequency Focus",
		MaxRank = 5,
		Costs = { 20000, 60000, 180000, 540000, 1600000 },
		Summary = "Your Signal Frequency pulls its family harder (x1.5 up to x3).",
	},
	{
		Id = "MutationResonance",
		Pos = { 3, 3 },
		Requires = "FrequencyFocus",
		Icon = "Lightning",
		Branch = "Resonance",
		Name = "Mutation Resonance",
		MaxRank = 5,
		-- GDD 6.6: "set via balance config". Rank 1 around the first Rebirth, rank 5 late.
		Costs = { 250000, 5000000, 100000000, 2000000000, 40000000000 },
		Summary = "Unlocks mutations (one more per rank) and raises the mutation chance.",
	},
	{
		Id = "EnergyConduction",
		Pos = { 2, 1 },
		Icon = "CursedEnergy",
		Branch = "Sanctuary",
		Name = "Energy Conduction",
		MaxRank = 20,
		CostBase = 500,
		CostGrowth = 1.7,
		Summary = "More pedestal income: +2% per rank (up to +40%).",
	},
	{
		-- Studio Phase 3 trial only (BalanceTrials.pedestalMasteryEnabled). +4%/rank on pedestal income.
		Id = "PedestalMastery",
		Pos = { 3, 2 },
		Requires = "EnergyConduction",
		Icon = "Pedestals",
		Branch = "Sanctuary",
		Name = "Pedestal Mastery",
		MaxRank = 5,
		CostBase = 180000,
		CostGrowth = 2.8,
		Summary = "Deeper pedestal craft — +4% pedestal income per rank (2 ranks pre-Rebirth, 5 after).",
	},
	{
		Id = "SpiritMerchant",
		Pos = { 1, 2 },
		Requires = "EnergyConduction",
		Icon = "PotionFortune",
		Branch = "Sanctuary",
		Name = "Spirit Merchant",
		MaxRank = 5,
		CostBase = 2000,
		CostGrowth = 2.5,
		Summary = "Relics sell for more: +10% per rank (up to +50%).",
	},
	{
		Id = "SpiritReservoir",
		Pos = { 1, 3 },
		Requires = "SpiritMerchant",
		Icon = "Streak",
		Branch = "Sanctuary",
		Name = "Spirit Reservoir",
		MaxRank = 2,
		Costs = { 1000000, 50000000 },
		Summary = "Offline earnings last longer: 2 h, then 3 h, then 4 h.",
	},
	{
		Id = "SpiritSight",
		Pos = { 1, 2 },
		Requires = "SwiftStep",
		Icon = "SpiritSight",
		Branch = "BindingArts",
		Name = "Spirit Sight",
		MaxRank = 5,
		CostBase = 2000,
		CostGrowth = 2.2,
		Summary = "See signals from farther away and pulse more often.",
	},
	{
		Id = "BindingEfficiency",
		Pos = { 3, 2 },
		Requires = "SwiftStep",
		Icon = "Bind",
		Branch = "BindingArts",
		Name = "Binding Efficiency",
		MaxRank = 5,
		CostBase = 3000,
		CostGrowth = 2.4,
		Summary = "Signals resist less: the hold to bind gets shorter.",
	},
	{
		Id = "ResonantHarvest",
		Pos = { 2, 3 },
		Requires = "SpiritSight",
		Icon = "Wild",
		Branch = "BindingArts",
		Name = "Resonant Harvest",
		MaxRank = 5,
		CostBase = 5000,
		CostGrowth = 2.6,
		Summary = "More bonus discoveries per capture: +10% per rank.",
	},
	{
		Id = "SwiftStep",
		Pos = { 2, 1 },
		Icon = "Home",
		Branch = "BindingArts",
		Name = "Swift Step",
		MaxRank = 10,
		CostBase = 1000,
		CostGrowth = 1.9,
		Summary = "Walk faster: +4 walk speed per rank (16 up to 56).",
	},
	{
		-- Overnight v0.1 nodes (Config-free, balance in this file): bigger relics show up more often.
		Id = "HugeAttunement",
		Pos = { 1, 3 },
		Requires = "ScanSpeed",
		Icon = "Pedestals",
		Badge = "H",
		Branch = "Resonance",
		Name = "Huge Attunement",
		MaxRank = 5,
		CostBase = 25000,
		CostGrowth = 2.5,
		Summary = "Huge relics turn up more often: +25% Huge chance per rank.",
	},
	{
		Id = "TitanicAttunement",
		Pos = { 2, 4 },
		Requires = "HugeAttunement",
		Icon = "Pedestals",
		Badge = "T",
		Branch = "Resonance",
		Name = "Titanic Attunement",
		MaxRank = 3,
		Costs = { 500000, 4000000, 30000000 },
		Summary = "Titanic relics turn up more often: +25% Titanic chance per rank.",
	},
	{
		Id = "Kindred",
		Pos = { 2, 3 },
		Requires = "EnergyConduction",
		Icon = "Favorite",
		Branch = "Sanctuary",
		Name = "Kindred Spirits",
		MaxRank = 2,
		Costs = { 50000, 500000 },
		Summary = "Friends in your server help more: +5% luck per friend per rank.",
	},
} :: { Node }

SkillConfig.ById = {} :: { [string]: Node }
for _, node in SkillConfig.Nodes do
	SkillConfig.ById[node.Id] = node
end

-- Effect numbers. Rank 0 values must match Config (Scan, SpiritSight, Bind, Offline).
SkillConfig.Effects = {
	ScanBaseSeconds = 4,
	ScanFastestSeconds = 1,
	IncomePerConductionRank = 0.02,
	-- Studio Pedestal Mastery (Phase 3): additive with Energy Conduction, applied in PedestalService.
	IncomePerMasteryRank = 0.04,
	SellPerMerchantRank = 0.10,
	OfflineBaseSeconds = 2 * 3600,
	OfflineSecondsPerReservoirRank = 3600,
	SightBaseRange = 90,
	SightRangePerRank = 15,
	PulseBaseCooldown = 6,
	PulseCooldownPerRank = 0.6,
	HoldBaseSeconds = 6,
	HoldSecondsPerRank = 0.5,
	HarvestPerRank = 0.10,
	WalkBaseSpeed = 16,
	WalkSpeedPerRank = 4,
	HugeChancePerRank = 0.25,
	TitanicChancePerRank = 0.25,
	FriendLuckPerKindredRank = 0.05,
}

export type CostOverride = {
	Base: number,
	Growth: number,
	SoftK: number?,
	SoftPower: number?,
}

-- CE to buy rank `rank + 1`; nil when the node is maxed.
-- Optional costOverride (base, growth[, softK]) is used by balance trials for CoreLuck.
function SkillConfig.cost(node: Node, rank: number, costOverride: CostOverride?): number?
	if rank >= node.MaxRank then
		return nil
	end
	if costOverride and node.Id == "CoreLuck" then
		local Formulas = if script ~= nil then require(script.Parent.Formulas) else require("./Formulas")
		if costOverride.SoftK then
			return Formulas.coreLuckCostSoft(
				rank,
				costOverride.Base,
				costOverride.Growth,
				costOverride.SoftK,
				costOverride.SoftPower
			)
		end
		return Formulas.coreLuckCost(rank, costOverride.Base, costOverride.Growth)
	end
	if node.Costs then
		return node.Costs[rank + 1]
	end
	return math.ceil((node.CostBase :: number) * (node.CostGrowth :: number) ^ rank - 1e-9)
end

-- How many ranks `budget` buys from `rank` (at most `limit`), checking every intermediate cost.
function SkillConfig.affordable(
	node: Node,
	rank: number,
	budget: number,
	limit: number,
	costOverride: CostOverride?
): (number, number)
	local bought, total = 0, 0
	while bought < limit do
		local nextCost = SkillConfig.cost(node, rank + bought, costOverride)
		if not nextCost or total + nextCost > budget + 1e-9 then
			break
		end
		total += nextCost
		bought += 1
	end
	return bought, total
end

local effects = SkillConfig.Effects

-- Scan interval: geometric from 4 s at rank 0 to 1 s at max rank (same % faster every rank).
function SkillConfig.scanInterval(rank: number): number
	local node = SkillConfig.ById.ScanSpeed
	local t = math.clamp(rank, 0, node.MaxRank) / node.MaxRank
	return effects.ScanBaseSeconds * (effects.ScanFastestSeconds / effects.ScanBaseSeconds) ^ t
end

function SkillConfig.incomeBonus(rank: number): number
	return effects.IncomePerConductionRank * rank
end

function SkillConfig.sellBonus(rank: number): number
	return effects.SellPerMerchantRank * rank
end

function SkillConfig.offlineCapSeconds(rank: number): number
	return effects.OfflineBaseSeconds + effects.OfflineSecondsPerReservoirRank * rank
end

function SkillConfig.sightRange(rank: number): number
	return effects.SightBaseRange + effects.SightRangePerRank * rank
end

function SkillConfig.pulseCooldown(rank: number): number
	return effects.PulseBaseCooldown - effects.PulseCooldownPerRank * rank
end

function SkillConfig.holdSeconds(rank: number): number
	return effects.HoldBaseSeconds - effects.HoldSecondsPerRank * rank
end

-- Multiplier on hunt bonus discoveries.
function SkillConfig.harvestMultiplier(rank: number): number
	return 1 + effects.HarvestPerRank * rank
end

-- Humanoid WalkSpeed (studs/s).
function SkillConfig.walkSpeed(rank: number): number
	return effects.WalkBaseSpeed + effects.WalkSpeedPerRank * rank
end

-- Multipliers on the Huge / Titanic size chances (SizeConfig.roll).
function SkillConfig.hugeChanceMult(rank: number): number
	return 1 + effects.HugeChancePerRank * rank
end

function SkillConfig.titanicChanceMult(rank: number): number
	return 1 + effects.TitanicChancePerRank * rank
end

-- Extra luck per friend in the server (on top of Config.Friends.LuckPerFriend).
function SkillConfig.kindredBonus(rank: number): number
	return effects.FriendLuckPerKindredRank * rank
end

-- Can `nodeId` be bought given these ranks? Owned nodes always stay open (old saves).
function SkillConfig.unlocked(nodeId: string, ranks: { [string]: number }): boolean
	local node = SkillConfig.ById[nodeId]
	if not node then
		return false
	end
	if (ranks[nodeId] or 0) > 0 or not node.Requires then
		return true
	end
	return (ranks[node.Requires] or 0) > 0
end

return SkillConfig

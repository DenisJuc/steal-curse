-- Lost offering boxes (and the Lost One's Spirit Gift): a weighted reward tier with pity, then one
-- reward of that tier. Pure (no Roblox APIs): randomness comes from `nextNumber`, so Lune tests
-- cover the odds, the pity and the reward shapes. WildFindsService pays the result out.

local Offerings = {}

export type Tier = { Id: string, Name: string, Weight: number, Color: { number } }

export type RewardSpec = {
	Weight: number,
	CE: { number }?,
	Rolls: { number }?,
	Potion: { string }?,
	Bundle: { [string]: number }?,
	LanternChance: number?,
}

export type Options = {
	PityAt: number,
	MinCE: number,
	Tiers: { Tier },
	Rewards: { [string]: { RewardSpec } },
	Lanterns: { string },
}

-- What one box gives (CEMinutes is turned into CE with the player's income by the server).
export type Reward = {
	Tier: string,
	CEMinutes: number?,
	Rolls: number?,
	Potions: { [string]: number },
	Lantern: string?,
}

local function between(range: { number }, roll: number): number
	return range[1] + roll * (range[2] - range[1])
end

-- Index of the tier (in options.Tiers) for a roll in [0, 1).
local function tierIndex(options: Options, roll: number): number
	local total = 0
	for _, tier in options.Tiers do
		total += tier.Weight
	end
	local target = roll * total
	for index, tier in options.Tiers do
		target -= tier.Weight
		if target < 0 then
			return index
		end
	end
	return #options.Tiers
end

-- Picks a tier. `misses` = boxes in a row below the second tier. Returns the tier id and the new
-- miss count.
function Offerings.rollTier(options: Options, misses: number, roll: number): (string, number)
	local index = tierIndex(options, roll)
	if index < 2 and misses + 1 >= options.PityAt then
		index = 2
	end
	return options.Tiers[index].Id, if index < 2 then misses + 1 else 0
end

function Offerings.tierOf(options: Options, id: string): Tier?
	for _, tier in options.Tiers do
		if tier.Id == id then
			return tier
		end
	end
	return nil
end

-- One reward of `tierId`. `owned` = lantern ids the player already has.
function Offerings.rollReward(
	options: Options,
	tierId: string,
	nextNumber: () -> number,
	owned: { [string]: boolean }
): Reward
	local list = options.Rewards[tierId] or {}
	local total = 0
	for _, spec in list do
		total += spec.Weight
	end
	local target = nextNumber() * total
	local spec = list[#list]
	for _, each in list do
		target -= each.Weight
		if target < 0 then
			spec = each
			break
		end
	end
	local reward: Reward = { Tier = tierId, Potions = {} }
	if not spec then
		return reward
	end
	if spec.CE then
		reward.CEMinutes = between(spec.CE, nextNumber())
	end
	if spec.Rolls then
		reward.Rolls = math.floor(between(spec.Rolls, nextNumber()) + 0.5)
	end
	if spec.Potion and #spec.Potion > 0 then
		local id = spec.Potion[math.clamp(math.floor(nextNumber() * #spec.Potion) + 1, 1, #spec.Potion)]
		reward.Potions[id] = 1
	end
	if spec.Bundle then
		for id, count in spec.Bundle do
			reward.Potions[id] = (reward.Potions[id] or 0) + count
		end
	end
	if spec.LanternChance and nextNumber() < spec.LanternChance then
		local missing = {}
		for _, id in options.Lanterns do
			if not owned[id] then
				table.insert(missing, id)
			end
		end
		if #missing > 0 then
			reward.Lantern = missing[math.clamp(math.floor(nextNumber() * #missing) + 1, 1, #missing)]
		end
	end
	return reward
end

-- CE for `minutes` of income, never below the floor (new players have no income yet).
function Offerings.ceAmount(minutes: number, incomePerSec: number, options: Options): number
	return math.max(options.MinCE, math.floor(minutes * 60 * incomePerSec))
end

return Offerings

-- Potions (Slice 12): earnable consumables, no Robux and no second currency. Each one starts a
-- timed buff; using another of the same kind adds its time, up to MaxBuffSeconds. Timers only count
-- down while the player is online. Pure (no Roblox APIs) so Lune tests cover stacking, caps and
-- timer math; ItemService applies the effects on the server.

local ItemConfig = {}

export type Effect = "Luck" | "Haste" | "Fortune"

export type Item = {
	Id: string,
	Name: string,
	Description: string,
	Effect: Effect,
	-- Luck: luck factor (capped by Config.Luck.MaxConsumable). Haste: scan interval factor.
	-- Fortune: income bonus added to the Income stack.
	Value: number,
	DurationSeconds: number,
	-- {r, g, b} for the UI.
	Color: { number },
}

ItemConfig.Items = {
	{
		Id = "LuckPotion",
		Name = "Luck Potion",
		Description = "x2 Luck for 10 minutes.",
		Effect = "Luck",
		Value = 2,
		DurationSeconds = 600,
		Color = { 120, 235, 140 },
	},
	{
		Id = "HastePotion",
		Name = "Haste Potion",
		Description = "Rolls charge in 75% of the time for 10 minutes.",
		Effect = "Haste",
		Value = 0.75,
		DurationSeconds = 600,
		Color = { 120, 200, 255 },
	},
	{
		Id = "FortunePotion",
		Name = "Fortune Potion",
		Description = "+50% Cursed Energy income for 10 minutes.",
		Effect = "Fortune",
		Value = 0.5,
		DurationSeconds = 600,
		Color = { 255, 196, 80 },
	},
} :: { Item }

ItemConfig.ById = {} :: { [string]: Item }
for _, item in ItemConfig.Items do
	ItemConfig.ById[item.Id] = item
end

-- A buff never holds more than this many seconds.
ItemConfig.MaxBuffSeconds = 3600
-- Owned potions of one kind are capped so drops can't pile up forever.
ItemConfig.MaxStack = 99

-- Drop sources.
ItemConfig.Drops = {
	-- Chance per successful hunt capture to find one potion, picked by Weights.
	CaptureChance = 0.12,
	Weights = { LuckPotion = 40, HastePotion = 30, FortunePotion = 30 },
	-- Fixed rewards when a Codex milestone is claimed.
	Milestones = {
		Essential20 = { LuckPotion = 1 },
		Essential40 = { HastePotion = 1, FortunePotion = 1 },
		Essential60 = { LuckPotion = 2 },
		Essential80 = { LuckPotion = 2, HastePotion = 2 },
		Essential100 = { LuckPotion = 3, HastePotion = 3, FortunePotion = 3 },
		Collection50 = { FortunePotion = 2 },
	} :: { [string]: { [string]: number } },
	-- One-time reward for the first Legendary-or-rarer relic ever found.
	FirstRareTier = "Legendary",
	FirstRare = { LuckPotion = 1, FortunePotion = 1 } :: { [string]: number },
}

-- Seconds left after using one more potion with `current` seconds left, and whether it can be used
-- (refused when the buff is already at the cap, so a potion is never wasted entirely).
function ItemConfig.addTime(current: number, duration: number, cap: number): (number, boolean)
	current = math.max(0, current)
	if current >= cap then
		return current, false
	end
	return math.min(cap, current + duration), true
end

-- Counts every buff down by `dt` seconds (online time only). Removes and returns expired ids.
function ItemConfig.tick(buffs: { [string]: number }, dt: number): { string }
	local expired = {}
	for id, left in buffs do
		local now = left - dt
		if now <= 0 then
			buffs[id] = nil
			table.insert(expired, id)
		else
			buffs[id] = now
		end
	end
	table.sort(expired)
	return expired
end

local function active(buffs: { [string]: number }, effect: Effect): Item?
	for id, left in buffs do
		local item = ItemConfig.ById[id]
		if item and item.Effect == effect and left > 0 then
			return item
		end
	end
	return nil
end

-- Luck factor from potions, never above the consumable cap (GDD 5.2).
function ItemConfig.luckFactor(buffs: { [string]: number }, maxConsumable: number): number
	local item = active(buffs, "Luck")
	return if item then math.min(maxConsumable, item.Value) else 1
end

function ItemConfig.intervalFactor(buffs: { [string]: number }): number
	local item = active(buffs, "Haste")
	return if item then item.Value else 1
end

function ItemConfig.incomeBonus(buffs: { [string]: number }): number
	local item = active(buffs, "Fortune")
	return if item then item.Value else 0
end

-- Picks one potion id from Drops.Weights with a uniform roll in [0, 1).
function ItemConfig.pickDrop(weights: { [string]: number }, roll: number): string
	local ids = {}
	local total = 0
	for id, weight in weights do
		table.insert(ids, id)
		total += weight
	end
	table.sort(ids)
	local target = roll * total
	for _, id in ids do
		target -= weights[id]
		if target < 0 then
			return id
		end
	end
	return ids[#ids]
end

-- "9:58" / "1:00:00"
function ItemConfig.formatTime(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return ItemConfig

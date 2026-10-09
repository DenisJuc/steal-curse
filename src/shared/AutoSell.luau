-- Auto-sell rules (GDD 9.2, 9.3). Pure: no Roblox APIs, no requires, so Lune tests it as a
-- decision table. The server runs decide() on every new find that Auto-Display didn't place;
-- the UI runs the same function for its "what will happen" preview.
--
-- Precedence (first match wins):
--   1. Favorite relic (relic + mutation)          -> keep
--   2. First discovery, if ProtectFirst is on       -> keep
--   3. Mutated, if ProtectMutated is on             -> keep
--   4. Rarity rule "Sell All"                       -> sell
--   5. Duplicate, with rarity rule "Sell Duplicates" or the global Sell All Duplicates toggle -> sell
--   6. Base odds more common than 1 in SellEasierThan -> sell
--   7. Otherwise                                     -> keep
-- Displayed and locked items never reach decide(); the Codex records a find before this runs.

local AutoSell = {}

export type Mode = "Keep" | "SellDuplicates" | "SellAll"

export type Rules = {
	Tiers: { [string]: Mode },
	SellAllDuplicates: boolean,
	-- 0 = off. Otherwise sell finds whose base odds are better (more common) than 1 in this number.
	SellEasierThan: number,
	ProtectFirst: boolean,
	ProtectMutated: boolean,
}

export type Facts = {
	Tier: string,
	-- Base odds as "1 in BaseOneIn" (1x luck, no focus, no frequency).
	BaseOneIn: number,
	First: boolean,
	Mutated: boolean,
	-- You already hold a copy of the same base relic that earns at least as much.
	Duplicate: boolean,
	Favorite: boolean,
}

export type Reason = "Favorite" | "FirstDiscovery" | "Mutated" | "RarityRule" | "Duplicate" | "OddsThreshold" | "NoRule"

AutoSell.Modes = { "Keep", "SellDuplicates", "SellAll" } :: { Mode }

AutoSell.ModeLabels = {
	Keep = "Keep All",
	SellDuplicates = "Sell Duplicates",
	SellAll = "Sell All",
} :: { [Mode]: string }

AutoSell.ThresholdPresets = { 0, 10, 100, 1000, 10000, 100000, 1000000 }

AutoSell.ReasonText = {
	Favorite = "favorite",
	FirstDiscovery = "first discovery",
	Mutated = "mutated",
	RarityRule = "rarity rule",
	Duplicate = "duplicate",
	OddsThreshold = "odds rule",
	NoRule = "no rule",
	InventoryFull = "inventory full",
} :: { [string]: string }

function AutoSell.defaults(tierIds: { string }): Rules
	local tiers = {}
	for _, tierId in tierIds do
		tiers[tierId] = "Keep"
	end
	return {
		Tiers = tiers,
		SellAllDuplicates = false,
		SellEasierThan = 0,
		ProtectFirst = true,
		ProtectMutated = true,
	}
end

local VALID_MODE = { Keep = true, SellDuplicates = true, SellAll = true }

-- Builds a clean rule set from untrusted input; anything missing or invalid falls back to `base`.
function AutoSell.sanitize(raw: any, tierIds: { string }, base: Rules): Rules
	local source = if type(raw) == "table" then raw else {}
	local rawTiers = if type(source.Tiers) == "table" then source.Tiers else {}
	local tiers = {}
	for _, tierId in tierIds do
		local mode = rawTiers[tierId]
		tiers[tierId] = if type(mode) == "string" and VALID_MODE[mode] then mode else base.Tiers[tierId] or "Keep"
	end
	local function flag(value: any, fallback: boolean): boolean
		return if type(value) == "boolean" then value else fallback
	end
	local threshold = source.SellEasierThan
	if type(threshold) ~= "number" or threshold ~= threshold or threshold < 0 or threshold > 1e18 then
		threshold = base.SellEasierThan
	end
	return {
		Tiers = tiers,
		SellAllDuplicates = flag(source.SellAllDuplicates, base.SellAllDuplicates),
		SellEasierThan = threshold,
		ProtectFirst = flag(source.ProtectFirst, base.ProtectFirst),
		ProtectMutated = flag(source.ProtectMutated, base.ProtectMutated),
	}
end

-- Returns (sell?, reason).
function AutoSell.decide(rules: Rules, facts: Facts): (boolean, Reason)
	if facts.Favorite then
		return false, "Favorite"
	end
	if facts.First and rules.ProtectFirst then
		return false, "FirstDiscovery"
	end
	if facts.Mutated and rules.ProtectMutated then
		return false, "Mutated"
	end
	local mode = rules.Tiers[facts.Tier] or "Keep"
	if mode == "SellAll" then
		return true, "RarityRule"
	end
	if facts.Duplicate and (mode == "SellDuplicates" or rules.SellAllDuplicates) then
		return true, "Duplicate"
	end
	if rules.SellEasierThan > 0 and facts.BaseOneIn < rules.SellEasierThan then
		return true, "OddsThreshold"
	end
	return false, "NoRule"
end

-- Favorites are per relic + mutation, so future copies are protected too.
function AutoSell.favoriteKey(relicId: string, mutationId: string?): string
	return if mutationId then `{relicId}|{mutationId}` else relicId
end

return AutoSell

-- Ordered, idempotent data migrations. Pure (no Roblox APIs) so Lune tests can run fixtures.
-- Steps[n] upgrades data from version n-1 to n. Runs BEFORE Reconcile on every load.

local Migrations = {}

-- Slice 0 placeholder relic ids -> their roster replacements (same tiers). Frozen: never edit,
-- old saves depend on it.
Migrations.RenamedRelics = {
	CrackedPrayerBead = "PaladynsNecklace",
	RustedWardNail = "Kunay",
	AshenPaperCharm = "ExplodingTag",
	MothWingLantern = "EternalPoze",
	HollowBoneFlute = "HolloBait",
	InkboundSigilTome = "QuadLeafGrimoire",
	WeepingIronHalberd = "KubikiriCleaver",
	VeilOfTheNinthMoon = "HolloMask",
	StarforgedReliquary = "Hogyuku",
	HeartOfTheLastEclipse = "RedStoneOfAia",
}

-- "<relicId>" or "<relicId>|<rest>" with the relic id renamed.
local function renameKey(key: string): string
	local id, rest = string.match(key, "^([^|]*)(.*)$")
	local renamed = Migrations.RenamedRelics[id :: string]
	return if renamed then renamed .. rest else key
end

-- Renames the keys of a map; when two keys merge, keepOld(old, new) picks the surviving value.
local function renameMapKeys(map: any, keepOld: (any, any) -> any)
	if type(map) ~= "table" then
		return
	end
	local renamed = {}
	for key, value in map do
		if type(key) == "string" and renameKey(key) ~= key then
			renamed[key] = value
		end
	end
	for key, value in renamed do
		map[key] = nil
		local newKey = renameKey(key)
		map[newKey] = if map[newKey] == nil then value else keepOld(map[newKey], value)
	end
end

local function earliest(a: any, b: any): any
	return if type(a) == "number" and type(b) == "number" then math.min(a, b) else a
end

Migrations.Steps = {
	-- 0 -> 1: pre-ProfileStore Slice 0/1 data had no version, no Discovered map and no history.
	[1] = function(data: any)
		data.Discovered = data.Discovered or {}
		for _, item in data.Inventory or {} do
			if type(item) == "table" and type(item.Id) == "string" and data.Discovered[item.Id] == nil then
				data.Discovered[item.Id] = item.At or 0
			end
		end
		data.RareHistory = data.RareHistory or {}
	end,
	-- 1 -> 2: the Codex now remembers which mutations were seen per relic; rebuild it from held items.
	[2] = function(data: any)
		data.CodexMutations = data.CodexMutations or {}
		for _, item in data.Inventory or {} do
			if type(item) == "table" and type(item.Id) == "string" and type(item.Mutation) == "string" then
				local seen = data.CodexMutations[item.Id] or {}
				data.CodexMutations[item.Id] = seen
				if seen[item.Mutation] == nil then
					seen[item.Mutation] = item.At or 0
				end
			end
		end
	end,
	-- 2 -> 3: Auto-Display was replaced by the Equip Best button; the numeric interface size became
	-- Small/Medium/Big. Drop the old fields (Reconcile adds the new ones).
	[3] = function(data: any)
		if type(data.Settings) == "table" then
			data.Settings.AutoDisplay = nil
			if type(data.Settings.Client) == "table" then
				data.Settings.Client.UIScale = nil
			end
		end
	end,
	-- 3 -> 4: the placeholder relics became the real roster; rename their ids everywhere.
	[4] = function(data: any)
		for _, list in { data.Inventory, data.RareHistory } do
			if type(list) == "table" then
				for _, entry in list do
					if type(entry) == "table" and type(entry.Id) == "string" then
						entry.Id = Migrations.RenamedRelics[entry.Id] or entry.Id
					end
				end
			end
		end
		renameMapKeys(data.Discovered, earliest)
		renameMapKeys(data.Favorites, function(a, b)
			return a or b
		end)
		if type(data.CodexMutations) == "table" then
			renameMapKeys(data.CodexMutations, function(a, b)
				for mutation, at in b do
					a[mutation] = earliest(a[mutation], at) or at
				end
				return a
			end)
		end
		if type(data.Cosmetic) == "table" and type(data.Cosmetic.Key) == "string" then
			data.Cosmetic.Key = renameKey(data.Cosmetic.Key)
		end
	end,
	-- 4 -> 5: income is per second. The offline snapshot was CE/min. (The DataStore was renamed
	-- with this change, so this only matters for copied test data.)
	[5] = function(data: any)
		if type(data.Offline) == "table" then
			local perMin = tonumber(data.Offline.IncomePerMin) or 0
			data.Offline.IncomePerMin = nil
			data.Offline.IncomePerSec = perMin / 60
		end
	end,
	-- 5 -> 6: the carried relic (Key = "<relicId>|<mutation>", Float or Hand) became one floating
	-- backpack copy (Uid). Pick a copy of that relic that isn't on a pedestal.
	[6] = function(data: any)
		local old = data.Cosmetic
		if type(old) ~= "table" then
			return
		end
		local uid = 0
		local relicId, mutationId = string.match(if type(old.Key) == "string" then old.Key else "", "^([^|]+)|(.*)$")
		if relicId then
			local onPedestal = {}
			for _, pedestal in if type(data.Pedestals) == "table" then data.Pedestals else {} do
				if type(pedestal) == "table" and pedestal.Uid then
					onPedestal[pedestal.Uid] = true
				end
			end
			for _, item in if type(data.Inventory) == "table" then data.Inventory else {} do
				if
					type(item) == "table"
					and item.Id == relicId
					and (item.Mutation or "") == mutationId
					and not onPedestal[item.Uid]
				then
					uid = item.Uid
					break
				end
			end
		end
		data.Cosmetic = { Uid = uid }
	end,
} :: { [number]: (any) -> () }

export type Outcome = "Current" | "Migrated" | "Newer"

-- Upgrades data in place to targetVersion. Data from a NEWER game version is left untouched
-- (an old server must never downgrade or overwrite it).
function Migrations.run(data: any, targetVersion: number): Outcome
	local version = if type(data.DataVersion) == "number" then data.DataVersion else 0
	if version > targetVersion then
		return "Newer"
	end
	if version == targetVersion then
		return "Current"
	end
	for step = version + 1, targetVersion do
		local migrate = Migrations.Steps[step]
		if migrate then
			migrate(data)
		end
		data.DataVersion = step
	end
	return "Migrated"
end

return Migrations

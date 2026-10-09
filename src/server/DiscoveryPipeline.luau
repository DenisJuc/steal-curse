-- The single path every relic grant goes through (passive scans, captures, bonus rolls, debug).
-- Stages (GDD 9.3 order):
--   store item -> Codex discovery (base relic id) + seen mutation -> rare history
--   -> auto-display -> auto-sell (rules, then capacity) -> Codex milestones
--   -> priority save -> notify owner.
-- The Codex is written before auto-sell, so a first find counts even if it is sold right away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local AutoSellService = require(script.Parent.Services.AutoSellService)
local CodexService = require(script.Parent.Services.CodexService)
local DataService = require(script.Parent.Services.DataService)
local GameEvents = require(script.Parent.Services.GameEvents)
local PedestalService = require(script.Parent.Services.PedestalService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DiscoveryResult = Remotes:WaitForChild("DiscoveryResult") :: RemoteEvent

local DiscoveryPipeline = {}

export type Entry = {
	Id: string,
	Mutation: string?,
	Source: string,
}

export type Result = {
	Uid: number,
	Id: string,
	Mutation: string?,
	Source: string,
	First: boolean,
	NewVariant: boolean,
	Displayed: boolean,
	-- Set when the find was auto-sold: CE earned and why.
	Sold: number?,
	SoldReason: string?,
}

local PRIORITY_INDEX = RarityConfig.IndexById[Config.Save.PriorityTier]
local PRIORITY_MUTATED_INDEX = RarityConfig.IndexById[Config.Save.PriorityMutatedTier]
local HISTORY_INDEX = RarityConfig.IndexById[Config.Save.RareHistoryTier]

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 1 else 1
end

-- Applies one entry to a data table. Returns the stored item, whether it was a first Codex
-- discovery, whether it should trigger a priority save, and whether this mutation of this
-- relic was seen for the first time.
function DiscoveryPipeline.ApplyEntry(data: any, entry: Entry, now: number): (any, boolean, boolean, boolean)
	local item = {
		Uid = data.NextUid,
		Id = entry.Id,
		Mutation = entry.Mutation,
		At = now,
		Source = entry.Source,
	}
	data.NextUid += 1
	table.insert(data.Inventory, item)

	local first = data.Discovered[entry.Id] == nil
	if first then
		data.Discovered[entry.Id] = now
	end

	local newVariant = false
	if entry.Mutation then
		local seen = data.CodexMutations[entry.Id]
		if not seen then
			seen = {}
			data.CodexMutations[entry.Id] = seen
		end
		if seen[entry.Mutation] == nil then
			seen[entry.Mutation] = now
			newVariant = true
		end
	end

	local index = tierIndex(entry.Id)
	local mutatedRare = entry.Mutation ~= nil and index >= PRIORITY_MUTATED_INDEX
	if index >= HISTORY_INDEX or mutatedRare then
		table.insert(data.RareHistory, 1, {
			Id = entry.Id,
			Mutation = entry.Mutation,
			At = now,
			Source = entry.Source,
		})
		while #data.RareHistory > Config.Save.RareHistoryMax do
			table.remove(data.RareHistory)
		end
	end

	local priority = first or index >= PRIORITY_INDEX or mutatedRare
	return item, first, priority, newVariant
end

-- Grants every entry as one batch: one data update, at most one save request, one client message.
function DiscoveryPipeline.GrantBatch(player: Player, entries: { Entry }): { Result }
	local data = DataService.Get(player)
	if not data or #entries == 0 then
		return {}
	end

	local now = os.time()
	local results = {}
	local items = {}
	local firsts: { [number]: boolean } = {}
	local needsSave, codexChanged = false, false
	for _, entry in entries do
		local item, first, priority, newVariant = DiscoveryPipeline.ApplyEntry(data, entry, now)
		needsSave = needsSave or priority
		codexChanged = codexChanged or first or newVariant
		firsts[item.Uid] = first
		table.insert(items, item)
		table.insert(results, {
			Uid = item.Uid,
			Id = item.Id,
			Mutation = item.Mutation,
			Source = item.Source,
			First = first,
			NewVariant = newVariant,
			Displayed = false,
		})
		GameEvents.Fire("Discovery", player, item, first)
	end

	local shown = PedestalService.AutoDisplayNew(player, items)
	local sold = AutoSellService.Apply(player, items, firsts, shown)
	for _, result in results do
		result.Displayed = shown[result.Uid] == true
		local sale = sold[result.Uid]
		if sale then
			result.Sold = sale.Earned
			result.SoldReason = sale.Reason
		end
	end

	if codexChanged then
		CodexService.Evaluate(player)
	end
	DataService.MirrorAttributes(player)
	if needsSave then
		DataService.RequestSave(player)
	end
	DiscoveryResult:FireClient(player, results)
	return results
end

function DiscoveryPipeline.Grant(player: Player, relicIds: { string }, source: string): { Result }
	local entries = table.create(#relicIds)
	for index, relicId in relicIds do
		entries[index] = { Id = relicId, Source = source }
	end
	return DiscoveryPipeline.GrantBatch(player, entries)
end

return DiscoveryPipeline

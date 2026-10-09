-- The single path every relic grant goes through (passive scans, captures, bonus rolls, debug).
-- Stages (GDD 9.3 order; later slices insert auto-display and auto-sell):
--   store item -> Codex discovery (base relic id) -> rare history -> priority save -> notify owner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local DataService = require(script.Parent.Services.DataService)
local GameEvents = require(script.Parent.Services.GameEvents)

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
}

local PRIORITY_INDEX = RarityConfig.IndexById[Config.Save.PriorityTier]
local PRIORITY_MUTATED_INDEX = RarityConfig.IndexById[Config.Save.PriorityMutatedTier]
local HISTORY_INDEX = RarityConfig.IndexById[Config.Save.RareHistoryTier]

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 1 else 1
end

-- Applies one entry to a data table. Returns the stored item, whether it was a first Codex
-- discovery, and whether it should trigger a priority save.
function DiscoveryPipeline.ApplyEntry(data: any, entry: Entry, now: number): (any, boolean, boolean)
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
	return item, first, priority
end

-- Grants every entry as one batch: one data update, at most one save request, one client message.
function DiscoveryPipeline.GrantBatch(player: Player, entries: { Entry }): { Result }
	local data = DataService.Get(player)
	if not data or #entries == 0 then
		return {}
	end

	local now = os.time()
	local results = {}
	local needsSave = false
	for _, entry in entries do
		local item, first, priority = DiscoveryPipeline.ApplyEntry(data, entry, now)
		needsSave = needsSave or priority
		table.insert(results, {
			Uid = item.Uid,
			Id = item.Id,
			Mutation = item.Mutation,
			Source = item.Source,
			First = first,
		})
		GameEvents.Fire("Discovery", player, item, first)
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

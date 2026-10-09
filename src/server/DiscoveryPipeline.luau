-- The single path every relic grant goes through (passive scans, captures, bonus rolls).
-- Slice 0 stages: store the relic, then notify the owner. Later slices insert Codex,
-- auto-display, auto-sell and save stages here in the GDD 9.3 order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.Services.DataService)
local GameEvents = require(script.Parent.Services.GameEvents)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DiscoveryResult = Remotes:WaitForChild("DiscoveryResult") :: RemoteEvent

local DiscoveryPipeline = {}

export type Entry = {
	Id: string,
	Source: string,
}

export type Result = {
	Uid: number,
	Id: string,
	Source: string,
}

-- Grants every entry as one batch: one data update and one client message.
function DiscoveryPipeline.GrantBatch(player: Player, entries: { Entry }): { Result }
	local data = DataService.Get(player)
	if not data or #entries == 0 then
		return {}
	end

	local results = {}
	for _, entry in entries do
		local item = {
			Uid = data.NextUid,
			Id = entry.Id,
			At = os.time(),
			Source = entry.Source,
		}
		data.NextUid += 1
		table.insert(data.Inventory, item)
		table.insert(results, { Uid = item.Uid, Id = item.Id, Source = item.Source })
		GameEvents.Fire("Discovery", player, item)
	end

	DataService.MirrorAttributes(player)
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

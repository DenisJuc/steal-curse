-- The single path every relic grant goes through (passive scans, captures, bonus rolls).
-- Slice 0 stages: store the relic, then notify the owner. Later slices insert Codex,
-- auto-display, auto-sell and save stages here in the GDD 9.3 order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.Services.DataService)
local GameEvents = require(script.Parent.Services.GameEvents)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DiscoveryResult = Remotes:WaitForChild("DiscoveryResult") :: RemoteEvent

local DiscoveryPipeline = {}

export type Result = {
	Uid: number,
	Id: string,
	Source: string,
}

function DiscoveryPipeline.Grant(player: Player, relicIds: { string }, source: string): { Result }
	local data = DataService.Get(player)
	if not data or #relicIds == 0 then
		return {}
	end

	local results = {}
	for _, relicId in relicIds do
		local item = {
			Uid = data.NextUid,
			Id = relicId,
			At = os.time(),
			Source = source,
		}
		data.NextUid += 1
		table.insert(data.Inventory, item)
		table.insert(results, { Uid = item.Uid, Id = relicId, Source = source })
		GameEvents.Fire("Discovery", player, item)
	end

	DataService.MirrorAttributes(player)
	DiscoveryResult:FireClient(player, results)
	return results
end

return DiscoveryPipeline

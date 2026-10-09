-- Client-side discovery reports (SessionReport) built from the server's discovery results.
-- A tracker summarizes everything from the moment it starts: the whole session (Journal) or one
-- AFK stretch. Scans and shrine income come from the TotalScans / SessionIncome attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Presentation = require(ReplicatedStorage.Shared.Presentation)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local SessionReport = require(ReplicatedStorage.Shared.SessionReport)

local DiscoveryResult = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DiscoveryResult") :: RemoteEvent

local Session = {}

export type Tracker = {
	Report: SessionReport.Report,
	StartScans: number,
	StartIncome: number,
	StartedAt: number,
}

export type Summary = {
	Report: SessionReport.Report,
	Scans: number,
	IncomeCE: number,
	Seconds: number,
}

local player = Players.LocalPlayer
local trackers: { Tracker } = {}

local function attribute(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

function Session.Score(relicId: string, mutation: string?): number
	local relic = RelicConfig.ById[relicId]
	local index = if relic then RarityConfig.IndexById[relic.Tier] or 1 else 1
	return Presentation.score(index, mutation ~= nil)
end

function Session.Track(): Tracker
	local tracker = {
		Report = SessionReport.new(),
		StartScans = attribute("TotalScans"),
		StartIncome = attribute("SessionIncome"),
		StartedAt = os.clock(),
	}
	table.insert(trackers, tracker)
	return tracker
end

function Session.Untrack(tracker: Tracker)
	local index = table.find(trackers, tracker)
	if index then
		table.remove(trackers, index)
	end
end

function Session.Summarize(tracker: Tracker): Summary
	return {
		Report = tracker.Report,
		Scans = math.max(0, attribute("TotalScans") - tracker.StartScans),
		IncomeCE = math.max(0, attribute("SessionIncome") - tracker.StartIncome),
		Seconds = os.clock() - tracker.StartedAt,
	}
end

-- The whole session since this client started.
Session.Total = Session.Track()

DiscoveryResult.OnClientEvent:Connect(function(results)
	if type(results) ~= "table" then
		return
	end
	for _, result in results do
		if type(result) == "table" and type(result.Id) == "string" then
			local score = Session.Score(result.Id, result.Mutation)
			for _, tracker in trackers do
				SessionReport.add(tracker.Report, result, score)
			end
		end
	end
end)

return Session

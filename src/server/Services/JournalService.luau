-- Journal (GDD 3.2 rare-find history, 9.4 recent notable finds): returns the saved rare-find
-- history so players can inspect finds they missed while away or that a reveal coalesced.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local RemoteGuard = require(script.Parent.RemoteGuard)

local GetJournal = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GetJournal") :: RemoteFunction

local JournalService = {}

function JournalService.Get(player: Player): { RareHistory: { any } }
	local data = DataService.Get(player)
	return { RareHistory = if data then table.clone(data.RareHistory) else {} }
end

function JournalService.Init()
	RemoteGuard.Function(GetJournal, JournalService.Get, "Inventory")
end

return JournalService

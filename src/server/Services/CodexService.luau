-- Codex milestones (GDD 7). Discovery itself is recorded by the DiscoveryPipeline; this service
-- marks milestones as ready, lets the player claim them (ClaimCodex), applies the claimed
-- bonuses through MultiplierService ("Codex" Luck factor and Income bonus) and owns Signal
-- Frequency unlocks. Ready and claimed milestones are saved and never removed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local MultiplierService = require(script.Parent.MultiplierService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local RollService = require(script.Parent.RollService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetCodex = Remotes:WaitForChild("GetCodex") :: RemoteFunction
local ClaimCodex = Remotes:WaitForChild("ClaimCodex") :: RemoteFunction

local CodexService = {}

local function stateOf(data: any): Codex.State
	return { Discovered = data.Discovered, Mutations = data.CodexMutations }
end

local function bonuses(player: Player): (number, number)
	local data = DataService.Get(player)
	if not data then
		return 0, 0
	end
	return Codex.bonuses(CodexBook, data.CodexMilestones)
end

function CodexService.UnlockedFrequencies(player: Player): { [string]: boolean }
	local data = DataService.Get(player)
	return Codex.unlockedFrequencies(CodexBook, if data then data.CodexMilestones else {})
end

function CodexService.IsFrequencyUnlocked(player: Player, frequency: string): boolean
	return frequency == "All" or CodexService.UnlockedFrequencies(player)[frequency] == true
end

-- What the player still needs for a locked frequency, e.g. "Discover 2 Demonic relics (Common-Legendary)".
function CodexService.FrequencyGoal(frequency: string): string?
	local milestone = CodexBook.ById[`Frequency_{frequency}`]
	return if milestone then Codex.goalText(CodexBook, milestone) else nil
end

local function claimableCount(data: any): number
	local count = 0
	for id in data.CodexReady do
		if data.CodexMilestones[id] == nil and CodexBook.ById[id] then
			count += 1
		end
	end
	return count
end

local function mirror(player: Player, data: any)
	local essential = 0
	for _, relicId in CodexBook.Pool do
		if data.Discovered[relicId] ~= nil then
			essential += 1
		end
	end
	local unlocked = {}
	for family in Codex.unlockedFrequencies(CodexBook, data.CodexMilestones) do
		table.insert(unlocked, family)
	end
	table.sort(unlocked)
	player:SetAttribute("CodexEssential", essential)
	player:SetAttribute("CodexClaimable", claimableCount(data))
	player:SetAttribute("FrequenciesUnlocked", table.concat(unlocked, ","))
end

-- Marks newly reached milestones as ready to claim. Call after anything that adds Codex entries.
function CodexService.Evaluate(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local changed = false
	for _, id in Codex.earned(CodexBook, stateOf(data)) do
		if data.CodexMilestones[id] == nil and data.CodexReady[id] == nil then
			data.CodexReady[id] = os.time()
			changed = true
		end
	end
	if not CodexService.IsFrequencyUnlocked(player, data.Settings.Frequency) then
		data.Settings.Frequency = "All"
		RollService.RefreshAttributes(player)
	end
	mirror(player, data)
	if changed then
		DataService.RequestSave(player)
	end
end

local function snapshot(player: Player)
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	return {
		Discovered = data.Discovered,
		Mutations = data.CodexMutations,
		Ready = data.CodexReady,
		Claimed = data.CodexMilestones,
	}
end

-- Claims one ready milestone, or every ready one with "All". Returns the claimed ids + fresh snapshot.
local function claim(player: Player, which: any)
	local data = DataService.Get(player)
	if not data or type(which) ~= "string" then
		return nil
	end
	local claimed = {}
	for id in data.CodexReady do
		if (which == "All" or which == id) and data.CodexMilestones[id] == nil and CodexBook.ById[id] then
			data.CodexMilestones[id] = os.time()
			table.insert(claimed, id)
		end
	end
	if #claimed > 0 then
		MultiplierService.Refresh(player)
		mirror(player, data)
		DataService.RequestSave(player)
	end
	return { Claimed = claimed, Snapshot = snapshot(player) }
end

function CodexService.Init()
	MultiplierService.Register("Luck", "Codex", function(player)
		local luck = bonuses(player)
		return 1 + luck
	end)
	MultiplierService.Register("Income", "Codex", function(player)
		local _, income = bonuses(player)
		return income
	end)
	RemoteGuard.Function(GetCodex, snapshot, "Inventory")
	RemoteGuard.Function(ClaimCodex, claim, "Inventory")

	DataService.OnPlayerLoaded(CodexService.Evaluate)
	GameEvents.On("DataReset", function(player: Player)
		CodexService.Evaluate(player)
	end)
end

return CodexService

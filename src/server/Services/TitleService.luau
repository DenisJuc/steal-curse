-- Titles over players' heads (PlayerTitles). Earned from purified zones (Curse), zone mastery
-- (ZoneMastery) and Codex milestones; the player picks one at the Spirit Wardrobe in the hub
-- (SetTitle remote: an earned title, "Auto" for the best one or "Off"). Mirrored as:
--   Title          the title shown (nil = none)
--   TitleChoice    the saved choice
--   TitlesEarned   earned titles joined with "\n" (for the Wardrobe)
-- GetTitles returns every title with how it is earned and the progress (Titles.catalog).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Curse = require(ReplicatedStorage.Shared.Curse)
local Titles = require(ReplicatedStorage.Shared.Titles)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local ZoneMastery = require(ReplicatedStorage.Shared.ZoneMastery)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetTitle = Remotes:WaitForChild("SetTitle") :: RemoteEvent
local GetTitles = Remotes:WaitForChild("GetTitles") :: RemoteFunction

local TitleService = {}

local areaOrder: { string } = {}
local areaNames: { [string]: string } = {}
for _, area in Config.Areas do
	table.insert(areaOrder, area.Id)
	areaNames[area.Id] = area.Name
end

-- Every title with its source and progress (Wardrobe), earned ones first.
local function catalogOf(data: any): { Titles.Entry }
	local purify, mastery, codex = {}, {}, {}
	for _, area in areaOrder do
		local name = areaNames[area] or area
		local curseZone = (Config.Curse.Zones :: any)[area]
		if curseZone then
			local done, total = Curse.progress(data.Cleansed, WildLayout.CursedShrines, area)
			table.insert(purify, {
				Title = curseZone.Title,
				Source = `Purify the {name} (cleanse its Cursed Shrines)`,
				Have = done,
				Need = total,
				Unit = "shrines",
				Earned = total > 0 and done >= total,
			})
		end
		local masteryZone = (Config.Mastery.Zones :: any)[area]
		if masteryZone then
			local need = Config.Mastery.TitleAt
			local level = ZoneMastery.level(data.Mastery[area] or 0, Config.Mastery :: any)
			table.insert(mastery, {
				Title = masteryZone.Title,
				Source = `Reach {name} mastery {need} (capture signals there)`,
				Have = math.min(level, need),
				Need = need,
				Unit = "levels",
				Earned = level >= need,
			})
		end
	end
	local state = { Discovered = data.Discovered, Mutations = data.CodexMutations }
	for _, milestone in CodexBook.Milestones do
		if milestone.Title then
			local claimed = data.CodexMilestones[milestone.Id] ~= nil
			local have = Codex.progress(milestone, state)
			local ready = not claimed and have >= milestone.Need
			table.insert(codex, {
				Title = milestone.Title,
				Source = if ready
					then "Ready: claim it in the Codex"
					else `Codex: {Codex.goalText(CodexBook, milestone)}`,
				Have = math.min(have, milestone.Need),
				Need = milestone.Need,
				Unit = "relics",
				Earned = claimed,
			})
		end
	end
	return Titles.catalog({ purify, mastery, codex })
end

local function earnedOf(data: any): { string }
	local purifiedByArea = Curse.titles(data.Cleansed, WildLayout.CursedShrines, Config.Curse :: any)
	local purified = {}
	for _, area in areaOrder do
		if purifiedByArea[area] then
			table.insert(purified, purifiedByArea[area])
		end
	end
	local levels = {}
	for area, xp in data.Mastery do
		levels[area] = (ZoneMastery.level(xp, Config.Mastery :: any))
	end
	return Titles.earned({
		purified,
		ZoneMastery.titles(levels, areaOrder, Config.Mastery :: any),
		Codex.titles(CodexBook, data.CodexMilestones),
	})
end

-- Recomputes the earned titles and the shown one (call after anything that can earn a title).
function TitleService.Refresh(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local earned = earnedOf(data)
	local choice = if Titles.valid(data.TitleChoice, earned) then data.TitleChoice else Titles.Auto
	player:SetAttribute("TitlesEarned", table.concat(earned, "\n"))
	player:SetAttribute("TitleChoice", choice)
	player:SetAttribute("Title", Titles.shown(choice, earned))
end

local function onSet(player: Player, choice: any)
	local data = DataService.Get(player)
	if not data or not Titles.valid(choice, earnedOf(data)) then
		return
	end
	data.TitleChoice = choice
	TitleService.Refresh(player)
	DataService.RequestSave(player)
end

function TitleService.Init()
	RemoteGuard.Event(SetTitle, onSet, "Settings")
	RemoteGuard.Function(GetTitles, function(player: Player)
		local data = DataService.Get(player)
		return if data then catalogOf(data) else nil
	end, "Settings")
	DataService.OnPlayerLoaded(TitleService.Refresh)
	GameEvents.On("DataReset", TitleService.Refresh)
	GameEvents.On("CodexClaimed", function(player: Player)
		TitleService.Refresh(player)
	end)
end

return TitleService

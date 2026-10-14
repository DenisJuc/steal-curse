-- Zone mastery (ZoneMastery, Config.Mastery): every capture gives XP in its zone. Levels unlock
-- zone-only perks (BindService asks HoldFactor / ExtraIdle; Spirit Sight range through the
-- SightRangeFactor attribute while standing in the zone), lantern colours, a title and the zone's
-- Showcase. Mirrored on the player:
--   Mastery_<areaId>   XP in that zone
--   SightRangeFactor   Spirit Sight / landmark range factor where the player stands now
-- Mastery titles are handed to TitleService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local ZoneMastery = require(ReplicatedStorage.Shared.ZoneMastery)
local DataService = require(script.Parent.DataService)
local GameEvents = require(script.Parent.GameEvents)
local LanternService = require(script.Parent.LanternService)
local ShowcaseService = require(script.Parent.ShowcaseService)
local TitleService = require(script.Parent.TitleService)

local Notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

local MasteryService = {}

local OPTIONS = Config.Mastery :: ZoneMastery.Options
local TICK_SECONDS = 1

local areaNames: { [string]: string } = {}
local areaOrder: { string } = {}
for _, area in Config.Areas do
	areaNames[area.Id] = area.Name
	table.insert(areaOrder, area.Id)
end

function MasteryService.Level(player: Player, area: string): number
	local data = DataService.Get(player)
	return if data then (ZoneMastery.level(data.Mastery[area] or 0, OPTIONS)) else 0
end

local function perks(player: Player, area: string?): ZoneMastery.Perks
	return ZoneMastery.perks(if area then MasteryService.Level(player, area) else 0, OPTIONS)
end

-- Bind time factor in `area` (< 1 = faster).
function MasteryService.HoldFactor(player: Player, area: string?): number
	return perks(player, area).Hold
end

-- Extra Hunt Streak seconds for a capture in `area`.
function MasteryService.ExtraIdle(player: Player, area: string?): number
	return perks(player, area).Idle
end

local function mirror(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	for _, area in areaOrder do
		player:SetAttribute(`Mastery_{area}`, data.Mastery[area] or 0)
	end
end

-- Sets XP in `area` and hands out everything unlocked on the way (also used by /mastery).
function MasteryService.SetXp(player: Player, area: string, xp: number)
	local data = DataService.Get(player)
	if not data or not areaNames[area] then
		return
	end
	local before = (ZoneMastery.level(data.Mastery[area] or 0, OPTIONS))
	data.Mastery[area] = math.max(0, math.floor(xp))
	local after = (ZoneMastery.level(data.Mastery[area], OPTIONS))
	player:SetAttribute(`Mastery_{area}`, data.Mastery[area])
	if after > before then
		Notify:FireClient(player, `{areaNames[area]} mastery {after}!`, "Item")
		local unlocks = ZoneMastery.unlocks(area, before, after, OPTIONS)
		for _, lantern in unlocks.Lanterns do
			LanternService.Grant(player, lantern, `{areaNames[area]} mastery`)
		end
		if unlocks.Title then
			Notify:FireClient(player, `New title: {unlocks.Title} - wear it at the Spirit Wardrobe in town`, "Item")
		end
		if unlocks.Showcase then
			ShowcaseService.CheckFreeUnlocks(player)
		end
		for _, perk in OPTIONS.Perks do
			if perk.Level > before and perk.Level <= after then
				Notify:FireClient(player, `{areaNames[area]} perk: {ZoneMastery.perkText(perk)}`, "Item")
			end
		end
	end
	if after ~= before then
		TitleService.Refresh(player)
	end
	DataService.RequestSave(player)
end

local function onCaptured(player: Player, info: any)
	local data = DataService.Get(player)
	if not data or type(info) ~= "table" or not areaNames[info.Area] then
		return
	end
	local xp = data.Mastery[info.Area] or 0
	MasteryService.SetXp(player, info.Area, xp + ZoneMastery.xpFor(info.Band, OPTIONS))
end

function MasteryService.Init()
	GameEvents.On("Captured", onCaptured)
	DataService.OnPlayerLoaded(mirror)
	GameEvents.On("DataReset", mirror)

	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local factor = 1
				if root and root:IsA("BasePart") and WorldLayout.inWild(Config.World, root.Position.X, root.Position.Z) then
					local area = WorldLayout.areaAt(Config.Areas, Config.World, root.Position.X, root.Position.Z)
					factor = perks(player, area).Pulse
				end
				if (player:GetAttribute("SightRangeFactor") or 1) ~= factor then
					player:SetAttribute("SightRangeFactor", if factor ~= 1 then factor else nil)
				end
			end
		end
	end)
end

return MasteryService

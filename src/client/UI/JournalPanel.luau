-- Journal (GDD 3.2 rare-find history, 9.4 recent notable finds). Finds tab: this session's
-- report and the saved list of rare finds, so nothing found while away or coalesced by a reveal
-- is missed. Zones tab: each zone's curse progress, mastery level and the shrine lore pages.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Curse = require(ReplicatedStorage.Shared.Curse)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local ZoneMastery = require(ReplicatedStorage.Shared.ZoneMastery)
local Session = require(script.Parent.Parent.Session)
local Odds = require(script.Parent.Odds)
local ReportCard = require(script.Parent.ReportCard)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetJournal = Remotes:WaitForChild("GetJournal") :: RemoteFunction
local DiscoveryResult = Remotes:WaitForChild("DiscoveryResult") :: RemoteEvent

local JournalPanel = {}

local TABS_HEIGHT = 52
local MASTERY = Config.Mastery :: ZoneMastery.Options
local player = Players.LocalPlayer

local SOURCE_TEXT: { [string]: string } = {
	Scan = "scan",
	Capture = "sealed",
	Bonus = "hunt bonus",
	Debug = "debug",
}

function JournalPanel.Start(screen: ScreenGui): { Toggle: () -> (), Open: () -> (), SetVisible: (boolean) -> () }
	local colors = UIKit.Colors
	local panel, content =
		UIKit.modal(screen, "JournalMenu", "JOURNAL", colors.Accent, Vector2.new(520, 600), "Journal")
	local list = UIKit.scrollList(content, 4)
	list.Position = UDim2.fromOffset(0, TABS_HEIGHT)
	list.Size = UDim2.new(1, 0, 1, -TABS_HEIGHT)
	local tab = "Finds"
	local tabButtons: { [string]: TextButton } = {}
	local load: () -> ()

	local function heading(text: string, order: number)
		UIKit.heading({
			LayoutOrder = order,
			Text = text,
			TextSize = 20,
			Size = UDim2.new(1, -10, 0, 28),
			Parent = list,
		})
	end

	local function render(history: { any })
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		heading("This session", 1)
		local order = ReportCard.Fill(list, Session.Summarize(Session.Total), 1)
		order += 1
		heading(`Rare finds ({Config.Save.RareHistoryTier}+)`, order)
		if #history == 0 then
			order += 1
			UIKit.label({
				LayoutOrder = order,
				Text = "Nothing rare yet. Keep scanning!",
				TextSize = 18,
				TextColor3 = colors.SubText,
				Size = UDim2.new(1, -10, 0, 24),
				Parent = list,
			})
			return
		end
		local now = os.time()
		for _, find in history do
			local relic = RelicConfig.ById[find.Id]
			if not relic then
				continue
			end
			order += 1
			local color = if find.Mutation then UIKit.mutationColor(find.Mutation) else UIKit.tierColor(relic.Tier)
			local row = UIKit.create("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -10, 0, 54),
				BackgroundColor3 = colors.Card,
				Parent = list,
			}, { UIKit.corner(8), UIKit.stroke(color, 1, 0.5) })
			UIKit.skinCard(row)
			UIKit.create("Frame", {
				Size = UDim2.new(0, 5, 1, -12),
				Position = UDim2.fromOffset(6, 6),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Parent = row,
			}, { UIKit.corner(3) })
			UIKit.label({
				Text = Odds.displayName(find.Id, find.Mutation),
				TextSize = 19,
				TextScaled = true,
				TextColor3 = color,
				Position = UDim2.fromOffset(18, 5),
				Size = UDim2.new(1, -24, 0, 22),
				Parent = row,
			})
			local ago = math.max(0, now - (tonumber(find.At) or now))
			UIKit.label({
				Text = `{Odds.describe(find.Id, nil)}  |  {SOURCE_TEXT[find.Source] or "found"} {Format.duration(ago)} ago`,
				TextSize = 16,
				TextScaled = true,
				TextColor3 = colors.SubText,
				Position = UDim2.fromOffset(18, 30),
				Size = UDim2.new(1, -24, 0, 18),
				Parent = row,
			})
		end
	end

	local function clear()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- Zones tab: curse progress, mastery and the lore pages found at cleansed shrines.
	local function renderZones()
		clear()
		local cleansed = {}
		local text = player:GetAttribute("Cleansed")
		if type(text) == "string" and text ~= "" then
			for _, id in string.split(text, ",") do
				cleansed[id] = true
			end
		end
		local order = 1
		-- Said once here instead of on every zone card.
		UIKit.label({
			LayoutOrder = order,
			Text = "Cleanse shrines to lift a zone's curse. Hunting there levels its mastery.",
			TextSize = 17,
			TextWrapped = true,
			TextColor3 = colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -10, 0, 44),
			Parent = list,
		})
		for _, area in Config.Areas do
			local done, total = Curse.progress(cleansed, WildLayout.CursedShrines, area.Id)
			local xp = player:GetAttribute(`Mastery_{area.Id}`)
			xp = if type(xp) == "number" then xp else 0
			local level, into, size = ZoneMastery.level(xp, MASTERY)
			local nextPerk = ZoneMastery.nextPerk(level, MASTERY)
			order += 1
			heading(area.Name, order)
			order += 1
			local card = UIKit.create("Frame", {
				LayoutOrder = order,
				Size = UDim2.new(1, -10, 0, 92),
				BackgroundColor3 = colors.Card,
				Parent = list,
			}, { UIKit.corner(8), UIKit.padding(10) })
			UIKit.skinCard(card)
			UIKit.label({
				Text = if done == total then `Shrines {done}/{total}  Purified!` else `Shrines {done}/{total}`,
				TextSize = 19,
				TextColor3 = if done == total then colors.Gold else colors.Text,
				Size = UDim2.new(0.5, 0, 0, 22),
				Parent = card,
			})
			UIKit.label({
				Text = if size > 0 then `Mastery Lv {level}` else `Mastery Lv {level} (max)`,
				TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.new(0.5, 0, 0, 22),
				Parent = card,
			})
			local track = UIKit.create("Frame", {
				BackgroundColor3 = colors.Track,
				Position = UDim2.fromOffset(0, 30),
				Size = UDim2.new(1, 0, 0, 10),
				Parent = card,
			}, { UIKit.corner(4) })
			UIKit.create("Frame", {
				BackgroundColor3 = colors.Accent,
				Size = UDim2.fromScale(if size > 0 then into / size else 1, 1),
				Parent = track,
			}, { UIKit.corner(4) })
			UIKit.label({
				Text = if nextPerk then `Lv {nextPerk.Level}: {ZoneMastery.perkText(nextPerk)}` else "All perks unlocked",
				TextSize = 17,
				TextScaled = true,
				TextColor3 = colors.Cyan,
				Position = UDim2.fromOffset(0, 48),
				Size = UDim2.new(1, 0, 0, 20),
				Parent = card,
			})
			for _, shrine in WildLayout.CursedShrines do
				local lore = Config.Curse.Lore[shrine.Id]
				if shrine.Area ~= area.Id or not cleansed[shrine.Id] or not lore then
					continue
				end
				order += 1
				UIKit.label({
					LayoutOrder = order,
					Text = `"{lore}"`,
					TextSize = 16,
					TextWrapped = true,
					TextColor3 = colors.SubText,
					Size = UDim2.new(1, -10, 0, 34),
					Parent = list,
				})
			end
		end
	end

	local function skinTabs()
		for name, button in tabButtons do
			UIKit.skinTab(button, name == tab)
		end
	end
	local function setTab(id: string)
		tab = id
		skinTabs()
		load()
	end
	for index, id in { "Finds", "Zones" } do
		local button = UIKit.button({
			Text = id,
			TextSize = 15,
			Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 4, 0, 0),
			Size = UDim2.new(0.5, -4, 0, TABS_HEIGHT - 8),
			Parent = content,
		}, function()
			setTab(id)
		end)
		tabButtons[id] = button
	end

	function load()
		if tab == "Zones" then
			renderZones()
			return
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return GetJournal:InvokeServer()
			end)
			if ok and type(result) == "table" and panel.Visible and tab == "Finds" then
				render(if type(result.RareHistory) == "table" then result.RareHistory else {})
			end
		end)
	end
	skinTabs()

	local refreshQueued = false
	DiscoveryResult.OnClientEvent:Connect(function()
		if not panel.Visible or refreshQueued or tab ~= "Finds" then
			return
		end
		refreshQueued = true
		task.delay(1, function()
			refreshQueued = false
			if panel.Visible then
				load()
			end
		end)
	end)

	local function open()
		UIKit.show(panel)
		load()
	end

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
				load()
			end
		end,
		Open = open,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return JournalPanel

-- Zones page of the Codex (moved from the old Journal on 2026-11-09): each wild zone's curse
-- progress (cleansed shrines), its mastery level and next perk, and the lore pages found at the
-- shrines already cleansed there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Curse = require(ReplicatedStorage.Shared.Curse)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local ZoneMastery = require(ReplicatedStorage.Shared.ZoneMastery)
local UIKit = require(script.Parent.UIKit)

local ZonesPage = {}

local MASTERY = Config.Mastery :: ZoneMastery.Options

-- Rebuilds `list` (a scroll list with a UIListLayout) with one card per zone.
function ZonesPage.render(list: ScrollingFrame)
	local colors = UIKit.Colors
	local player = Players.LocalPlayer
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
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
		local purified = done == total
		order += 1
		local card = UIKit.create("Frame", {
			Name = area.Id,
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = colors.Card,
			Parent = list,
		}, {
			UIKit.corner(10),
			UIKit.padding(10),
			UIKit.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		})
		UIKit.skinCard(card, if purified then colors.Gold else nil)
		local head = UIKit.create("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = card })
		UIKit.label({
			Text = area.Name,
			FontFace = UIKit.TitleFont,
			TextSize = 20,
			TextColor3 = colors.Gold,
			Size = UDim2.fromScale(0.6, 1),
			Parent = head,
		})
		UIKit.label({
			Text = if size > 0 then `Mastery Lv {level}` else `Mastery Lv {level} (max)`,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.4, 1),
			Parent = head,
		})
		UIKit.label({
			LayoutOrder = 2,
			Text = if purified then `Shrines {done}/{total}  Purified!` else `Shrines cleansed {done}/{total}`,
			TextSize = 17,
			TextColor3 = if purified then colors.Gold else colors.Text,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = card,
		})
		local track = UIKit.create("Frame", {
			LayoutOrder = 3,
			BackgroundColor3 = colors.Track,
			Size = UDim2.new(1, 0, 0, 10),
			Parent = card,
		}, { UIKit.corner(4) })
		UIKit.create("Frame", {
			BackgroundColor3 = colors.Accent,
			Size = UDim2.fromScale(if size > 0 then into / size else 1, 1),
			Parent = track,
		}, { UIKit.corner(4) })
		UIKit.label({
			LayoutOrder = 4,
			Text = if nextPerk then `Next at Lv {nextPerk.Level}: {ZoneMastery.perkText(nextPerk)}` else "All perks unlocked",
			TextSize = 16,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = colors.Cyan,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = card,
		})
		local loreOrder = 4
		for _, shrine in WildLayout.CursedShrines do
			local lore = Config.Curse.Lore[shrine.Id]
			if shrine.Area ~= area.Id or not cleansed[shrine.Id] or not lore then
				continue
			end
			loreOrder += 1
			UIKit.label({
				LayoutOrder = loreOrder,
				Text = `"{lore}"`,
				TextSize = 15,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3 = colors.SubText,
				Size = UDim2.new(1, 0, 0, 18),
				Parent = card,
			})
		end
	end
end

return ZonesPage

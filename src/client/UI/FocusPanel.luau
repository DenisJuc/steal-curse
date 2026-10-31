-- Luck menu (GDD 3.3, 5.2): two tabs.
--   Odds: the big luck multiplier and the 1-in-N chance of every rarity (and mutations).
--   Focus: Attune at the top, then big chips for the Rarity Focus and the Signal Frequency (family);
--   locked families fold into one "N locked" line.
-- Chips only send the chosen id; the panel redraws when the server mirrors the new settings.
-- Every odds number here comes from Odds.current(), i.e. the exact context the server rolls with.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SetRarityFocus = Remotes:WaitForChild("SetRarityFocus") :: RemoteEvent
local SetFrequency = Remotes:WaitForChild("SetFrequency") :: RemoteEvent
local CollectionAction = Remotes:FindFirstChild("CollectionAction") :: RemoteFunction?

local FocusPanel = {}

local PANEL_WIDTH = 470
local ODDS_ROW = 34
local CHIP_HEIGHT = 48
local CHIP_COLUMNS = 3
local PAGE_TOP = UIKit.TAB_HEIGHT + 10

type Option = { Id: string, Label: string }

local FOCUS_OPTIONS: { Option } = { { Id = "MaxLuck", Label = "Max Luck" } }
for _, tier in RarityConfig.Tiers do
	table.insert(FOCUS_OPTIONS, { Id = tier.Id, Label = tier.Name })
end

local FREQUENCY_OPTIONS: { Option } = { { Id = "All", Label = "All" } }
for _, family in RelicConfig.Families do
	table.insert(FREQUENCY_OPTIONS, { Id = family, Label = family })
end

local WATCHED_ATTRIBUTES = {
	"FullLuck",
	"EffectiveLuck",
	"RarityFocus",
	"Frequency",
	"FrequencyRank",
	"MutationRank",
	"FrequenciesUnlocked",
	"AttuneScansLeft",
}

-- "1 in N", with "1 in ∞" for a rarity this luck can no longer roll.
local function oddsText(probability: number): string
	return if probability <= 0 then "1 in \u{221E}" else Format.odds(probability)
end

-- A page that scrolls vertically and stacks its children in LayoutOrder.
local function page(parent: Instance, name: string): ScrollingFrame
	local frame = UIKit.scrollList(parent, 8)
	frame.Name = name
	frame.Position = UDim2.fromOffset(0, PAGE_TOP)
	frame.Size = UDim2.new(1, 0, 1, -PAGE_TOP)
	frame.ScrollBarImageColor3 = UIKit.Colors.Trim
	return frame
end

local function heading(parent: Instance, text: string, order: number)
	UIKit.heading({
		Text = text,
		TextSize = 18,
		LayoutOrder = order,
		Size = UDim2.new(1, -10, 0, 22),
		Parent = parent,
	})
end

local function chipGrid(parent: Instance, name: string, order: number): Frame
	return UIKit.create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Parent = parent,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.new(1 / CHIP_COLUMNS, -6, 0, CHIP_HEIGHT),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function makeChips(grid: Frame, options: { Option }, onPick: (string) -> ()): { [string]: TextButton }
	local chips = {}
	for index, option in options do
		local chip = UIKit.button({
			Name = option.Id,
			LayoutOrder = index,
			Text = option.Label,
			TextSize = 18,
			Parent = grid,
		}, function()
			onPick(option.Id)
		end)
		chips[option.Id] = chip
	end
	return chips
end

function FocusPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local panel, content = UIKit.modal(screen, "LuckMenu", "LUCK", colors.Accent, Vector2.new(PANEL_WIDTH, 620), "Luck")

	local oddsPage = page(content, "OddsPage")
	local focusPage = page(content, "FocusPage")
	focusPage.Visible = false
	UIKit.tabBar(content, { { Id = "Odds", Text = "Odds" }, { Id = "Focus", Text = "Focus" } }, "Odds", function(id)
		oddsPage.Visible = id == "Odds"
		focusPage.Visible = id == "Focus"
	end)

	-- Odds tab.
	local luckLabel = UIKit.label({
		Name = "Luck",
		FontFace = UIKit.TitleFont,
		TextSize = 44,
		TextColor3 = colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Size = UDim2.new(1, -10, 0, 52),
		Parent = oddsPage,
	})
	local focusCapLabel = UIKit.label({
		TextSize = 18,
		TextColor3 = colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Size = UDim2.new(1, -10, 0, 22),
		Parent = oddsPage,
	})
	local tierRows: { [string]: TextLabel } = {}
	for index, tier in RarityConfig.Tiers do
		local row = UIKit.create("Frame", {
			Name = tier.Id,
			LayoutOrder = 10 + index,
			BackgroundColor3 = colors.Card,
			BackgroundTransparency = if index % 2 == 0 then 0.6 else 0.3,
			Size = UDim2.new(1, -10, 0, ODDS_ROW),
			Parent = oddsPage,
		}, { UIKit.corner(8) })
		UIKit.label({
			Text = tier.Name,
			TextSize = 20,
			TextColor3 = UIKit.tierColor(tier.Id),
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.5, -12, 1, 0),
			Parent = row,
		})
		tierRows[tier.Id] = UIKit.label({
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.5, -12, 1, 0),
			Parent = row,
		})
	end
	local mutationLabel = UIKit.label({
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 50,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Parent = oddsPage,
	})

	-- Focus tab: Attune first, then the rarity and family chips.
	local attuneRow = UIKit.create("Frame", {
		Name = "Attune",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.new(1, -10, 0, 52),
		Parent = focusPage,
	})
	local attuneButton = UIKit.button({
		Name = "ActivateAttune",
		Text = "Use Attune",
		TextSize = 20,
		Size = UDim2.new(0.5, -4, 1, 0),
		Parent = attuneRow,
	}, function()
		if CollectionAction then
			pcall(function()
				CollectionAction:InvokeServer("ActivateAttune")
			end)
		end
		SetRarityFocus:FireServer("Common")
	end)
	UIKit.skinButton(attuneButton, "Gold")
	local commonButton = UIKit.button({
		Name = "FocusCommon",
		Text = "Focus Common",
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		Parent = attuneRow,
	}, function()
		SetRarityFocus:FireServer("Common")
	end)
	UIKit.skinButton(commonButton, "Dark")
	local attuneStatus = UIKit.label({
		TextSize = 17,
		TextColor3 = colors.Cyan,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Size = UDim2.new(1, -10, 0, 22),
		Parent = focusPage,
	})

	heading(focusPage, "Rarity", 3)
	local focusChips = makeChips(chipGrid(focusPage, "Rarity", 4), FOCUS_OPTIONS, function(id)
		SetRarityFocus:FireServer(id)
	end)
	heading(focusPage, "Family", 5)
	local frequencyChips = makeChips(chipGrid(focusPage, "Family", 6), FREQUENCY_OPTIONS, function(id)
		SetFrequency:FireServer(id)
	end)
	local lockedLabel = UIKit.label({
		TextSize = 17,
		TextColor3 = colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 7,
		Size = UDim2.new(1, -10, 0, 22),
		Parent = focusPage,
	})

	local function highlight(chips: { [string]: TextButton }, selected: string)
		for id, chip in chips do
			UIKit.skinTab(chip, id == selected)
		end
	end

	local function refresh()
		local ctx = Odds.current()
		local fullLuck = player:GetAttribute("FullLuck") or 1
		local focus = player:GetAttribute("RarityFocus") or "MaxLuck"
		local frequency = player:GetAttribute("Frequency") or "All"
		local attuneLeft = player:GetAttribute("AttuneScansLeft") or 0
		luckLabel.Text = `x{Format.number(fullLuck)} Luck`
		if ctx.Luck < fullLuck then
			local tier = RarityConfig.Get(focus)
			local focusName = if tier then tier.Name else tostring(focus)
			focusCapLabel.Text = `{focusName} focus: rolling at x{Format.number(ctx.Luck)}`
		else
			focusCapLabel.Text = "Higher luck makes rare relics more likely."
		end
		attuneStatus.Text = if attuneLeft > 0 then `Attune: {attuneLeft} focused scans left` else ""
		attuneStatus.Visible = attuneLeft > 0
		highlight(focusChips, focus)
		highlight(frequencyChips, frequency)
		local unlocked = {}
		for _, family in string.split(player:GetAttribute("FrequenciesUnlocked") or "", ",") do
			unlocked[family] = true
		end
		local lockedCount = 0
		for _, option in FREQUENCY_OPTIONS do
			local isLocked = option.Id ~= "All" and not unlocked[option.Id]
			frequencyChips[option.Id].Visible = not isLocked
			if isLocked then
				lockedCount += 1
			end
		end
		lockedLabel.Text = if lockedCount > 0 then `{lockedCount} locked: find more of their relics to unlock` else ""
		lockedLabel.Visible = lockedCount > 0

		local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
		for index, tier in ctx.Tiers do
			tierRows[tier.Id].Text = oddsText(masses[index])
		end

		local mutationOdds = RollMath.mutationProbabilities(ctx)
		if ctx.MutationRank <= 0 then
			mutationLabel.Text = ""
		else
			local parts = {}
			for _, mutation in MutationConfig.Mutations do
				local p = mutationOdds[mutation.Id]
				if p then
					table.insert(parts, `{mutation.Name} {Format.odds(p)}`)
				end
			end
			mutationLabel.Text = `Mutations: {table.concat(parts, ", ")}`
		end
	end

	for _, name in WATCHED_ATTRIBUTES do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
				refresh()
			end
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return FocusPanel

-- Rarity Focus + Signal Frequency picker with live odds (GDD 3.3, 5.2).
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

local LOCK = "\u{1F512}"
local ODDS_ROW = 26

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

local function sectionLabel(parent: Instance, text: string, y: number)
	UIKit.heading({
		Text = text,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = parent,
	})
end

local function chipGrid(parent: Instance, y: number, rows: number): Frame
	return UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, rows * 32 + (rows - 1) * 6),
		Parent = parent,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(104, 32),
			CellPadding = UDim2.fromOffset(6, 6),
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
			Parent = grid,
		}, function()
			onPick(option.Id)
		end)
		UIKit.skinButton(chip, "Dark")
		chips[option.Id] = chip
	end
	return chips
end

local function highlight(chips: { [string]: TextButton }, selected: string)
	for id, chip in chips do
		UIKit.skinButton(chip, if id == selected then "Primary" else "Dark")
	end
end

function FocusPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local panel, content =
		UIKit.modal(screen, "LuckMenu", "LUCK, FOCUS & ODDS", colors.Accent, Vector2.new(380, 600), "Luck")
	local body = UIKit.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 680),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = content,
	})

	local luckLabel = UIKit.label({
		FontFace = UIKit.TitleFont,
		TextSize = 30,
		TextColor3 = colors.Gold,
		Size = UDim2.new(1, -8, 0, 34),
		Parent = body,
	})
	local focusCapLabel = UIKit.label({
		TextSize = 13,
		TextColor3 = colors.SubText,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, -8, 0, 16),
		Parent = body,
	})

	sectionLabel(body, "Focus", 56)
	local focusChips = makeChips(chipGrid(body, 76, 3), FOCUS_OPTIONS, function(id)
		SetRarityFocus:FireServer(id)
	end)

	sectionLabel(body, "Family", 196)
	local frequencyChips = makeChips(chipGrid(body, 216, 2), FREQUENCY_OPTIONS, function(id)
		SetFrequency:FireServer(id)
	end)

	sectionLabel(body, "Odds", 298)
	local tierRows: { [string]: TextLabel } = {}
	for index, tier in RarityConfig.Tiers do
		local y = 318 + (index - 1) * ODDS_ROW
		UIKit.label({
			Text = tier.Name,
			TextSize = 18,
			TextColor3 = UIKit.tierColor(tier.Id),
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(0.45, 0, 0, ODDS_ROW),
			Parent = body,
		})
		tierRows[tier.Id] = UIKit.label({
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.45, 0, 0, y),
			Size = UDim2.new(0.55, -12, 0, ODDS_ROW),
			Parent = body,
		})
	end

	local oddsBottom = 318 + #RarityConfig.Tiers * ODDS_ROW
	sectionLabel(body, "Attune", oddsBottom + 12)
	local attuneStatus = UIKit.label({
		TextSize = 13,
		TextColor3 = colors.SubText,
		Position = UDim2.fromOffset(0, oddsBottom + 32),
		Size = UDim2.new(1, -12, 0, 18),
		Parent = body,
	})
	local attuneButtonsY = oddsBottom + 54
	UIKit.button({
		Name = "ActivateAttune",
		Text = "Use Attune (Focus Common)",
		TextSize = 14,
		Position = UDim2.fromOffset(0, attuneButtonsY),
		Size = UDim2.new(0.48, -4, 0, 32),
		Parent = body,
	}, function()
		if CollectionAction then
			pcall(function()
				CollectionAction:InvokeServer("ActivateAttune")
			end)
		end
		SetRarityFocus:FireServer("Common")
	end)
	UIKit.button({
		Name = "FocusCommon",
		Text = "Focus Common now",
		TextSize = 14,
		Position = UDim2.new(0.52, 0, 0, attuneButtonsY),
		Size = UDim2.new(0.48, -4, 0, 32),
		Parent = body,
	}, function()
		SetRarityFocus:FireServer("Common")
	end)

	local mutationLabel = UIKit.label({
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.SubText,
		Position = UDim2.fromOffset(0, attuneButtonsY + 44),
		Size = UDim2.new(1, -12, 0, 40),
		Parent = body,
	})
	body.CanvasSize = UDim2.fromOffset(0, attuneButtonsY + 100)

	local function refresh()
		local ctx = Odds.current()
		local fullLuck = player:GetAttribute("FullLuck") or 1
		local focus = player:GetAttribute("RarityFocus") or "MaxLuck"
		local frequency = player:GetAttribute("Frequency") or "All"
		local attuneLeft = player:GetAttribute("AttuneScansLeft") or 0
		luckLabel.Text = `Luck x{Format.number(fullLuck)}`
		if ctx.Luck < fullLuck then
			local tier = RarityConfig.Get(focus)
			local focusName = if tier then tier.Name else tostring(focus)
			focusCapLabel.Text = `Focus: {focusName} (capped at x{Format.number(ctx.Luck)})`
		else
			focusCapLabel.Text = ""
		end
		attuneStatus.Text = if attuneLeft > 0
			then `Attune active: {attuneLeft} Focused Common scans left`
			else ""
		highlight(focusChips, focus)
		highlight(frequencyChips, frequency)
		local unlocked = {}
		for _, family in string.split(player:GetAttribute("FrequenciesUnlocked") or "", ",") do
			unlocked[family] = true
		end
		for _, option in FREQUENCY_OPTIONS do
			local isLocked = option.Id ~= "All" and not unlocked[option.Id]
			local chip = frequencyChips[option.Id]
			chip.Text = if isLocked then `{LOCK} {option.Label}` else option.Label
			chip.TextSize = 14
			chip.TextColor3 = if isLocked then colors.SubText else colors.Text
		end

		local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
		for index, tier in ctx.Tiers do
			tierRows[tier.Id].Text = Format.odds(masses[index])
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
			mutationLabel.Text = `Mutations ({math.round((1 - mutationOdds.Normal) * 100)}%): {table.concat(parts, ", ")}`
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

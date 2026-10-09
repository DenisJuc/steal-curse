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

local FocusPanel = {}

type Option = { Id: string, Label: string }

local FOCUS_OPTIONS: { Option } = { { Id = "MaxLuck", Label = "Max Luck" } }
for _, tier in RarityConfig.Tiers do
	table.insert(FOCUS_OPTIONS, { Id = tier.Id, Label = tier.Name })
end

local FREQUENCY_OPTIONS: { Option } = { { Id = "All", Label = "All" } }
for _, family in RelicConfig.Families do
	table.insert(FREQUENCY_OPTIONS, { Id = family, Label = family })
end

local WATCHED_ATTRIBUTES =
	{ "FullLuck", "EffectiveLuck", "RarityFocus", "Frequency", "FrequencyRank", "MutationRank", "FrequenciesUnlocked" }

local function sectionLabel(parent: Instance, text: string, y: number)
	UIKit.label({
		Text = text,
		TextSize = 14,
		TextColor3 = UIKit.Colors.Accent,
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
		local chip = UIKit.create("TextButton", {
			Name = option.Id,
			LayoutOrder = index,
			Text = option.Label,
			Font = UIKit.Font,
			TextSize = 14,
			TextColor3 = UIKit.Colors.Text,
			BackgroundColor3 = UIKit.Colors.Card,
			AutoButtonColor = true,
			Parent = grid,
		}, { UIKit.corner(8) })
		chip.Activated:Connect(function()
			onPick(option.Id)
		end)
		chips[option.Id] = chip
	end
	return chips
end

local function highlight(chips: { [string]: TextButton }, selected: string)
	for id, chip in chips do
		chip.BackgroundColor3 = if id == selected then UIKit.Colors.Accent else UIKit.Colors.Card
	end
end

function FocusPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local panel, content = UIKit.modal(screen, "LuckMenu", "LUCK, FOCUS & ODDS", colors.Accent, Vector2.new(380, 600))
	local body = UIKit.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 520),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = content,
	})

	local luckLabel = UIKit.label({
		TextSize = 14,
		TextColor3 = colors.SubText,
		Size = UDim2.new(1, -8, 0, 18),
		Parent = body,
	})

	sectionLabel(body, "Rarity Focus (caps luck so that tier keeps appearing)", 26)
	local focusChips = makeChips(chipGrid(body, 46, 3), FOCUS_OPTIONS, function(id)
		SetRarityFocus:FireServer(id)
	end)

	sectionLabel(body, "Signal Frequency (favors a family inside each tier)", 164)
	local frequencyChips = makeChips(chipGrid(body, 184, 2), FREQUENCY_OPTIONS, function(id)
		SetFrequency:FireServer(id)
	end)

	sectionLabel(body, "Your chance per discovery", 272)
	local tierRows: { [string]: TextLabel } = {}
	for index, tier in RarityConfig.Tiers do
		local y = 292 + (index - 1) * 22
		UIKit.label({
			Text = tier.Name,
			TextSize = 15,
			TextColor3 = UIKit.tierColor(tier.Id),
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(0.45, 0, 0, 22),
			Parent = body,
		})
		tierRows[tier.Id] = UIKit.label({
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.45, 0, 0, y),
			Size = UDim2.new(0.55, -12, 0, 22),
			Parent = body,
		})
	end

	local mutationLabel = UIKit.label({
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.SubText,
		Position = UDim2.fromOffset(0, 474),
		Size = UDim2.new(1, -12, 0, 40),
		Parent = body,
	})

	local function refresh()
		local ctx = Odds.current()
		local fullLuck = player:GetAttribute("FullLuck") or 1
		local focus = player:GetAttribute("RarityFocus") or "MaxLuck"
		local frequency = player:GetAttribute("Frequency") or "All"
		local capped = if ctx.Luck < fullLuck then "  (capped by focus)" else ""
		luckLabel.Text = `Luck {Format.number(fullLuck)}x  |  used {Format.number(ctx.Luck)}x{capped}`
		highlight(focusChips, focus)
		highlight(frequencyChips, frequency)
		local unlocked = {}
		for _, family in string.split(player:GetAttribute("FrequenciesUnlocked") or "", ",") do
			unlocked[family] = true
		end
		for _, option in FREQUENCY_OPTIONS do
			local isLocked = option.Id ~= "All" and not unlocked[option.Id]
			local chip = frequencyChips[option.Id]
			chip.Text = if isLocked then `{option.Label}\nlocked (Codex)` else option.Label
			chip.TextSize = if isLocked then 12 else 14
			chip.TextColor3 = if isLocked then colors.SubText else colors.Text
		end

		local masses = RollMath.tierMasses(ctx.Tiers, ctx.Luck)
		for index, tier in ctx.Tiers do
			tierRows[tier.Id].Text = Format.odds(masses[index])
		end

		local mutationOdds = RollMath.mutationProbabilities(ctx)
		if ctx.MutationRank <= 0 then
			mutationLabel.Text = "Mutations: locked (Mutation Resonance rank 0)"
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
			panel.Visible = not panel.Visible
			if panel.Visible then
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

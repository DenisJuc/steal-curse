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

local WATCHED_ATTRIBUTES = { "FullLuck", "EffectiveLuck", "RarityFocus", "Frequency", "FrequencyRank", "MutationRank" }

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
		Size = UDim2.new(1, 0, 0, rows * 26 + (rows - 1) * 6),
		Parent = parent,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(100, 26),
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

	local panel = UIKit.create("Frame", {
		Name = "FocusPanel",
		Position = UDim2.fromOffset(304, 12),
		Size = UDim2.fromOffset(340, 500),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = screen,
	}, {
		UIKit.corner(12),
		UIKit.stroke(colors.Accent, 2, 0.35),
		UIKit.padding(12),
	})
	UIKit.scaler(panel)

	UIKit.label({
		Text = "RARITY FOCUS & ODDS",
		TextColor3 = colors.Accent,
		TextSize = 16,
		Size = UDim2.new(1, -30, 0, 20),
		Parent = panel,
	})
	local close = UIKit.create("TextButton", {
		Text = "X",
		Font = UIKit.Font,
		TextSize = 16,
		TextColor3 = colors.Text,
		BackgroundColor3 = colors.Card,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(24, 22),
		Parent = panel,
	}, { UIKit.corner(6) })
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local luckLabel = UIKit.label({
		TextSize = 14,
		TextColor3 = colors.SubText,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = panel,
	})

	sectionLabel(panel, "Rarity Focus (caps luck so that tier keeps appearing)", 52)
	local focusChips = makeChips(chipGrid(panel, 72, 3), FOCUS_OPTIONS, function(id)
		SetRarityFocus:FireServer(id)
	end)

	sectionLabel(panel, "Signal Frequency (favors a family inside each tier)", 170)
	local frequencyChips = makeChips(chipGrid(panel, 190, 2), FREQUENCY_OPTIONS, function(id)
		SetFrequency:FireServer(id)
	end)

	sectionLabel(panel, "Your chance per discovery", 256)
	local tierRows: { [string]: TextLabel } = {}
	for index, tier in RarityConfig.Tiers do
		local y = 276 + (index - 1) * 20
		UIKit.label({
			Text = tier.Name,
			TextSize = 15,
			TextColor3 = UIKit.tierColor(tier.Id),
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(0.45, 0, 0, 20),
			Parent = panel,
		})
		tierRows[tier.Id] = UIKit.label({
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0.45, 0, 0, y),
			Size = UDim2.new(0.55, 0, 0, 20),
			Parent = panel,
		})
	end

	local mutationLabel = UIKit.label({
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = colors.SubText,
		Position = UDim2.fromOffset(0, 440),
		Size = UDim2.new(1, 0, 0, 36),
		Parent = panel,
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

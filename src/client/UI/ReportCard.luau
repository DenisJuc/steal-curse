-- Stat tiles for a Session summary (GDD 9.4): time, scans, finds, new relics, CE produced online,
-- relics auto-sold, and the best find. Used by the Journal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Session = require(script.Parent.Parent.Session)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local ReportCard = {}

local TILE_HEIGHT = 72

local function findText(find: { Id: string, Mutation: string? }?): (string, Color3)
	if not find then
		return "none yet", UIKit.Colors.SubText
	end
	local relic = RelicConfig.ById[find.Id]
	local tier = relic and RarityConfig.Get(relic.Tier)
	local color = if find.Mutation
		then UIKit.mutationColor(find.Mutation)
		elseif relic then UIKit.tierColor(relic.Tier)
		else UIKit.Colors.Text
	return `{Odds.displayName(find.Id, find.Mutation)}{if tier then ` ({tier.Name})` else ""}`, color
end

-- Adds a grid of big stat tiles (value on top, small label under it) to `parent` (a frame with a
-- UIListLayout) at LayoutOrder `order`. Returns the next free LayoutOrder.
function ReportCard.Fill(parent: Instance, summary: Session.Summary, order: number): number
	local report = summary.Report
	local bestText, bestColor = findText(report.Best)
	local tiles: { { string | Color3 } } = {
		{ Format.duration(summary.Seconds), "Time" },
		{ Format.number(summary.Scans), "Scans" },
		{ Format.number(report.Discoveries), "Found" },
		{ Format.number(report.NewUnique), "New relics" },
		{ Format.ce(summary.IncomeCE), "CE earned", UIKit.Colors.Gold },
		{ Format.number(report.SoldCount), "Auto-sold" },
	}
	order += 1
	local grid = UIKit.create("Frame", {
		Name = "Stats",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -10, 0, 0),
		Parent = parent,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, TILE_HEIGHT),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, tile in tiles do
		local frame = UIKit.create("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = UIKit.Colors.Card,
			Parent = grid,
		}, { UIKit.corner(10) })
		UIKit.skinCard(frame)
		local value = UIKit.label({
			Text = tile[1] :: string,
			TextSize = 30,
			TextScaled = true,
			TextColor3 = (tile[3] :: Color3?) or UIKit.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(6, 8),
			Size = UDim2.new(1, -12, 0, 34),
			Parent = frame,
		})
		UIKit.create("UITextSizeConstraint", { MaxTextSize = 32, MinTextSize = 14, Parent = value })
		UIKit.label({
			Text = tile[2] :: string,
			TextSize = 17,
			TextColor3 = UIKit.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 44),
			Size = UDim2.new(1, -8, 0, 20),
			Parent = frame,
		})
	end
	-- Best find gets its own wide line in its rarity color.
	order += 1
	local best = UIKit.label({
		LayoutOrder = order,
		Text = `Best: {bestText}`,
		TextSize = 20,
		TextScaled = true,
		TextColor3 = bestColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -10, 0, 28),
		Parent = parent,
	})
	UIKit.create("UITextSizeConstraint", { MaxTextSize = 21, MinTextSize = 13, Parent = best })
	return order
end

return ReportCard

-- Rows describing a Session summary (GDD 9.4): time, scans, discoveries, new relics, best item
-- and mutation, junk sold and shrine CE produced online. Used by the Journal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Session = require(script.Parent.Parent.Session)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local ReportCard = {}

local ROW_HEIGHT = 24

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

-- Adds the rows to `parent` (a frame with a UIListLayout) starting at LayoutOrder `order`.
-- Returns the next free LayoutOrder.
function ReportCard.Fill(parent: Instance, summary: Session.Summary, order: number): number
	local report = summary.Report
	local bestText, bestColor = findText(report.Best)
	local mutatedText, mutatedColor = findText(report.BestMutated)
	local newText = `{report.NewUnique} new relic{if report.NewUnique == 1 then "" else "s"}`
	if report.NewVariants > 0 then
		newText ..= `, {report.NewVariants} new mutation{if report.NewVariants == 1 then "" else "s"}`
	end
	local rows: { { string | Color3 } } = {
		{ "Time", Format.duration(summary.Seconds) },
		{ "Scans", Format.number(summary.Scans) },
		{ "Discoveries", `{Format.number(report.Discoveries)}  ({newText})` },
		{ "Best find", bestText, bestColor },
		{ "Best mutation", mutatedText, mutatedColor },
		{ "Auto-sold", `{Format.number(report.SoldCount)} relics for {Format.ce(report.SoldCE)} CE` },
		{ "Shrine income", `{Format.ce(summary.IncomeCE)} CE`, UIKit.Colors.Gold },
	}
	for _, row in rows do
		order += 1
		local line = UIKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
			BackgroundTransparency = 1,
			Parent = parent,
		})
		UIKit.label({
			Text = row[1] :: string,
			TextSize = 14,
			TextColor3 = UIKit.Colors.SubText,
			Size = UDim2.fromScale(0.32, 1),
			Parent = line,
		})
		UIKit.label({
			Text = row[2] :: string,
			TextSize = 15,
			TextColor3 = (row[3] :: Color3?) or UIKit.Colors.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromScale(0.32, 0),
			Size = UDim2.fromScale(0.68, 1),
			Parent = line,
		})
	end
	return order
end

return ReportCard

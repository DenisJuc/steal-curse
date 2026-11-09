-- Top-middle feed of recent discoveries, newest on top. Lines fade out on their own and never block anything.
-- Batches arrive through RollReel, after the roll reel has landed. Hunt batches roll on the hunt
-- papers (HuntRolls) instead.
-- Routine Common/Uncommon Normal duplicates collapse into one currency summary per batch.
-- Exceptional finds (new base / mutation / size / Huge / Titanic / Epic+) stay individual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AutoSell = require(ReplicatedStorage.Shared.AutoSell)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RewardPresentation = require(ReplicatedStorage.Shared.RewardPresentation)
local SizeConfig = require(ReplicatedStorage.Shared.SizeConfig)
local Odds = require(script.Parent.Odds)
local RollReel = require(script.Parent.RollReel)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local DiscoveryFeed = {}

type Result = RewardPresentation.Result

local LINE_HEIGHT = 44
local MUTED_HEIGHT = 26
local order = 0
local maxLines = Config.Feed.MaxLines

local function tierOf(result: Result): string?
	local relic = RelicConfig.ById[result.Id]
	return if relic then relic.Tier else nil
end

local function tierIndex(relicId: string): number
	local relic = RelicConfig.ById[relicId]
	return if relic then RarityConfig.IndexById[relic.Tier] or 0 else 0
end

local function fadeLater(line: Frame)
	task.delay(Config.Feed.LineLifetimeSeconds, function()
		if not line.Parent then
			return
		end
		for _, child in line:GetDescendants() do
			if child:IsA("TextLabel") then
				UIKit.tween(child, 0.4, { TextTransparency = 1 })
			elseif child:IsA("UIStroke") then
				UIKit.tween(child, 0.4, { Transparency = 1 })
			end
		end
		UIKit.tween(line, 0.4, { BackgroundTransparency = 1 })
		task.wait(0.45)
		line:Destroy()
	end)
end

local function trimFeed(list: Frame)
	local lines = {}
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = maxLines + 1, #lines do
		lines[index]:Destroy()
	end
end

local function makeLine(list: Frame, title: string, subtitle: string, color: Color3, highlight: boolean, muted: boolean?)
	order -= 1
	local height = if muted then MUTED_HEIGHT else LINE_HEIGHT
	local line = UIKit.create("Frame", {
		Name = "Line",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = UIKit.Colors.Card,
		BackgroundTransparency = if muted then 0.62 else 0.15,
		Parent = list,
	}, {
		UIKit.corner(10),
		UIKit.stroke(color, if highlight then 2.5 else 1, if highlight then 0 elseif muted then 0.9 else 0.55),
	})
	UIKit.create("Frame", {
		Name = "TierBar",
		Size = UDim2.new(0, if muted then 3 else 5, 1, -12),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = color,
		BackgroundTransparency = if muted then 0.5 else 0,
		BorderSizePixel = 0,
		Parent = line,
	}, { UIKit.corner(3) })
	UIKit.label({
		Name = "Title",
		Text = title,
		TextSize = if muted then 12 else 16,
		TextColor3 = if highlight then color elseif muted then UIKit.Colors.SubText else UIKit.Colors.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.new(1, -24, 0, if muted then 18 else 20),
		Parent = line,
	})
	if not muted then
		UIKit.label({
			Name = "Subtitle",
			Text = subtitle,
			TextSize = 13,
			TextColor3 = color,
			Position = UDim2.fromOffset(18, 23),
			Size = UDim2.new(1, -24, 0, 16),
			Parent = line,
		})
	elseif subtitle ~= "" then
		UIKit.label({
			Name = "Subtitle",
			Text = subtitle,
			TextSize = 11,
			TextColor3 = UIKit.Colors.SubText,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(18, 4),
			Size = UDim2.new(1, -24, 0, 18),
			Parent = line,
		})
	end
	UIKit.skinCard(line)
	if highlight then
		Motion.flash(line, color, 0.35)
		Motion.shine(line, 0.7)
		Motion.punch(line, 1.5)
	end
	trimFeed(list)
	fadeLater(line)
end

local function showExceptional(list: Frame, result: Result)
	local relic = RelicConfig.ById[result.Id]
	if not relic then
		return
	end
	local sizeId = SizeConfig.normalize(result.Size)
	local title = Odds.displayName(relic.Id, result.Mutation, sizeId)
	if result.First then
		title = "NEW! " .. title
	elseif result.NewSize then
		title = "NEW SIZE! " .. title
	elseif result.NewVariant then
		title = "NEW VARIANT! " .. title
	elseif sizeId == "Titanic" then
		title = "TITANIC! " .. title
	elseif sizeId == "Huge" then
		title = "HUGE! " .. title
	end
	local color = if sizeId == "Titanic"
		then Color3.fromRGB(255, 210, 90)
		elseif sizeId == "Huge"
		then Color3.fromRGB(160, 210, 255)
		elseif result.Mutation
		then UIKit.mutationColor(result.Mutation)
		else UIKit.tierColor(relic.Tier)
	local worth = RewardPresentation.worthKeeping(result, relic.Tier)
	local subtitle = worth
	if subtitle == "" then
		subtitle = Odds.describe(relic.Id, result.Mutation)
	end
	if sizeId and not string.find(subtitle, sizeId, 1, true) then
		subtitle ..= `  ·  {SizeConfig.Label[sizeId]}`
	end
	if result.Sold then
		local reason = AutoSell.ReasonText[result.SoldReason or ""] or "auto-sell"
		subtitle ..= `  ·  sold +{Format.number(result.Sold)} CE ({reason})`
	end
	makeLine(list, title, subtitle, color, true, false)
end

local function showNotable(list: Frame, result: Result)
	local relic = RelicConfig.ById[result.Id]
	if not relic then
		return
	end
	local sizeId = SizeConfig.normalize(result.Size)
	local title = Odds.displayName(relic.Id, result.Mutation, sizeId)
	local color = if result.Mutation then UIKit.mutationColor(result.Mutation) else UIKit.tierColor(relic.Tier)
	local worth = RewardPresentation.worthKeeping(result, relic.Tier)
	local subtitle = if worth ~= "" then worth else Odds.describe(relic.Id, result.Mutation)
	if result.Sold then
		local reason = AutoSell.ReasonText[result.SoldReason or ""] or "auto-sell"
		subtitle ..= `  ·  +{Format.number(result.Sold)} CE ({reason})`
	end
	makeLine(list, title, subtitle, color, tierIndex(relic.Id) >= (RarityConfig.IndexById[Config.Feed.HighlightTier] or 99), false)
end

local function rarityKey(result: Result): number
	local bonus = SizeConfig.rank(result.Size) * 4
	if result.First or result.NewVariant or result.NewSize then
		bonus += 8
	end
	return tierIndex(result.Id) * 2 + (if result.Mutation then 1 else 0) + bonus
end

local SHOW_CARDS = false

function DiscoveryFeed.Start(screen: ScreenGui)
	local list = UIKit.create("Frame", {
		Name = "DiscoveryFeed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(340, (LINE_HEIGHT + 6) * Config.Feed.MaxLines),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	UIKit.scaler(list)
	-- Starts under the next-unlock chip while it shows (NextUnlockChip).
	local function follow()
		local top = screen:GetAttribute("TopChipHeight")
		list.Position = UDim2.new(0.5, 0, 0, if type(top) == "number" and top > 0 then top else 8)
	end
	screen:GetAttributeChangedSignal("TopChipHeight"):Connect(follow)
	follow()
	UIKit.watchCompact(function(compact: boolean)
		maxLines = if compact then Config.Feed.CompactMaxLines else Config.Feed.MaxLines
		list.Size = UDim2.fromOffset(340, (LINE_HEIGHT + 6) * maxLines)
	end)

	RollReel.OnResults(function(results: { Result }, hunt: boolean)
		if type(results) ~= "table" or hunt then
			return
		end
		-- 2026-11-09: the feed's cards are off (Rosselle: screen clutter; the roll card and the big
		-- reveal already show every find). All that is left is the Codex button's "new" badge:
		-- first finds count up there and clear when the Codex is opened.
		local fresh = 0
		for _, result in results do
			if result.First then
				fresh += 1
			end
		end
		if fresh > 0 then
			local player = Players.LocalPlayer
			player:SetAttribute("CodexNew", (player:GetAttribute("CodexNew") or 0) + fresh)
		end
		if not SHOW_CARDS then
			return
		end
		local plan = RewardPresentation.planFeed(results, tierOf)
		-- Exceptionals first (rarest), then notables, then one routine summary.
		local exceptional = table.clone(plan.Exceptional)
		table.sort(exceptional, function(a, b)
			return rarityKey(a) > rarityKey(b)
		end)
		local notable = table.clone(plan.Notable)
		table.sort(notable, function(a, b)
			return rarityKey(a) > rarityKey(b)
		end)

		local budget = maxLines
		local routineLine = if plan.RoutineCount > 0 then 1 else 0
		budget -= routineLine

		local showExc = math.min(#exceptional, budget)
		budget -= showExc
		local showNot = math.min(#notable, budget)

		for i = 1, showExc do
			showExceptional(list, exceptional[i])
		end
		for i = 1, showNot do
			showNotable(list, notable[i])
		end
		local hidden = (#exceptional - showExc) + (#notable - showNot)
		-- Kept-only common duplicates get no line: the roll card already showed them, and a line
		-- every scan was just noise. Sold ones still show the CE they earned.
		if plan.RoutineSummaryTitle and plan.RoutineSummarySubtitle and plan.RoutineSoldCE > 0 then
			local subtitle = plan.RoutineSummarySubtitle
			if hidden > 0 then
				subtitle ..= `  ·  +{hidden} other`
			end
			-- Format CE in summary with Format.number when sold
			local title = plan.RoutineSummaryTitle
			if plan.RoutineSoldCE > 0 then
				title = if plan.RoutineKeptCount > 0
					then `· {plan.RoutineCount} common finds`
					else `· +{Format.number(plan.RoutineSoldCE)} CE`
				subtitle = if plan.RoutineKeptCount > 0
					then `+{Format.number(plan.RoutineSoldCE)} CE sold · {plan.RoutineKeptCount} kept`
					else `{plan.RoutineSoldCount} common duplicate{if plan.RoutineSoldCount == 1 then "" else "s"} sold`
				if hidden > 0 then
					subtitle ..= `  ·  +{hidden} other`
				end
			end
			makeLine(list, title, subtitle, UIKit.Colors.SubText, false, true)
		elseif hidden > 0 then
			makeLine(list, `+{hidden} more`, "see Journal", UIKit.Colors.SubText, false, true)
		end
	end)
end

return DiscoveryFeed

-- Codex menu (GDD 7, 12.1): discovery progress, milestones (essential bonuses, frequency
-- unlocks, set titles, prestige titles), earned titles and one card per relic. Unknown relics
-- show as silhouettes with only their tier and base odds. Seen mutations appear as colored dots
-- on the relic's card (no separate mutation Codex).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Banner = require(script.Parent.Banner)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetCodex = Remotes:WaitForChild("GetCodex") :: RemoteFunction
local ClaimCodex = Remotes:WaitForChild("ClaimCodex") :: RemoteFunction

local CodexPanel = {}

local KIND_ORDER = { "Essential", "Frequency", "SetComplete", "Collection", "MutatedTier" }
local KIND_HEADINGS = {
	Essential = "Essential milestones (Common-Legendary relics, any mutation counts)",
	Frequency = "Signal Frequency unlocks",
	SetComplete = "Family sets (titles)",
	Collection = "Full collection (titles)",
	MutatedTier = "Mutated rarities (titles)",
}
local REFRESH_SECONDS = 1
local DONE_COLOR = Color3.fromRGB(120, 230, 140)

function CodexPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local panel, content = UIKit.modal(screen, "CodexMenu", "CODEX", colors.Accent, Vector2.new(580, 640))
	local body = UIKit.scrollList(content, 6)
	local order = 0

	local function nextOrder(): number
		order += 1
		return order
	end

	local function heading(value: string)
		UIKit.label({
			LayoutOrder = nextOrder(),
			Text = value,
			TextSize = 15,
			TextColor3 = colors.Accent,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -10, 0, 24),
			Parent = body,
		})
	end

	local claim: (string) -> ()

	local function milestoneRow(milestone: Codex.Milestone, have: number, claimed: boolean, ready: boolean)
		local frame = UIKit.create("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -10, 0, 46),
			BackgroundColor3 = colors.Card,
			Parent = body,
		}, { UIKit.corner(8), UIKit.stroke(colors.Gold, 2, if ready and not claimed then 0 else 1) })
		local done = claimed or milestone.Need == 0
		UIKit.label({
			Text = Codex.goalText(CodexBook, milestone),
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if done then DONE_COLOR else colors.Text,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -110, 0, 20),
			Parent = frame,
		})
		UIKit.label({
			Text = Codex.rewardText(milestone),
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = colors.Gold,
			Position = UDim2.fromOffset(10, 24),
			Size = UDim2.new(1, -110, 0, 18),
			Parent = frame,
		})
		if ready and not done then
			UIKit.button({
				Text = "Claim",
				TextSize = 16,
				TextColor3 = colors.Panel,
				BackgroundColor3 = colors.Gold,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(88, 34),
				Parent = frame,
			}, function()
				claim(milestone.Id)
			end)
			return
		end
		UIKit.label({
			Text = if done then "EARNED" else `{math.min(have, milestone.Need)} / {milestone.Need}`,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if done then DONE_COLOR else colors.SubText,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.new(0, 90, 1, 0),
			Parent = frame,
		})
	end

	local function relicCard(grid: Frame, relicId: string, index: number, state: Codex.State)
		local relic = RelicConfig.ById[relicId]
		local known = state.Discovered[relicId] ~= nil
		local tierColor = UIKit.tierColor(relic.Tier)
		local tier = RarityConfig.Get(relic.Tier)
		local card = UIKit.create("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = if known then colors.Card else colors.Track,
		}, { UIKit.corner(8), UIKit.stroke(tierColor, 1.5, if known then 0.1 else 0.6) })
		if not known then
			UIKit.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Color3.fromRGB(4, 4, 8),
				Parent = card,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		UIKit.label({
			Text = if known then relic.Name else "???",
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = if known then tierColor else colors.SubText,
			Position = UDim2.fromOffset(4, if known then 6 else 38),
			Size = UDim2.new(1, -8, 0, if known then 32 else 16),
			Parent = card,
		})
		UIKit.label({
			Text = `{if tier then tier.Name else relic.Tier}  {Format.odds(Odds.baseItem(relicId))}`,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = tierColor,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 4, 1, -36),
			Size = UDim2.new(1, -8, 0, 14),
			Parent = card,
		})
		local seen = state.Mutations[relicId]
		if known and seen then
			local dots = UIKit.create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 6, 1, -18),
				Size = UDim2.new(1, -12, 0, 12),
				Parent = card,
			}, {
				UIKit.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
			})
			for mutationIndex, mutation in MutationConfig.Mutations do
				if seen[mutation.Id] then
					UIKit.create("Frame", {
						LayoutOrder = mutationIndex,
						Size = UDim2.fromOffset(12, 12),
						BackgroundColor3 = UIKit.mutationColor(mutation.Id),
						Parent = dots,
					}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
				end
			end
		end
		card.Parent = grid
	end

	local function render(snapshot: any)
		order = 0
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local state: Codex.State = { Discovered = snapshot.Discovered or {}, Mutations = snapshot.Mutations or {} }
		local claimed = snapshot.Claimed or {}
		local ready = snapshot.Ready or {}
		local claimable = 0
		for id in ready do
			if not claimed[id] and CodexBook.ById[id] then
				claimable += 1
			end
		end

		local discovered, essential = 0, 0
		for _, relicId in CodexBook.AllIds do
			if state.Discovered[relicId] then
				discovered += 1
				if CodexBook.PoolSet[relicId] then
					essential += 1
				end
			end
		end
		local luck, income = Codex.bonuses(CodexBook, claimed)
		local summary = UIKit.create("Frame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -10, 0, 52),
			BackgroundColor3 = colors.Card,
			Parent = body,
		}, { UIKit.corner(8) })
		UIKit.label({
			Text = `Discovered {discovered} / {#CodexBook.AllIds}   |   Essential {essential} / {#CodexBook.Pool}`,
			TextSize = 15,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 22),
			Parent = summary,
		})
		UIKit.label({
			Text = `Codex bonus: +{math.round(luck * 100)}% Luck, +{math.round(income * 100)}% CE income (permanent)`,
			TextSize = 13,
			TextColor3 = colors.Gold,
			Position = UDim2.fromOffset(10, 27),
			Size = UDim2.new(1, -20, 0, 20),
			Parent = summary,
		})

		if claimable > 0 then
			UIKit.button({
				LayoutOrder = nextOrder(),
				Text = `Claim all rewards ({claimable})`,
				TextSize = 17,
				TextColor3 = colors.Panel,
				BackgroundColor3 = colors.Gold,
				Size = UDim2.new(1, -10, 0, 40),
				Parent = body,
			}, function()
				claim("All")
			end)
		end

		for _, kind in KIND_ORDER do
			heading(KIND_HEADINGS[kind])
			for _, milestone in CodexBook.Milestones do
				if milestone.Kind == kind then
					milestoneRow(
						milestone,
						Codex.progress(milestone, state),
						claimed[milestone.Id] ~= nil,
						ready[milestone.Id] ~= nil
					)
				end
			end
		end

		heading("Titles")
		local titles = Codex.titles(CodexBook, claimed)
		UIKit.label({
			LayoutOrder = nextOrder(),
			Text = if #titles > 0 then table.concat(titles, ", ") else "None yet. Titles come from the milestones above.",
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = if #titles > 0 then colors.Gold else colors.SubText,
			Size = UDim2.new(1, -10, 0, 36),
			Parent = body,
		})

		heading("Relics")
		local grid = UIKit.create("Frame", {
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = body,
		}, {
			UIKit.create("UIGridLayout", {
				CellSize = UDim2.fromOffset(124, 96),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for index, relicId in CodexBook.AllIds do
			relicCard(grid, relicId, index, state)
		end
	end

	local claiming = false
	function claim(which: string)
		if claiming then
			return
		end
		claiming = true
		task.spawn(function()
			local ok, result = pcall(function()
				return ClaimCodex:InvokeServer(which)
			end)
			claiming = false
			if not ok or type(result) ~= "table" then
				return
			end
			if result.Snapshot and panel.Visible then
				render(result.Snapshot)
			end
			local milestones = {}
			for _, id in result.Claimed or {} do
				local milestone = CodexBook.ById[id]
				if milestone then
					table.insert(milestones, milestone)
				end
			end
			if #milestones > 0 then
				local title = if #milestones == 1 then "MILESTONE CLAIMED!" else `{#milestones} MILESTONES CLAIMED!`
				Banner.Show(title, Codex.combinedRewardText(milestones), colors.Gold)
			end
		end)
	end

	local function load()
		task.spawn(function()
			local ok, snapshot = pcall(function()
				return GetCodex:InvokeServer()
			end)
			if ok and type(snapshot) == "table" and panel.Visible then
				render(snapshot)
			end
		end)
	end

	local refreshQueued = false
	player:GetAttributeChangedSignal("DiscoveredCount"):Connect(function()
		if not panel.Visible or refreshQueued then
			return
		end
		refreshQueued = true
		task.delay(REFRESH_SECONDS, function()
			refreshQueued = false
			if panel.Visible then
				load()
			end
		end)
	end)

	return {
		Toggle = function()
			panel.Visible = not panel.Visible
			if panel.Visible then
				load()
			end
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return CodexPanel

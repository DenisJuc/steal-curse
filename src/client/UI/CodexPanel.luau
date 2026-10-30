-- Codex menu (GDD 7, 12.1): discovery progress, milestones (essential bonuses, frequency
-- unlocks, set titles, prestige titles), earned titles and one card per relic with its 3D model
-- and, once discovered, its base income per second. Unknown relics show as a black silhouette of the model with only their tier and base odds. Seen mutations appear as colored dots
-- on the relic's card (no separate mutation Codex). Relics are tabbed Normal / Huge / Titanic
-- and grouped by rarity like an index.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicIncome = require(ReplicatedStorage.Shared.RelicIncome)
local Banner = require(script.Parent.Banner)
local Motion = require(script.Parent.Motion)
local Odds = require(script.Parent.Odds)
local RelicViewport = require(script.Parent.RelicViewport)
local UIKit = require(script.Parent.UIKit)
local Sounds = require(script.Parent.Parent.Sounds)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetCodex = Remotes:WaitForChild("GetCodex") :: RemoteFunction
local ClaimCodex = Remotes:WaitForChild("ClaimCodex") :: RemoteFunction

local CodexPanel = {}

local KIND_ORDER = { "Essential", "Frequency", "SetComplete", "Collection", "MutatedTier" }
local KIND_HEADINGS = {
	Essential = "Milestones",
	Frequency = "Family unlocks",
	SetComplete = "Family sets",
	Collection = "Full collection",
	MutatedTier = "Mutated rarities",
}
local REFRESH_SECONDS = 1
local DONE_COLOR = Color3.fromRGB(120, 230, 140)
local ROW_HEIGHT = 58
local BAR_HEIGHT = 6
local SIZE_TABS = { "Normal", "Huge", "Titanic" }
local SIZE_COLORS = {
	Huge = Color3.fromRGB(160, 210, 255),
	Titanic = Color3.fromRGB(255, 210, 90),
}

-- Short reward-track titles ("28 relics", "9 Demonic") instead of full goal sentences.
local function shortGoal(milestone: Codex.Milestone): string
	if milestone.Kind == "Essential" or milestone.Kind == "Collection" then
		return `{milestone.Need} relics`
	elseif milestone.Kind == "Frequency" or milestone.Kind == "SetComplete" then
		return `{milestone.Need} {milestone.Family}`
	elseif milestone.Kind == "MutatedTier" then
		return `mutated {milestone.Tier}`
	end
	return Codex.goalText(CodexBook, milestone)
end

function CodexPanel.Start(screen: ScreenGui): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local panel, content = UIKit.modal(screen, "CodexMenu", "CODEX", colors.Accent, Vector2.new(580, 640), "Codex")
	local body = UIKit.scrollList(content, 6)
	local order = 0
	-- One render per relic, kept across refreshes; unknown relics tint it black.
	local renders = RelicViewport.cache(#CodexBook.AllIds)
	local sizeTab = "Normal"
	local lastState: Codex.State = { Discovered = {}, Mutations = {} }
	local lastSizes: { [string]: { [string]: number } } = {}
	local relicList: Frame? = nil
	local tabButtons: { [string]: TextButton } = {}

	local function nextOrder(): number
		order += 1
		return order
	end

	local function heading(value: string)
		UIKit.heading({
			LayoutOrder = nextOrder(),
			Text = value,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -10, 0, 24),
			Parent = body,
		})
	end

	local claim: (string) -> ()

	local function milestoneRow(milestone: Codex.Milestone, have: number, claimed: boolean, ready: boolean)
		local done = claimed or milestone.Need == 0
		local claimable = ready and not done
		local holder = UIKit.slot(body, milestone.Id, UDim2.new(1, -10, 0, ROW_HEIGHT), nextOrder())
		local frame = UIKit.create("Frame", {
			Name = "Card",
			BackgroundColor3 = colors.Card,
			Parent = holder,
		}, { UIKit.corner(8) })
		UIKit.fill(frame)
		UIKit.skinCard(frame, if claimable then colors.Gold elseif done then DONE_COLOR else nil)
		frame:SetAttribute("PopIn", true)
		UIKit.label({
			Text = shortGoal(milestone),
			TextSize = 18,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if done then DONE_COLOR else colors.Text,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -110, 0, 22),
			Parent = frame,
		})
		UIKit.label({
			Text = Codex.rewardText(milestone),
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = colors.Gold,
			Position = UDim2.fromOffset(10, 26),
			Size = UDim2.new(1, -110, 0, 18),
			Parent = frame,
		})
		local fill = if milestone.Need <= 0 then 1 else math.clamp(have / milestone.Need, 0, 1)
		local track = UIKit.create("Frame", {
			Name = "Track",
			Position = UDim2.fromOffset(10, ROW_HEIGHT - BAR_HEIGHT - 6),
			Size = UDim2.new(1, -20, 0, BAR_HEIGHT),
			BackgroundColor3 = colors.Track,
			BorderSizePixel = 0,
			Parent = frame,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		UIKit.create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(fill, 1),
			BackgroundColor3 = if claimable then colors.Gold elseif done then DONE_COLOR else colors.Jade,
			BorderSizePixel = 0,
			Parent = track,
		}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		if claimable then
			local claimButton = UIKit.button({
				Text = "Claim",
				TextSize = 16,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -50, 0.5, -2),
				Size = UDim2.fromOffset(88, 34),
				Parent = frame,
			}, function()
				claim(milestone.Id)
			end)
			UIKit.skinButton(claimButton, "Gold")
			Motion.shineLoop(claimButton, 2.2)
			return
		end
		UIKit.label({
			Text = if done then "EARNED" else `{math.min(have, milestone.Need)} / {milestone.Need}`,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if done then DONE_COLOR else colors.SubText,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 4),
			Size = UDim2.fromOffset(90, 40),
			Parent = frame,
		})
	end

	local function relicKnown(relicId: string, tab: string, state: Codex.State, sizes: { [string]: { [string]: number } }): boolean
		if tab == "Normal" then
			return state.Discovered[relicId] ~= nil
		end
		local seen = sizes[relicId]
		return seen ~= nil and seen[tab] ~= nil
	end

	local function tabFound(tab: string, state: Codex.State, sizes: { [string]: { [string]: number } }): number
		local found = 0
		for _, relicId in CodexBook.AllIds do
			if relicKnown(relicId, tab, state, sizes) then
				found += 1
			end
		end
		return found
	end

	local function relicCard(grid: Frame, relicId: string, index: number, state: Codex.State, known: boolean, sizeId: string?)
		local relic = RelicConfig.ById[relicId]
		local tierColor = UIKit.tierColor(relic.Tier)
		local card = UIKit.create("Frame", {
			LayoutOrder = index,
			BackgroundColor3 = if known then colors.Card else colors.Track,
		}, { UIKit.corner(8), UIKit.stroke(tierColor, 1.5, if known then 0.1 else 0.6) })
		UIKit.skinCard(card)
		local render = renders.Get(relicId, relicId)
		render.AnchorPoint = Vector2.new(0.5, 0)
		render.Position = UDim2.new(0.5, 0, 0, 3)
		render.Size = UDim2.fromOffset(42, 42)
		render.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		render.Parent = card
		if known and sizeId then
			UIKit.label({
				Text = string.upper(sizeId),
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = SIZE_COLORS[sizeId] or colors.Text,
				Position = UDim2.fromOffset(4, 2),
				Size = UDim2.new(1, -8, 0, 12),
				Parent = card,
			})
		end
		UIKit.label({
			Text = if known then relic.Name else "???",
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if known then tierColor else colors.SubText,
			Position = UDim2.fromOffset(4, 46),
			Size = UDim2.new(1, -8, 0, 16),
			Parent = card,
		})
		if known then
			UIKit.label({
				Text = `+{Format.rate(RelicIncome.of(relicId))}`,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = colors.Gold,
				Position = UDim2.fromOffset(4, 62),
				Size = UDim2.new(1, -8, 0, 14),
				Parent = card,
			})
		end
		UIKit.label({
			-- Effective 1/p_i at current luck (SoftCap/Ladder); base rarity stays in the tier name.
			Text = Odds.indexLine(relicId),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = tierColor,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 4, 1, -32),
			Size = UDim2.new(1, -8, 0, 14),
			Parent = card,
		})
		local seen = state.Mutations[relicId]
		if known and seen then
			local dots = UIKit.create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 6, 1, -16),
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

	local function skinTabs()
		local total = #CodexBook.AllIds
		for _, tab in SIZE_TABS do
			local button = tabButtons[tab]
			if button then
				button.Text = `{tab} {tabFound(tab, lastState, lastSizes)}/{total}`
				UIKit.skinButton(button, if tab == sizeTab then "Primary" else "Dark")
			end
		end
	end

	local function renderRelicList()
		local list = relicList
		if not list then
			return
		end
		renders.DetachAll()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		skinTabs()
		local listOrder = 0
		local sizeId = if sizeTab == "Normal" then nil else sizeTab
		for _, tier in RarityConfig.Tiers do
			local ids = {}
			for _, relicId in CodexBook.AllIds do
				local relic = RelicConfig.ById[relicId]
				if relic and relic.Tier == tier.Id then
					table.insert(ids, relicId)
				end
			end
			if #ids == 0 then
				continue
			end
			local found = 0
			for _, relicId in ids do
				if relicKnown(relicId, sizeTab, lastState, lastSizes) then
					found += 1
				end
			end
			listOrder += 1
			local tierColor = UIKit.tierColor(tier.Id)
			UIKit.label({
				LayoutOrder = listOrder,
				Text = `{tier.Name} {found}/{#ids}`,
				TextSize = 14,
				TextColor3 = tierColor,
				Size = UDim2.new(1, 0, 0, 20),
				Parent = list,
			})
			listOrder += 1
			local grid = UIKit.create("Frame", {
				LayoutOrder = listOrder,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Parent = list,
			}, {
				UIKit.create("UIGridLayout", {
					CellSize = UDim2.fromOffset(124, 110),
					CellPadding = UDim2.fromOffset(6, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			for index, relicId in ids do
				relicCard(grid, relicId, index, lastState, relicKnown(relicId, sizeTab, lastState, lastSizes), sizeId)
			end
		end
	end

	local function render(snapshot: any)
		order = 0
		renders.DetachAll()
		relicList = nil
		tabButtons = {}
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local state: Codex.State = { Discovered = snapshot.Discovered or {}, Mutations = snapshot.Mutations or {} }
		lastState = state
		lastSizes = snapshot.Sizes or {}
		local claimed = snapshot.Claimed or {}
		local ready = snapshot.Ready or {}
		local claimable = 0
		for id in ready do
			if not claimed[id] and CodexBook.ById[id] then
				claimable += 1
			end
		end

		local discovered = 0
		for _, relicId in CodexBook.AllIds do
			if state.Discovered[relicId] then
				discovered += 1
			end
		end
		local luck, income = Codex.bonuses(CodexBook, claimed)
		local summaryHolder = UIKit.slot(body, "Summary", UDim2.new(1, -10, 0, 56), nextOrder())
		local summary = UIKit.create("Frame", {
			BackgroundColor3 = colors.Card,
			Parent = summaryHolder,
		}, { UIKit.corner(8) })
		UIKit.fill(summary)
		UIKit.skinCard(summary, colors.Trim)
		summary:SetAttribute("PopIn", true)
		UIKit.label({
			Text = `{discovered} / {#CodexBook.AllIds} found`,
			TextSize = 24,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -20, 0, 28),
			Parent = summary,
		})
		UIKit.label({
			Text = `+{math.round(luck * 100)}% Luck  +{math.round(income * 100)}% CE`,
			TextSize = 13,
			TextColor3 = colors.Gold,
			Position = UDim2.fromOffset(10, 34),
			Size = UDim2.new(1, -20, 0, 18),
			Parent = summary,
		})

		if claimable > 0 then
			local claimSlot = UIKit.slot(body, "ClaimAll", UDim2.new(1, -10, 0, 40), nextOrder())
			local claimAll = UIKit.button({
				Text = `Claim all rewards ({claimable})`,
				TextSize = 17,
				Parent = claimSlot,
			}, function()
				claim("All")
			end)
			UIKit.fill(claimAll)
			UIKit.skinButton(claimAll, "Gold")
			Motion.shineLoop(claimAll, 2.2)
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
		local tabs = UIKit.create("Frame", {
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 32),
			Parent = body,
		}, {
			UIKit.create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		})
		for index, tab in SIZE_TABS do
			tabButtons[tab] = UIKit.button({
				Text = tab,
				TextSize = 15,
				LayoutOrder = index,
				Size = UDim2.new(1 / #SIZE_TABS, -4, 1, 0),
				Parent = tabs,
			}, function()
				if sizeTab == tab then
					return
				end
				sizeTab = tab
				renderRelicList()
			end)
		end
		relicList = UIKit.create("Frame", {
			LayoutOrder = nextOrder(),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = body,
		}, {
			UIKit.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
		})
		renderRelicList()
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
				Sounds.Play("Shine")
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
	local function queueRefresh()
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
	end
	player:GetAttributeChangedSignal("DiscoveredCount"):Connect(queueRefresh)
	-- Index odds are 1/p_i at current luck — refresh when luck or sampler changes.
	player:GetAttributeChangedSignal("EffectiveLuck"):Connect(queueRefresh)
	player:GetAttributeChangedSignal("FullLuck"):Connect(queueRefresh)
	player:GetAttributeChangedSignal("RaritySampler"):Connect(queueRefresh)

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
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

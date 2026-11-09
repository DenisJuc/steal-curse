-- Codex menu (GDD 7, 12.1): discovery progress, milestones (essential bonuses, frequency
-- unlocks, set titles, prestige titles), earned titles and one card per relic with its 3D model
-- and, once discovered, its base income per second. Unknown relics show as a black silhouette of the model with only their tier and base odds. Seen mutations appear as colored dots
-- on the relic's card (no separate mutation Codex). Relics are tabbed Normal / Huge / Titanic
-- and grouped by rarity like an index. Three tabs: Relics (the index, first), Rewards
-- (milestones, titles and Claim all) and Zones (curse progress, mastery, lore; see ZonesPage).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codex = require(ReplicatedStorage.Shared.Codex)
local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Banner = require(script.Parent.Banner)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local Odds = require(script.Parent.Odds)
local RelicViewport = require(script.Parent.RelicViewport)
local UIKit = require(script.Parent.UIKit)
local ZonesPage = require(script.Parent.ZonesPage)
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
local CARD_SIZE = Vector2.new(106, 104)
-- Render box (px) and how much of it the relic fills, per size tab. Huge and Titanic get taller
-- cards and bigger boxes so the relic reads about 1.7x and 2.4x the Normal one (2026-11-09:
-- framing alone was clipped by the fixed 56 px box and the jump was hard to see).
local RENDER_BOX = {
	Normal = { Box = 56, Fill = 0.72 },
	Huge = { Box = 76, Fill = 0.9 },
	Titanic = { Box = 98, Fill = 0.98 },
}
local function cardHeight(sizeId: string?): number
	return CARD_SIZE.Y - 56 + RENDER_BOX[sizeId or "Normal"].Box
end
local BAR_HEIGHT = 6
local SIZE_TABS = { "Normal", "Huge", "Titanic" }
local SIZE_COLORS = {
	Huge = Color3.fromRGB(160, 210, 255),
	Titanic = Color3.fromRGB(255, 210, 90),
}

-- The picture on a reward stamp: what the milestone gives (UI pass 2026-11-09; the stamps used to
-- be blank or a "!").
local function rewardIcon(milestone: Codex.Milestone): string
	if milestone.Kind == "Frequency" then
		return "Pulse"
	elseif milestone.Luck > 0 then
		return "Luck"
	elseif milestone.Income > 0 then
		return "CursedEnergy"
	elseif milestone.Title then
		return "Favorite"
	end
	return "Codex"
end

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

	local panel, content = UIKit.modal(screen, "CodexMenu", "CODEX", colors.Accent, Vector2.new(600, 640), "Codex")
	local pageTop = UIKit.TAB_HEIGHT + 8
	local function pageList(name: string): ScrollingFrame
		local list = UIKit.scrollList(content, 6)
		list.Name = name
		list.Position = UDim2.fromOffset(0, pageTop)
		list.Size = UDim2.new(1, 0, 1, -pageTop)
		list.ScrollBarImageColor3 = colors.Trim
		return list
	end
	-- Relics first (the index), rewards on their own tab, then the zones (curse progress, mastery
	-- and shrine lore, moved here from the old Journal).
	local relicsBody = pageList("RelicsPage")
	local body = pageList("RewardsPage")
	body.Visible = false
	local zonesBody = pageList("ZonesPage")
	zonesBody.Visible = false
	local pageTabs = {
		{ Id = "Relics", Text = "Relics" },
		{ Id = "Rewards", Text = "Rewards" },
		{ Id = "Zones", Text = "Zones" },
	}
	local _, pageButtons = UIKit.tabBar(content, pageTabs, "Relics", function(id)
		relicsBody.Visible = id == "Relics"
		body.Visible = id == "Rewards"
		zonesBody.Visible = id == "Zones"
		if id == "Zones" then
			ZonesPage.render(zonesBody)
		end
	end)
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
			TextSize = 19,
			Size = UDim2.new(1, -10, 0, 26),
			Parent = body,
		})
	end

	local claim: (string) -> ()

	-- One kind of milestone as a card: title + "earned/total", a wrap of round stamps (green
	-- check = earned, gold = ready to claim, dim = locked with its goal under it) and one line on
	-- the next goal with its progress bar.
	local STAMP = 46
	local function milestoneTrack(title: string, list: { Codex.Milestone }, state: Codex.State, claimed: { [string]: any }, ready: { [string]: any })
		local earned, nextOne = 0, nil
		for _, milestone in list do
			if claimed[milestone.Id] ~= nil or milestone.Need == 0 then
				earned += 1
			elseif not nextOne and ready[milestone.Id] == nil then
				nextOne = milestone
			end
		end
		local card = UIKit.create("Frame", {
			Name = title,
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = colors.Card,
			Parent = body,
		}, {
			UIKit.corner(10),
			UIKit.padding(10),
			UIKit.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		})
		UIKit.skinCard(card, if earned == #list then DONE_COLOR else nil)
		local head = UIKit.create("Frame", { LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), Parent = card })
		UIKit.label({
			Text = title,
			FontFace = UIKit.TitleFont,
			TextSize = 19,
			TextColor3 = colors.Gold,
			Size = UDim2.new(1, -80, 1, 0),
			Parent = head,
		})
		UIKit.label({
			Text = `{earned} / {#list}`,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if earned == #list then DONE_COLOR else colors.SubText,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 80, 1, 0),
			Parent = head,
		})
		local stamps = UIKit.create("Frame", {
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		}, {
			UIKit.create("UIGridLayout", {
				CellSize = UDim2.fromOffset(72, STAMP + 22),
				CellPadding = UDim2.fromOffset(6, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for index, milestone in list do
			local done = claimed[milestone.Id] ~= nil or milestone.Need == 0
			local claimable = ready[milestone.Id] ~= nil and not done
			local cell = UIKit.create("Frame", { LayoutOrder = index, BackgroundTransparency = 1, Parent = stamps })
			local icon = rewardIcon(milestone)
			local stamp = UIKit.button({
				Name = milestone.Id,
				-- The reward's picture; text only if its icon is missing.
				Text = if Icons.has(icon) then "" elseif claimable then "!" else "",
				TextSize = 24,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(STAMP, STAMP),
				Parent = cell,
			}, function()
				if claimable then
					claim(milestone.Id)
				end
			end)
			stamp:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
			UIKit.skinButton(stamp, if claimable then "Gold" elseif done then "Buy" else "Dark")
			stamp.TextColor3 = if claimable then colors.Panel else colors.Text
			local picture = Icons.image(stamp, icon, STAMP - 12)
			if picture then
				picture.AnchorPoint = Vector2.new(0.5, 0.5)
				picture.Position = UDim2.fromScale(0.5, 0.5)
				-- Locked rewards show what they will give, greyed out.
				picture.ImageTransparency = if done or claimable then 0 else 0.45
				picture.ImageColor3 = if done or claimable then Color3.new(1, 1, 1) else Color3.fromRGB(150, 140, 160)
			end
			-- Corner badge: a red "!" when ready to claim, a green tick once earned.
			if claimable or done then
				local badge = UIKit.label({
					Name = "Badge",
					Text = if claimable then "!" else "✓",
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BackgroundColor3 = if claimable then colors.Red else colors.Jade,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -4, 0, 4),
					Size = UDim2.fromOffset(18, 18),
					ZIndex = 5,
					Parent = stamp,
				})
				UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
				UIKit.stroke(colors.Panel, 1.5, 0).Parent = badge
			end
			if claimable then
				Motion.shineLoop(stamp, 2.2)
			end
			UIKit.label({
				Text = shortGoal(milestone),
				TextSize = 13,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if done then DONE_COLOR elseif claimable then colors.Gold else colors.SubText,
				Position = UDim2.fromOffset(0, STAMP + 3),
				Size = UDim2.new(1, 0, 0, 16),
				Parent = cell,
			})
		end
		if nextOne then
			local have = Codex.progress(nextOne, state)
			UIKit.label({
				LayoutOrder = 3,
				Text = `Next at {shortGoal(nextOne)}: {Codex.rewardText(nextOne)}`,
				TextSize = 17,
				TextColor3 = colors.Text,
				TextWrapped = true,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.new(1, 0, 0, 20),
				Parent = card,
			})
			local track = UIKit.create("Frame", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
				BackgroundColor3 = colors.Track,
				BorderSizePixel = 0,
				Parent = card,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			UIKit.create("Frame", {
				Size = UDim2.fromScale(math.clamp(have / math.max(nextOne.Need, 1), 0, 1), 1),
				BackgroundColor3 = colors.Jade,
				BorderSizePixel = 0,
				Parent = track,
			}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
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
			ClipsDescendants = true,
		}, { UIKit.corner(10) })
		-- Rarity card (UI pass 2026-11-09): found relics glow in their tier colour like the Shop
		-- cards; unfound ones stay dark with a faint tier edge.
		local glow = UIKit.skinRarityCard(card, tierColor, not known, known and UIKit.tierShines(relic.Tier))
		-- Huge / Titanic tabs render the relic bigger in its card (RelicViewport frames by size).
		local box = RENDER_BOX[sizeId or "Normal"]
		if glow then
			glow.Position = UDim2.new(0.5, 0, 0, 4 + box.Box / 2)
			glow.Size = UDim2.fromOffset(box.Box * 1.1, box.Box * 1.1)
		end
		local render = renders.Get(`{relicId}|{sizeId or ""}`, relicId, sizeId)
		RelicViewport.refit(render, box.Fill)
		render.AnchorPoint = Vector2.new(0.5, 0)
		render.Position = UDim2.new(0.5, 0, 0, 4)
		render.Size = UDim2.fromOffset(box.Box, box.Box)
		local below = box.Box - 56
		render.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		render.Parent = card
		if known and sizeId then
			UIKit.label({
				Text = string.upper(sizeId),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = SIZE_COLORS[sizeId] or colors.Text,
				Position = UDim2.fromOffset(6, 2),
				Size = UDim2.new(1, -12, 0, 14),
				Parent = card,
			})
		end
		-- Name on one line that shrinks to fit, then "1 in N" at your current luck.
		local name = UIKit.label({
			Text = if known then relic.Name else "???",
			TextSize = 16,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			-- White on the tinted card (the card colour now says the rarity).
			TextColor3 = if known then colors.Text else colors.SubText,
			TextStrokeTransparency = if known then 0.55 else 1,
			Position = UDim2.fromOffset(4, 62 + below),
			Size = UDim2.new(1, -8, 0, 18),
			Parent = card,
		})
		UIKit.create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9, Parent = name })
		UIKit.label({
			Text = Format.odds(Odds.item(relicId)),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if known then colors.Text else colors.SubText,
			Position = UDim2.fromOffset(4, 82 + below),
			Size = UDim2.new(1, -8, 0, 18),
			Parent = card,
		})
		local seen = state.Mutations[relicId]
		if known and seen then
			local dots = UIKit.create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -5, 0, 5),
				Size = UDim2.fromOffset(40, 10),
				Parent = card,
			}, {
				UIKit.create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 3),
				}),
			})
			for mutationIndex, mutation in MutationConfig.Mutations do
				if seen[mutation.Id] then
					UIKit.create("Frame", {
						LayoutOrder = mutationIndex,
						Size = UDim2.fromOffset(10, 10),
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
				UIKit.skinTab(button, tab == sizeTab)
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
				Text = `{tier.Name}  {found}/{#ids}`,
				TextSize = 19,
				TextColor3 = tierColor,
				Size = UDim2.new(1, 0, 0, 26),
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
					CellSize = UDim2.fromOffset(CARD_SIZE.X, cardHeight(sizeId)),
					CellPadding = UDim2.fromOffset(6, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			for index, relicId in ids do
				relicCard(grid, relicId, index, lastState, relicKnown(relicId, sizeTab, lastState, lastSizes), sizeId)
			end
		end
	end

	local function clear(list: Instance)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function render(snapshot: any)
		order = 0
		renders.DetachAll()
		relicList = nil
		tabButtons = {}
		clear(body)
		clear(relicsBody)
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
		local rewardsTab = pageButtons.Rewards
		rewardsTab.Text = if claimable > 0 then `Rewards ({claimable})` else "Rewards"

		local discovered = 0
		for _, relicId in CodexBook.AllIds do
			if state.Discovered[relicId] then
				discovered += 1
			end
		end

		-- Relics tab: found count, size tabs, then the grid grouped by rarity.
		UIKit.label({
			LayoutOrder = 1,
			Text = `{discovered} / {#CodexBook.AllIds} found`,
			FontFace = UIKit.TitleFont,
			TextSize = 26,
			TextColor3 = colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -10, 0, 32),
			Parent = relicsBody,
		})
		local sizeTabs = { { Id = "Normal", Text = "Normal" }, { Id = "Huge", Text = "Huge" }, { Id = "Titanic", Text = "Titanic" } }
		local sizeBar, sizeButtons = UIKit.tabBar(relicsBody, sizeTabs, sizeTab, function(id)
			if sizeTab ~= id then
				sizeTab = id
				renderRelicList()
			end
		end)
		sizeBar.LayoutOrder = 2
		sizeBar.Size = UDim2.new(1, -10, 0, UIKit.TAB_HEIGHT)
		tabButtons = sizeButtons
		relicList = UIKit.create("Frame", {
			Name = "RelicList",
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = relicsBody,
		}, {
			UIKit.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		})
		renderRelicList()

		-- Rewards tab: bonuses, Claim all, milestones and titles.
		local luck, income = Codex.bonuses(CodexBook, claimed)
		UIKit.label({
			LayoutOrder = nextOrder(),
			Text = `Codex bonus: +{math.round(luck * 100)}% Luck  +{math.round(income * 100)}% CE`,
			TextSize = 20,
			TextColor3 = colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -10, 0, 30),
			Parent = body,
		})
		if claimable > 0 then
			local claimSlot = UIKit.slot(body, "ClaimAll", UDim2.new(1, -10, 0, 56), nextOrder())
			local claimAll = UIKit.button({
				Text = `Claim all ({claimable})`,
				TextSize = 22,
				Parent = claimSlot,
			}, function()
				claim("All")
			end)
			UIKit.fill(claimAll)
			UIKit.skinButton(claimAll, "Gold")
			Motion.shineLoop(claimAll, 2.2)
		end

		-- 2026-11-09: one compact card per kind (a row of stamps, one per milestone) and only the
		-- next goal spelled out, instead of a long list of near-identical rows.
		for _, kind in KIND_ORDER do
			local list = {}
			for _, milestone in CodexBook.Milestones do
				if milestone.Kind == kind then
					table.insert(list, milestone)
				end
			end
			if #list > 0 then
				milestoneTrack(KIND_HEADINGS[kind], list, state, claimed, ready)
			end
		end

		heading("Titles")
		local titles = Codex.titles(CodexBook, claimed)
		UIKit.label({
			LayoutOrder = nextOrder(),
			Text = if #titles > 0 then table.concat(titles, ", ") else "None yet.",
			TextSize = 18,
			TextWrapped = true,
			TextColor3 = if #titles > 0 then colors.Gold else colors.SubText,
			Size = UDim2.new(1, -10, 0, 40),
			Parent = body,
		})
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
		if zonesBody.Visible then
			ZonesPage.render(zonesBody)
		end
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

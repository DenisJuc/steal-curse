-- Backpack (GDD 9.2, 12.1; Slice 10): the one place for relics and items. Relics on pedestals are
-- not in it (take one back with E on its pedestal). The Relics tab is a card grid (3D render, name,
-- count, income, mutation gem, lock / favorite / floating markers) with a detail panel on the right
-- for the selected card: base and current 1-in-X odds (RollMath via Odds), income, sell value and
-- the actions: equip (best pedestal), float (one copy hovers beside you; display only), sell,
-- lock and favorite. Equip Best, Auto-Sell (the rules) and the slot count sit in the footer. The
-- header has "Sell all" (everything but locked, favorite and floating relics; tap twice to confirm)
-- and a link to the auto-sell rules. The Items tab lists potions.
-- The Shrine's "Choose" opens this menu in pick mode: tapping a card places it on that pedestal.
-- Every button sends an intent; the server answers with the fresh state.
-- Renders: only cards scrolled into view get a 3D render, from a shared cache (RelicViewport).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local SizeConfig = require(ReplicatedStorage.Shared.SizeConfig)
local Icons = require(script.Parent.Icons)
local ItemsTab = require(script.Parent.ItemsTab)
local Motion = require(script.Parent.Motion)
local Odds = require(script.Parent.Odds)
local RelicViewport = require(script.Parent.RelicViewport)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetInventory = Remotes:WaitForChild("GetInventory") :: RemoteFunction
local InventoryAction = Remotes:WaitForChild("InventoryAction") :: RemoteFunction
local ShrineAction = Remotes:WaitForChild("ShrineAction") :: RemoteEvent
local ShrineState = Remotes:WaitForChild("ShrineState") :: RemoteEvent

local InventoryPanel = {}

export type State = {
	Groups: { any },
	Count: number,
	Capacity: number,
	AutoSell: any,
	-- What "Sell all" sells right now.
	SellAll: { Count: number, Value: number }?,
}

export type Hooks = {
	OnOpenAutoSell: (State?) -> (),
	-- Pick mode finished (relic placed, pedestal emptied or Back): return to the Shrine.
	OnPickDone: () -> (),
}

local TAB_HEIGHT = 44
local SELL_ALL_WIDTH = 250
local CONFIRM_SECONDS = 4
local FOOTER_HEIGHT = 48
local SIDE_WIDTH = 270
local CELL = Vector2.new(100, 126)
local MAX_LIVE_RENDERS = 36
local RENDER_SHARE = 0.4
local NAME_HEIGHT = 30
local BIG_BUTTON_HEIGHT = 56
local TOGGLE_HEIGHT = 42
local ACTIONS_HEIGHT = BIG_BUTTON_HEIGHT + 8 + TOGGLE_HEIGHT
local REFRESH_SECONDS = 1
local LAYOUT_SETTLE_SECONDS = 0.05
local SELECT_HINT = "Tap a card to see it here."

local function relicColor(relicId: string, mutation: string?): Color3
	if mutation then
		return UIKit.mutationColor(mutation)
	end
	local relic = RelicConfig.ById[relicId]
	return if relic then UIKit.tierColor(relic.Tier) else UIKit.Colors.Text
end

-- Plain text for a RichText label.
local function escape(text: string): string
	return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

local function groupKey(group: any): string
	local size = if group.Size == "Huge" or group.Size == "Titanic" then group.Size else ""
	return `{group.Id}|{group.Mutation or ""}|{size}`
end

local function groupSized(group: any): boolean
	return group.Size == "Huge" or group.Size == "Titanic"
end

local function marker(parent: Instance, text: string, color: Color3, anchor: Vector2, position: UDim2)
	local badge = UIKit.label({
		Text = text,
		TextSize = 12,
		TextColor3 = UIKit.Colors.Panel,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 3,
		Parent = parent,
	})
	UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	return badge
end

function InventoryPanel.Start(
	screen: ScreenGui,
	hooks: Hooks
): { Toggle: () -> (), Pick: (number) -> (), SetVisible: (boolean) -> (), GetState: () -> State? }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local state: State? = nil
	local selectedKey: string? = nil
	-- The card just tapped gets a bounce when the grid is rebuilt.
	local justSelected: string? = nil
	local pickSlot: number? = nil
	local renders = RelicViewport.cache(MAX_LIVE_RENDERS)

	local panel, content =
		UIKit.modal(screen, "RelicsMenu", "BACKPACK", colors.Gold, Vector2.new(860, 620), "Backpack")

	-- Tabs.
	local tabs = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
		Parent = content,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})
	local relicsPage = UIKit.create("Frame", {
		Name = "RelicsPage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TAB_HEIGHT + 6),
		Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 6)),
		Parent = content,
	})
	local itemsPage = UIKit.create("Frame", {
		Name = "ItemsPage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TAB_HEIGHT + 6),
		Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 6)),
		Visible = false,
		Parent = content,
	})
	local items = ItemsTab.Build(itemsPage)

	local tabButtons: { [string]: TextButton } = {}
	local currentTab = "Relics"
	local function showTab(name: string)
		currentTab = name
		relicsPage.Visible = name == "Relics"
		itemsPage.Visible = name == "Items"
		for tabName, button in tabButtons do
			UIKit.skinTab(button, tabName == name)
		end
		if name == "Items" then
			items.Refresh()
		end
	end
	for order, name in { "Relics", "Items" } do
		tabButtons[name] = UIKit.button({
			Name = `{name}Tab`,
			Text = name,
			TextSize = 16,
			LayoutOrder = order,
			Size = UDim2.fromOffset(110, TAB_HEIGHT),
			Parent = tabs,
		}, function()
			if pickSlot == nil then
				showTab(name)
			end
		end)
	end
	for tabName, button in tabButtons do
		UIKit.skinTab(button, tabName == currentTab)
	end

	local send: (string, ...any) -> ()

	-- Header right: "Sell all" (tap, then tap again within CONFIRM_SECONDS) and a link to the
	-- auto-sell rules.
	local sellAll: TextButton
	local confirmUntil = 0
	local refreshSellAll: () -> ()
	sellAll = UIKit.button({
		Name = "SellAll",
		Text = "Sell all",
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(SELL_ALL_WIDTH, TAB_HEIGHT),
		Parent = content,
	}, function()
		if not (state and state.SellAll and state.SellAll.Count > 0) then
			return
		end
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Motion.markCoinSource(sellAll)
			send("SellAll")
		else
			confirmUntil = os.clock() + CONFIRM_SECONDS
			Motion.punch(sellAll, 2)
			task.delay(CONFIRM_SECONDS, function()
				if confirmUntil ~= 0 and os.clock() >= confirmUntil then
					confirmUntil = 0
					refreshSellAll()
				end
			end)
		end
		refreshSellAll()
	end)
	-- Footer's Auto-sell button (built below) shows the rule; refreshSellAll keeps it current.
	local refreshAutoSellButton: () -> () = function() end

	function refreshSellAll()
		local preview = state and state.SellAll
		local count = if preview then preview.Count else 0
		local confirming = count > 0 and os.clock() < confirmUntil
		if confirming then
			sellAll.Text = `Tap again: sell {count} (+{Format.ce(preview.Value)})`
		elseif count > 0 then
			sellAll.Text = `Sell all {count} (+{Format.ce(preview.Value)})`
		else
			sellAll.Text = "Sell all"
		end
		UIKit.skinButton(sellAll, if confirming then "Danger" elseif count > 0 then "Sell" else "Dark")
		sellAll.TextColor3 = if count > 0 then colors.Text else colors.SubText
		Motion.setDisabled(sellAll, count == 0)
		refreshAutoSellButton()
	end

	-- Relics page: grid (left), detail (right), footer (under the grid).
	local gridArea = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(SIDE_WIDTH + 8), 1, -(FOOTER_HEIGHT + 6)),
		Parent = relicsPage,
	})
	local grid = UIKit.create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = gridArea,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(CELL.X, CELL.Y),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIKit.create("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	})
	local emptyLabel = UIKit.label({
		Text = "No relics yet. Your ROLL button finds one every few seconds.",
		TextColor3 = colors.SubText,
		TextSize = 14,
		TextWrapped = true,
		Size = UDim2.new(1, -10, 0, 40),
		Visible = false,
		Parent = gridArea,
	})

	local footer = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -(SIDE_WIDTH + 8), 0, FOOTER_HEIGHT),
		Parent = relicsPage,
	})
	local countLabel = UIKit.label({
		Text = "",
		TextSize = 18,
		TextColor3 = colors.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(0.4, -4, 1, 0),
		Parent = footer,
	})
	local countPadding = UIKit.create("UIPadding", { Parent = countLabel })
	local fullIcon = Icons.image(countLabel, "Warning", 20)
	if fullIcon then
		fullIcon.AnchorPoint = Vector2.new(0, 0.5)
		fullIcon.Position = UDim2.new(0, -24, 0.5, 0)
		fullIcon.Visible = false
	end
	local equipBest = UIKit.button({
		Name = "EquipBest",
		Text = "Equip Best",
		TextSize = 20,
		Position = UDim2.fromScale(0.4, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Parent = footer,
	}, function()
		ShrineAction:FireServer("EquipBest")
	end)
	UIKit.skinButton(equipBest, "Equip")
	-- Auto-sell: name on top, the current rule under it in its rarity colour ("Off" grey).
	local autoSell = UIKit.button({
		Name = "AutoSell",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Parent = footer,
	}, function()
		hooks.OnOpenAutoSell(state)
	end)
	UIKit.skinButton(autoSell, "Dark")
	UIKit.label({
		Name = "Title",
		Text = "Auto-sell",
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.08),
		Size = UDim2.fromScale(1, 0.46),
		Parent = autoSell,
	})
	local autoSellState = UIKit.label({
		Name = "State",
		Text = "Off",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = colors.SubText,
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.42),
		Parent = autoSell,
	})
	function refreshAutoSellButton()
		local highestId
		for _, tier in RarityConfig.Tiers do
			local mode = state and state.AutoSell and state.AutoSell.Tiers[tier.Id]
			if mode == "SellDuplicates" or mode == "SellAll" then
				highestId = tier.Id
			end
		end
		local tier = highestId and RarityConfig.Get(highestId)
		autoSellState.Text = if tier then `Up to {tier.Name}` else "Off"
		autoSellState.TextColor3 = if highestId then UIKit.tierColor(highestId) else colors.SubText
		local stroke = autoSell:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if highestId then colors.Coral else colors.Trim
			stroke.Transparency = if highestId then 0.1 else 0.55
		end
	end
	refreshAutoSellButton()

	-- Pick mode reuses the footer: which pedestal, empty it, or go back.
	local function endPick()
		pickSlot = nil
		hooks.OnPickDone()
	end
	local emptyPedestal = UIKit.button({
		Text = "Empty pedestal",
		TextSize = 15,
		Position = UDim2.fromScale(0.4, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Visible = false,
		Parent = footer,
	}, function()
		if pickSlot then
			ShrineAction:FireServer("Clear", pickSlot)
		end
		endPick()
	end)
	local backButton = UIKit.button({
		Text = "Back",
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Visible = false,
		Parent = footer,
	}, endPick)
	UIKit.skinButton(emptyPedestal, "Dark")
	UIKit.skinButton(backButton, "Dark")

	-- Detail panel: big render, name in its rarity color, big income, one short stats line, then
	-- one big Sell button over a row of small toggles (Lock, Favorite, Float, Sell all).
	local side = UIKit.create("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, SIDE_WIDTH, 1, 0),
		BackgroundColor3 = colors.Card,
		Parent = relicsPage,
	}, { UIKit.corner(10), UIKit.padding(8) })
	local sideStroke = UIKit.stroke(colors.Gold, 2, 0.4)
	sideStroke.Parent = side
	UIKit.skinCard(side)
	local detailView = RelicViewport.new("SenzoBean", {
		Name = "DetailRender",
		Size = UDim2.fromScale(1, RENDER_SHARE),
		Visible = false,
	})
	detailView.Parent = side
	local detailName = UIKit.label({
		Name = "DetailName",
		TextSize = 18,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, RENDER_SHARE, 4),
		Size = UDim2.new(1, 0, 0, NAME_HEIGHT),
		Text = SELECT_HINT,
		TextColor3 = colors.SubText,
		Parent = side,
	})
	UIKit.create("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 14, Parent = detailName })
	local detailIncome, detailIncomeLabel = UIKit.coinValue(side, 30, 30, colors.Gold)
	detailIncome.Name = "DetailIncome"
	detailIncome.AnchorPoint = Vector2.new(0.5, 0)
	detailIncome.Position = UDim2.new(0.5, 0, RENDER_SHARE, NAME_HEIGHT + 8)
	detailIncome.Visible = false
	local detailInfo = UIKit.label({
		Name = "DetailInfo",
		TextSize = 17,
		TextWrapped = true,
		TextColor3 = colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		Position = UDim2.new(0, 0, RENDER_SHARE, NAME_HEIGHT + 48),
		Size = UDim2.new(1, 0, 1 - RENDER_SHARE, -(NAME_HEIGHT + 48 + ACTIONS_HEIGHT + 4)),
		Text = "",
		Parent = side,
	})
	local actions = UIKit.create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, ACTIONS_HEIGHT),
		Visible = false,
		Parent = side,
	})
	local toggles = UIKit.create("Frame", {
		Name = "Toggles",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, TOGGLE_HEIGHT),
		Parent = actions,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	local render: (State) -> ()

	local function selectedGroup(): any?
		if not state or not selectedKey then
			return nil
		end
		for _, group in state.Groups do
			if groupKey(group) == selectedKey then
				return group
			end
		end
		return nil
	end

	local statusText = ""
	function send(action: string, ...: any)
		local args = table.pack(...)
		task.spawn(function()
			local ok, result = pcall(function()
				return InventoryAction:InvokeServer(action, table.unpack(args, 1, args.n))
			end)
			if ok and type(result) == "table" and result.State then
				statusText = result.Message or ""
				render(result.State)
			end
		end)
	end

	local function onSelected(onClick: (group: any) -> ()): () -> ()
		return function()
			local group = selectedGroup()
			if group then
				onClick(group)
			end
		end
	end
	-- Placing lives in the Pedestals menu (tap a pedestal's relic); the backpack only sells.
	local sellOneButton: TextButton
	sellOneButton = UIKit.button({
		Name = "Sell",
		Text = "Sell",
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, BIG_BUTTON_HEIGHT),
		Parent = actions,
	}, onSelected(function(group)
		Motion.markCoinSource(sellOneButton)
		send("Sell", group.Id, group.Mutation, 1, group.Size)
	end))
	-- Small square toggles: an icon when there is one, otherwise a short word.
	local function toggleButton(order: number, iconKey: string?, text: string, onClick: (group: any) -> ()): TextButton
		local instance = UIKit.button({
			Name = text,
			LayoutOrder = order,
			Text = "",
			TextSize = 16,
			Size = UDim2.fromOffset(if iconKey then TOGGLE_HEIGHT else 64, TOGGLE_HEIGHT),
			Parent = toggles,
		}, onSelected(onClick))
		local icon = if iconKey then Icons.image(instance, iconKey, 28) else nil
		if icon then
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
		else
			instance.Text = text
		end
		return instance
	end
	local lockButton = toggleButton(1, "Lock", "Lock", function(group)
		send("Lock", group.Id, group.Mutation, group.Locked < group.Count, group.Size)
	end)
	local favButton = toggleButton(2, "Favorite", "Fav", function(group)
		send("Favorite", group.Id, group.Mutation, not group.Favorite, group.Size)
	end)
	local floatButton = toggleButton(3, nil, "Float", function(group)
		send("Float", group.Id, group.Mutation, not group.Floating, group.Size)
	end)
	local sellAllButton: TextButton
	sellAllButton = toggleButton(4, nil, "Sell all", function(group)
		Motion.markCoinSource(sellAllButton)
		send("Sell", group.Id, group.Mutation, "All", group.Size)
	end)
	sellAllButton.Size = UDim2.fromOffset(80, TOGGLE_HEIGHT)

	-- Toggles that are on light up gold; unusable ones go dim.
	local function styleToggle(instance: TextButton, on: boolean, usable: boolean?)
		local enabled = usable ~= false
		UIKit.skinButton(instance, if on then "Gold" else "Dark")
		instance.TextColor3 = if on then colors.Panel elseif enabled then colors.Text else colors.SubText
		Motion.setDisabled(instance, not enabled)
	end

	local function refreshDetail()
		local inPick = pickSlot ~= nil
		local group = selectedGroup()
		if inPick or not group then
			actions.Visible = false
			detailView.Visible = false
			detailIncome.Visible = false
			detailName.Text = if inPick then `Pick a relic for pedestal {pickSlot}` else SELECT_HINT
			detailName.TextColor3 = if inPick then colors.Gold else colors.SubText
			detailInfo.Text = if inPick
				then "Tap a card to place it."
				elseif statusText ~= "" then escape(statusText)
				else ""
			sideStroke.Color = colors.Gold
			return
		end
		actions.Visible = true
		detailIncome.Visible = true
		local color = relicColor(group.Id, group.Mutation)
		local sizeId = SizeConfig.normalize(group.Size)
		if detailView:GetAttribute("RelicId") ~= group.Id or detailView:GetAttribute("Size") ~= (sizeId or "") then
			RelicViewport.show(detailView, group.Id, sizeId)
		end
		detailView.Visible = true
		sideStroke.Color = if sizeId == "Titanic" then colors.Gold elseif sizeId then Color3.fromRGB(160, 210, 255) else color
		detailName.Text = Odds.displayName(group.Id, group.Mutation, sizeId)
		detailName.TextColor3 = sideStroke.Color
		detailIncomeLabel.Text = `+{Format.rate(group.IncomePerSec)}`
		local relic = RelicConfig.ById[group.Id]
		local tier = relic and RarityConfig.Get(relic.Tier)
		local yours = RollMath.comboProbability(Odds.current(), group.Id, group.Mutation)
		-- One short line: rarity (size), how many, your odds.
		local parts = { if tier then tier.Name else "?" }
		if sizeId then
			table.insert(parts, `{SizeConfig.Label[sizeId]} x{SizeConfig.incomeMult(sizeId)}`)
		end
		table.insert(parts, `x{group.Count}`)
		table.insert(parts, Format.odds(yours))
		local lines = { table.concat(parts, "  ·  ") }
		if statusText ~= "" then
			table.insert(lines, `<font color="#F0C268">{escape(statusText)}</font>`)
		end
		detailInfo.Text = table.concat(lines, "\n")

		local canSell = group.Sellable > 0
		sellOneButton.Text = if canSell then `Sell +{Format.number(group.SellValue)}` else "Kept"
		UIKit.skinButton(sellOneButton, if canSell then "Sell" else "Dark")
		sellOneButton.TextColor3 = if canSell then colors.Text else colors.SubText
		Motion.setDisabled(sellOneButton, not canSell)
		styleToggle(lockButton, group.Locked >= group.Count)
		styleToggle(favButton, group.Favorite)
		styleToggle(floatButton, group.Floating)
		sellAllButton.Visible = group.Sellable > 1
		styleToggle(sellAllButton, false, canSell)
		if canSell then
			UIKit.skinButton(sellAllButton, "Sell")
		end
	end

	local function onCardClicked(group: any)
		local slot = pickSlot
		if slot then
			ShrineAction:FireServer("DisplayGroup", slot, group.Id, group.Mutation, group.Size)
			endPick()
			return
		end
		selectedKey = groupKey(group)
		justSelected = selectedKey
		statusText = ""
		if state then
			render(state)
		end
	end

	-- Cards waiting for a render: [card] = group. Filled in as they scroll into view.
	local cards: { [Frame]: any } = {}
	local renderedAt = 0
	local function attachVisibleRenders()
		local top = grid.AbsolutePosition.Y
		local bottom = top + grid.AbsoluteSize.Y
		for card, group in cards do
			local y = card.AbsolutePosition.Y
			local slot = card:FindFirstChild("RenderSlot")
			if slot and y + card.AbsoluteSize.Y >= top - CELL.Y and y <= bottom + CELL.Y then
				local sizeId = SizeConfig.normalize(group.Size)
				local viewport = renders.Get(groupKey(group), group.Id, sizeId)
				viewport.Parent = slot
				cards[card] = nil
			end
		end
	end
	local function makeCard(index: number, group: any)
		local selected = pickSlot == nil and groupKey(group) == selectedKey
		local color = relicColor(group.Id, group.Mutation)
		local sizeId = SizeConfig.normalize(group.Size)
		local strokeColor = if sizeId == "Titanic"
			then colors.Gold
			elseif sizeId
			then Color3.fromRGB(160, 210, 255)
			else color
		local cell = UIKit.slot(grid, "Cell", UDim2.new(), index)
		local card = UIKit.create("TextButton", {
			Name = "Card",
			Text = "",
			ClipsDescendants = true,
			Parent = cell,
		}, {
			UIKit.corner(10),
		})
		-- Rarity card like the Codex and Shop (UI pass 2026-11-09): tinted by the relic's colour,
		-- shine on Legendary and up. Selected cards keep the thick gold edge; Huge/Titanic keep
		-- their size-coloured edge.
		local relicInfo = RelicConfig.ById[group.Id]
		local glow = UIKit.skinRarityCard(card, color, false, relicInfo ~= nil and UIKit.tierShines(relicInfo.Tier))
		if glow then
			glow.Position = UDim2.new(0.5, 0, 0, 39)
			glow.Size = UDim2.fromOffset(72, 72)
		end
		local edge = card:FindFirstChildOfClass("UIStroke")
		if edge and (selected or sizeId) then
			edge.Color = if selected then colors.Gold else strokeColor
			edge.Thickness = 3
			edge.Transparency = 0
		end
		UIKit.fill(card)
		Motion.button(card)
		card:SetAttribute("PopIn", true)
		if selected and groupKey(group) == justSelected then
			justSelected = nil
			Motion.punch(card, 2)
		end
		card.Activated:Connect(function()
			onCardClicked(group)
		end)
		UIKit.create("Frame", {
			Name = "RenderSlot",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 70),
			Parent = card,
		})
		local nameLabel = UIKit.label({
			Name = "RelicName",
			Text = Odds.displayName(group.Id, group.Mutation, sizeId),
			TextSize = 16,
			-- One line that shrinks to fit, never cut off with "...".
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			-- White on the tinted card; Huge/Titanic names keep their size colour.
			TextColor3 = if sizeId then strokeColor else colors.Text,
			TextStrokeTransparency = 0.55,
			Position = UDim2.fromOffset(3, 78),
			Size = UDim2.new(1, -6, 0, 20),
			Parent = card,
		})
		UIKit.create("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 9, Parent = nameLabel })
		UIKit.label({
			Name = "Income",
			Text = `+{Format.rate(group.IncomePerSec)}`,
			TextSize = 16,
			TextColor3 = colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 5, 1, -19),
			Size = UDim2.new(0.6, 0, 0, 16),
			Parent = card,
		})
		UIKit.label({
			Name = "Count",
			Text = `x{group.Count}`,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 1, -19),
			Size = UDim2.new(0.4, 0, 0, 16),
			Parent = card,
		})
		local leftBadge = 4
		if sizeId then
			marker(
				card,
				if sizeId == "Titanic" then "T" else "H",
				if sizeId == "Titanic" then colors.Gold else Color3.fromRGB(160, 210, 255),
				Vector2.new(0, 0),
				UDim2.fromOffset(leftBadge, 4)
			)
			leftBadge += 22
		end
		if group.Mutation then
			marker(card, string.sub(group.Mutation, 1, 1), color, Vector2.new(0, 0), UDim2.fromOffset(leftBadge, 4))
		end
		local right = 4
		local function corner(text: string, badgeColor: Color3, iconKey: string?)
			local image = if iconKey then Icons.image(card, iconKey, 22) else nil
			if image then
				image.AnchorPoint = Vector2.new(1, 0)
				image.Position = UDim2.new(1, -right + 1, 0, 3)
				image.ZIndex = 3
			else
				marker(card, text, badgeColor, Vector2.new(1, 0), UDim2.new(1, -right, 0, 4))
			end
			right += 22
		end
		if group.Floating then
			corner("F", colors.Accent)
		end
		if group.Locked > 0 then
			corner("L", colors.SubText, "Lock")
		end
		if group.Favorite then
			corner("*", colors.Red, "Favorite")
		end
		cards[card] = group
	end

	function render(newState: State)
		state = newState
		renderedAt = os.clock()
		renders.DetachAll()
		table.clear(cards)
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local over = newState.Count - newState.Capacity
		local full = over >= 0
		countLabel.Text = `{if full then "FULL " else ""}{newState.Count} / {newState.Capacity}{if over > 0
			then ` (+{over})`
			else ""}`
		countLabel.TextColor3 = if full then colors.Red else colors.Gold
		if fullIcon then
			fullIcon.Visible = full
			countPadding.PaddingLeft = UDim.new(0, if full then 24 else 0)
		end
		refreshSellAll()
		if not selectedGroup() then
			selectedKey = nil
		end
		refreshDetail()
		emptyLabel.Visible = #newState.Groups == 0
		for index, group in newState.Groups do
			makeCard(index, group)
		end
	end

	local function load()
		task.spawn(function()
			local ok, result = pcall(function()
				return GetInventory:InvokeServer()
			end)
			if ok and type(result) == "table" and panel.Visible then
				render(result)
			end
		end)
	end

	local function setMode(slot: number?)
		pickSlot = slot
		countLabel.Visible = slot == nil
		equipBest.Visible = slot == nil
		autoSell.Visible = slot == nil
		sellAll.Visible = slot == nil
		emptyPedestal.Visible = slot ~= nil
		backButton.Visible = slot ~= nil
		if slot then
			showTab("Relics")
		end
		refreshDetail()
	end

	-- Layout positions settle a frame after a rebuild, so pending renders are checked each frame.
	RunService.RenderStepped:Connect(function(dt)
		if not panel.Visible then
			return
		end
		if detailView.Visible then
			RelicViewport.spin(detailView, dt * 0.8)
		end
		if next(cards) ~= nil and relicsPage.Visible and os.clock() - renderedAt > LAYOUT_SETTLE_SECONDS then
			attachVisibleRenders()
		end
	end)

	-- New finds and pedestal changes alter the grid while it's open; refresh at most once per REFRESH_SECONDS.
	local refreshQueued = false
	local function queueRefresh()
		if not panel.Visible or refreshQueued or currentTab ~= "Relics" then
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
	player:GetAttributeChangedSignal("InventoryCount"):Connect(queueRefresh)
	ShrineState.OnClientEvent:Connect(function()
		if panel.Visible then
			load()
		end
	end)

	return {
		Toggle = function()
			if UIKit.toggle(panel) then
				setMode(nil)
				load()
			end
		end,
		Pick = function(slot: number)
			setMode(slot)
			UIKit.show(panel)
			load()
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
				pickSlot = nil
			end
		end,
		GetState = function()
			return state
		end,
	}
end

return InventoryPanel

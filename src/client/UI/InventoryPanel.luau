-- Backpack (GDD 9.2, 12.1; Slice 10): the one place for relics and items. The Relics tab is a card
-- grid (3D render, name, count, income, mutation gem, lock / favorite / pedestal markers) with a
-- detail panel on the right for the selected card: base and current 1-in-X odds (RollMath via
-- Odds), income, sell value and the actions: equip/unequip (pedestal), sell, lock, favorite and
-- carry (for show: floating, then in hand, then put away; display only). Equip Best, Auto-Sell
-- and the held count sit in the footer. The Items tab lists potions.
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
	Carry: { Key: string, Mode: string }?,
}

export type Hooks = {
	OnOpenAutoSell: (State?) -> (),
	-- Pick mode finished (relic placed, pedestal emptied or Back): return to the Shrine.
	OnPickDone: () -> (),
}

local TAB_HEIGHT = 32
local FOOTER_HEIGHT = 36
local SIDE_WIDTH = 230
local CELL = Vector2.new(100, 126)
local MAX_LIVE_RENDERS = 36
local RENDER_SHARE = 0.32
local NAME_HEIGHT = 38
local ACTIONS_HEIGHT = 64
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
	return `{group.Id}|{group.Mutation or ""}`
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

	local panel, content = UIKit.modal(screen, "RelicsMenu", "BACKPACK", colors.Gold, Vector2.new(860, 620))

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
			UIKit.skinButton(button, if tabName == name then "Gold" else "Dark")
			button.TextColor3 = if tabName == name then colors.Panel else colors.Text
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
		TextSize = 15,
		TextColor3 = colors.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(0.4, -4, 1, 0),
		Parent = footer,
	})
	local equipBest = UIKit.button({
		Name = "EquipBest",
		Text = "Equip Best",
		TextSize = 15,
		Position = UDim2.fromScale(0.4, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Parent = footer,
	}, function()
		ShrineAction:FireServer("EquipBest")
	end)
	UIKit.skinButton(equipBest, "Gold")
	local autoSell = UIKit.button({
		Text = "Auto-Sell",
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Parent = footer,
	}, function()
		hooks.OnOpenAutoSell(state)
	end)
	UIKit.skinButton(autoSell, "Dark")

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

	-- Detail panel.
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
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, RENDER_SHARE, 2),
		Size = UDim2.new(1, 0, 0, NAME_HEIGHT),
		Text = SELECT_HINT,
		TextColor3 = colors.SubText,
		Parent = side,
	})
	local infoScroll = UIKit.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, RENDER_SHARE, NAME_HEIGHT + 4),
		Size = UDim2.new(1, 0, 1 - RENDER_SHARE, -(NAME_HEIGHT + 4 + ACTIONS_HEIGHT + 4)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		Parent = side,
	})
	local detailInfo = UIKit.label({
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = colors.SubText,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -6, 0, 0),
		Text = "",
		Parent = infoScroll,
	})
	local actions = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, ACTIONS_HEIGHT),
		Parent = side,
	}, {
		UIKit.create("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -4, 0, 30),
			CellPadding = UDim2.fromOffset(5, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
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
	local function send(action: string, ...: any)
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

	local function actionButton(order: number, onClick: (group: any) -> ()): TextButton
		local instance = UIKit.button({
			LayoutOrder = order,
			TextScaled = true,
			Parent = actions,
		}, function()
			local group = selectedGroup()
			if group then
				onClick(group)
			end
		end)
		UIKit.create("UITextSizeConstraint", { MaxTextSize = 14, Parent = instance })
		return instance
	end
	local equipButton = actionButton(1, function(group)
		ShrineAction:FireServer(if group.Displayed > 0 then "UnequipGroup" else "EquipGroup", group.Id, group.Mutation)
	end)
	local carryButton
	local function carryMode(group: any): string?
		if state and state.Carry and state.Carry.Key == groupKey(group) then
			return state.Carry.Mode
		end
		return nil
	end
	carryButton = actionButton(2, function(group)
		local mode = carryMode(group)
		local nextMode = if mode == nil then "Float" elseif mode == "Float" then "Hand" else "None"
		send("Carry", group.Id, group.Mutation, nextMode)
	end)
	local sellOneButton, sellAllButton
	sellOneButton = actionButton(3, function(group)
		Motion.markCoinSource(sellOneButton)
		send("Sell", group.Id, group.Mutation, 1)
	end)
	sellAllButton = actionButton(4, function(group)
		Motion.markCoinSource(sellAllButton)
		send("Sell", group.Id, group.Mutation, "All")
	end)
	local lockButton = actionButton(5, function(group)
		send("Lock", group.Id, group.Mutation, group.Locked < group.Count)
	end)
	local favButton = actionButton(6, function(group)
		send("Favorite", group.Id, group.Mutation, not group.Favorite)
	end)

	local function styleAction(instance: TextButton, text: string, enabled: boolean, color: Color3?)
		instance.Text = text
		local kind = if not enabled or color == colors.Panel then "Dark" elseif color == colors.Gold then "Gold" else "Primary"
		UIKit.skinButton(instance, kind)
		instance.TextColor3 = if enabled then (if color == colors.Gold then colors.Panel else colors.Text) else colors.SubText
		Motion.setDisabled(instance, not enabled)
	end

	local function refreshDetail()
		local inPick = pickSlot ~= nil
		actions.Visible = not inPick
		local group = selectedGroup()
		if inPick then
			detailView.Visible = false
			detailName.Text = `Pick a relic for pedestal {pickSlot}`
			detailName.TextColor3 = colors.Gold
			detailInfo.Text = "Tap a card to place it. Favorites first, then best income."
			sideStroke.Color = colors.Gold
			return
		end
		if not group then
			detailView.Visible = false
			detailName.Text = SELECT_HINT
			detailName.TextColor3 = colors.SubText
			detailInfo.Text = if statusText ~= "" then escape(statusText) else "Favorite: never auto-sold. Lock: can't be sold."
			sideStroke.Color = colors.Gold
			for _, button in { equipButton, carryButton, sellOneButton, sellAllButton, lockButton, favButton } do
				styleAction(button, button.Text, false)
			end
			return
		end
		local color = relicColor(group.Id, group.Mutation)
		if detailView:GetAttribute("RelicId") ~= group.Id then
			RelicViewport.show(detailView, group.Id)
		end
		detailView.Visible = true
		sideStroke.Color = color
		detailName.Text = `{if group.Favorite then "* " else ""}{Odds.displayName(group.Id, group.Mutation)}`
		detailName.TextColor3 = color
		local relic = RelicConfig.ById[group.Id]
		local tier = relic and RarityConfig.Get(relic.Tier)
		local yours = RollMath.comboProbability(Odds.current(), group.Id, group.Mutation)
		local lines = {
			`<b>{if tier then tier.Name else "?"}</b>{if group.Mutation then `  |  {group.Mutation}` else ""}`,
			`Owned x{group.Count}{if group.Displayed > 0 then `  |  {group.Displayed} on pedestal` else ""}{if group.Locked > 0
				then `  |  {group.Locked} locked`
				else ""}`,
			`Income +{Format.number(group.IncomePerMin)} CE/min`,
			`Sells for {Format.number(group.SellValue)} CE`,
			`Base {Format.odds(Odds.baseItem(group.Id))}  |  Yours {Format.odds(yours)}`,
		}
		if relic and relic.Description then
			table.insert(lines, `<i>{escape(relic.Description)}</i>`)
		end
		if statusText ~= "" then
			table.insert(lines, escape(statusText))
		end
		detailInfo.Text = table.concat(lines, "\n")

		local carried = carryMode(group)
		local equipped = group.Displayed > 0
		local allLocked = group.Locked >= group.Count
		styleAction(equipButton, if equipped then "Unequip" else "Equip", true, if equipped then colors.Gold else nil)
		styleAction(
			carryButton,
			if carried == nil then "Carry" elseif carried == "Float" then "Hold" else "Put away",
			true,
			if carried then colors.Gold else colors.Panel
		)
		styleAction(sellOneButton, "Sell 1", group.Sellable > 0)
		styleAction(sellAllButton, "Sell all", group.Sellable > 0)
		styleAction(lockButton, if allLocked then "Unlock" else "Lock", true, if allLocked then colors.Gold else colors.Panel)
		styleAction(favButton, if group.Favorite then "Unfavorite" else "Favorite", true, if group.Favorite
			then colors.Gold
			else colors.Panel)
	end

	local function onCardClicked(group: any)
		local slot = pickSlot
		if slot then
			if group.Count - group.Displayed <= 0 then
				detailInfo.Text = "Every copy of that relic is already on a pedestal."
				return
			end
			ShrineAction:FireServer("DisplayGroup", slot, group.Id, group.Mutation)
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
				local viewport = renders.Get(groupKey(group), group.Id)
				viewport.Parent = slot
				cards[card] = nil
			end
		end
	end
	local function makeCard(index: number, group: any)
		local spare = group.Count - group.Displayed
		local dimmed = pickSlot ~= nil and spare <= 0
		local selected = pickSlot == nil and groupKey(group) == selectedKey
		local color = relicColor(group.Id, group.Mutation)
		local cell = UIKit.slot(grid, "Cell", UDim2.new(), index)
		local card = UIKit.create("TextButton", {
			Name = "Card",
			Text = "",
			BackgroundColor3 = colors.Card,
			BackgroundTransparency = if dimmed then 0.5 else 0,
			Parent = cell,
		}, {
			UIKit.corner(10),
			UIKit.stroke(if selected then colors.Gold else color, if selected then 3 else 2, if selected then 0 else 0.35),
			UIKit.create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(colors.Card, color:Lerp(colors.Card, 0.7)),
			}),
		})
		UIKit.fill(card)
		Motion.button(card)
		Motion.setDisabled(card, dimmed)
		card:SetAttribute("PopIn", true)
		if selected and groupKey(group) == justSelected then
			justSelected = nil
			Motion.punch(card, 2)
		end
		card.Activated:Connect(function()
			if not dimmed then
				onCardClicked(group)
			end
		end)
		UIKit.create("Frame", {
			Name = "RenderSlot",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 70),
			Parent = card,
		})
		UIKit.label({
			Name = "RelicName",
			Text = Odds.displayName(group.Id, group.Mutation),
			TextSize = 12,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = color,
			Position = UDim2.fromOffset(3, 74),
			Size = UDim2.new(1, -6, 0, 28),
			Parent = card,
		})
		UIKit.label({
			Name = "Income",
			Text = `+{Format.number(group.IncomePerMin)}/m`,
			TextSize = 11,
			TextColor3 = colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, 5, 1, -19),
			Size = UDim2.new(0.6, 0, 0, 16),
			Parent = card,
		})
		UIKit.label({
			Name = "Count",
			Text = `x{group.Count}`,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 1, -19),
			Size = UDim2.new(0.4, 0, 0, 16),
			Parent = card,
		})
		if group.Mutation then
			marker(card, string.sub(group.Mutation, 1, 1), color, Vector2.new(0, 0), UDim2.fromOffset(4, 4))
		end
		local right = 4
		local function corner(text: string, badgeColor: Color3)
			marker(card, text, badgeColor, Vector2.new(1, 0), UDim2.new(1, -right, 0, 4))
			right += 22
		end
		if group.Displayed > 0 then
			corner("P", colors.Gold)
		end
		if group.Locked > 0 then
			corner("L", colors.SubText)
		end
		if group.Favorite then
			corner("*", colors.Red)
		end
		if carryMode(group) then
			corner("C", colors.Accent)
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

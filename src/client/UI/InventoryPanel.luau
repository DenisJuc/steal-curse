-- Relics menu (GDD 9.2, 12.1): the one place for relics. Held relics grouped by relic + mutation,
-- with base and current 1-in-X odds (RollMath via Odds). Tap a relic to select it; the action bar
-- equips/unequips it (pedestal), sells, locks or favorites it. Equip Best and Auto-Sell Rules sit in
-- the header. The Shrine's "Choose" opens this menu in pick mode: tapping a relic places it on
-- that pedestal. Every button sends an intent; the server answers with the fresh state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RollMath = require(ReplicatedStorage.Shared.RollMath)
local Odds = require(script.Parent.Odds)
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
}

export type Hooks = {
	OnOpenAutoSell: (State?) -> (),
	-- Pick mode finished (relic placed, pedestal emptied or Back): return to the Shrine.
	OnPickDone: () -> (),
}

local ROW_HEIGHT = 64
local HEADER_HEIGHT = 34
local LIST_TOP = 62
local BAR_HEIGHT = 40
local REFRESH_SECONDS = 1
local SELECT_HINT = "Tap a relic to select it. Favorite: never auto-sold. Lock: can't be sold."

local function relicColor(relicId: string, mutation: string?): Color3
	if mutation then
		return UIKit.mutationColor(mutation)
	end
	local relic = RelicConfig.ById[relicId]
	return if relic then UIKit.tierColor(relic.Tier) else UIKit.Colors.Text
end

local function groupKey(group: any): string
	return `{group.Id}|{group.Mutation or ""}`
end

function InventoryPanel.Start(
	screen: ScreenGui,
	hooks: Hooks
): { Toggle: () -> (), Pick: (number) -> (), SetVisible: (boolean) -> (), GetState: () -> State? }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local state: State? = nil
	local selectedKey: string? = nil
	local pickSlot: number? = nil

	local panel, content = UIKit.modal(screen, "RelicsMenu", "RELICS", colors.Gold, Vector2.new(560, 620))

	-- Normal header: count, Equip Best, Auto-Sell Rules.
	local header = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		Parent = content,
	})
	local countLabel = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(0.4, 1),
		Parent = header,
	})
	UIKit.button({
		Name = "EquipBest",
		Text = "Equip Best",
		Position = UDim2.fromScale(0.4, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Parent = header,
	}, function()
		ShrineAction:FireServer("EquipBest")
	end)
	UIKit.button({
		Text = "Auto-Sell Rules",
		BackgroundColor3 = colors.Card,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Parent = header,
	}, function()
		hooks.OnOpenAutoSell(state)
	end)

	-- Pick-mode header: which pedestal, empty it, or go back.
	local pickHeader = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		Visible = false,
		Parent = content,
	})
	local pickLabel = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(0.5, 1),
		Parent = pickHeader,
	})
	local function endPick()
		pickSlot = nil
		hooks.OnPickDone()
	end
	UIKit.button({
		Text = "Empty pedestal",
		BackgroundColor3 = colors.Card,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.3, -4, 1, 0),
		Parent = pickHeader,
	}, function()
		if pickSlot then
			ShrineAction:FireServer("Clear", pickSlot)
		end
		endPick()
	end)
	UIKit.button({
		Text = "Back",
		BackgroundColor3 = colors.Card,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.2, -4, 1, 0),
		Parent = pickHeader,
	}, endPick)

	local statusLabel = UIKit.label({
		TextSize = 13,
		TextColor3 = colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 18),
		Text = SELECT_HINT,
		Parent = content,
	})
	local list = UIKit.scrollList(content, 4)
	list.Position = UDim2.fromOffset(0, LIST_TOP)

	-- Action bar for the selected relic.
	local bar = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		Parent = content,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
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

	local function send(action: string, ...: any)
		local args = table.pack(...)
		task.spawn(function()
			local ok, result = pcall(function()
				return InventoryAction:InvokeServer(action, table.unpack(args, 1, args.n))
			end)
			if ok and type(result) == "table" and result.State then
				if result.Message then
					statusLabel.Text = result.Message
				end
				render(result.State)
			end
		end)
	end

	local function barButton(order: number, onClick: (group: any) -> ()): TextButton
		return UIKit.button({
			LayoutOrder = order,
			Size = UDim2.new(0.2, -5, 1, 0),
			Parent = bar,
		}, function()
			local group = selectedGroup()
			if group then
				onClick(group)
			end
		end)
	end
	local equipButton = barButton(1, function(group)
		ShrineAction:FireServer(if group.Displayed > 0 then "UnequipGroup" else "EquipGroup", group.Id, group.Mutation)
	end)
	local sellOneButton = barButton(2, function(group)
		send("Sell", group.Id, group.Mutation, 1)
	end)
	local sellAllButton = barButton(3, function(group)
		send("Sell", group.Id, group.Mutation, "All")
	end)
	local lockButton = barButton(4, function(group)
		send("Lock", group.Id, group.Mutation, group.Locked < group.Count)
	end)
	local favButton = barButton(5, function(group)
		send("Favorite", group.Id, group.Mutation, not group.Favorite)
	end)

	local function styleBarButton(instance: TextButton, text: string, enabled: boolean, color: Color3?)
		instance.Text = text
		instance.AutoButtonColor = enabled
		instance.BackgroundColor3 = if not enabled then colors.Card else color or colors.Accent
		instance.TextColor3 = if enabled then (if color == colors.Gold then colors.Panel else colors.Text) else colors.SubText
	end

	local function refreshBar()
		local inPick = pickSlot ~= nil
		bar.Visible = not inPick
		list.Size = UDim2.new(1, 0, 1, if inPick then -LIST_TOP else -(LIST_TOP + BAR_HEIGHT + 6))
		local group = selectedGroup()
		if not group then
			styleBarButton(equipButton, "Equip", false)
			styleBarButton(sellOneButton, "Sell 1", false)
			styleBarButton(sellAllButton, "Sell all", false)
			styleBarButton(lockButton, "Lock", false)
			styleBarButton(favButton, "Favorite", false)
			return
		end
		local equipped = group.Displayed > 0
		local allLocked = group.Locked >= group.Count
		styleBarButton(equipButton, if equipped then "Unequip" else "Equip", true, if equipped then colors.Gold else nil)
		styleBarButton(sellOneButton, "Sell 1", group.Sellable > 0)
		styleBarButton(sellAllButton, "Sell all", group.Sellable > 0)
		styleBarButton(lockButton, if allLocked then "Unlock" else "Lock", true, if allLocked then colors.Gold else colors.Panel)
		styleBarButton(favButton, if group.Favorite then "Unfavorite" else "Favorite", true, if group.Favorite
			then colors.Gold
			else colors.Panel)
	end

	local function onRowClicked(group: any)
		local slot = pickSlot
		if slot then
			if group.Count - group.Displayed <= 0 then
				statusLabel.Text = "Every copy of that relic is already on a pedestal."
				return
			end
			ShrineAction:FireServer("DisplayGroup", slot, group.Id, group.Mutation)
			endPick()
			return
		end
		selectedKey = groupKey(group)
		statusLabel.Text = `Selected: {Odds.displayName(group.Id, group.Mutation)}`
		if state then
			render(state)
		end
	end

	function render(newState: State)
		state = newState
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local over = newState.Count - newState.Capacity
		local full = over >= 0
		countLabel.Text = `{if full then "[INVENTORY FULL] " else ""}Held {newState.Count} / {newState.Capacity}{if over > 0
			then `  (+{over} protected)`
			else ""}`
		countLabel.TextColor3 = if full then colors.Red else colors.Gold
		if not selectedGroup() then
			selectedKey = nil
		end
		refreshBar()
		if #newState.Groups == 0 then
			UIKit.label({
				Text = "No relics yet. Your resonator finds one every few seconds.",
				TextColor3 = colors.SubText,
				TextSize = 14,
				Size = UDim2.new(1, -10, 0, 30),
				Parent = list,
			})
			return
		end

		local ctx = Odds.current()
		for index, group in newState.Groups do
			local spare = group.Count - group.Displayed
			local dimmed = pickSlot ~= nil and spare <= 0
			local selected = pickSlot == nil and groupKey(group) == selectedKey
			local row = UIKit.create("TextButton", {
				Text = "",
				AutoButtonColor = not dimmed,
				LayoutOrder = index,
				Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
				BackgroundColor3 = colors.Card,
				BackgroundTransparency = if dimmed then 0.5 else 0,
				Parent = list,
			}, {
				UIKit.corner(8),
				UIKit.stroke(colors.Gold, 2, if selected then 0 else 1),
			})
			row.Activated:Connect(function()
				onRowClicked(group)
			end)

			local tags = {}
			if group.Displayed > 0 then
				table.insert(tags, if group.Displayed > 1 then `ON PEDESTAL x{group.Displayed}` else "ON PEDESTAL")
			end
			if group.Locked > 0 then
				table.insert(tags, "LOCKED")
			end
			UIKit.label({
				Text = table.concat(tags, "  "),
				TextSize = 12,
				TextColor3 = colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 6),
				Size = UDim2.fromOffset(170, 16),
				Parent = row,
			})
			UIKit.label({
				Text = `{if group.Favorite then "* " else ""}{Odds.displayName(group.Id, group.Mutation)}`,
				TextSize = 15,
				TextColor3 = relicColor(group.Id, group.Mutation),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 4),
				Size = UDim2.new(1, -190, 0, 20),
				Parent = row,
			})
			UIKit.label({
				Text = `x{group.Count}  |  +{Format.number(group.IncomePerMin)}/min  |  sells {Format.number(group.SellValue)}`,
				TextSize = 12,
				TextColor3 = colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 25),
				Size = UDim2.new(1, -16, 0, 16),
				Parent = row,
			})
			local yours = RollMath.comboProbability(ctx, group.Id, group.Mutation)
			UIKit.label({
				Text = `Base {Format.odds(Odds.baseItem(group.Id))}  |  Yours {Format.odds(yours)}{if group.Mutation
					then ` ({group.Mutation})`
					else ""}`,
				TextSize = 12,
				TextColor3 = colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 43),
				Size = UDim2.new(1, -16, 0, 16),
				Parent = row,
			})
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
		header.Visible = slot == nil
		pickHeader.Visible = slot ~= nil
		if slot then
			pickLabel.Text = `Pick a relic for pedestal {slot}`
			statusLabel.Text = "Tap a relic to place it. Favorites first, then best income."
		else
			statusLabel.Text = SELECT_HINT
		end
		refreshBar()
	end

	-- New finds and pedestal changes alter the list while it's open; refresh at most once per REFRESH_SECONDS.
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
	player:GetAttributeChangedSignal("InventoryCount"):Connect(queueRefresh)
	ShrineState.OnClientEvent:Connect(function()
		if panel.Visible then
			load()
		end
	end)

	return {
		Toggle = function()
			panel.Visible = not panel.Visible
			if panel.Visible then
				setMode(nil)
				load()
			end
		end,
		Pick = function(slot: number)
			setMode(slot)
			panel.Visible = true
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

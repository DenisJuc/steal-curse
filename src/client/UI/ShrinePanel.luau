-- Shrine management (GDD 6.3-6.5, 9.4): six pedestal rows (buy, upgrade, max, lock, change) and a
-- relic picker to choose what a pedestal displays. Selling lives in the Relics menu. The client only sends intents; the server validates
-- costs and ownership and pushes the new state back on ShrineState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShrineAction = Remotes:WaitForChild("ShrineAction") :: RemoteEvent
local ShrineState = Remotes:WaitForChild("ShrineState") :: RemoteEvent
local GetInventory = Remotes:WaitForChild("GetInventory") :: RemoteFunction

local ShrinePanel = {}

local ROW_HEIGHT = 58
local PANEL_WIDTH = 500

type Snapshot = { Slots: { any }, AutoDisplay: boolean, IncomePerMin: number, IncomeMultiplier: number }

local function button(parent: Instance, text: string, width: number, x: number, onClick: () -> ()): TextButton
	local instance = UIKit.create("TextButton", {
		Text = text,
		Font = UIKit.Font,
		TextSize = 14,
		TextColor3 = UIKit.Colors.Text,
		BackgroundColor3 = UIKit.Colors.Accent,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, x, 0.5, 0),
		Size = UDim2.fromOffset(width, 34),
		Parent = parent,
	}, { UIKit.corner(8) })
	instance.Activated:Connect(onClick)
	return instance
end

local function relicColor(relicId: string, mutation: string?): Color3
	if mutation then
		return UIKit.mutationColor(mutation)
	end
	local relic = RelicConfig.ById[relicId]
	return if relic then UIKit.tierColor(relic.Tier) else UIKit.Colors.Text
end

function ShrinePanel.Start(screen: ScreenGui, onOpenRelics: () -> ()): { Toggle: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local snapshot: Snapshot? = nil
	local pickerSlot: number? = nil
	local pickerOpen = false
	-- Buttons whose color depends on affordability: { button, cost }.
	local costButtons: { { Button: TextButton, Cost: number } } = {}

	local panel, content =
		UIKit.modal(screen, "ShrineMenu", "SHRINE PEDESTALS", colors.Gold, Vector2.new(PANEL_WIDTH, 600))

	local incomeLabel = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.Gold,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = content,
	})

	local toolbar = UIKit.create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = content,
	})
	local autoButton = UIKit.create("TextButton", {
		Font = UIKit.Font,
		TextSize = 14,
		TextColor3 = colors.Text,
		BackgroundColor3 = colors.Card,
		Size = UDim2.new(0.5, -3, 1, 0),
		Parent = toolbar,
	}, { UIKit.corner(8) })
	local relicsButton = UIKit.create("TextButton", {
		Text = "Relics & Selling",
		Font = UIKit.Font,
		TextSize = 14,
		TextColor3 = colors.Text,
		BackgroundColor3 = colors.Card,
		Position = UDim2.new(0.5, 3, 0, 0),
		Size = UDim2.new(0.5, -3, 1, 0),
		Parent = toolbar,
	}, { UIKit.corner(8) })

	local slotsFrame = UIKit.scrollList(content, 6)
	slotsFrame.Name = "Slots"
	slotsFrame.Position = UDim2.fromOffset(0, 68)
	slotsFrame.Size = UDim2.new(1, 0, 1, -68)

	local picker = UIKit.create("Frame", {
		Name = "Picker",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 1, -68),
		Visible = false,
		Parent = content,
	})
	local pickerTitle = UIKit.label({
		TextSize = 15,
		TextWrapped = true,
		Size = UDim2.new(1, -170, 0, 34),
		Parent = picker,
	})
	local pickerStatus = UIKit.label({
		TextSize = 13,
		TextColor3 = colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = picker,
	})
	local list = UIKit.scrollList(picker, 4)
	list.Position = UDim2.fromOffset(0, 60)
	list.Size = UDim2.new(1, 0, 1, -60)

	local function refreshAffordability()
		local ce = player:GetAttribute("CE") or 0
		for _, entry in costButtons do
			local affordable = ce + 1e-9 >= entry.Cost
			entry.Button.BackgroundColor3 = if affordable then colors.Accent else colors.Card
			entry.Button.TextColor3 = if affordable then colors.Text else colors.SubText
		end
	end

	local function refreshIncome()
		local ce = player:GetAttribute("CE") or 0
		local perMin = player:GetAttribute("IncomePerMin") or 0
		incomeLabel.Text = `CE {Format.ce(ce)}   |   +{Format.number(perMin)} CE/min`
	end

	local function renderGroups(groups: { any })
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if #groups == 0 then
			pickerStatus.Text = "No relics yet. Your resonator finds one every few seconds."
		end
		for index, group in groups do
			local spare = group.Count - group.Displayed
			local row = UIKit.create("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(1, -10, 0, 48),
				BackgroundColor3 = colors.Card,
				Parent = list,
			}, { UIKit.corner(8) })
			local hasActions = spare > 0 and pickerSlot ~= nil
			local textWidth = if hasActions then -84 else -12
			UIKit.label({
				Text = Odds.displayName(group.Id, group.Mutation),
				TextSize = 14,
				TextColor3 = relicColor(group.Id, group.Mutation),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(8, 4),
				Size = UDim2.new(1, textWidth, 0, 20),
				Parent = row,
			})
			UIKit.label({
				Text = `x{group.Count}{if group.Displayed > 0 then ` ({group.Displayed} shown)` else ""}  |  +{Format.number(
					group.IncomePerMin
				)}/min`,
				TextSize = 12,
				TextColor3 = colors.SubText,
				Position = UDim2.fromOffset(8, 24),
				Size = UDim2.new(1, textWidth, 0, 16),
				Parent = row,
			})
			if not hasActions then
				continue
			end
			local slot = pickerSlot
			button(row, "Display", 72, -6, function()
				ShrineAction:FireServer("DisplayGroup", slot, group.Id, group.Mutation)
				pickerOpen = false
				picker.Visible = false
				slotsFrame.Visible = true
			end)
		end
	end

	local function loadGroups()
		task.spawn(function()
			local ok, state = pcall(function()
				return GetInventory:InvokeServer()
			end)
			if ok and type(state) == "table" and pickerOpen then
				renderGroups(state.Groups)
			end
		end)
	end

	local function openPicker(slot: number)
		pickerSlot = slot
		pickerOpen = true
		pickerTitle.Text = `Choose a relic for pedestal {slot}`
		pickerStatus.Text = "Favorites first, then best income. Sell relics from the Relics menu."
		for _, child in picker:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local back = button(picker, "Back", 60, 0, function()
			pickerOpen = false
			picker.Visible = false
			slotsFrame.Visible = true
		end)
		back.AnchorPoint = Vector2.new(1, 0)
		back.Position = UDim2.fromScale(1, 0)
		back.BackgroundColor3 = colors.Card
		local clear = button(picker, "Empty slot", 90, -66, function()
			ShrineAction:FireServer("Clear", slot)
			pickerOpen = false
			picker.Visible = false
			slotsFrame.Visible = true
		end)
		clear.AnchorPoint = Vector2.new(1, 0)
		clear.Position = UDim2.new(1, -66, 0, 0)
		clear.BackgroundColor3 = colors.Card
		slotsFrame.Visible = false
		picker.Visible = true
		renderGroups({})
		pickerStatus.Text = "Loading..."
		loadGroups()
	end

	local function renderSlots()
		costButtons = {}
		for _, child in slotsFrame:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if not snapshot then
			return
		end
		autoButton.Text = `Auto-Display: {if snapshot.AutoDisplay then "ON" else "OFF"}`
		autoButton.BackgroundColor3 = if snapshot.AutoDisplay then colors.Accent else colors.Card

		for _, slot in snapshot.Slots do
			local row = UIKit.create("Frame", {
				LayoutOrder = slot.Slot,
				Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
				BackgroundColor3 = colors.Card,
				BackgroundTransparency = if slot.Owned then 0 else 0.5,
				Parent = slotsFrame,
			}, { UIKit.corner(10) })
			UIKit.label({
				Text = tostring(slot.Slot),
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if slot.Locked then colors.Gold else colors.SubText,
				Position = UDim2.fromOffset(4, 0),
				Size = UDim2.new(0, 24, 1, 0),
				Parent = row,
			})
			local title = UIKit.label({
				TextSize = 15,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(32, 7),
				Size = UDim2.new(1, -290, 0, 20),
				Parent = row,
			})
			local subtitle = UIKit.label({
				TextSize = 12,
				TextColor3 = colors.SubText,
				Position = UDim2.fromOffset(32, 31),
				Size = UDim2.new(1, -290, 0, 16),
				Parent = row,
			})

			if not slot.Owned then
				title.Text = `Pedestal {slot.Slot}`
				title.TextColor3 = colors.SubText
				if slot.IsNext and slot.Price then
					subtitle.Text = "Unlock with Cursed Energy"
					local buy = button(row, `Buy {Format.number(slot.Price)} CE`, 140, -8, function()
						ShrineAction:FireServer("BuyPedestal")
					end)
					table.insert(costButtons, { Button = buy, Cost = slot.Price })
				else
					subtitle.Text = "Unlock the previous pedestal first"
				end
				continue
			end

			if slot.Id then
				title.Text = Odds.displayName(slot.Id, slot.Mutation)
				title.TextColor3 = relicColor(slot.Id, slot.Mutation)
			else
				title.Text = "Empty"
				title.TextColor3 = colors.SubText
			end
			subtitle.Text = `+{Format.number(slot.IncomePerMin)}/min  |  Lv {slot.Level} (x{Format.number(slot.Multiplier)})`

			local slotNumber = slot.Slot
			button(row, "Change", 62, -8, function()
				openPicker(slotNumber)
			end)
			if slot.UpgradeCost then
				local maxButton = button(row, "Max", 44, -74, function()
					ShrineAction:FireServer("Upgrade", slotNumber, "Max")
				end)
				local upButton = button(row, `Lv+ {Format.number(slot.UpgradeCost)}`, 82, -122, function()
					ShrineAction:FireServer("Upgrade", slotNumber, "One")
				end)
				table.insert(costButtons, { Button = maxButton, Cost = slot.UpgradeCost })
				table.insert(costButtons, { Button = upButton, Cost = slot.UpgradeCost })
			else
				local maxed = button(row, "MAX LV", 126, -74, function() end)
				maxed.BackgroundColor3 = colors.Card
				maxed.AutoButtonColor = false
			end
			local lock = button(row, if slot.Locked then "Locked" else "Lock", 58, -208, function()
				ShrineAction:FireServer("Lock", slotNumber, not slot.Locked)
			end)
			lock.BackgroundColor3 = if slot.Locked then colors.Gold else colors.Card
			lock.TextColor3 = if slot.Locked then colors.Panel else colors.Text
		end
		refreshAffordability()
	end

	autoButton.Activated:Connect(function()
		if snapshot then
			ShrineAction:FireServer("AutoDisplay", not snapshot.AutoDisplay)
		end
	end)
	relicsButton.Activated:Connect(onOpenRelics)

	ShrineState.OnClientEvent:Connect(function(state: Snapshot)
		if type(state) ~= "table" or type(state.Slots) ~= "table" then
			return
		end
		snapshot = state
		renderSlots()
		if pickerOpen and panel.Visible then
			loadGroups()
		end
	end)
	player:GetAttributeChangedSignal("CE"):Connect(function()
		refreshIncome()
		refreshAffordability()
	end)
	player:GetAttributeChangedSignal("IncomePerMin"):Connect(refreshIncome)
	refreshIncome()

	return {
		Toggle = function()
			panel.Visible = not panel.Visible
			if panel.Visible then
				pickerOpen = false
				picker.Visible = false
				slotsFrame.Visible = true
				renderSlots()
			end
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return ShrinePanel

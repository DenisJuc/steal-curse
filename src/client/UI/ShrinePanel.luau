-- Shrine menu (GDD 6.3-6.5): the pedestals. Buy slots, upgrade levels, lock a pedestal and see
-- what each one earns; "Showcases" in the header opens the Showcase menu (GDD 6.7).
-- "Choose" opens the Relics menu to pick what a pedestal shows; everything
-- about relics themselves (Equip Best, selling, locks, favorites) lives in the Relics menu.
-- The client only sends intents; the server validates costs and pushes the new state back on
-- ShrineState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Odds = require(script.Parent.Odds)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShrineAction = Remotes:WaitForChild("ShrineAction") :: RemoteEvent
local ShrineState = Remotes:WaitForChild("ShrineState") :: RemoteEvent

local ShrinePanel = {}

local ROW_HEIGHT = 58
local PANEL_WIDTH = 500
local LIST_TOP = 50

type Snapshot = { Slots: { any }, IncomePerMin: number, IncomeMultiplier: number }

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

function ShrinePanel.Start(
	screen: ScreenGui,
	onChoose: (slot: number) -> (),
	onShowcases: () -> ()
): { Toggle: () -> (), Open: () -> (), SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors
	local snapshot: Snapshot? = nil
	-- Buttons whose color depends on affordability: { button, cost }.
	local costButtons: { { Button: TextButton, Cost: number } } = {}

	local panel, content = UIKit.modal(screen, "ShrineMenu", "SHRINE", colors.Gold, Vector2.new(PANEL_WIDTH, 600))

	local incomeLabel = UIKit.label({
		TextSize = 15,
		TextColor3 = colors.Gold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -130, 0, 20),
		Parent = content,
	})
	UIKit.button({
		Name = "Showcases",
		Text = "Showcases >",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, -2),
		Size = UDim2.fromOffset(118, 24),
		Parent = content,
	}, onShowcases)
	UIKit.label({
		Text = "Choose what each pedestal shows, or use Equip Best in Relics. Locked pedestals never change.",
		TextSize = 12,
		TextColor3 = colors.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = content,
	})

	local slotsFrame = UIKit.scrollList(content, 6)
	slotsFrame.Name = "Slots"
	slotsFrame.Position = UDim2.fromOffset(0, LIST_TOP)
	slotsFrame.Size = UDim2.new(1, 0, 1, -LIST_TOP)

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
			button(row, "Choose", 62, -8, function()
				onChoose(slotNumber)
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

	ShrineState.OnClientEvent:Connect(function(state: Snapshot)
		if type(state) ~= "table" or type(state.Slots) ~= "table" then
			return
		end
		snapshot = state
		renderSlots()
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
		end,
		Open = function()
			panel.Visible = true
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return ShrinePanel

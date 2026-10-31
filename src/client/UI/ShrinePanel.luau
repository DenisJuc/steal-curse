-- Shrine menu (GDD 6.3-6.5): one card per pedestal. A card shows the relic (tap it to swap), what
-- it earns per second and its level as a bar ("Lv 12/50"). The Upgrade side shows the next level
-- ("Lv 3 -> 4") and a small gold boost (+10%) above one big price button ("+N Lv"). The padlock
-- keeps a pedestal's relic during Equip Best.
-- The header holds the free Equip Best button and the Auto-equip toggle, a game pass (on: Equip
-- Best runs after every find, purchase and upgrade; without the pass it opens the purchase prompt); "Showcases" opens the Showcase menu (GDD 6.7). Selling, item locks and
-- favorites live in the Relics menu.
-- The client only sends intents; the server validates costs and pushes the new state back on
-- ShrineState.
-- Buying levels: the header's x1 / x10 / Max toggle picks what every row's single price button
-- buys (one level, ten levels, or as many as the current CE affords).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local Odds = require(script.Parent.Odds)
local RelicViewport = require(script.Parent.RelicViewport)
local UIKit = require(script.Parent.UIKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShrineAction = Remotes:WaitForChild("ShrineAction") :: RemoteEvent
local ShrineState = Remotes:WaitForChild("ShrineState") :: RemoteEvent

local ShrinePanel = {}

local PANEL_WIDTH = 580
local LIST_TOP = 96
local ROW2_Y = 42
local ROW2_HEIGHT = 44
local BUY_MODES = { { Id = "One", Text = "x1" }, { Id = "Ten", Text = "x10" }, { Id = "Max", Text = "Max" } }
local CARD_HEIGHT = 116
local LOCKED_CARD_HEIGHT = 84
local THUMB = 88
local SIDE_WIDTH = 190
local INFO_X = 12 + THUMB + 26
local LEVEL_TEXT = 72
local LEVEL_BAR = 8
local ARROW = "\u{2192}"

type Snapshot = {
	Slots: { any },
	IncomePerSec: number,
	IncomeMultiplier: number,
	AutoEquip: boolean?,
	AutoEquipOwned: boolean?,
}

local function relicColor(relicId: string, mutation: string?): Color3
	if mutation then
		return UIKit.mutationColor(mutation)
	end
	local relic = RelicConfig.ById[relicId]
	return if relic then UIKit.tierColor(relic.Tier) else UIKit.Colors.Text
end

local function toHex(color: Color3): string
	return "#" .. color:ToHex()
end

-- A rounded dark pill holding a coin value (header balance and income).
local function pill(parent: Instance, order: number): TextLabel
	local frame = UIKit.create("Frame", {
		BackgroundColor3 = UIKit.Colors.Track,
		BackgroundTransparency = 0.2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 32),
		LayoutOrder = order,
		Parent = parent,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(UIKit.Colors.Trim, 1, 0.6),
		UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12) }),
	})
	local holder, label = UIKit.coinValue(frame, 22, 19)
	holder.Size = UDim2.fromScale(0, 1)
	return label
end

-- "Lv 12/50" and a slim gold bar filled to the current level.
local function levelBar(parent: Instance, level: number)
	local colors = UIKit.Colors
	local maxLevel = Config.Economy.PedestalMaxLevel
	local holder = UIKit.create("Frame", {
		Name = "Level",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(INFO_X, 78),
		Size = UDim2.new(1, -(INFO_X + SIDE_WIDTH + 20), 0, 22),
		Parent = parent,
	})
	UIKit.label({
		Text = `Lv {level}/{maxLevel}`,
		TextSize = 16,
		TextColor3 = if level >= maxLevel then colors.Gold else colors.Text,
		Size = UDim2.new(0, LEVEL_TEXT, 1, 0),
		Parent = holder,
	})
	local track = UIKit.create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, LEVEL_TEXT + 6, 0.5, 0),
		Size = UDim2.new(1, -(LEVEL_TEXT + 6), 0, LEVEL_BAR),
		BackgroundColor3 = colors.Track,
		BorderSizePixel = 0,
		Parent = holder,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(colors.Trim, 1, 0.6),
	})
	UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(math.clamp(level / maxLevel, 0, 1), 1),
		BackgroundColor3 = colors.Gold,
		BorderSizePixel = 0,
		Parent = track,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
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
	-- Upgrade buttons, re-priced whenever CE or the buy mode changes.
	local upgradeButtons: { { Button: TextButton, Level: number, OneCost: number } } = {}
	local buyMode = "One"

	local panel, content =
		UIKit.modal(screen, "ShrineMenu", "PEDESTALS", colors.Gold, Vector2.new(PANEL_WIDTH, 620), "Pedestals")

	local header = UIKit.create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -150, 0, 32),
		Parent = content,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local balanceLabel = pill(header, 1)
	local incomeLabel = pill(header, 2)
	local showcases = UIKit.button({
		Name = "Showcases",
		Text = "Showcases",
		TextSize = 18,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.fromOffset(136, 32),
		Parent = content,
	}, onShowcases)
	UIKit.skinButton(showcases, "Gold")

	local equipBest = UIKit.button({
		Name = "EquipBest",
		Text = "Equip Best",
		TextSize = 19,
		Position = UDim2.fromOffset(0, ROW2_Y),
		Size = UDim2.fromOffset(124, ROW2_HEIGHT),
		Parent = content,
	}, function()
		ShrineAction:FireServer("EquipBest")
	end)
	UIKit.skinButton(equipBest, "Primary")
	local autoEquip = UIKit.button({
		Name = "AutoEquip",
		Text = "",
		TextSize = 17,
		Position = UDim2.fromOffset(132, ROW2_Y),
		Size = UDim2.fromOffset(196, ROW2_HEIGHT),
		Parent = content,
	}, function()
		local owned = snapshot ~= nil and snapshot.AutoEquipOwned == true
		local passId = Config.GamePasses.AutoEquip
		if not owned and passId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, passId)
			return
		end
		local on = not (snapshot ~= nil and snapshot.AutoEquip == true)
		ShrineAction:FireServer("SetAutoEquip", on)
	end)
	local function refreshAutoEquip()
		local owned = snapshot ~= nil and snapshot.AutoEquipOwned == true
		local on = snapshot ~= nil and snapshot.AutoEquip == true
		autoEquip.Text = if not owned then "Auto-equip (Pass)"
			elseif on then "Auto-equip: ON"
			else "Auto-equip: OFF"
		UIKit.skinButton(autoEquip, if not owned then "Gold" elseif on then "Buy" else "Dark")
		autoEquip.TextColor3 = if not owned then colors.Panel elseif on then colors.Text else colors.SubText
	end
	refreshAutoEquip()

	local refreshAffordability: () -> ()
	-- x1 / x10 / Max: what each row's price button buys.
	local modeBar = UIKit.tabBar(content, BUY_MODES, buyMode, function(id)
		buyMode = id
		refreshAffordability()
	end, {
		Name = "BuyMode",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, ROW2_Y),
		Size = UDim2.fromOffset(204, ROW2_HEIGHT),
	})
	modeBar.ZIndex = 2

	local slotsFrame = UIKit.scrollList(content, 8)
	slotsFrame.Name = "Slots"
	slotsFrame.Position = UDim2.fromOffset(0, LIST_TOP)
	slotsFrame.Size = UDim2.new(1, 0, 1, -LIST_TOP)

	function refreshAffordability()
		local ce = player:GetAttribute("CE") or 0
		for _, entry in costButtons do
			UIKit.setAffordable(entry.Button, ce + 1e-9 >= entry.Cost, entry.Cost)
		end
		for _, entry in upgradeButtons do
			local levels, cost = 1, entry.OneCost
			if buyMode == "Ten" then
				levels, cost = Economy.bulkUpgrades(Config.Economy, entry.Level, 10)
			elseif buyMode == "Max" then
				levels, cost = Economy.maxAffordableUpgrades(Config.Economy, entry.Level, ce)
				if levels < 1 then
					levels, cost = 1, entry.OneCost
				end
			end
			UIKit.setPrice(entry.Button, `+{levels} Lv`, cost)
			UIKit.setAffordable(entry.Button, ce + 1e-9 >= cost, cost)
		end
	end

	local function refreshIncome()
		balanceLabel.Text = Format.ce(player:GetAttribute("CE") or 0)
		incomeLabel.Text = `+{Format.rate(player:GetAttribute("IncomePerSec") or 0)}`
	end

	-- Cards of the last render by slot number, and what each showed (to celebrate changes).
	local rowsBySlot: { [number]: Frame } = {}
	local lastSeen: { [number]: { Owned: boolean, Level: number, Locked: boolean } } = {}

	local function card(slot: any, height: number): Frame
		local holder = UIKit.slot(slotsFrame, `Pedestal{slot.Slot}`, UDim2.new(1, -10, 0, height), slot.Slot)
		local frame = UIKit.create("Frame", {
			Name = "Card",
			BackgroundColor3 = colors.Card,
			BackgroundTransparency = if slot.Owned or slot.IsNext then 0 else 0.5,
			Parent = holder,
		}, { UIKit.corner(12) })
		UIKit.fill(frame)
		UIKit.skinCard(frame, if slot.Locked then colors.Gold else nil)
		frame:SetAttribute("PopIn", true)
		rowsBySlot[slot.Slot] = frame
		return frame
	end

	-- The relic picture (a button: tap to choose what the pedestal shows), with the slot number.
	local function thumbnail(parent: Frame, slot: any, size: number): GuiObject
		local thumb = UIKit.create("Frame", {
			Name = "Relic",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = colors.Track,
			Parent = parent,
		}, {
			UIKit.corner(10),
			UIKit.stroke(if slot.Id then relicColor(slot.Id, slot.Mutation) else colors.Trim, 2, if slot.Id then 0.1 else 0.6),
		})
		UIKit.create("TextLabel", {
			Name = "Number",
			Text = tostring(slot.Slot),
			Font = UIKit.Font,
			TextSize = 14,
			TextColor3 = colors.Text,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = colors.Plum,
			ZIndex = 3,
			Parent = thumb,
		}, {
			UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIKit.stroke(colors.Trim, 1.5, 0.2),
		})
		return thumb
	end

	local function ownedCard(slot: any)
		local frame = card(slot, CARD_HEIGHT)
		local slotNumber = slot.Slot
		local thumb = thumbnail(frame, slot, THUMB)
		UIKit.button({
			Name = "Swap",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = thumb,
		}, function()
			onChoose(slotNumber)
		end)
		if slot.Id then
			RelicViewport.new(slot.Id, { ZIndex = 1 }).Parent = thumb
		else
			UIKit.label({
				Text = "+",
				TextSize = 40,
				TextColor3 = colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 1, -16),
				Parent = thumb,
			})
		end
		local hint = UIKit.label({
			Name = "Hint",
			Text = if slot.Id then "SWAP" else "PLACE",
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0.3,
			BackgroundColor3 = colors.Panel,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -8, 0, 24),
			ZIndex = 2,
			Parent = thumb,
		})
		UIKit.corner(6).Parent = hint

		local lock = UIKit.button({
			Name = "Lock",
			Text = "",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 12 + THUMB - 4, 0.5, -THUMB / 2 + 6),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = 4,
			Parent = frame,
		}, function()
			ShrineAction:FireServer("Lock", slotNumber, not slot.Locked)
		end)
		UIKit.skinButton(lock, if slot.Locked then "Gold" else "Dark")
		UIKit.corner(20).Parent = lock
		Icons.padlock(lock, 22, if slot.Locked then colors.Panel else colors.SubText, not slot.Locked)

		local infoWidth = UDim2.new(1, -(INFO_X + SIDE_WIDTH + 20), 0, 26)
		local nameLabel = UIKit.label({
			Name = "RelicName",
			Text = if slot.Id then Odds.displayName(slot.Id, slot.Mutation) else "Empty pedestal",
			TextSize = 20,
			TextScaled = true,
			TextColor3 = if slot.Id then relicColor(slot.Id, slot.Mutation) else colors.SubText,
			Position = UDim2.fromOffset(INFO_X, 12),
			Size = infoWidth,
			Parent = frame,
		})
		UIKit.create("UITextSizeConstraint", { MaxTextSize = 21, MinTextSize = 13, Parent = nameLabel })
		if slot.Id then
			local income, incomeValue = UIKit.coinValue(frame, 20, 19)
			income.Position = UDim2.fromOffset(INFO_X, 44)
			incomeValue.Text = Format.rate(slot.IncomePerSec)
		end
		levelBar(frame, slot.Level)

		local function sideLabel(text: string, y: number, size: number, color: Color3): TextLabel
			return UIKit.label({
				Text = text,
				RichText = true,
				TextSize = size,
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, y),
				Size = UDim2.fromOffset(SIDE_WIDTH, size + 4),
				Parent = frame,
			})
		end

		if not slot.UpgradeCost then
			sideLabel(`x{Format.multiplier(slot.Multiplier)} income boost`, 14, 16, colors.Gold)
			local maxed = UIKit.label({
				Text = "MAX LEVEL",
				TextSize = 17,
				TextColor3 = colors.Panel,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0,
				BackgroundColor3 = colors.Gold,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 44),
				Size = UDim2.fromOffset(SIDE_WIDTH, 36),
				Parent = frame,
			})
			UIKit.corner(8).Parent = maxed
			return
		end

		local nextLevel = slot.Level + 1
		local jade = toHex(colors.Jade)
		local gold = toHex(colors.Gold)
		-- Boost % is not shown elsewhere on upgradeable rows; keep it next to the level arrow.
		local pct = math.floor((Config.Economy.LevelGrowth - 1) * 100 + 0.5)
		sideLabel(
			`Lv {slot.Level} {ARROW} <font color="{jade}">{nextLevel}</font>  <font color="{gold}">+{pct}%</font>`,
			4,
			18,
			colors.Text
		)

		local upgrade = UIKit.priceButton({
			Name = "Upgrade",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 44),
			Size = UDim2.fromOffset(SIDE_WIDTH, 56),
			TextSize = 20,
			Parent = frame,
		}, "+1 Lv", slot.UpgradeCost, function()
			ShrineAction:FireServer("Upgrade", slotNumber, buyMode)
		end)
		table.insert(upgradeButtons, { Button = upgrade, Level = slot.Level, OneCost = slot.UpgradeCost })
	end

	local function lockedCard(slot: any)
		local frame = card(slot, LOCKED_CARD_HEIGHT)
		local thumb = thumbnail(frame, slot, LOCKED_CARD_HEIGHT - 20)
		Icons.padlock(thumb, 28, if slot.IsNext then colors.Gold else colors.SubText)
		local textWidth = UDim2.new(1, -(LOCKED_CARD_HEIGHT + 4 + SIDE_WIDTH + 20), 0, 24)
		UIKit.label({
			Text = `Pedestal {slot.Slot}`,
			TextSize = 20,
			TextColor3 = if slot.IsNext then colors.Text else colors.SubText,
			Position = UDim2.fromOffset(LOCKED_CARD_HEIGHT + 4, 14),
			Size = textWidth,
			Parent = frame,
		})
		if not slot.IsNext then
			UIKit.label({
				Text = `Unlock pedestal {slot.Slot - 1} first`,
				TextSize = 15,
				TextColor3 = colors.SubText,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(LOCKED_CARD_HEIGHT + 4, 42),
				Size = textWidth,
				Parent = frame,
			})
		end
		if slot.IsNext and slot.Price then
			local buy = UIKit.priceButton({
				Name = "Unlock",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(SIDE_WIDTH, 38),
				TextSize = 18,
				Parent = frame,
			}, "Unlock", slot.Price, function()
				ShrineAction:FireServer("BuyPedestal")
			end)
			table.insert(costButtons, { Button = buy, Cost = slot.Price })
		end
	end

	local function renderSlots()
		costButtons = {}
		upgradeButtons = {}
		rowsBySlot = {}
		for _, child in slotsFrame:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if not snapshot then
			return
		end
		for _, slot in snapshot.Slots do
			if slot.Owned then
				ownedCard(slot)
			else
				lockedCard(slot)
			end
		end
		refreshAffordability()
	end

	-- Bought pedestals and new levels get the purchase celebration; locking gives a small bounce.
	local function celebrate()
		if not snapshot then
			return
		end
		for _, slot in snapshot.Slots do
			local before = lastSeen[slot.Slot]
			local row = rowsBySlot[slot.Slot]
			if before and row and panel.Visible then
				if (slot.Owned and not before.Owned) or (slot.Level or 0) > before.Level then
					Motion.purchased(row)
				elseif slot.Locked ~= before.Locked then
					Motion.punch(row, 0.6)
				end
			end
			lastSeen[slot.Slot] = { Owned = slot.Owned == true, Level = slot.Level or 0, Locked = slot.Locked == true }
		end
	end

	ShrineState.OnClientEvent:Connect(function(state: Snapshot)
		if type(state) ~= "table" or type(state.Slots) ~= "table" then
			return
		end
		snapshot = state
		refreshAutoEquip()
		renderSlots()
		celebrate()
	end)
	player:GetAttributeChangedSignal("CE"):Connect(function()
		refreshIncome()
		refreshAffordability()
	end)
	player:GetAttributeChangedSignal("IncomePerSec"):Connect(refreshIncome)
	refreshIncome()

	return {
		Toggle = function()
			UIKit.toggle(panel)
		end,
		Open = function()
			UIKit.show(panel)
		end,
		SetVisible = function(visible: boolean)
			if not visible then
				panel.Visible = false
			end
		end,
	}
end

return ShrinePanel

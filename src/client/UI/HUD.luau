-- Top-left column: the Spirit Resonator box (totals; the charge lives on the ROLL button), then
-- the Cursed Energy coin counter, then the Shrine (pedestal), Luck (cursed lucky flower), Rebirth
-- (cycle ring; shines once affordable), Codex (book), Journal (scroll) and Settings (gear)
-- buttons, one under the other: names hang on each button's bottom edge, values (luck, Rebirths,
-- Codex count) sit in a corner chip. Backpack and Upgrades
-- sit in the bottom RollBar. On small (phone) screens the buttons wrap into rows of three. Reads
-- player attributes only; one UIScale keeps the whole column readable on phones.
-- CE rolls up instead of jumping; a windfall (more than a few seconds of passive income at once,
-- e.g. a sale) also bursts coins into the counter, from the button that earned it (Sell) or the
-- screen center.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local HUD = {}

export type Callbacks = {
	OnShrine: () -> (),
	OnLuck: () -> (),
	OnRebirth: () -> (),
	OnCodex: () -> (),
	OnJournal: () -> (),
	OnSettings: () -> (),
}

local ICON_BUTTON_SIZE = 64
local ICON_GAP = 6
-- Rows also leave room for the caption hanging under each button.
local ROW_GAP = 16
local COMPACT_PER_ROW = 3
local CE_HEIGHT = 44
-- A CE gain bigger than this many seconds of passive income counts as a windfall.
local WINDFALL_SECONDS = 5

-- Square button: the icon fills it, the name straddles its bottom edge, and a value (if any)
-- goes in a chip on the top-left corner, so no text sits on the icon.
local function iconButton(
	parent: Instance,
	name: string,
	order: number,
	caption: string,
	iconKey: string
): (TextButton, TextLabel, TextLabel)
	local slot = UIKit.slot(parent, name .. "Slot", UDim2.fromOffset(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE), order)
	local button = UIKit.create("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		Parent = slot,
	}, { UIKit.corner(14) })
	UIKit.fill(button)
	UIKit.skinPanel(button)
	Motion.button(button)
	local icon = Icons.draw(button, iconKey)
	if icon then
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(0.5, 0, 0.5, -3)
		local scale = icon:FindFirstChildOfClass("UIScale")
		if scale and scale.Scale < 1 then
			scale.Scale = 1
		end
	end
	local label = UIKit.iconCaption(button, caption, 14)
	local chip = UIKit.iconChip(button)
	chip.Visible = false
	return button, label, chip
end

function HUD.Start(screen: ScreenGui, callbacks: Callbacks): { SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local column = UIKit.create("Frame", {
		Name = "LeftColumn",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(280, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		UIKit.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	UIKit.scaler(column)

	local panel = UIKit.create("Frame", {
		Name = "ResonatorPanel",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(280, 92),
		Parent = column,
	}, {
		UIKit.corner(12),
		UIKit.padding(12),
	})
	UIKit.skinPanel(panel)

	local titleLabel = UIKit.label({
		Name = "Title",
		Text = "SPIRIT RESONATOR",
		FontFace = UIKit.TitleFont,
		TextColor3 = colors.Gold,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = panel,
	})

	local statsLabel = UIKit.label({
		Name = "Stats",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		Parent = panel,
	})
	local capturesLabel = UIKit.label({
		Name = "Captures",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = colors.Cyan,
		TextSize = 16,
		Parent = panel,
	})

	-- Cursed Energy: a coin pill in a fixed slot so its bounce never moves the buttons below.
	local ceSlot = UIKit.slot(column, "CursedEnergySlot", UDim2.fromOffset(220, CE_HEIGHT), 2)
	local cePill = UIKit.create("Frame", {
		Name = "CursedEnergy",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = ceSlot,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UIKit.skinPanel(cePill, colors.Gold)
	local coinIcon = UIKit.coin(30)
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.Position = UDim2.new(0, 7, 0.5, 0)
	coinIcon.Parent = cePill
	local ceLabel = UIKit.label({
		Name = "Amount",
		TextColor3 = colors.Gold,
		TextSize = 24,
		TextStrokeTransparency = 0.4,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -54, 1, 0),
		Parent = cePill,
	})
	local setCE = Motion.counter(ceLabel, function(value: number): string
		return `{Format.ce(value)} CE`
	end)

	Motion.setCoinTarget(coinIcon, cePill, function()
		return UIKit.coin(24)
	end)
	local shownCE = player:GetAttribute("CE")
	setCE(shownCE or 0, true)
	local function windfall(gain: number, target: number)
		local count = math.clamp(math.floor(3 + math.log10(gain + 1) * 1.5), 4, 12)
		Motion.floatText(cePill, `+{Format.ce(gain)}`, colors.Gold, UDim2.new(1, 8, 0.5, 0))
		Motion.payout(screen, Motion.coinSource(screen), count, function()
			setCE(target)
		end)
	end
	player:GetAttributeChangedSignal("CE"):Connect(function()
		local ce = player:GetAttribute("CE") or 0
		local before = shownCE
		shownCE = ce
		if before == nil then
			setCE(ce, true)
			return
		end
		local gain = ce - before
		local perSecond = player:GetAttribute("IncomePerSec") or 0
		if gain > math.max(1, perSecond * WINDFALL_SECONDS) then
			windfall(gain, ce)
		else
			setCE(ce)
		end
	end)

	local buttons = UIKit.create("Frame", {
		Name = "Buttons",
		LayoutOrder = 3,
		BackgroundTransparency = 1,
		Parent = column,
	})
	local grid = UIKit.create("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellSize = UDim2.fromOffset(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE),
		CellPadding = UDim2.fromOffset(ICON_GAP + 6, ROW_GAP),
		FillDirection = Enum.FillDirection.Horizontal,
		Parent = buttons,
	})

	local shrineButton = iconButton(buttons, "ShrineButton", 3, "Shrine", "Shrine")
	shrineButton.Activated:Connect(callbacks.OnShrine)

	local luckButton, _, luckChip = iconButton(buttons, "LuckButton", 4, "Luck", "Luck")
	luckButton.Activated:Connect(callbacks.OnLuck)
	luckChip.Visible = true
	local function refreshLuck()
		luckChip.Text = `x{Format.number(player:GetAttribute("EffectiveLuck") or 1)}`
	end
	player:GetAttributeChangedSignal("EffectiveLuck"):Connect(refreshLuck)
	refreshLuck()

	-- Rebirth: shines and turns jade once the next Rebirth is affordable; the chip counts Rebirths.
	local rebirthButton, rebirthCaption, rebirthChip = iconButton(buttons, "RebirthButton", 5, "Rebirth", "Rebirth")
	rebirthButton.Activated:Connect(callbacks.OnRebirth)
	local rebirthStroke = rebirthButton:FindFirstChildOfClass("UIStroke")
	local rebirthReady = false
	Motion.shineLoop(rebirthButton, 2.4, function()
		return rebirthReady
	end)
	local function refreshRebirth()
		local count = player:GetAttribute("Rebirths") or 0
		local cost = Rebirth.cost(Config.Rebirth, count)
		rebirthReady = (player:GetAttribute("CE") or 0) + 1e-9 >= cost
		rebirthChip.Visible = count > 0
		rebirthChip.Text = tostring(count)
		rebirthCaption.TextColor3 = if rebirthReady then colors.Jade else colors.Text
		if rebirthStroke then
			rebirthStroke.Color = if rebirthReady then colors.Jade else colors.Trim
			rebirthStroke.Thickness = if rebirthReady then 3 else 2
		end
	end
	player:GetAttributeChangedSignal("Rebirths"):Connect(refreshRebirth)
	player:GetAttributeChangedSignal("CE"):Connect(refreshRebirth)
	refreshRebirth()

	local codexButton, _, codexChip = iconButton(buttons, "CodexButton", 7, "Codex", "Codex")
	codexButton.Activated:Connect(callbacks.OnCodex)
	codexChip.Visible = true

	local journalButton = iconButton(buttons, "JournalButton", 8, "Journal", "Journal")
	journalButton.Activated:Connect(callbacks.OnJournal)

	local settingsButton = iconButton(buttons, "SettingsButton", 9, "Settings", "Settings")
	settingsButton.Activated:Connect(callbacks.OnSettings)

	local buttonCount = 6
	UIKit.watchCompact(function(compact: boolean)
		local perRow = if compact then COMPACT_PER_ROW else 1
		local rows = math.ceil(buttonCount / perRow)
		grid.FillDirectionMaxCells = perRow
		buttons.Size = UDim2.fromOffset(
			perRow * ICON_BUTTON_SIZE + (perRow - 1) * (ICON_GAP + 6),
			rows * ICON_BUTTON_SIZE + (rows - 1) * ROW_GAP + ROW_GAP / 2
		)
	end)
	local function refreshCodex()
		codexChip.Text = `{player:GetAttribute("DiscoveredCount") or 0}/{#CodexBook.AllIds}`
	end
	player:GetAttributeChangedSignal("DiscoveredCount"):Connect(refreshCodex)
	refreshCodex()

	-- "!" badge while Codex milestones are waiting to be claimed; it breathes and the button shines.
	local badge = UIKit.label({
		Name = "ClaimBadge",
		Text = "!",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = colors.Red,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		ZIndex = 10,
		Visible = false,
		Parent = codexButton,
	})
	UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	UIKit.stroke(colors.Text, 2, 0).Parent = badge
	Motion.badge(badge)
	local codexStroke = codexButton:FindFirstChildOfClass("UIStroke")
	local claimable = false
	Motion.shineLoop(codexButton, 2.6, function()
		return claimable
	end)
	local function refreshBadge()
		local now = (player:GetAttribute("CodexClaimable") or 0) > 0
		if now and not claimable then
			Motion.pop(badge, 0, 0.2)
		end
		claimable = now
		badge.Visible = now
		if codexStroke then
			codexStroke.Color = if now then colors.Gold else colors.Trim
			codexStroke.Thickness = if now then 3 else 2
		end
	end
	player:GetAttributeChangedSignal("CodexClaimable"):Connect(refreshBadge)
	refreshBadge()

	local function refreshStats()
		local scans = player:GetAttribute("TotalScans") or 0
		local held = player:GetAttribute("InventoryCount") or 0
		local captures = player:GetAttribute("TotalCaptures") or 0
		statsLabel.Text = `Scans {Format.number(scans)}   |   Relics {Format.number(held)}`
		capturesLabel.Text = `Signals sealed {Format.number(captures)}`
	end
	player:GetAttributeChangedSignal("TotalScans"):Connect(refreshStats)
	player:GetAttributeChangedSignal("InventoryCount"):Connect(refreshStats)
	player:GetAttributeChangedSignal("TotalCaptures"):Connect(refreshStats)
	refreshStats()

	local panelStroke = panel:FindFirstChildOfClass("UIStroke")
	local wasPaused = false
	local function refreshPaused()
		local paused = player:GetAttribute("ScanPaused") == true
		titleLabel.Text = if paused then "INVENTORY FULL - PAUSED" else "SPIRIT RESONATOR"
		titleLabel.TextColor3 = if paused then colors.Red else colors.Gold
		if panelStroke then
			panelStroke.Color = if paused then colors.Red else colors.Trim
		end
		if paused and not wasPaused then
			Motion.shake(panel, 120)
		end
		wasPaused = paused
	end
	player:GetAttributeChangedSignal("ScanPaused"):Connect(refreshPaused)
	refreshPaused()

	return {
		-- Spirit Sight hides management UI; scanning itself only stops when the inventory is full.
		SetVisible = function(visible: boolean)
			column.Visible = visible
		end,
	}
end

return HUD

-- Top-left column: the Spirit Resonator box (totals; the charge lives on the ROLL button), then
-- the Cursed Energy coin counter, then Pedestals, Luck, Rebirth, Collection (Essence chip;
-- fuse-ready badge; Studio prototype), Codex and Settings. Backpack and Upgrades sit in
-- the bottom RollBar. On small (phone) screens the buttons wrap into rows of three. Reads player
-- attributes only; one UIScale keeps the whole column readable on phones.
-- CE rolls up instead of jumping; a windfall (more than a few seconds of passive income at once,
-- e.g. a sale) also bursts coins into the counter, from the button that earned it (Sell) or the
-- screen center.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceTrials = require(ReplicatedStorage.Shared.BalanceTrials)
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
	OnRebirth: () -> (),
	OnCollection: (() -> ())?,
	OnCodex: () -> (),
	OnSettings: () -> (),
}

local ICON_BUTTON_SIZE = 72
local ICON_GAP = 6
-- Rows also leave room for the caption hanging under each button.
local ROW_GAP = 16
-- Settings: a small pill under the CE counter instead of big tiles (HUD declutter,
-- 2026-11-08), so the big tiles are only the four everyday buttons.
local PILL_SIZE = Vector2.new(132, 40)
local CE_HEIGHT = 52
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
	local label = UIKit.iconCaption(button, caption, 16)
	local chip = UIKit.iconChip(button)
	chip.Visible = false
	return button, label, chip
end

-- Small pill button: icon + name, for the rarely used entries. Same Name / slot names as the old
-- tiles, so HudUnlocks and other lookups keep working.
local function pillButton(parent: Instance, name: string, order: number, caption: string, iconKey: string): TextButton
	local slot = UIKit.slot(parent, name .. "Slot", UDim2.fromOffset(PILL_SIZE.X, PILL_SIZE.Y), order)
	local button = UIKit.create("TextButton", {
		Name = name,
		Text = caption,
		Font = UIKit.Font,
		TextSize = 18,
		TextColor3 = UIKit.Colors.Text,
		TextStrokeTransparency = 0.5,
		AutoButtonColor = false,
		Parent = slot,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UIKit.fill(button)
	UIKit.skinPanel(button)
	Motion.button(button)
	Icons.inline(button, iconKey, 26)
	return button
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

	-- (The NEXT objective card that sat here was removed on 2026-11-09: the tutorial guides new
	-- players; after it the screen stays clear.)

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
	local ceSlot = UIKit.slot(column, "CursedEnergySlot", UDim2.fromOffset(250, CE_HEIGHT), 2)
	local cePill = UIKit.create("Frame", {
		Name = "CursedEnergy",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = ceSlot,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UIKit.skinPanel(cePill, colors.Gold)
	local coinIcon = UIKit.coin(36)
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.Position = UDim2.new(0, 7, 0.5, 0)
	coinIcon.Parent = cePill
	local ceLabel = UIKit.label({
		Name = "Amount",
		TextColor3 = colors.Gold,
		TextSize = 30,
		TextStrokeTransparency = 0.4,
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(1, -60, 1, 0),
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

	-- Settings pill right under the CE counter.
	local pills = UIKit.create("Frame", {
		Name = "Pills",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(PILL_SIZE.X * 2 + 8, PILL_SIZE.Y),
		BackgroundTransparency = 1,
		Parent = column,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	local buttons = UIKit.create("Frame", {
		Name = "Buttons",
		LayoutOrder = 5,
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

	local shrineButton = iconButton(buttons, "ShrineButton", 3, "Pedestals", "Pedestals")
	shrineButton.Activated:Connect(callbacks.OnShrine)

	-- Luck readout (read-only; the Luck/Focus menu was removed 2026-11-08): "x494 Luck" with the
	-- friends bonus beside it.
	local luckSlot = UIKit.slot(column, "LuckPillSlot", UDim2.fromOffset(250, 34), 3)
	local luckPill = UIKit.create("Frame", {
		Name = "LuckPill",
		Size = UDim2.fromOffset(170, 34),
		Parent = luckSlot,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UIKit.skinPanel(luckPill)
	local luckIcon = Icons.image(luckPill, "Luck", 26)
	if luckIcon then
		luckIcon.AnchorPoint = Vector2.new(0, 0.5)
		luckIcon.Position = UDim2.new(0, 6, 0.5, 0)
	end
	local luckLabel = UIKit.label({
		Name = "Amount",
		Text = "x1 Luck",
		TextSize = 20,
		TextColor3 = colors.Text,
		TextStrokeTransparency = 0.5,
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -44, 1, 0),
		Parent = luckPill,
	})
	local friendChip = UIKit.label({
		Name = "FriendChip",
		Text = "",
		TextSize = 15,
		TextColor3 = colors.Jade,
		TextStrokeTransparency = 0.5,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 178, 0.5, 0),
		Size = UDim2.fromOffset(80, 20),
		Parent = luckSlot,
	})
	local function refreshLuck()
		luckLabel.Text = `x{Format.number(player:GetAttribute("EffectiveLuck") or 1)} Luck`
		local friends = player:GetAttribute("FriendLuckPercent")
		friendChip.Visible = type(friends) == "number" and friends > 0
		friendChip.Text = `Friends +{friends or 0}%`
	end
	player:GetAttributeChangedSignal("EffectiveLuck"):Connect(refreshLuck)
	player:GetAttributeChangedSignal("FriendLuckPercent"):Connect(refreshLuck)
	refreshLuck()

	-- Rebirth: shines and turns jade once the next Rebirth is affordable; the chip counts Rebirths.
	local rebirthButton, rebirthCaption, rebirthChip = iconButton(buttons, "RebirthButton", 8, "Rebirth", "Rebirth")
	rebirthButton.Activated:Connect(callbacks.OnRebirth)
	local rebirthStroke = rebirthButton:FindFirstChildOfClass("UIStroke")
	local rebirthReady = false
	Motion.shineLoop(rebirthButton, 2.4, function()
		return rebirthReady
	end)
	local function refreshRebirth()
		local count = player:GetAttribute("Rebirths") or 0
		local settings = BalanceTrials.rebirthSettings(Config.Rebirth)
		local cost = Rebirth.cost(settings, count)
		local ce = player:GetAttribute("CE") or 0
		rebirthReady = ce + 1e-9 >= cost
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

	-- Collection (Studio prototype): Essence chip + fuse-ready badge. Hidden when collection is off.
	local collectionSlot: Frame? = nil
	local collectionVisible = false
	if callbacks.OnCollection then
		local collectionButton, _, collectionChip = iconButton(buttons, "CollectionButton", 6, "Collection", "Collection")
		collectionSlot = collectionButton.Parent :: Frame
		collectionButton.Activated:Connect(callbacks.OnCollection)
		collectionChip.Visible = true
		collectionChip.Text = "—"
		local fuseBadge = UIKit.label({
			Name = "FuseBadge",
			Text = "!",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = colors.Accent,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(24, 24),
			ZIndex = 10,
			Visible = false,
			Parent = collectionButton,
		})
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fuseBadge })
		UIKit.stroke(colors.Text, 2, 0).Parent = fuseBadge
		Motion.badge(fuseBadge)
		local collectionStroke = collectionButton:FindFirstChildOfClass("UIStroke")
		local fuseReady = false
		Motion.shineLoop(collectionButton, 2.5, function()
			return fuseReady and collectionVisible
		end)
		local function refreshCollection()
			local essence = player:GetAttribute("Essence")
			collectionVisible = type(essence) == "number"
			if collectionSlot then
				collectionSlot.Visible = collectionVisible
			end
			if not collectionVisible then
				fuseReady = false
				fuseBadge.Visible = false
				return
			end
			collectionChip.Text = Format.number(essence :: number)
			local ready = (player:GetAttribute("FuseReadyCount") or 0) > 0
				or (player:GetAttribute("CharmNeededCount") or 0) > 0
			if ready and not fuseReady then
				Motion.pop(fuseBadge, 0, 0.2)
			end
			fuseReady = ready
			fuseBadge.Visible = ready
			fuseBadge.Text = if (player:GetAttribute("CharmNeededCount") or 0) > 0 and (player:GetAttribute("FuseReadyCount") or 0) <= 0
				then "★"
				else "!"
			if collectionStroke then
				collectionStroke.Color = if ready then colors.Accent else colors.Trim
				collectionStroke.Thickness = if ready then 3 else 2
			end
		end
		player:GetAttributeChangedSignal("Essence"):Connect(refreshCollection)
		player:GetAttributeChangedSignal("FuseReadyCount"):Connect(refreshCollection)
		player:GetAttributeChangedSignal("CharmNeededCount"):Connect(refreshCollection)
		refreshCollection()
	end

	local codexButton, _, codexChip = iconButton(buttons, "CodexButton", 7, "Codex", "Codex")
	codexButton.Activated:Connect(function()
		-- Opening the Codex clears the "new relics" badge (DiscoveryFeed counts them).
		player:SetAttribute("CodexNew", 0)
		callbacks.OnCodex()
	end)
	codexChip.Visible = true

	-- Icon only: a gear needs no word (2026-11-09).
	local settingsButton = pillButton(pills, "SettingsButton", 2, "", "Settings")
	local settingsSlot = settingsButton.Parent :: Frame
	settingsSlot.Size = UDim2.fromOffset(PILL_SIZE.Y, PILL_SIZE.Y)
	local gear = settingsButton:FindFirstChild("InlineIcon") :: Frame?
	local inset = settingsButton:FindFirstChildOfClass("UIPadding")
	if inset then
		inset.PaddingLeft = UDim.new(0, 0)
	end
	if gear then
		gear.AnchorPoint = Vector2.new(0.5, 0.5)
		gear.Position = UDim2.fromScale(0.5, 0.5)
	end
	settingsButton.Activated:Connect(callbacks.OnSettings)

	-- Big tiles: Pedestals, Codex, Rebirth (+ Collection in the collection trial).
	local function liveButtonCount(): number
		return if collectionVisible then 4 else 3
	end
	local function layoutButtons(compact: boolean)
		local count = liveButtonCount()
		-- Phones: one row of three tiles (2 x 2 with Collection).
		local perRow = if not compact then 1 elseif count <= 3 then 3 else 2
		local rows = math.ceil(count / perRow)
		grid.FillDirectionMaxCells = perRow
		buttons.Size = UDim2.fromOffset(
			perRow * ICON_BUTTON_SIZE + (perRow - 1) * (ICON_GAP + 6),
			rows * ICON_BUTTON_SIZE + (rows - 1) * ROW_GAP + ROW_GAP / 2
		)
	end
	local compactLayout = false
	UIKit.watchCompact(function(compact: boolean)
		compactLayout = compact
		layoutButtons(compact)
	end)
	if callbacks.OnCollection then
		player:GetAttributeChangedSignal("Essence"):Connect(function()
			layoutButtons(compactLayout)
		end)
	end
	local function refreshCodex()
		codexChip.Text = `{player:GetAttribute("DiscoveredCount") or 0}/{#CodexBook.AllIds}`
	end
	player:GetAttributeChangedSignal("DiscoveredCount"):Connect(refreshCodex)
	refreshCodex()

	-- Badge while Codex milestones are waiting to be claimed or new relics wait to be seen; it
	-- breathes and the button shines.
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
		local fresh = player:GetAttribute("CodexNew") or 0
		local now = (player:GetAttribute("CodexClaimable") or 0) > 0 or fresh > 0
		if now and not claimable then
			Motion.pop(badge, 0, 0.2)
		end
		claimable = now
		badge.Visible = now
		-- A count of new relics to look at, or "!" when only a reward is waiting.
		badge.Text = if fresh > 0 then tostring(math.min(fresh, 99)) else "!"
		if codexStroke then
			codexStroke.Color = if now then colors.Gold else colors.Trim
			codexStroke.Thickness = if now then 3 else 2
		end
	end
	player:GetAttributeChangedSignal("CodexClaimable"):Connect(refreshBadge)
	player:GetAttributeChangedSignal("CodexNew"):Connect(refreshBadge)
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
	local warning = Icons.image(panel, "Warning", 24)
	if warning then
		warning.AnchorPoint = Vector2.new(1, 0)
		warning.Position = UDim2.new(1, 0, 0, -4)
		warning.Visible = false
	end
	local wasPaused = false
	local function refreshPaused()
		local paused = player:GetAttribute("ScanPaused") == true
		if warning then
			warning.Visible = paused
		end
		-- The totals box only appears as the inventory-full warning (less text on screen).
		panel.Visible = paused
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

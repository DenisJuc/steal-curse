-- Top-left column: the Spirit Resonator box (scan progress and totals), then Cursed Energy,
-- then the Shrine (pedestal), Luck (cursed lucky flower), Relics (chest) and Codex (book)
-- buttons, one under the other. Reads player attributes only; one UIScale keeps the whole
-- column readable on phones.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CodexBook = require(ReplicatedStorage.Shared.CodexBook)
local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(script.Parent.Icons)
local UIKit = require(script.Parent.UIKit)

local HUD = {}

export type Callbacks = {
	OnShrine: () -> (),
	OnLuck: () -> (),
	OnRelics: () -> (),
	OnCodex: () -> (),
}

local ICON_BUTTON_SIZE = 64

local function iconButton(parent: Instance, name: string, order: number, caption: string): (TextButton, TextLabel)
	local button = UIKit.create("TextButton", {
		Name = name,
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = UIKit.Colors.Panel,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(ICON_BUTTON_SIZE, ICON_BUTTON_SIZE),
		Parent = parent,
	}, { UIKit.corner(14), UIKit.stroke(UIKit.Colors.Accent, 2, 0.35) })
	local label = UIKit.label({
		Name = "Caption",
		Text = caption,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, -4, 0, 14),
		Parent = button,
	})
	return button, label
end

function HUD.Start(screen: ScreenGui, callbacks: Callbacks): { SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local column = UIKit.create("Frame", {
		Name = "LeftColumn",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(280, 470),
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
		Size = UDim2.fromOffset(280, 134),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = column,
	}, {
		UIKit.corner(12),
		UIKit.stroke(colors.Accent, 2, 0.35),
		UIKit.padding(12),
	})

	UIKit.label({
		Name = "Title",
		Text = "SPIRIT RESONATOR",
		TextColor3 = colors.Accent,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = panel,
	})

	local track = UIKit.create("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = colors.Track,
		Parent = panel,
	}, { UIKit.corner(7) })
	local fill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = colors.Accent,
		Parent = track,
	}, { UIKit.corner(7) })

	local timerLabel = UIKit.label({
		Name = "Timer",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = colors.SubText,
		TextSize = 14,
		Parent = panel,
	})
	local statsLabel = UIKit.label({
		Name = "Stats",
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		Parent = panel,
	})
	local capturesLabel = UIKit.label({
		Name = "Captures",
		Position = UDim2.fromOffset(0, 90),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = Color3.fromRGB(170, 230, 255),
		TextSize = 16,
		Parent = panel,
	})

	local ceLabel = UIKit.label({
		Name = "CursedEnergy",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(200, 30),
		TextColor3 = colors.Gold,
		TextSize = 26,
		TextStrokeTransparency = 0.4,
		Parent = column,
	})
	local function refreshCE()
		ceLabel.Text = `{Format.ce(player:GetAttribute("CE") or 0)} CE`
	end
	player:GetAttributeChangedSignal("CE"):Connect(refreshCE)
	refreshCE()

	local shrineButton = iconButton(column, "ShrineButton", 3, "Shrine")
	Icons.pedestal(shrineButton)
	shrineButton.Activated:Connect(callbacks.OnShrine)

	local luckButton, luckCaption = iconButton(column, "LuckButton", 4, "Luck")
	Icons.cursedFlower(luckButton)
	luckButton.Activated:Connect(callbacks.OnLuck)
	local function refreshLuck()
		luckCaption.Text = `Luck {Format.number(player:GetAttribute("EffectiveLuck") or 1)}x`
	end
	player:GetAttributeChangedSignal("EffectiveLuck"):Connect(refreshLuck)
	refreshLuck()

	local relicsButton = iconButton(column, "RelicsButton", 5, "Relics")
	Icons.chest(relicsButton)
	relicsButton.Activated:Connect(callbacks.OnRelics)

	local codexButton, codexCaption = iconButton(column, "CodexButton", 6, "Codex")
	Icons.book(codexButton)
	codexButton.Activated:Connect(callbacks.OnCodex)
	local function refreshCodex()
		codexCaption.Text = `Codex {player:GetAttribute("DiscoveredCount") or 0}/{#CodexBook.AllIds}`
	end
	player:GetAttributeChangedSignal("DiscoveredCount"):Connect(refreshCodex)
	refreshCodex()

	-- "!" badge while Codex milestones are waiting to be claimed.
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
		ZIndex = 2,
		Visible = false,
		Parent = codexButton,
	})
	UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
	UIKit.stroke(colors.Text, 2, 0).Parent = badge
	local codexStroke = codexButton:FindFirstChildOfClass("UIStroke")
	local function refreshBadge()
		local claimable = (player:GetAttribute("CodexClaimable") or 0) > 0
		badge.Visible = claimable
		if codexStroke then
			codexStroke.Color = if claimable then colors.Gold else colors.Accent
			codexStroke.Transparency = if claimable then 0 else 0.35
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
	local relicsStroke = relicsButton:FindFirstChildOfClass("UIStroke")
	local function refreshPaused()
		local paused = player:GetAttribute("ScanPaused") == true
		local color = if paused then colors.Red else colors.Accent
		fill.BackgroundColor3 = color
		timerLabel.TextColor3 = if paused then colors.Red else colors.SubText
		for _, stroke in { panelStroke, relicsStroke } do
			if stroke then
				stroke.Color = color
				stroke.Transparency = if paused then 0 else 0.35
			end
		end
	end
	player:GetAttributeChangedSignal("ScanPaused"):Connect(refreshPaused)
	refreshPaused()

	RunService.RenderStepped:Connect(function()
		if player:GetAttribute("ScanPaused") == true then
			fill.Size = UDim2.fromScale(1, 1)
			timerLabel.Text = "[INVENTORY FULL] Scanning paused"
			return
		end
		local nextAt = player:GetAttribute("NextScanAt")
		local interval = player:GetAttribute("ScanInterval")
		if type(nextAt) ~= "number" or type(interval) ~= "number" or interval <= 0 then
			timerLabel.Text = "Resonator warming up..."
			return
		end
		local remaining = math.max(0, nextAt - workspace:GetServerTimeNow())
		fill.Size = UDim2.fromScale(math.clamp(1 - remaining / interval, 0, 1), 1)
		timerLabel.Text = `Next scan {Format.seconds(remaining)}   (every {Format.seconds(interval)})`
	end)

	return {
		-- Spirit Sight hides management UI; scanning itself only stops when the inventory is full.
		SetVisible = function(visible: boolean)
			column.Visible = visible
		end,
	}
end

return HUD

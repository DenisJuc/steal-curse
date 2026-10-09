-- Top-left Spirit Resonator panel: scan progress bar, interval, total scans and relics held.
-- Reads player attributes only; never asks the server for data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local UIKit = require(script.Parent.UIKit)

local HUD = {}

function HUD.Start(screen: ScreenGui, onOpenFocus: () -> ()): { SetVisible: (boolean) -> () }
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local panel = UIKit.create("Frame", {
		Name = "ResonatorPanel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(280, 170),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = screen,
	}, {
		UIKit.corner(12),
		UIKit.stroke(colors.Accent, 2, 0.35),
		UIKit.padding(12),
	})
	UIKit.scaler(panel)

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

	local focusButton = UIKit.create("TextButton", {
		Name = "FocusButton",
		Font = UIKit.Font,
		TextSize = 14,
		TextColor3 = colors.Text,
		BackgroundColor3 = colors.Card,
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = panel,
	}, { UIKit.corner(8), UIKit.stroke(colors.Accent, 1, 0.5) })
	focusButton.Activated:Connect(onOpenFocus)

	local function refreshFocus()
		local luck = player:GetAttribute("EffectiveLuck") or 1
		local focus = player:GetAttribute("RarityFocus") or "MaxLuck"
		local focusText = if focus == "MaxLuck" then "Max Luck" else focus
		focusButton.Text = `Luck {Format.number(luck)}x  |  Focus: {focusText}`
	end
	player:GetAttributeChangedSignal("EffectiveLuck"):Connect(refreshFocus)
	player:GetAttributeChangedSignal("RarityFocus"):Connect(refreshFocus)
	refreshFocus()

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

	RunService.RenderStepped:Connect(function()
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
		-- Spirit Sight hides management UI; scanning itself never stops.
		SetVisible = function(visible: boolean)
			panel.Visible = visible
		end,
	}
end

return HUD

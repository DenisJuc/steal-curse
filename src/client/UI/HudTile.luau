-- Square icon tile for the right side of the HUD (Shop, Gifts, Bounties), in the same style as the
-- left column: the icon fills it, the name straddles the bottom edge, a red dot when something is
-- ready and a small chip (top-left) for a timer. Replaced the text buttons ("GIFT READY!") on
-- 2026-11-08. Stacked down the right edge on desktop, one row under the travel bar on phones.

local Icons = require(script.Parent.Icons)
local Motion = require(script.Parent.Motion)
local UIKit = require(script.Parent.UIKit)

local HudTile = {}

local SIZE = 72
local DESKTOP_TOP = 116
local DESKTOP_STEP = 118
local COMPACT_TOP = 34
local COMPACT_STEP = 84

export type Tile = { Holder: Frame, Button: TextButton, Dot: Frame, Chip: TextLabel, Caption: TextLabel }

-- `slot` is the tile's place in the stack (1 = top on desktop, rightmost on phones).
function HudTile.make(screen: ScreenGui, name: string, slot: number, caption: string, iconKey: string, onActivated: () -> ()): Tile
	local holder = UIKit.create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	UIKit.scaler(holder)
	UIKit.watchCompact(function(compact: boolean)
		holder.Position = if compact
			then UDim2.new(1, -24 - (slot - 1) * COMPACT_STEP, 0, COMPACT_TOP)
			else UDim2.new(1, -40, 0, DESKTOP_TOP + (slot - 1) * DESKTOP_STEP)
	end)
	local button = UIKit.create("TextButton", {
		Name = "Tile",
		Text = "",
		AutoButtonColor = false,
		Parent = holder,
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
	local dot = UIKit.create("Frame", {
		Name = "Ready",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = UIKit.Colors.Red,
		Visible = false,
		ZIndex = 5,
		Parent = button,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UIKit.stroke(UIKit.Colors.Text, 2, 0).Parent = dot
	Motion.badge(dot)
	button.Activated:Connect(onActivated)
	return { Holder = holder, Button = button, Dot = dot, Chip = chip, Caption = label }
end

-- Gold border + shine while something is waiting.
function HudTile.setReady(tile: Tile, ready: boolean)
	if tile.Dot.Visible ~= ready then
		tile.Dot.Visible = ready
		if ready then
			Motion.pop(tile.Dot, 0, 0.2)
		end
	end
	local stroke = tile.Button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if ready then UIKit.Colors.Gold else UIKit.Colors.Trim
		stroke.Thickness = if ready then 3 else 2
	end
end

return HudTile

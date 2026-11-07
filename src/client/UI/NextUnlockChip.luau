-- "Next unlock" chip just above the ROLL bar: "Pedestals unlock in 4 rolls" with a thin progress
-- bar, from HudUnlocks.Next(). It explains the roll-only start: more of the shrine is always on its
-- way. Updates with every check (each roll), moves on when an entry unlocks (HudUnlocks plays the
-- banner) and disappears once everything is open. Sits in the gap under the roll reel.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local HudUnlocks = require(script.Parent.HudUnlocks)
local UIKit = require(script.Parent.UIKit)

local NextUnlockChip = {}

local WIDTH, HEIGHT = 270, 24
local GAP = 3

function NextUnlockChip.Start(screen: ScreenGui, anchor: GuiObject)
	local colors = UIKit.Colors
	local chip = UIKit.create("Frame", {
		Name = "NextUnlockChip",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = colors.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screen,
	}, {
		UIKit.corner(HEIGHT // 2),
		UIKit.stroke(Color3.fromRGB(255, 215, 120), 1, 0.4),
	})
	UIKit.scaler(chip)
	local track = UIKit.create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -24, 0, 3),
		BackgroundColor3 = Color3.fromRGB(60, 50, 80),
		BorderSizePixel = 0,
		Parent = chip,
	}, { UIKit.corner(2) })
	local fill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 215, 120),
		BorderSizePixel = 0,
		Parent = track,
	}, { UIKit.corner(2) })
	local label = UIKit.label({
		Name = "Text",
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, 0, 1, -6),
		TextSize = 15,
		TextColor3 = Color3.fromRGB(245, 235, 210),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = chip,
	})

	RunService.RenderStepped:Connect(function()
		local offset = anchor.AbsolutePosition - screen.AbsolutePosition
		chip.Position = UDim2.fromOffset(offset.X + anchor.AbsoluteSize.X / 2, offset.Y - GAP)
	end)

	local shownId: string? = nil
	local function refresh()
		local nextUnlock = HudUnlocks.Next()
		if not nextUnlock then
			chip.Visible = false
			shownId = nil
			return
		end
		local verb = if string.sub(nextUnlock.Label, -1) == "s" then "unlock" else "unlocks"
		local text = `{nextUnlock.Label} {verb} in {nextUnlock.Remaining} {nextUnlock.Unit}`
		if label.Text ~= text then
			label.Text = text
		end
		if shownId ~= nextUnlock.Id then
			-- A new target: restart the bar from empty.
			fill.Size = UDim2.fromScale(0, 1)
			shownId = nextUnlock.Id
		end
		TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(nextUnlock.Progress, 1) }):Play()
		chip.Visible = true
	end
	HudUnlocks.Changed:Connect(refresh)
end

return NextUnlockChip

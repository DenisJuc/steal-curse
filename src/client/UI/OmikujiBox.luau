-- The lacquered omikuji (fortune) box, drawn from frames: red lacquer with a gold rim, a gold band
-- and the 御籤 mark. The ROLL button (RollBar) and the Omikuji roll style both use it.

local UIKit = require(script.Parent.UIKit)

local OmikujiBox = {}

-- The shape everything below is measured on; other sizes scale from it.
local BASE = Vector2.new(66, 86)

OmikujiBox.Lacquer = Color3.fromRGB(120, 36, 30)

-- The ROLL button's box (set by RollBar). While it is on screen the Omikuji roll shoots its slip
-- out of it instead of drawing a box of its own.
local launcher: GuiObject? = nil

function OmikujiBox.SetLauncher(box: GuiObject?)
	launcher = box
end

-- The launcher box if it is showing right now (Auto Roll hides it), else nil.
function OmikujiBox.Launcher(): GuiObject?
	local current: Instance? = launcher
	if not current or not current:IsDescendantOf(game) then
		return nil
	end
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return nil
		elseif current:IsA("ScreenGui") then
			return if current.Enabled then launcher else nil
		end
		current = current.Parent
	end
	return nil
end

-- A box `size` pixels big in `parent`; its parts sit one ZIndex above `zIndex`. The caller sets
-- AnchorPoint / Position. The rim is the box's UIStroke. `className` "TextButton" makes the box
-- itself clickable.
function OmikujiBox.draw(parent: Instance, size: Vector2, zIndex: number, className: string?): GuiObject
	local colors = UIKit.Colors
	local scale = size.X / BASE.X
	local box = UIKit.create(className or "Frame", {
		Name = "Box",
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = OmikujiBox.Lacquer,
		ZIndex = zIndex,
		Parent = parent,
	}, {
		UIKit.corner(math.round(8 * scale)),
		UIKit.stroke(colors.Gold, 2, 0.1),
		UIKit.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 110, 110)),
		}),
	}) :: GuiObject
	if box:IsA("TextButton") then
		box.Text = ""
		box.AutoButtonColor = false
	end
	UIKit.create("Frame", {
		Name = "Band",
		Position = UDim2.fromOffset(0, math.round(12 * scale)),
		Size = UDim2.new(1, 0, 0, math.max(3, math.round(5 * scale))),
		BackgroundColor3 = colors.Gold,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
		Parent = box,
	})
	UIKit.label({
		Name = "Mark",
		Text = "御\n籤",
		TextSize = math.round(20 * scale),
		TextColor3 = colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, math.round(22 * scale)),
		Size = UDim2.new(1, 0, 1, -math.round(26 * scale)),
		ZIndex = zIndex + 1,
		Parent = box,
	})
	return box
end

return OmikujiBox

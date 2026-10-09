-- Placeholder icons drawn from plain frames (no image assets needed). Each draws into a 48x48 box.

local UIKit = require(script.Parent.UIKit)

local Icons = {}

local function box(parent: Instance): Frame
	return UIKit.create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { UIKit.create("UIScale", { Scale = 0.85 }) })
end

local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, radius: number): Frame
	return UIKit.create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	}, { UIKit.corner(radius) })
end

-- Marble shrine pedestal with a floating spirit orb.
function Icons.pedestal(parent: Instance): Frame
	local icon = box(parent)
	local marble = Color3.fromRGB(215, 210, 228)
	local shade = Color3.fromRGB(165, 158, 185)
	local orb = rect(icon, 17, 1, 14, 14, UIKit.Colors.Accent, 7)
	UIKit.stroke(Color3.fromRGB(220, 190, 255), 2, 0.2).Parent = orb
	rect(icon, 8, 18, 32, 6, marble, 2)
	rect(icon, 15, 24, 18, 16, shade, 1)
	rect(icon, 6, 40, 36, 7, marble, 2)
	return icon
end

-- Cursed lucky flower: five dark petals around a sickly glowing core.
function Icons.cursedFlower(parent: Instance): Frame
	local icon = box(parent)
	local center = Vector2.new(24, 24)
	for index = 0, 4 do
		local angle = math.rad(index * 72)
		local offset = Vector2.new(math.sin(angle), -math.cos(angle)) * 11
		UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X + offset.X, center.Y + offset.Y),
			Size = UDim2.fromOffset(14, 22),
			Rotation = index * 72,
			BackgroundColor3 = Color3.fromRGB(105, 28, 92),
			BorderSizePixel = 0,
			Parent = icon,
		}, {
			UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIKit.stroke(Color3.fromRGB(215, 90, 190), 1.5, 0.1),
		})
	end
	local core = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.fromRGB(170, 255, 95),
		BorderSizePixel = 0,
		Parent = icon,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(Color3.fromRGB(40, 70, 20), 2, 0),
	})
	rect(core, 5, 5, 4, 4, Color3.fromRGB(30, 10, 30), 2)
	return icon
end

-- Relic chest with a gold band and lock.
function Icons.chest(parent: Instance): Frame
	local icon = box(parent)
	local wood = Color3.fromRGB(120, 74, 44)
	local woodDark = Color3.fromRGB(88, 52, 30)
	local gold = UIKit.Colors.Gold
	rect(icon, 5, 10, 38, 14, wood, 6)
	rect(icon, 5, 22, 38, 22, woodDark, 3)
	rect(icon, 5, 21, 38, 3, gold, 1)
	rect(icon, 21, 10, 6, 34, gold, 1)
	local lock = rect(icon, 19, 24, 10, 10, gold, 2)
	rect(lock, 4, 3, 2, 4, woodDark, 1)
	return icon
end

-- Codex: a dark grimoire with a glowing eye sigil.
function Icons.book(parent: Instance): Frame
	local icon = box(parent)
	rect(icon, 10, 6, 30, 38, Color3.fromRGB(232, 222, 200), 3)
	rect(icon, 8, 4, 30, 38, Color3.fromRGB(70, 32, 100), 3)
	rect(icon, 8, 4, 5, 38, Color3.fromRGB(45, 18, 65), 2)
	local eye = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(25, 23),
		Size = UDim2.fromOffset(16, 10),
		BackgroundColor3 = Color3.fromRGB(170, 255, 95),
		BorderSizePixel = 0,
		Parent = icon,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	rect(eye, 6, 2, 4, 6, Color3.fromRGB(30, 10, 30), 2)
	return icon
end

return Icons

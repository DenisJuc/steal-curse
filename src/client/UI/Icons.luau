-- Interface icons. Icons.draw / Icons.inline use the uploaded image from IconAssets when there is
-- one: a full-color painted icon as it is, or a white silhouette tinted gold, both with a soft
-- shadow. Otherwise Icons.draw falls back to the placeholders below, drawn from plain frames into a
-- 48x48 box.

local IconAssets = require(script.Parent.IconAssets)
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

-- Journal: an unrolled parchment scroll with ink lines.
function Icons.scroll(parent: Instance): Frame
	local icon = box(parent)
	local paper = Color3.fromRGB(236, 220, 180)
	local roll = Color3.fromRGB(190, 160, 110)
	local ink = Color3.fromRGB(90, 60, 110)
	rect(icon, 10, 8, 28, 32, paper, 2)
	rect(icon, 6, 4, 36, 8, roll, 4)
	rect(icon, 6, 38, 36, 8, roll, 4)
	rect(icon, 15, 17, 18, 3, ink, 1)
	rect(icon, 15, 23, 14, 3, ink, 1)
	rect(icon, 15, 29, 17, 3, ink, 1)
	return icon
end

-- Skills: a small rune tree, three glowing nodes branching from one root.
function Icons.runeTree(parent: Instance): Frame
	local icon = box(parent)
	local branch = Color3.fromRGB(120, 90, 160)
	local glow = Color3.fromRGB(150, 230, 255)
	local function line(x: number, y: number, length: number, rotation: number)
		UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(4, length),
			Rotation = rotation,
			BackgroundColor3 = branch,
			BorderSizePixel = 0,
			Parent = icon,
		}, { UIKit.corner(2) })
	end
	line(24, 30, 26, 0)
	line(17, 23, 18, -50)
	line(31, 23, 18, 50)
	local function node(x: number, y: number, size: number, color: Color3)
		UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = icon,
		}, {
			UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			UIKit.stroke(Color3.fromRGB(40, 30, 60), 2, 0),
		})
	end
	node(24, 9, 13, glow)
	node(9, 17, 11, UIKit.Colors.Gold)
	node(39, 17, 11, UIKit.Colors.Accent)
	node(24, 43, 10, branch)
	return icon
end

-- Settings: a gear (eight teeth around a ring).
function Icons.gear(parent: Instance): Frame
	local icon = box(parent)
	local metal = Color3.fromRGB(190, 185, 210)
	for index = 0, 3 do
		UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(24, 24),
			Size = UDim2.fromOffset(40, 9),
			Rotation = index * 45,
			BackgroundColor3 = metal,
			BorderSizePixel = 0,
			Parent = icon,
		}, { UIKit.corner(2) })
	end
	local ring = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = metal,
		BorderSizePixel = 0,
		Parent = icon,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = UIKit.Colors.Panel,
		BorderSizePixel = 0,
		Parent = ring,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	return icon
end

-- Rebirth: a jade cycle ring with an arrowhead around a rising spirit flame.
-- Rebirth: a gold ring of two chasing arrows around a spirit flame, shaded like the gold images.
function Icons.rebirth(parent: Instance): Frame
	local icon = box(parent)
	local light, dark = Color3.fromRGB(255, 240, 200), Color3.fromRGB(215, 160, 75)
	local function shade(): UIGradient
		return UIKit.create("UIGradient", { Rotation = 90, Color = ColorSequence.new(light, dark) })
	end
	local ringShadow = UIKit.stroke(Color3.new(0, 0, 0), 5, 0.55)
	UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(25, 26),
		Size = UDim2.fromOffset(38, 38),
		BackgroundTransparency = 1,
		Parent = icon,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }), ringShadow })
	local ringStroke = UIKit.stroke(Color3.new(1, 1, 1), 5, 0)
	shade().Parent = ringStroke
	UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(24, 24),
		Size = UDim2.fromOffset(38, 38),
		BackgroundTransparency = 1,
		Parent = icon,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }), ringStroke })
	-- Arrowheads on the ring at top-right and bottom-left, pointing clockwise: half of a square
	-- (cut along its diagonal by the gradient) whose right-angle corner is the tip.
	for _, spot in { { 38, 9, 180 }, { 10, 39, 0 } } do
		UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(spot[1], spot[2]),
			Size = UDim2.fromOffset(16, 16),
			Rotation = spot[3],
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = icon,
		}, {
			UIKit.create("UIGradient", {
				Rotation = 45,
				Color = ColorSequence.new(light, dark),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(0.501, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	local flame = UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(24, 26),
		Size = UDim2.fromOffset(14, 19),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = icon,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }), shade() })
	rect(flame, 4, 8, 6, 8, Color3.fromRGB(255, 252, 235), 3)
	return icon
end

-- Padlock centered in `parent`, `size` pixels square; `open` lifts the shackle to one side.
function Icons.padlock(parent: Instance, size: number, color: Color3, open: boolean?): Frame
	local icon = UIKit.create("Frame", {
		Name = "Padlock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	UIKit.create("Frame", {
		Name = "Shackle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(if open then 0.66 else 0.5, if open then -0.1 else 0.02),
		Size = UDim2.fromScale(0.52, 0.62),
		BackgroundTransparency = 1,
		Parent = icon,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(color, math.max(2, math.floor(size * 0.12)), 0),
	})
	local body = UIKit.create("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.8, 0.56),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = icon,
	}, { UIKit.corner(math.max(2, math.floor(size * 0.14))) })
	UIKit.create("Frame", {
		Name = "Keyhole",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.16, 0.36),
		BackgroundColor3 = UIKit.Colors.Panel,
		BorderSizePixel = 0,
		Parent = body,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	return icon
end

local DRAWN: { [string]: (Instance) -> Frame } = {
	Shrine = Icons.pedestal,
	Luck = Icons.cursedFlower,
	Codex = Icons.book,
	Journal = Icons.scroll,
	Settings = Icons.gear,
	Backpack = Icons.chest,
	Upgrades = Icons.runeTree,
	Rebirth = Icons.rebirth,
}

-- The image for `key` and whether it is a full-color one (IconAssets.Color) rather than gold.
local function imageId(key: string): (string?, boolean)
	local color = IconAssets.Color[key]
	if color and color ~= "" then
		return color, true
	end
	local gold = IconAssets.Gold[key]
	return if gold and gold ~= "" then gold else nil, false
end

-- Full-color image as it is, over a soft dark shadow, filling `parent`.
local function colorImage(parent: GuiObject, id: string)
	UIKit.create("ImageLabel", {
		Name = "Shadow",
		Image = id,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.55,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	UIKit.create("ImageLabel", {
		Name = "Image",
		Image = id,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
end

-- Gold image with a dark drop shadow, filling `parent`.
local function tintedImage(parent: GuiObject, id: string)
	UIKit.create("ImageLabel", {
		Name = "Shadow",
		Image = id,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	UIKit.create("ImageLabel", {
		Name = "Image",
		Image = id,
		ImageColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}, {
		UIKit.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(215, 160, 75)),
		}),
	})
end

function Icons.has(key: string): boolean
	return imageId(key) ~= nil
end

-- The icon of a square button (top part; the caption sits below it).
function Icons.draw(parent: Instance, key: string): Frame?
	local id, colored = imageId(key)
	if id then
		local icon = box(parent)
		if colored then
			-- Painted icons carry their own outline, so they can fill more of the button.
			(icon:FindFirstChildOfClass("UIScale") :: UIScale).Scale = 1.05
			colorImage(icon, id)
		else
			tintedImage(icon, id)
		end
		return icon
	end
	local drawn = DRAWN[key]
	return if drawn then drawn(parent) else nil
end

-- A small icon left of a text button's label (only when an image is set).
function Icons.inline(button: TextButton, key: string, size: number?): Frame?
	local id, colored = imageId(key)
	if not id then
		return nil
	end
	local pixels = size or 26
	local padding = button:FindFirstChildOfClass("UIPadding")
		or UIKit.create("UIPadding", { Parent = button }) :: UIPadding
	local left = pixels + 14
	padding.PaddingLeft = UDim.new(0, left)
	local icon = UIKit.create("Frame", {
		Name = "InlineIcon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8 - left, 0.5, 0),
		Size = UDim2.fromOffset(pixels, pixels),
		Parent = button,
	})
	if colored then
		colorImage(icon, id)
	else
		tintedImage(icon, id)
	end
	return icon
end

return Icons

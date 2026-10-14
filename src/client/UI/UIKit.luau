-- Shared UI building kit: the "dark mystic shrine" style (ink panels, gold trim, spirit violet),
-- fonts, instance helpers, skinned panels/buttons and screen-size scaling.
-- Style rules:
--   * Panels: plum-to-ink gradient, gold trim with a thin inner line (skinPanel).
--   * Gold means value (CE, maxed, rewards); violet means action; vermilion means danger/close.
--   * Anything that spends CE is a jade "Buy" price button: verb, coin, amount (priceButton).
--     When it can't be afforded it turns dark and pressing it says how much CE is missing.
--   * Headings use TitleFont; numbers and body text use Font.
--   * Every button is juiced by Motion (hover, press, sounds); never animate with raw Size changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local Motion = require(script.Parent.Motion)

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.TitleFont = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

UIKit.Colors = {
	Panel = Color3.fromRGB(17, 13, 24),
	Card = Color3.fromRGB(33, 26, 44),
	Text = Color3.fromRGB(246, 238, 224),
	SubText = Color3.fromRGB(182, 170, 158),
	Accent = Color3.fromRGB(152, 100, 236),
	Track = Color3.fromRGB(11, 9, 15),
	Gold = Color3.fromRGB(240, 194, 104),
	Red = Color3.fromRGB(222, 74, 62),
	Trim = Color3.fromRGB(205, 164, 96),
	Plum = Color3.fromRGB(46, 30, 62),
	Cyan = Color3.fromRGB(130, 220, 255),
	Jade = Color3.fromRGB(62, 170, 108),
}

type Props = { [string]: any }

function UIKit.create(className: string, props: Props?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.corner(radius: number): UICorner
	return UIKit.create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function UIKit.stroke(color: Color3, thickness: number, transparency: number?): UIStroke
	return UIKit.create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.padding(pixels: number): UIPadding
	local amount = UDim.new(0, pixels)
	return UIKit.create("UIPadding", {
		PaddingTop = amount,
		PaddingBottom = amount,
		PaddingLeft = amount,
		PaddingRight = amount,
	})
end

-- Vertical light-to-shade gradient; it multiplies the background color, so recoloring still works.
local function sheen(): UIGradient
	return UIKit.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 165, 180)),
	})
end

-- Rounded text button with hover/press juice and sounds; `onClick` runs on mouse, touch and
-- gamepad activation.
function UIKit.button(props: Props, onClick: (() -> ())?): TextButton
	local button = UIKit.create("TextButton", {
		Font = UIKit.Font,
		TextSize = 14,
		TextColor3 = UIKit.Colors.Text,
		BackgroundColor3 = UIKit.Colors.Accent,
		AutoButtonColor = false,
	}, { UIKit.corner(8), sheen() })
	for key, value in props do
		if key ~= "Parent" then
			(button :: any)[key] = value
		end
	end
	button.Parent = props.Parent
	Motion.button(button)
	if onClick then
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") ~= true then
				onClick()
			end
		end)
	end
	return button
end

function UIKit.label(props: Props): TextLabel
	local defaults: Props = {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextColor3 = UIKit.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	if props.FontFace then
		defaults.Font = nil
	end
	return UIKit.create("TextLabel", defaults)
end

-- Name of a square icon button, straddling its bottom edge with a thick dark outline so it never
-- sits on the icon. Leave room under the button (grid padding) for the lower half.
function UIKit.iconCaption(button: GuiObject, text: string, textSize: number?): TextLabel
	local size = textSize or 15
	local label = UIKit.label({
		Name = "Caption",
		Text = text,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, 20, 0, size + 2),
		ZIndex = 4,
		Parent = button,
	})
	UIKit.create("UIStroke", {
		Color = Color3.fromRGB(18, 10, 26),
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = label,
	})
	return label
end

-- A small value pill on an icon button's top-left corner ("x1.72", "35/92"); hide it when empty.
function UIKit.iconChip(button: GuiObject): TextLabel
	local chip = UIKit.label({
		Name = "Chip",
		Text = "",
		TextSize = 12,
		TextColor3 = UIKit.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0.05,
		BackgroundColor3 = UIKit.Colors.Plum,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(-6, 2),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
		Parent = button,
	})
	UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = chip })
	UIKit.create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = chip })
	UIKit.stroke(UIKit.Colors.Trim, 1, 0.2).Parent = chip
	return chip
end

-- Section heading inside a menu: title font in muted gold.
function UIKit.heading(props: Props): TextLabel
	local merged: Props = { FontFace = UIKit.TitleFont, TextColor3 = UIKit.Colors.Trim, TextSize = 14 }
	for key, value in props do
		merged[key] = value
	end
	return UIKit.label(merged)
end

-- Fixed-size transparent cell for layouts, so whatever bounces inside never shifts its neighbours.
function UIKit.slot(parent: Instance, name: string, size: UDim2, order: number?): Frame
	return UIKit.create("Frame", {
		Name = name,
		LayoutOrder = order or 0,
		Size = size,
		BackgroundTransparency = 1,
		Parent = parent,
	})
end

-- Fills a slot and scales around its center.
function UIKit.fill(gui: GuiObject): GuiObject
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.Position = UDim2.fromScale(0.5, 0.5)
	gui.Size = UDim2.fromScale(1, 1)
	return gui
end

-- The house panel look: plum-to-ink gradient, gold trim and a thin inner line with corner studs.
-- Frames arranged by a layout skip the inner line (it would become a layout item).
function UIKit.skinPanel(frame: GuiObject, trim: Color3?)
	local color = trim or UIKit.Colors.Trim
	frame.BackgroundColor3 = UIKit.Colors.Plum
	frame.BackgroundTransparency = math.min(frame.BackgroundTransparency, 0.04)
	UIKit.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(85, 80, 95)),
		Parent = frame,
	})
	local stroke = frame:FindFirstChildOfClass("UIStroke") or UIKit.create("UIStroke", { Parent = frame })
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if frame:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return
	end
	local corner = frame:FindFirstChildOfClass("UICorner")
	local rounded = corner ~= nil and corner.CornerRadius.Scale > 0
	local radius = if corner then corner.CornerRadius.Offset else 0
	local inner = UIKit.create("Frame", {
		Name = "Trim",
		BackgroundTransparency = 1,
		ZIndex = 0,
		Active = false,
	}, {
		UIKit.create("UICorner", {
			CornerRadius = if rounded and corner then corner.CornerRadius else UDim.new(0, math.max(0, radius - 3)),
		}),
		UIKit.stroke(color, 1, 0.65),
	})
	Motion.cover(inner, frame, 4)
	inner.Parent = frame
	if rounded then
		return
	end
	for _, corner2 in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		UIKit.create("Frame", {
			Name = "Stud",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(corner2.X, if corner2.X == 0 then 2 else -2, corner2.Y, if corner2.Y == 0 then 2 else -2),
			Size = UDim2.fromOffset(7, 7),
			Rotation = 45,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = inner,
		})
	end
end

-- Card look for rows and tiles inside menus: soft sheen and a faint trim edge (an existing stroke,
-- e.g. a tier color, is kept).
function UIKit.skinCard(frame: GuiObject, edge: Color3?)
	if not frame:FindFirstChildOfClass("UIGradient") then
		UIKit.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 145, 160)),
			Parent = frame,
		})
	end
	if not frame:FindFirstChildOfClass("UIStroke") then
		UIKit.stroke(edge or UIKit.Colors.Trim, 1.5, if edge then 0.2 else 0.7).Parent = frame
	end
end

-- Cost buttons: jade when you can pay, dark and refusing ("Need X more CE") when you can't.
function UIKit.setAffordable(button: TextButton, affordable: boolean, cost: number)
	UIKit.skinButton(button, if affordable then "Buy" else "Dark")
	local color = if affordable then UIKit.Colors.Text else UIKit.Colors.SubText
	button.TextColor3 = color
	local price = button:FindFirstChild("Price")
	if price then
		for _, child in price:GetDescendants() do
			if child:IsA("TextLabel") then
				child.TextColor3 = color
			end
		end
	end
	button:SetAttribute("Cost", cost)
	Motion.setDisabled(button, not affordable)
end

-- Button looks: "Primary" (violet action), "Buy" (jade, spends CE), "Gold" (rewards / claim),
-- "Danger" (vermilion, close) and "Dark" (secondary).
function UIKit.skinButton(button: GuiButton, kind: string)
	local colors = UIKit.Colors
	local stroke = button:FindFirstChildOfClass("UIStroke") or UIKit.create("UIStroke", { Parent = button })
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.5
	if kind == "Buy" then
		button.BackgroundColor3 = colors.Jade
		stroke.Color = Color3.fromRGB(20, 70, 42)
		stroke.Transparency = 0.1
	elseif kind == "Danger" then
		button.BackgroundColor3 = colors.Red
		stroke.Color = Color3.fromRGB(96, 22, 18)
		stroke.Transparency = 0.1
	elseif kind == "Gold" then
		button.BackgroundColor3 = colors.Gold
		stroke.Color = Color3.fromRGB(120, 78, 26)
		stroke.Transparency = 0.1
		if button:IsA("TextButton") then
			button.TextColor3 = colors.Panel
		end
	elseif kind == "Dark" then
		button.BackgroundColor3 = colors.Card
		stroke.Color = colors.Trim
		stroke.Transparency = 0.55
	else
		button.BackgroundColor3 = colors.Accent
		stroke.Color = colors.Trim
		stroke.Transparency = 0.35
	end
	if not button:FindFirstChildOfClass("UIGradient") then
		sheen().Parent = button
	end
end

-- A gold "mon" coin (round with a square hole), the CE currency mark.
function UIKit.coin(size: number): Frame
	local coin = UIKit.create("Frame", {
		Name = "Coin",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UIKit.Colors.Gold,
		BorderSizePixel = 0,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.create("UIGradient", {
			Rotation = 60,
			Color = ColorSequence.new(Color3.fromRGB(255, 244, 205), Color3.fromRGB(185, 130, 50)),
		}),
		UIKit.stroke(Color3.fromRGB(110, 70, 20), math.max(1, size / 14), 0),
	})
	UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		BackgroundTransparency = 1,
		Parent = coin,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(Color3.fromRGB(150, 100, 35), 1, 0.3),
	})
	UIKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = UIKit.Colors.Panel,
		BorderSizePixel = 0,
		Parent = coin,
	}, { UIKit.stroke(Color3.fromRGB(110, 70, 20), 1, 0) })
	return coin
end

local function textOutline(): UIStroke
	return UIKit.create("UIStroke", { Color = Color3.fromRGB(14, 10, 20), Thickness = 1.5, Transparency = 0.35 })
end

local function row(parent: Instance, name: string, height: number, padding: number): Frame
	return UIKit.create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		Parent = parent,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, padding),
		}),
	})
end

-- A coin followed by a number on one line (balances, income, prices). Returns the holder (sized to
-- its content) and the number label.
function UIKit.coinValue(parent: Instance, coinSize: number, textSize: number, color: Color3?): (Frame, TextLabel)
	local holder = row(parent, "CoinValue", math.max(coinSize, textSize + 4), 5)
	local coin = UIKit.coin(coinSize)
	coin.LayoutOrder = 1
	coin.Parent = holder
	local label = UIKit.label({
		Name = "Value",
		TextSize = textSize,
		TextColor3 = color or UIKit.Colors.Gold,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = holder,
	})
	textOutline().Parent = label
	return holder, label
end

-- A button that spends CE: "<verb> (coin) <amount>" centered on one line, jade. Keep it current
-- with setPrice and setAffordable. `props.TextSize` sizes the line (default 16).
function UIKit.priceButton(props: Props, verb: string?, cost: number, onClick: (() -> ())?): TextButton
	local button = UIKit.button(props, onClick)
	button.Text = ""
	local textSize = props.TextSize or 16
	local line = row(button, "Price", textSize + 4, 6)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	local verbLabel = UIKit.label({
		Name = "Verb",
		TextSize = textSize,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 1,
		Parent = line,
	})
	textOutline().Parent = verbLabel
	local amount, amountLabel = UIKit.coinValue(line, math.floor(textSize * 1.15), textSize, UIKit.Colors.Text)
	amount.LayoutOrder = 2
	amountLabel.Name = "Amount"
	UIKit.skinButton(button, "Buy")
	UIKit.setPrice(button, verb, cost)
	return button
end

function UIKit.setPrice(button: GuiButton, verb: string?, cost: number)
	local line = button:FindFirstChild("Price")
	if not line then
		return
	end
	local verbLabel = line:FindFirstChild("Verb") :: TextLabel
	verbLabel.Text = verb or ""
	verbLabel.Visible = verb ~= nil and verb ~= ""
	local amount = line:FindFirstChild("Amount", true) :: TextLabel
	amount.Text = Format.number(cost)
	button:SetAttribute("Cost", cost)
end

function UIKit.tween(instance: Instance, seconds: number, goal: Props, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

function UIKit.tierColor(tierId: string): Color3
	local tier = RarityConfig.Get(tierId)
	return if tier then Color3.fromHex(tier.Color) else UIKit.Colors.Text
end

function UIKit.mutationColor(mutationId: string): Color3
	local mutation = MutationConfig.ById[mutationId]
	return if mutation then Color3.fromHex(mutation.Color) else UIKit.Colors.Text
end

local HEADER_HEIGHT = 46

-- Round emblem over the window's top-left corner holding the menu's icon (the same one as its
-- HUD button). Returns nil when there is no icon for `iconKey`.
local function emblem(window: Frame, iconKey: string, accent: Color3): Frame?
	local disc = UIKit.create("Frame", {
		Name = "Emblem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = UIKit.Colors.Plum,
		Parent = window,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 100, 125)),
		}),
		UIKit.stroke(accent, 3, 0),
	})
	-- Icons builds on UIKit, so it is loaded here rather than at the top.
	local Icons = require(script.Parent.Icons) :: any
	local icon = Icons.draw(disc, iconKey)
	if not icon then
		disc:Destroy()
		return nil
	end
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local scale = icon:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 1.05
	end
	return disc
end

-- Centered menu window. It fills most of a small screen (phones) and stops growing at maxSize on
-- big screens, so text never shrinks; content that doesn't fit goes in scrolling frames.
-- Header: the menu's icon in an emblem over the top-left corner (`iconKey`, an Icons key), the
-- title, and a red close button over the top-right corner.
-- Returns the window and the content area below the header.
function UIKit.modal(
	screen: ScreenGui,
	name: string,
	title: string,
	accent: Color3,
	maxSize: Vector2,
	iconKey: string?
): (Frame, Frame)
	local window = UIKit.create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.9),
		BackgroundTransparency = 0.03,
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	}, {
		UIKit.create("UISizeConstraint", { MaxSize = maxSize }),
		UIKit.create("UIScale", { Name = "Juice" }),
		UIKit.corner(14),
		UIKit.padding(10),
	})
	UIKit.skinPanel(window)
	window:SetAttribute("Modal", true)
	local titleX = if iconKey and emblem(window, iconKey, accent) then 54 else 6
	local titleLabel = UIKit.label({
		Name = "Title",
		Text = title,
		FontFace = UIKit.TitleFont,
		TextColor3 = UIKit.Colors.Gold,
		TextScaled = true,
		Position = UDim2.fromOffset(titleX, 4),
		Size = UDim2.new(1, -(titleX + 40), 0, 32),
		Parent = window,
	})
	UIKit.create("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 16, Parent = titleLabel })
	UIKit.create("UIStroke", { Color = Color3.fromRGB(14, 10, 20), Thickness = 2, Transparency = 0.2, Parent = titleLabel })
	UIKit.create("Frame", {
		Name = "TitleRule",
		Position = UDim2.fromOffset(titleX, HEADER_HEIGHT - 6),
		Size = UDim2.new(1, -titleX, 0, 2),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = window,
	}, {
		UIKit.create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.9),
				NumberSequenceKeypoint.new(0.25, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	local close = UIKit.button({
		Name = "Close",
		Text = "X",
		TextSize = 24,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 8, 0, 0),
		Size = UDim2.fromOffset(42, 42),
		Parent = window,
	})
	UIKit.skinButton(close, "Danger")
	close.Activated:Connect(function()
		window.Visible = false
	end)
	local content = UIKit.create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		Parent = window,
	})
	return window, content
end

-- Shows a menu window, cancelling its close animation if one is playing (see MenuMotion).
function UIKit.show(window: GuiObject)
	if window:GetAttribute("Closing") then
		window:SetAttribute("Closing", nil)
	end
	window.Visible = true
end

-- Opens or closes a menu window; returns true when it is now open.
function UIKit.toggle(window: GuiObject): boolean
	local open = not window.Visible or window:GetAttribute("Closing") == true
	if open then
		UIKit.show(window)
	else
		window.Visible = false
	end
	return open
end

-- Vertical scrolling list that grows its canvas with its children.
function UIKit.scrollList(parent: Instance, padding: number): ScrollingFrame
	return UIKit.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		Parent = parent,
	}, {
		UIKit.create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding) }),
	})
end

local function getCamera(): Camera
	local camera = workspace.CurrentCamera
	while not camera do
		task.wait()
		camera = workspace.CurrentCamera
	end
	return camera
end

-- Player's "Interface size" setting (1 = 100%), applied on top of the screen-size scale.
local userScale = 1
local scaleUpdaters: { () -> () } = {}

-- Keeps a panel readable on phones and not oversized on big monitors. Scales around the panel's AnchorPoint.
function UIKit.scaler(panel: GuiObject): UIScale
	local scale = UIKit.create("UIScale", { Parent = panel })
	local camera = getCamera()
	local function update()
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.65, 1.15) * userScale
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	table.insert(scaleUpdaters, update)
	update()
	return scale
end

function UIKit.SetUserScale(scale: number)
	userScale = math.clamp(scale, 0.5, 1.5)
	for _, update in scaleUpdaters do
		update()
	end
end

-- Compact layout for small screens (phones in landscape are about 390 px tall).
local COMPACT_HEIGHT = 520

function UIKit.isCompact(): boolean
	return getCamera().ViewportSize.Y < COMPACT_HEIGHT
end

-- Runs now and whenever the screen switches between compact and normal.
function UIKit.watchCompact(callback: (boolean) -> ())
	local camera = getCamera()
	local last = UIKit.isCompact()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local now = UIKit.isCompact()
		if now ~= last then
			last = now
			callback(now)
		end
	end)
	callback(last)
end

return UIKit

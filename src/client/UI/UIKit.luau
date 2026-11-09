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
local IconAssets = require(script.Parent.IconAssets)
local Motion = require(script.Parent.Motion)

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
-- One font family across the game (the old serif titles made the UI look like two games glued
-- together): titles use the same face as the HUD.
UIKit.TitleFont = Font.fromEnum(Enum.Font.FredokaOne)

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
	-- Action colours (2026-11-08): each kind of button says what it does by colour.
	Coral = Color3.fromRGB(232, 92, 72), -- sell (items leave for CE)
	Azure = Color3.fromRGB(64, 150, 236), -- equip / place
	Mint = Color3.fromRGB(96, 214, 140), -- switch on
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
-- "Sell" (coral, items for CE), "Equip" (azure, place / equip), "Danger" (vermilion, confirm a
-- loss) and "Dark" (secondary).
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
	elseif kind == "Sell" then
		button.BackgroundColor3 = colors.Coral
		stroke.Color = Color3.fromRGB(110, 34, 22)
		stroke.Transparency = 0.1
		if button:IsA("TextButton") then
			button.TextColor3 = colors.Text
		end
	elseif kind == "Equip" then
		button.BackgroundColor3 = colors.Azure
		stroke.Color = Color3.fromRGB(18, 56, 104)
		stroke.Transparency = 0.1
		if button:IsA("TextButton") then
			button.TextColor3 = colors.Text
		end
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

-- The CE currency mark: the Cursed Energy gem image once its id is set, otherwise a gold "mon" coin
-- (round with a square hole).
function UIKit.coin(size: number): Frame
	local gem = IconAssets.Color.CursedEnergy
	if gem and gem ~= "" then
		return UIKit.create("Frame", {
			Name = "Coin",
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
		}, {
			UIKit.create("ImageLabel", {
				Name = "Image",
				Image = gem,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
			}),
		})
	end
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
-- Header: the menu's icon in an emblem over the top-left corner (`iconKey`, an Icons key) and the
-- title. There is no close button: menus close on a click outside, their HUD button, Escape or
-- gamepad B (MenuMotion, GamepadController).
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
		Size = UDim2.new(1, -(titleX + 8), 0, 32),
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
	local content = UIKit.create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
		Parent = window,
	})
	return window, content
end

-- Tab look shared by every tabbed menu: the selected tab is filled gold with dark text, the others
-- are dark cards with readable light text.
UIKit.TAB_HEIGHT = 44
UIKit.TAB_TEXT_SIZE = 18

-- An on/off switch: a pill track with a sliding knob (mint when on). Returns the button and a
-- `set(on)` that restyles it without calling `onToggle`. `onToggle` gets the new value.
function UIKit.switch(parent: Instance, on: boolean, onToggle: (boolean) -> (), props: Props?): (TextButton, (boolean) -> ())
	local colors = UIKit.Colors
	local value = on
	local track = UIKit.create("TextButton", {
		Name = "Switch",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(64, 32),
		BackgroundColor3 = colors.Track,
		Parent = parent,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	for key, v in props or {} do
		(track :: any)[key] = v
	end
	local stroke = UIKit.stroke(colors.Trim, 1.5, 0.5)
	stroke.Parent = track
	local knob = UIKit.create("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = colors.Text,
		ZIndex = (track.ZIndex or 1) + 1,
		Parent = track,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local function set(next: boolean, animate: boolean?)
		value = next
		local goal = {
			Position = if next then UDim2.new(1, -16, 0.5, 0) else UDim2.new(0, 16, 0.5, 0),
			BackgroundColor3 = if next then colors.Text else colors.SubText,
		}
		if animate then
			TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Back), goal):Play()
			TweenService:Create(track, TweenInfo.new(0.16), { BackgroundColor3 = if next then colors.Mint else colors.Track }):Play()
		else
			knob.Position = goal.Position
			knob.BackgroundColor3 = goal.BackgroundColor3
			track.BackgroundColor3 = if next then colors.Mint else colors.Track
		end
		stroke.Color = if next then Color3.fromRGB(30, 96, 58) else colors.Trim
		stroke.Transparency = if next then 0.1 else 0.5
		track:SetAttribute("On", next)
	end
	set(on)
	Motion.button(track)
	track.Activated:Connect(function()
		if track:GetAttribute("Disabled") == true then
			return
		end
		set(not value, true)
		onToggle(value)
	end)
	return track, function(next: boolean)
		if next ~= value then
			set(next, true)
		end
	end
end

function UIKit.skinTab(button: TextButton, selected: boolean)
	UIKit.skinButton(button, if selected then "Gold" else "Dark")
	button.TextColor3 = if selected then UIKit.Colors.Panel else UIKit.Colors.Text
	button.TextTransparency = if selected then 0 else 0.15
	button.TextSize = UIKit.TAB_TEXT_SIZE
	button.Font = UIKit.Font
	button:SetAttribute("Selected", selected)
end

-- A row of equal-width tab pills. `tabs` is a list of { Id, Text }; `onSelect(id)` runs on a tap.
-- Returns the bar, the buttons by id and a `select(id)` that restyles them (it does not call
-- onSelect).
function UIKit.tabBar(
	parent: Instance,
	tabs: { { Id: string, Text: string } },
	selected: string,
	onSelect: (string) -> (),
	props: Props?
): (Frame, { [string]: TextButton }, (string) -> ())
	local bar = UIKit.create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, UIKit.TAB_HEIGHT),
		Parent = parent,
	}, {
		UIKit.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	if props then
		for key, value in props do
			(bar :: any)[key] = value
		end
	end
	local buttons: { [string]: TextButton } = {}
	local count = #tabs
	local function selectTab(id: string)
		for tabId, button in buttons do
			UIKit.skinTab(button, tabId == id)
		end
	end
	for index, tab in tabs do
		buttons[tab.Id] = UIKit.button({
			Name = `{tab.Id}Tab`,
			Text = tab.Text,
			LayoutOrder = index,
			Size = UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0),
			Parent = bar,
		}, function()
			selectTab(tab.Id)
			onSelect(tab.Id)
		end)
	end
	selectTab(selected)
	return bar, buttons, selectTab
end

-- Shows a menu window, cancelling its close animation if one is playing (see MenuMotion).
function UIKit.show(window: GuiObject)
	if window:GetAttribute("Closing") then
		window:SetAttribute("Closing", nil)
	end
	window.Visible = true
end

-- True while any menu window on `screen` is open (closing ones don't count).
function UIKit.anyMenuOpen(screen: Instance): boolean
	for _, child in screen:GetChildren() do
		if child:IsA("GuiObject") and child:GetAttribute("Modal") and child.Visible and not child:GetAttribute("Closing") then
			return true
		end
	end
	return false
end

-- Calls `callback(open)` now and whenever a menu window on `screen` opens or closes, so overlays
-- (toasts, banners, hints) can step out of the way.
function UIKit.watchMenus(screen: Instance, callback: (boolean) -> ())
	local last: boolean? = nil
	local function update()
		local open = UIKit.anyMenuOpen(screen)
		if open ~= last then
			last = open
			callback(open)
		end
	end
	local function watch(child: Instance)
		if child:IsA("GuiObject") and child:GetAttribute("Modal") then
			child:GetPropertyChangedSignal("Visible"):Connect(update)
			child:GetAttributeChangedSignal("Closing"):Connect(update)
		end
	end
	for _, child in screen:GetChildren() do
		watch(child)
	end
	screen.ChildAdded:Connect(function(child)
		task.defer(watch, child)
	end)
	update()
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
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.65, 1.3) * userScale
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	table.insert(scaleUpdaters, update)
	update()
	return scale
end

-- Resting scale for menu windows (MenuMotion springs to it): 1 on a 1280x720 screen, up to
-- 1.25x on big monitors so menu text is not tiny, times the player's interface size.
function UIKit.menuScale(): number
	local viewport = getCamera().ViewportSize
	return math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 1, 1.25) * userScale
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

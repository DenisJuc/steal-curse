-- Shared UI building kit: the "dark mystic shrine" style (ink panels, gold trim, spirit violet),
-- fonts, instance helpers, skinned panels/buttons and screen-size scaling.
-- Style rules:
--   * Panels: plum-to-ink gradient, gold trim with a thin inner line (skinPanel).
--   * Gold means value (CE, maxed, rewards); violet means action; vermilion means danger/refusal.
--   * Headings use TitleFont; numbers and body text use Font.
--   * Every button is juiced by Motion (hover, press, sounds); never animate with raw Size changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

-- Cost buttons: violet when you can pay, dark and refusing ("Need X more CE") when you can't.
function UIKit.setAffordable(button: TextButton, affordable: boolean, cost: number)
	UIKit.skinButton(button, if affordable then "Primary" else "Dark")
	button.TextColor3 = if affordable then UIKit.Colors.Text else UIKit.Colors.SubText
	button:SetAttribute("Cost", cost)
	Motion.setDisabled(button, not affordable)
end

-- Button looks: "Primary" (violet action), "Gold" (rewards / claim), "Dark" (secondary).
function UIKit.skinButton(button: GuiButton, kind: string)
	local colors = UIKit.Colors
	local stroke = button:FindFirstChildOfClass("UIStroke") or UIKit.create("UIStroke", { Parent = button })
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.5
	if kind == "Gold" then
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

-- Centered menu window. It fills most of a small screen (phones) and stops growing at maxSize on
-- big screens, so text never shrinks; content that doesn't fit goes in scrolling frames.
-- Returns the window and the content area below the title bar.
function UIKit.modal(screen: ScreenGui, name: string, title: string, accent: Color3, maxSize: Vector2): (Frame, Frame)
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
	UIKit.label({
		Name = "Title",
		Text = title,
		FontFace = UIKit.TitleFont,
		TextColor3 = UIKit.Colors.Gold,
		TextSize = 20,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -50, 0, 32),
		Parent = window,
	})
	UIKit.create("Frame", {
		Name = "TitleRule",
		Position = UDim2.fromOffset(0, 35),
		Size = UDim2.new(1, 0, 0, 2),
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
		TextSize = 18,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0, 16),
		Size = UDim2.fromOffset(36, 32),
		Parent = window,
	})
	UIKit.skinButton(close, "Dark")
	close.Activated:Connect(function()
		window.Visible = false
	end)
	local content = UIKit.create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
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

-- Shared UI building kit: colors, font, instance helpers and screen-size scaling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)
local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne

UIKit.Colors = {
	Panel = Color3.fromRGB(24, 20, 34),
	Card = Color3.fromRGB(38, 32, 54),
	Text = Color3.fromRGB(245, 240, 255),
	SubText = Color3.fromRGB(180, 170, 200),
	Accent = Color3.fromRGB(170, 110, 255),
	Track = Color3.fromRGB(14, 12, 22),
	Gold = Color3.fromRGB(255, 196, 80),
	Red = Color3.fromRGB(255, 90, 100),
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

-- Rounded text button; `onClick` runs on mouse, touch and gamepad activation.
function UIKit.button(props: Props, onClick: (() -> ())?): TextButton
	local button = UIKit.create("TextButton", {
		Font = UIKit.Font,
		TextSize = 14,
		TextColor3 = UIKit.Colors.Text,
		BackgroundColor3 = UIKit.Colors.Accent,
		AutoButtonColor = true,
	}, { UIKit.corner(8) })
	for key, value in props do
		if key ~= "Parent" then
			(button :: any)[key] = value
		end
	end
	button.Parent = props.Parent
	if onClick then
		button.Activated:Connect(onClick)
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
	return UIKit.create("TextLabel", defaults)
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
		BackgroundColor3 = UIKit.Colors.Panel,
		BackgroundTransparency = 0.03,
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	}, {
		UIKit.create("UISizeConstraint", { MaxSize = maxSize }),
		UIKit.corner(14),
		UIKit.stroke(accent, 2, 0.3),
		UIKit.padding(10),
	})
	window:SetAttribute("Modal", true)
	UIKit.label({
		Name = "Title",
		Text = title,
		TextColor3 = accent,
		TextSize = 18,
		Size = UDim2.new(1, -44, 0, 32),
		Parent = window,
	})
	local close = UIKit.create("TextButton", {
		Name = "Close",
		Text = "X",
		Font = UIKit.Font,
		TextSize = 18,
		TextColor3 = UIKit.Colors.Text,
		BackgroundColor3 = UIKit.Colors.Card,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(36, 32),
		Parent = window,
	}, { UIKit.corner(8) })
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

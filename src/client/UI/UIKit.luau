-- Shared UI building kit: colors, font, instance helpers and screen-size scaling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

-- Keeps a panel readable on phones and not oversized on big monitors. Scales around the panel's AnchorPoint.
function UIKit.scaler(panel: GuiObject): UIScale
	local scale = UIKit.create("UIScale", { Parent = panel })
	local camera = workspace.CurrentCamera
	while not camera do
		task.wait()
		camera = workspace.CurrentCamera
	end
	local function update()
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.65, 1.15)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	return scale
end

return UIKit

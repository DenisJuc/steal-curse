-- Big celebratory banner in the upper middle of the screen, above every menu. It never blocks
-- clicks and fades out on its own; a newer banner replaces an older one.

local UIKit = require(script.Parent.UIKit)

local Banner = {}

local SHOW_SECONDS = 3.5

local frame: Frame? = nil
local titleLabel: TextLabel? = nil
local textLabel: TextLabel? = nil
local stroke: UIStroke? = nil
local showId = 0

function Banner.Start(screen: ScreenGui)
	local colors = UIKit.Colors
	local holder = UIKit.create("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(460, 92),
		BackgroundColor3 = colors.Panel,
		Visible = false,
		ZIndex = 40,
		Parent = screen,
	}, { UIKit.corner(14), UIKit.padding(10) })
	stroke = UIKit.stroke(colors.Gold, 3, 0)
	stroke.Parent = holder
	titleLabel = UIKit.label({
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = holder,
	})
	textLabel = UIKit.label({
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		Parent = holder,
	})
	UIKit.scaler(holder)
	frame = holder
end

function Banner.Show(title: string, text: string, color: Color3)
	local holder, titleText, bodyText, border = frame, titleLabel, textLabel, stroke
	if not holder or not titleText or not bodyText or not border then
		return
	end
	showId += 1
	local myId = showId
	titleText.Text = title
	titleText.TextColor3 = color
	bodyText.Text = text
	border.Color = color
	holder.BackgroundTransparency = 0.05
	titleText.TextTransparency = 0
	bodyText.TextTransparency = 0
	border.Transparency = 0
	holder.Size = UDim2.fromOffset(400, 80)
	holder.Visible = true
	UIKit.tween(holder, 0.25, { Size = UDim2.fromOffset(460, 92) })
	task.delay(SHOW_SECONDS, function()
		if showId ~= myId then
			return
		end
		UIKit.tween(holder, 0.4, { BackgroundTransparency = 1 })
		UIKit.tween(titleText, 0.4, { TextTransparency = 1 })
		UIKit.tween(bodyText, 0.4, { TextTransparency = 1 })
		UIKit.tween(border, 0.4, { Transparency = 1 })
		task.wait(0.45)
		if showId == myId then
			holder.Visible = false
		end
	end)
end

return Banner

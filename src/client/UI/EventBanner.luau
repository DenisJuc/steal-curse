-- World event announcement (Blood Moon, Spirit Storm, Star Fall). Replaced the generic Banner card
-- on 2026-11-08: the event's colour floods in from the screen edges, a full-width band sweeps open
-- across the upper middle, the event icon pops, a big title rises letter-spaced in, the area and
-- effect sit under it, a light streak runs along the band, then everything folds away. Never blocks
-- clicks. Low effects: no streak, no edge flood.

local TweenService = game:GetService("TweenService")

local Icons = require(script.Parent.Icons)
local Settings = require(script.Parent.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local EventBanner = {}

local HOLD = 4.2
local BAND_HEIGHT = 150

local screenGui: ScreenGui? = nil

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function EventBanner.Start(screen: ScreenGui)
	screenGui = screen
end

function EventBanner.Show(title: string, subtitle: string, color: Color3, iconKey: string?)
	local screen = screenGui
	if not screen then
		return
	end
	local low = Settings.LowEffects()

	local root = UIKit.create("Frame", {
		Name = "EventBanner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = screen,
	})
	-- Edge flood: four soft gradients in the event colour.
	local edges = {}
	if not low then
		for _, spec in {
			{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), 270 },
			{ UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.18, 1), UDim2.fromScale(0.82, 0), 180 },
		} do
			local edge = UIKit.create("Frame", {
				Size = spec[1],
				Position = spec[2],
				BackgroundColor3 = color,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 40,
				Parent = root,
			}, {
				UIKit.create("UIGradient", {
					Rotation = spec[3],
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
				}),
			})
			table.insert(edges, edge)
			tween(edge, 0.35, { BackgroundTransparency = 0.45 })
		end
	end

	-- The band.
	local band = UIKit.create("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.27),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.fromRGB(10, 6, 16),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 41,
		Parent = root,
	}, {
		UIKit.create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.18, 0),
				NumberSequenceKeypoint.new(0.82, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	-- Coloured rules along the top and bottom edges of the band.
	for _, y in { 0, 1 } do
		UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, y),
			Position = UDim2.fromScale(0.5, y),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 42,
			Parent = band,
		}, {
			UIKit.create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end

	local icon: ImageLabel? = nil
	if iconKey then
		icon = Icons.image(band, iconKey, 88)
		if icon then
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.new(0.5, 0, 0, 34)
			icon.Size = UDim2.fromOffset(0, 0)
			icon.ZIndex = 43
		end
	end
	local titleLabel = UIKit.label({
		Name = "Title",
		Text = string.upper(title),
		FontFace = UIKit.TitleFont,
		TextSize = 54,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.new(1, 0, 0, 60),
		TextTransparency = 1,
		ZIndex = 43,
		Parent = band,
	})
	local subtitleLabel = UIKit.label({
		Name = "Subtitle",
		Text = subtitle,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(245, 238, 255),
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.new(1, 0, 0, 28),
		TextTransparency = 1,
		ZIndex = 43,
		Parent = band,
	})

	-- Open.
	tween(band, 0.32, { Size = UDim2.new(1, 0, 0, BAND_HEIGHT + 20) }, Enum.EasingStyle.Back)
	task.delay(0.12, function()
		if icon then
			tween(icon, 0.38, { Size = UDim2.fromOffset(72, 72) }, Enum.EasingStyle.Back)
		end
		titleLabel.Position = UDim2.new(0.5, 0, 0, 108)
		tween(titleLabel, 0.4, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0, 92) }, Enum.EasingStyle.Back)
	end)
	task.delay(0.35, function()
		tween(subtitleLabel, 0.3, { TextTransparency = 0 })
	end)
	-- Light streak sweeping along the band.
	if not low then
		task.delay(0.4, function()
			local streak = UIKit.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(-0.2, 0.5),
				Size = UDim2.fromScale(0.18, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				Rotation = 12,
				ZIndex = 44,
				Parent = band,
			}, {
				UIKit.create("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.5, 0.65),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			})
			tween(streak, 0.9, { Position = UDim2.fromScale(1.2, 0.5) }, Enum.EasingStyle.Sine).Completed:Once(function()
				streak:Destroy()
			end)
		end)
	end
	-- Edges ease back to a faint tint while the band holds.
	task.delay(0.6, function()
		for _, edge in edges do
			tween(edge, 1.2, { BackgroundTransparency = 0.8 })
		end
	end)

	-- Close.
	task.delay(HOLD, function()
		tween(titleLabel, 0.2, { TextTransparency = 1 })
		tween(subtitleLabel, 0.2, { TextTransparency = 1 })
		if icon then
			tween(icon, 0.2, { ImageTransparency = 1 })
		end
		for _, edge in edges do
			tween(edge, 0.4, { BackgroundTransparency = 1 })
		end
		tween(band, 0.3, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(function()
			root:Destroy()
		end)
	end)
end

return EventBanner

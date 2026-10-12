-- "Flicker" roll: one relic plate that cycles through relics (quick at first, then slowing, with a
-- rising tick) until it sticks on the result with a punch, a flash and a burst in its tier color.
-- Teasers over-sample rare tiers, so a rare relic often flashes by just before the landing.

local Motion = require(script.Parent.Parent.Motion)
local RollKit = require(script.Parent.RollKit)
local UIKit = require(script.Parent.Parent.UIKit)

local Flicker = {}

local FLICKS_PER_SECOND = 9

function Flicker.new(holder: GuiObject): RollKit.Style
	local colors = UIKit.Colors
	local root = UIKit.create("Frame", {
		Name = "Flicker",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(310, 92),
		Visible = false,
		Parent = holder,
	}, { UIKit.corner(16), UIKit.create("UIScale", { Name = "Juice" }) })
	UIKit.skinPanel(root)
	local stroke = root:FindFirstChildOfClass("UIStroke") :: UIStroke

	local halo = UIKit.create("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = colors.Accent,
		BackgroundTransparency = 0.6,
		ZIndex = 2,
		Parent = root,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.create("UIScale", { Name = "Juice" }),
	})
	local art = UIKit.create("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.15, 1.15),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = halo,
	})
	local nameLabel = UIKit.label({
		Name = "RelicName",
		FontFace = UIKit.TitleFont,
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(96, 16),
		Size = UDim2.new(1, -108, 0, 26),
		ZIndex = 3,
		Parent = root,
	})
	local tierLabel = UIKit.label({
		Name = "Tier",
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(96, 46),
		Size = UDim2.new(1, -108, 0, 20),
		ZIndex = 3,
		Parent = root,
	})

	local cancel: (() -> ())? = nil

	local function paint(info: RollKit.Info, name: string, detail: string, nameColor: Color3)
		RollKit.showRelic(art, info.Id)
		nameLabel.Text = name
		nameLabel.TextColor3 = nameColor
		tierLabel.Text = detail
		tierLabel.TextColor3 = info.Color
		halo.BackgroundColor3 = info.Color
		stroke.Color = info.Color:Lerp(colors.Trim, 0.5)
	end

	local function land(result: RollKit.Info)
		paint(result, result.Name, result.Odds, result.Color)
		stroke.Color = result.Color
		Motion.punch(root, 2 + result.TierIndex * 0.3)
		Motion.punch(halo, 3)
		Motion.flash(root, result.Color, 0.35)
		RollKit.impact(result, halo, halo, root)
	end

	local function stop()
		if cancel then
			cancel()
			cancel = nil
		end
	end

	return {
		Play = function(roll: RollKit.Roll)
			stop()
			RollKit.appear(root)
			local teasers = roll.Teasers
			local count = math.clamp(math.floor(roll.Seconds * FLICKS_PER_SECOND + 0.5), 4, #teasers)
			local first = #teasers - count + 1
			cancel = RollKit.steps(count, roll.Seconds, function(step)
				if step >= count then
					land(roll.Result)
					return
				end
				local info = RollKit.info(teasers[first + step - 1])
				paint(info, info.Name, string.upper(info.TierName), colors.Text)
				Motion.punch(halo, 1 + step / count)
				RollKit.tick(step / count)
			end)
		end,
		Hide = function()
			stop()
			RollKit.shrinkAway(root)
		end,
		Destroy = function()
			stop()
			RollKit.release(root)
			root:Destroy()
		end,
	}
end

return Flicker

-- "Flame" roll: a spirit flame ignites and climbs through the tier colors (Common, Uncommon, ...)
-- until it reaches the result's tier, then bursts and the relic appears inside it. Sometimes it
-- flares one tier too high and sputters back down first (cosmetic; the result never changes).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Motion = require(script.Parent.Parent.Motion)
local RollKit = require(script.Parent.RollKit)
local UIKit = require(script.Parent.Parent.UIKit)

local Flame = {}

local TEASE_CHANCE = 0.4
local OUTER_RADIUS = 40
local INNER_RADIUS = 22
-- Where the flame's round body sits inside the flame box (the tip points up from there).
local BODY_CENTER = Vector2.new(60, 78)

local WHITE = Color3.new(1, 1, 1)

-- A teardrop: a circle plus a 45-degree square whose side corners touch the circle, so the edges
-- meet smoothly and the top corner becomes the flame's tip.
local function drop(parent: GuiObject, radius: number, zIndex: number): { GuiObject }
	local body = UIKit.create("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(BODY_CENTER.X, BODY_CENTER.Y),
		Size = UDim2.fromOffset(radius * 2, radius * 2),
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = parent,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local tip = UIKit.create("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(BODY_CENTER.X, BODY_CENTER.Y - radius * 0.707),
		Size = UDim2.fromOffset(radius, radius),
		Rotation = 45,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = parent,
	})
	return { body, tip }
end

local function tint(parts: { GuiObject }, color: Color3, transparency: number, seconds: number)
	for _, part in parts do
		TweenService:Create(part, TweenInfo.new(seconds), {
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
		}):Play()
	end
end

function Flame.new(holder: GuiObject): RollKit.Style
	local root = UIKit.create("Frame", {
		Name = "Flame",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(320, 176),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = holder,
	}, { UIKit.create("UIScale", { Name = "Juice" }) })

	local flameBox = UIKit.create("Frame", {
		Name = "FlameBox",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(BODY_CENTER.X * 2, 124),
		BackgroundTransparency = 1,
		Parent = root,
	}, { UIKit.create("UIScale", { Name = "Juice" }) })
	local glow = UIKit.create("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(BODY_CENTER.X, BODY_CENTER.Y - 6),
		Size = UDim2.fromOffset(118, 118),
		BackgroundTransparency = 0.82,
		ZIndex = 1,
		Parent = flameBox,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local outer = drop(flameBox, OUTER_RADIUS, 2)
	local inner = drop(flameBox, INNER_RADIUS, 3)
	local core = UIKit.create("Frame", {
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(BODY_CENTER.X, BODY_CENTER.Y + 6),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.1,
		ZIndex = 4,
		Parent = flameBox,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	-- Centered on the flame's body: bursts, sparks and the relic come out of here.
	local heart = UIKit.create("Frame", {
		Name = "Heart",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(BODY_CENTER.X, BODY_CENTER.Y),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = flameBox,
	})
	local art = UIKit.create("Frame", {
		Name = "Art",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.1, 1.1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = heart,
	}, { UIKit.create("UIScale", { Name = "Juice" }) })

	local tierLabel = UIKit.label({
		Name = "Tier",
		FontFace = UIKit.TitleFont,
		TextSize = 20,
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 126),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = root,
	})
	local oddsLabel = UIKit.label({
		Name = "Odds",
		TextSize = 14,
		TextStrokeTransparency = 0.45,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 152),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = root,
	})

	-- The flame never stands still.
	local flicker = RunService.RenderStepped:Connect(function()
		if not root.Visible then
			return
		end
		local t = os.clock()
		local sway = math.sin(t * 7) * 4 + math.sin(t * 13) * 2
		for index, parts in { outer, inner } do
			local radius = if index == 1 then OUTER_RADIUS else INNER_RADIUS
			local tip = parts[2]
			tip.Rotation = 45 + sway
			local stretch = 1 + math.sin(t * (11 + index * 4)) * 0.08
			tip.Size = UDim2.fromOffset(radius * stretch, radius * stretch)
		end
		local pulse = 22 + math.sin(t * 17) * 3
		core.Size = UDim2.fromOffset(pulse, pulse)
		local breathe = 118 + math.sin(t * 5) * 8
		glow.Size = UDim2.fromOffset(breathe, breathe)
	end)

	local cancel: (() -> ())? = nil

	local function setTier(index: number, progress: number, sputter: boolean)
		local color = RollKit.tierColor(index)
		tint(outer, color, 0.08, 0.1)
		tint(inner, color:Lerp(WHITE, 0.55), 0.05, 0.1)
		tint({ glow }, color, 0.8, 0.1)
		tierLabel.Text = string.upper(RollKit.tierName(index))
		tierLabel.TextColor3 = color
		if sputter then
			Motion.shake(flameBox, 120)
			RollKit.tick(progress, 0.6)
		else
			Motion.punch(flameBox, 1 + index * 0.18)
			Motion.punch(tierLabel, 1.2)
			RollKit.tick(progress, 0.75)
			RollKit.sparks(heart, color, 2 + index, 50)
		end
	end

	local function land(result: RollKit.Info)
		art.Visible = true
		RollKit.showRelic(art, result.Id)
		Motion.pop(art, 0, 0.2)
		tint(outer, result.Color, 0.45, 0.15)
		tint(inner, result.Color:Lerp(WHITE, 0.6), 0.75, 0.15)
		core.Visible = false
		tierLabel.Text = result.Name
		tierLabel.TextColor3 = result.Color
		oddsLabel.Text = result.Odds
		oddsLabel.TextColor3 = result.Color:Lerp(WHITE, 0.4)
		Motion.punch(flameBox, 2.5)
		Motion.punch(tierLabel, 2)
		RollKit.impact(result, heart, flameBox)
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
			local result = roll.Result
			-- The tiers the flame climbs through; a tease flares one too high and drops back.
			local ladder = {}
			for index = 1, result.TierIndex do
				table.insert(ladder, index)
			end
			local teased = result.TierIndex < RollKit.TierCount and math.random() < TEASE_CHANCE
			if teased then
				table.insert(ladder, result.TierIndex + 1)
				table.insert(ladder, result.TierIndex)
			end

			art.Visible = false
			core.Visible = true
			oddsLabel.Text = ""
			tierLabel.Text = ""
			local ember = RollKit.tierColor(1):Lerp(Color3.fromRGB(120, 110, 130), 0.5)
			tint(outer, ember, 0.2, 0)
			tint(inner, ember:Lerp(WHITE, 0.5), 0.2, 0)
			tint({ glow }, ember, 0.9, 0)
			RollKit.appear(root)
			Motion.pop(flameBox, 0, 0.3)

			-- Step 1 lights the flame, then one step per rung, then the landing.
			local count = #ladder + 2
			cancel = RollKit.steps(count, roll.Seconds, function(step)
				if step >= count then
					land(result)
				elseif step > 1 then
					local rung = step - 1
					setTier(ladder[rung], step / count, teased and rung == #ladder)
				end
			end)
		end,
		Hide = function()
			stop()
			RollKit.shrinkAway(root)
		end,
		Destroy = function()
			stop()
			flicker:Disconnect()
			RollKit.release(root)
			root:Destroy()
		end,
	}
end

return Flame

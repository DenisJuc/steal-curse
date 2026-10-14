-- "Omikuji" roll (the default): a shrine fortune box rattles, a slip shoots out and a paper fortune
-- unrolls, all in about a third of a second. The box is the ROLL button's own (OmikujiBox launcher)
-- when it is showing; with Auto Roll on the roll draws its own. Then relics flicker on the paper (quick at first,
-- slowing, with a rising tick; rare teasers often flash by just before the end) until the result
-- sticks and a seal in its tier color stamps down.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Motion = require(script.Parent.Parent.Motion)
local OmikujiBox = require(script.Parent.Parent.OmikujiBox)
local RollKit = require(script.Parent.RollKit)
local UIKit = require(script.Parent.Parent.UIKit)

local Omikuji = {}

local PAPER_WIDTH = 290
local PAPER_HEIGHT = 84
local BOX_SIZE = Vector2.new(66, 86)
local SHAKES = 3
-- The draw (rattle, slip, unroll) before the flicker starts; shorter on fast rolls.
local INTRO_SECONDS = 0.32
local FLICKS_PER_SECOND = 9
-- How far the paper's bottom sits above the bottom of the roll: over its own box, or just above
-- the bar when the slip comes out of the ROLL button's box.
local OWN_BOX_LIFT = BOX_SIZE.Y - 18
local LAUNCHER_LIFT = 4
-- The slip grows out of the top of the ROLL button's box up to the paper.
local LAUNCH_SLIP = UDim2.fromOffset(10, 40)

local PAPER = Color3.fromRGB(244, 234, 212)
local INK = Color3.fromRGB(48, 32, 28)
local WOOD = Color3.fromRGB(70, 44, 30)
local BLACK = Color3.new(0, 0, 0)

-- Ink version of a tier color, readable on the paper.
local function ink(color: Color3): Color3
	return color:Lerp(BLACK, 0.35)
end

-- The slip that grows out of the top of the ROLL button's box (made once per box).
local function launcherSlip(launcher: GuiObject): Frame
	local existing = launcher:FindFirstChild("Slip")
	if existing and existing:IsA("Frame") then
		return existing
	end
	local slip = UIKit.create("Frame", {
		Name = "Slip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(10, 0),
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
		Parent = launcher,
	})
	UIKit.create("Frame", {
		Name = "Tip",
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = UIKit.Colors.Red,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = slip,
	})
	return slip
end

function Omikuji.new(holder: GuiObject): RollKit.Style
	local colors = UIKit.Colors
	local root = UIKit.create("Frame", {
		Name = "Omikuji",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(PAPER_WIDTH + 30, 176),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = holder,
	}, { UIKit.create("UIScale", { Name = "Juice" }) })

	local box = OmikujiBox.draw(root, BOX_SIZE, 3)
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.fromScale(0.5, 1)

	-- The slip hides inside the box until it shoots out of the top.
	local slipHidden = UDim2.new(0.5, 0, 1, -12)
	local slipOut = UDim2.new(0.5, 0, 1, -BOX_SIZE.Y + 6)
	local slip = UIKit.create("Frame", {
		Name = "Slip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = slipHidden,
		Size = UDim2.fromOffset(10, 60),
		BackgroundColor3 = PAPER,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = root,
	})
	UIKit.create("Frame", {
		Name = "Tip",
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = colors.Red,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = slip,
	})

	local paper = UIKit.create("Frame", {
		Name = "Paper",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(0, PAPER_HEIGHT),
		BackgroundColor3 = PAPER,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	}, { UIKit.corner(3), UIKit.stroke(WOOD, 2, 0), UIKit.create("UIScale", { Name = "Juice" }) })
	-- Fixed-width content centered in the paper, so unrolling reveals it from the middle out.
	local content = UIKit.create("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, PAPER_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = paper,
	})
	local border = UIKit.create("Frame", {
		Name = "Border",
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.new(1, -28, 1, -10),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = content,
	})
	local borderStroke = UIKit.stroke(colors.Red, 1.5, 0.3)
	borderStroke.Parent = border
	for _, side in { 0, 1 } do
		UIKit.create("Frame", {
			Name = "Rod",
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.fromScale(side, 0),
			Size = UDim2.new(0, 8, 1, 0),
			BackgroundColor3 = WOOD,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = content,
		})
	end
	local art = UIKit.create("Frame", {
		Name = "Art",
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = content,
	})
	local nameLabel = UIKit.label({
		Name = "RelicName",
		FontFace = UIKit.TitleFont,
		TextSize = 17,
		TextColor3 = INK,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Position = UDim2.fromOffset(90, 8),
		Size = UDim2.new(1, -152, 0, 42),
		ZIndex = 6,
		Parent = content,
	})
	local oddsLabel = UIKit.label({
		Name = "Odds",
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(90, 52),
		Size = UDim2.new(1, -152, 0, 18),
		ZIndex = 6,
		Parent = content,
	})
	-- Over the paper's right end, outside its clipping so the stamp can slam in big.
	local seal = UIKit.create("Frame", {
		Name = "Seal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(48, 48),
		Rotation = -12,
		Visible = false,
		ZIndex = 7,
		Parent = root,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.stroke(INK, 2, 0.2),
		UIKit.create("UIScale", { Name = "Juice" }),
	})
	local sealText = UIKit.label({
		Name = "Tier",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.82, 0.4),
		ZIndex = 8,
		Parent = seal,
	})

	-- Glow behind the paper during the hush before a big landing, in the result's tier color.
	local aura = UIKit.create("Frame", {
		Name = "Aura",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(PAPER_WIDTH + 26, PAPER_HEIGHT + 26),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
		Parent = root,
	}, { UIKit.corner(14) })
	-- Same place as the paper, under everything: the landing's light rays turn here.
	local raysAnchor = UIKit.create("Frame", {
		Name = "RaysAnchor",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(PAPER_WIDTH, PAPER_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = root,
	})

	-- The box this roll rattles (its own, or the ROLL button's) and the slip that comes out of it.
	local shaker: GuiObject = box
	local activeSlip: Frame = slip

	-- Puts the paper (and everything lined up with it) `lift` pixels above the roll's bottom.
	local function placePaper(lift: number)
		local centerY = -lift - PAPER_HEIGHT / 2
		paper.Position = UDim2.new(0.5, 0, 1, -lift)
		seal.Position = UDim2.new(0.5, PAPER_WIDTH / 2 - 38, 1, centerY)
		aura.Position = UDim2.new(0.5, 0, 1, centerY)
		raysAnchor.Position = UDim2.new(0.5, 0, 1, centerY)
	end
	placePaper(OWN_BOX_LIFT)

	local ticket = 0
	local cancels: { () -> () } = {}
	local hush: { Connection: RBXScriptConnection, Riser: Sound? }? = nil

	local function endHush()
		local current = hush
		if not current then
			return
		end
		hush = nil
		current.Connection:Disconnect()
		if current.Riser then
			current.Riser:Destroy()
		end
		paper.Rotation = 0
		RollKit.dim(false, 0.2)
		TweenService:Create(aura, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	end

	local function stop()
		ticket += 1
		for _, cancel in cancels do
			cancel()
		end
		table.clear(cancels)
		endHush()
		if activeSlip ~= slip then
			activeSlip.Visible = false
		end
	end

	-- Runs `callback` after `seconds` unless a newer roll (or Hide) came first.
	local function at(seconds: number, callback: () -> ())
		local myTicket = ticket
		task.delay(seconds, function()
			if ticket == myTicket then
				callback()
			end
		end)
	end

	-- Writes a relic on the paper (a teaser while flickering, or the result).
	local function write(info: RollKit.Info, detail: string)
		RollKit.showRelic(art, info.Id)
		nameLabel.Text = info.Name
		oddsLabel.Text = detail
		oddsLabel.TextColor3 = ink(info.Color)
		borderStroke.Color = ink(info.Color)
	end

	-- The hush before a big landing: the relic hides behind "???", the world dims, the paper
	-- trembles harder and harder inside a pulsing aura of the result's color, heartbeats quicken.
	local function startHush(result: RollKit.Info, seconds: number)
		art.Visible = false
		nameLabel.Text = "? ? ?"
		oddsLabel.Text = ""
		borderStroke.Color = ink(result.Color)
		aura.BackgroundColor3 = result.Color
		aura.BackgroundTransparency = 0.6
		aura.Visible = true
		RollKit.dim(true, 0.25)
		Motion.punch(paper, 1.5)
		local start = os.clock()
		local connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - start
			local build = math.clamp(t / seconds, 0, 1)
			paper.Rotation = math.noise(t * 30, 0.5) * (1 + build * 4)
			aura.BackgroundTransparency = 0.6 - build * 0.25 + math.sin(t * (10 + build * 14)) * 0.15
		end)
		hush = { Connection = connection, Riser = Sounds.Play("BindRiser") }
		local beats = 2 + (result.TierIndex - 4)
		for beat = 1, beats do
			-- Quicker and quicker: each gap shorter than the one before.
			at(seconds * (1 - (1 - beat / (beats + 1)) ^ 1.6), function()
				RollKit.tick(beat / beats, 0.55)
				Motion.punch(paper, 0.6 + beat * 0.15)
			end)
		end
	end

	local function land(result: RollKit.Info)
		endHush()
		art.Visible = true
		write(result, result.Odds)
		local stamp = 48 + math.max(0, result.TierIndex - 4) * 6
		seal.Size = UDim2.fromOffset(stamp, stamp)
		seal.Visible = true
		seal.BackgroundColor3 = result.Color
		sealText.Text = string.upper(result.TierName)
		local rainbow = seal:FindFirstChild("Rainbow")
		if rainbow then
			rainbow:Destroy()
		end
		if result.TierIndex >= RollKit.TierCount then
			seal.BackgroundColor3 = Color3.new(1, 1, 1)
			RollKit.rainbow(seal)
		end
		Motion.pop(seal, 0, 2.4 + math.max(0, result.TierIndex - 4) * 0.3)
		Motion.punch(paper, 1.6 + result.TierIndex * 0.25)
		Motion.punch(art, 3)
		Motion.flash(paper, result.Color, 0.4)
		Motion.shake(shaker, 60 + result.TierIndex * 10)
		RollKit.impact(result, seal, raysAnchor, paper)
	end

	return {
		Play = function(roll: RollKit.Roll)
			stop()
			local result = roll.Result
			local seconds = roll.Seconds
			local teasers = roll.Teasers
			-- Quick draw (rattle, slip, unroll), then the relics flicker on the open paper.
			local suspense = roll.Suspense
			local intro = math.min(INTRO_SECONDS, (seconds - suspense) * 0.35)
			local flickerSeconds = seconds - suspense - intro

			art.Visible = true
			aura.Visible = false
			write(RollKit.info(teasers[1]), "")
			paper.Visible = false
			paper.Size = UDim2.fromOffset(0, PAPER_HEIGHT)
			seal.Visible = false
			local launcher = OmikujiBox.Launcher()
			box.Visible = launcher == nil
			shaker = launcher or box
			placePaper(if launcher then LAUNCHER_LIFT else OWN_BOX_LIFT)
			activeSlip = if launcher then launcherSlip(launcher) else slip
			if launcher then
				activeSlip.Size = UDim2.fromOffset(10, 0)
			else
				slip.Position = slipHidden
			end
			activeSlip.Visible = true
			RollKit.appear(root)

			table.insert(
				cancels,
				RollKit.steps(SHAKES, intro * 0.5, function(step)
					Motion.shake(shaker, 60 + step * 30)
					RollKit.tick(step / SHAKES, 0.7)
				end)
			)
			at(intro * 0.45, function()
				TweenService:Create(
					activeSlip,
					TweenInfo.new(intro * 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					if activeSlip == slip then { Position = slipOut } else { Size = LAUNCH_SLIP }
				):Play()
			end)
			at(intro * 0.7, function()
				activeSlip.Visible = false
				paper.Visible = true
				TweenService:Create(
					paper,
					TweenInfo.new(intro * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.fromOffset(PAPER_WIDTH, PAPER_HEIGHT) }
				):Play()
			end)
			at(intro, function()
				local count = math.clamp(math.floor(flickerSeconds * FLICKS_PER_SECOND + 0.5), 4, #teasers)
				local first = #teasers - count + 1
				table.insert(
					cancels,
					RollKit.steps(count, flickerSeconds, function(step)
						if step >= count then
							if suspense > 0 then
								startHush(result, suspense)
								at(suspense, function()
									land(result)
								end)
							else
								land(result)
							end
							return
						end
						local info = RollKit.info(teasers[first + step - 1])
						write(info, string.upper(info.TierName))
						Motion.punch(art, 1 + step / count)
						RollKit.tick(step / count)
					end)
				)
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

return Omikuji

-- Screen-space crossing into (and out of) the spirit world when Spirit Sight toggles. Nothing
-- here touches the character or the camera: it is a ScreenGui plus two Lighting effects.
--
-- Entering (about half a second): the eyes shut fast (two lids with a violet glowing rim meet in
-- the middle while the view blurs), the world turns over behind them (the caller's `onCovered`
-- switches the spirit tint on there), then the lids tear open on a violet flash with a ripple
-- ring rushing outward and the blur clearing. A dark violet veil stays on the screen edges,
-- slowly breathing, for as long as Spirit Sight is on.
-- Leaving is a shorter half-blink that drops the veil and lets the colour flood back.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)

local SightTransition = {}

local RIM_COLOR = Color3.fromRGB(190, 140, 255)
local LID_COLOR = Color3.fromRGB(6, 2, 14)
local VEIL_COLOR = Color3.fromRGB(28, 6, 52)
local FLASH_TINT = Color3.fromRGB(200, 170, 255)

-- Seconds for each phase of entering.
local CLOSE_SECONDS = 0.09
local HOLD_SECONDS = 0.05
local OPEN_SECONDS = 0.32
-- Leaving: the lids only close part way.
local EXIT_CLOSE_SECONDS = 0.07
local EXIT_OPEN_SECONDS = 0.2
local EXIT_CLOSE_AMOUNT = 0.8
local BLUR_SIZE = 22
-- Fraction of the screen each edge of the veil covers.
local VEIL_DEPTH = 0.22

local gui: ScreenGui? = nil
-- The veil lives in its own ScreenGui under the HUD so it never darkens buttons.
local veilGui: ScreenGui
local topLid: Frame
local bottomLid: Frame
local ripple: Frame
local rippleStroke: UIStroke
local veilEdges: { Frame } = {}
local blur: BlurEffect
local flash: ColorCorrectionEffect
local veilOn = false
local veilAmount = 0
local lidAmount = 0
-- Bumped on every toggle so a quick re-press cuts the running transition short.
local token = 0

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

local function easeIn(t: number): number
	return t * t
end

-- A lid covers half the screen plus a little overlap; its rim glows along the inner edge.
local function makeLid(name: string, top: boolean, parent: Instance): Frame
	local lid = Instance.new("Frame")
	lid.Name = name
	lid.AnchorPoint = Vector2.new(0, if top then 1 else 0)
	lid.Size = UDim2.fromScale(1, 0.56)
	lid.BackgroundColor3 = LID_COLOR
	lid.BorderSizePixel = 0
	lid.ZIndex = 3
	lid.Parent = parent

	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	rim.Position = UDim2.fromScale(0, if top then 1 else 0)
	rim.Size = UDim2.new(1, 0, 0, 36)
	rim.BackgroundColor3 = RIM_COLOR
	rim.BorderSizePixel = 0
	rim.ZIndex = 4
	rim.Parent = lid
	local fade = Instance.new("UIGradient")
	fade.Rotation = if top then 90 else -90
	-- Bright at the lid's edge, fading out into the open screen.
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.25, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = rim
	return lid
end

-- One edge of the veil: solid at the screen edge, fading toward the middle.
local function makeEdge(name: string, rotation: number, anchor: Vector2, position: UDim2, size: UDim2, parent: Instance): Frame
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.AnchorPoint = anchor
	edge.Position = position
	edge.Size = size
	edge.BackgroundColor3 = VEIL_COLOR
	edge.BorderSizePixel = 0
	edge.BackgroundTransparency = 0
	edge.ZIndex = 1
	edge.Parent = parent
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.6, 0.75),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	gradient.Parent = edge
	return edge
end

local function build(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "SpiritSightTransition"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	-- Above the HUD so the blink covers everything, below nothing the player must click.
	screen.DisplayOrder = 90
	screen.Enabled = false
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	topLid = makeLid("TopLid", true, screen)
	bottomLid = makeLid("BottomLid", false, screen)

	ripple = Instance.new("Frame")
	ripple.Name = "Ripple"
	ripple.AnchorPoint = Vector2.new(0.5, 0.5)
	ripple.Position = UDim2.fromScale(0.5, 0.5)
	ripple.SizeConstraint = Enum.SizeConstraint.RelativeXX
	ripple.BackgroundTransparency = 1
	ripple.ZIndex = 2
	ripple.Visible = false
	ripple.Parent = screen
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = ripple
	rippleStroke = Instance.new("UIStroke")
	rippleStroke.Color = RIM_COLOR
	rippleStroke.Thickness = 10
	rippleStroke.Parent = ripple

	veilGui = Instance.new("ScreenGui")
	veilGui.Name = "SpiritSightVeil"
	veilGui.IgnoreGuiInset = true
	veilGui.ResetOnSpawn = false
	veilGui.DisplayOrder = -1
	veilGui.Parent = screen.Parent
	-- Gradient rotation points from transparent (0) to solid (1): toward each screen edge.
	veilEdges = {
		makeEdge("VeilTop", -90, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, VEIL_DEPTH), veilGui),
		makeEdge("VeilBottom", 90, Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, VEIL_DEPTH), veilGui),
		makeEdge("VeilLeft", 180, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(VEIL_DEPTH * 0.7, 1), veilGui),
		makeEdge("VeilRight", 0, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(VEIL_DEPTH * 0.7, 1), veilGui),
	}
	for _, edge in veilEdges do
		edge.Visible = false
	end

	blur = Instance.new("BlurEffect")
	blur.Name = "SpiritSightBlur"
	blur.Size = 0
	blur.Enabled = false
	blur.Parent = Lighting

	flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "SpiritSightFlash"
	flash.Enabled = false
	flash.Parent = Lighting
	return screen
end

local function ensure(): ScreenGui
	if not gui or not gui.Parent then
		gui = build()
	end
	return gui :: ScreenGui
end

-- closed 0 = lids fully open (off screen), 1 = shut.
local function setLids(closed: number)
	lidAmount = closed
	topLid.Position = UDim2.fromScale(0, closed * 0.56)
	bottomLid.Position = UDim2.fromScale(0, 1 - closed * 0.56)
	topLid.Visible = closed > 0.001
	bottomLid.Visible = closed > 0.001
end

local function setVeil(amount: number)
	veilAmount = amount
	for _, edge in veilEdges do
		edge.BackgroundTransparency = 1 - amount
		edge.Visible = amount > 0.01
	end
end

local function setFlash(amount: number, tint: Color3)
	flash.Enabled = amount > 0.001
	flash.Brightness = 0.35 * amount
	flash.Contrast = 0.25 * amount
	flash.Saturation = 0.2 * amount
	flash.TintColor = Color3.new(1, 1, 1):Lerp(tint, amount)
end

-- Runs `step(elapsed)` every frame until it returns true or a newer toggle took over.
local function animate(mine: number, step: (number) -> boolean)
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if mine ~= token then
			connection:Disconnect()
			return
		end
		if step(os.clock() - start) then
			connection:Disconnect()
		end
	end)
end

local breathing: RBXScriptConnection? = nil

local function startBreathing()
	if breathing then
		return
	end
	local start = os.clock()
	breathing = RunService.RenderStepped:Connect(function()
		if not veilOn or not gui then
			return
		end
		-- The veil swells slowly, like the world breathing around you.
		local swell = 0.88 + math.sin((os.clock() - start) * 1.6) * 0.12
		for _, edge in veilEdges do
			edge.BackgroundTransparency = 1 - veilAmount * swell
		end
	end)
end

-- Plays the crossing into the spirit world. `onCovered` runs once the eyes are shut (or at once
-- if the transition is skipped), which is where the caller swaps the world's look.
function SightTransition.Enter(onCovered: () -> ())
	token += 1
	local mine = token
	local screen = ensure()
	screen.Enabled = true
	local low = Settings.LowEffects()
	local covered = false
	local function cover()
		if not covered then
			covered = true
			onCovered()
		end
	end
	veilOn = true
	startBreathing()
	local fromVeil = veilAmount

	local total = CLOSE_SECONDS + HOLD_SECONDS + OPEN_SECONDS
	blur.Enabled = not low
	animate(mine, function(t)
		if t < CLOSE_SECONDS then
			local k = easeIn(t / CLOSE_SECONDS)
			setLids(k)
			blur.Size = BLUR_SIZE * k
			return false
		end
		cover()
		if t < CLOSE_SECONDS + HOLD_SECONDS then
			setLids(1)
			blur.Size = BLUR_SIZE
			setFlash(1, FLASH_TINT)
			return false
		end
		local k = math.min(1, (t - CLOSE_SECONDS - HOLD_SECONDS) / OPEN_SECONDS)
		local open = easeOut(k)
		setLids(1 - open)
		blur.Size = BLUR_SIZE * (1 - open)
		setFlash(1 - open, FLASH_TINT)
		setVeil(fromVeil + (1 - fromVeil) * open)
		if not low then
			ripple.Visible = k < 1
			ripple.Size = UDim2.fromScale(0.15 + open * 1.5, 0.15 + open * 1.5)
			rippleStroke.Thickness = 12 * (1 - k) + 1
			rippleStroke.Transparency = k
		end
		if t >= total then
			setLids(0)
			ripple.Visible = false
			blur.Enabled = false
			flash.Enabled = false
			return true
		end
		return false
	end)
end

-- Plays the way back out. `onCovered` runs at the bottom of the half-blink.
function SightTransition.Exit(onCovered: () -> ())
	token += 1
	local mine = token
	if not gui then
		onCovered()
		return
	end
	local covered = false
	local function cover()
		if not covered then
			covered = true
			onCovered()
		end
	end
	veilOn = false
	ripple.Visible = false
	local fromVeil = veilAmount
	-- A press mid-enter starts from wherever the lids and blur already are.
	local fromLids = lidAmount
	local peak = math.max(fromLids, EXIT_CLOSE_AMOUNT)
	local fromBlur = if blur.Enabled then blur.Size else 0
	local total = EXIT_CLOSE_SECONDS + EXIT_OPEN_SECONDS
	animate(mine, function(t)
		if t < EXIT_CLOSE_SECONDS then
			local k = t / EXIT_CLOSE_SECONDS
			setLids(fromLids + (peak - fromLids) * easeIn(k))
			blur.Size = fromBlur * (1 - k)
			return false
		end
		cover()
		local k = math.min(1, (t - EXIT_CLOSE_SECONDS) / EXIT_OPEN_SECONDS)
		local open = easeOut(k)
		setLids(peak * (1 - open))
		setVeil(fromVeil * (1 - open))
		blur.Enabled = false
		-- Colour floods back: a brief warm, saturated lift that settles to normal.
		flash.Enabled = k < 1
		flash.Saturation = 0.35 * (1 - open)
		flash.Brightness = 0.08 * (1 - open)
		flash.Contrast = 0
		flash.TintColor = Color3.new(1, 1, 1)
		if t >= total then
			setLids(0)
			setVeil(0)
			flash.Enabled = false
			blur.Enabled = false
			if gui then
				gui.Enabled = false
			end
			return true
		end
		return false
	end)
end

return SightTransition

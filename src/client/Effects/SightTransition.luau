-- Screen-space crossing into (and out of) the spirit world when Spirit Sight toggles. Nothing
-- here touches the character or the camera: it is two ScreenGuis plus two Lighting effects.
--
-- Entering (about 0.6s): vision softly dims in from the edges (the feathered edge veil deepens
-- while a dark violet wash fades over the whole screen and the view blurs), the world turns over
-- at the darkest moment (the caller's `onCovered` switches the spirit tint on there), then it
-- clears on a soft violet flash with a faint ripple ring and the blur lifting. A dark violet veil
-- stays on the screen edges, slowly breathing, for as long as Spirit Sight is on.
-- Leaving is a shorter, lighter dim that drops the veil and lets the colour flood back.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)

local SightTransition = {}

local DIM_COLOR = Color3.fromRGB(20, 6, 40)
local VEIL_COLOR = Color3.fromRGB(28, 6, 52)
local RING_COLOR = Color3.fromRGB(190, 140, 255)
local FLASH_TINT = Color3.fromRGB(200, 170, 255)

-- Seconds for each phase of entering.
local DIM_SECONDS = 0.2
local HOLD_SECONDS = 0.05
local OPEN_SECONDS = 0.35
-- Leaving: a lighter dim, then clear.
local EXIT_DIM_SECONDS = 0.12
local EXIT_OPEN_SECONDS = 0.23
local EXIT_DIM_AMOUNT = 0.4
local BLUR_SIZE = 18
-- Fraction of the screen each edge of the veil covers at rest, and at the darkest moment.
local VEIL_DEPTH = 0.22
local DIM_DEPTH = 0.6
-- The full-screen wash never goes fully black.
local WASH_OPACITY = 0.85

local gui: ScreenGui? = nil
-- The veil lives in its own ScreenGui under the HUD so it never darkens buttons at rest.
local veilGui: ScreenGui
local wash: Frame
local ripple: Frame
local rippleStroke: UIStroke
local veilEdges: { Frame } = {}
local blur: BlurEffect
local flash: ColorCorrectionEffect
local veilOn = false
-- veilAmount: the resting edge veil (0..1). dimAmount: how far vision has dimmed in (0..1).
local veilAmount = 0
local dimAmount = 0
local swell = 1
-- Bumped on every toggle so a quick re-press cuts the running transition short.
local token = 0

local function easeInOut(t: number): number
	return 0.5 - math.cos(math.pi * t) * 0.5
end

local function easeOut(t: number): number
	return math.sin(t * math.pi * 0.5)
end

-- One edge of the veil: solid at the screen edge, fading toward the middle.
local function makeEdge(name: string, rotation: number, anchor: Vector2, parent: Instance): Frame
	local edge = Instance.new("Frame")
	edge.Name = name
	edge.AnchorPoint = anchor
	edge.Position = UDim2.fromScale(anchor.X, anchor.Y)
	edge.BackgroundColor3 = VEIL_COLOR
	edge.BorderSizePixel = 0
	edge.Visible = false
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
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "SpiritSightTransition"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	-- Above the HUD so the dim covers everything, below nothing the player must click.
	screen.DisplayOrder = 90
	screen.Enabled = false
	screen.Parent = playerGui

	wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundColor3 = DIM_COLOR
	wash.BackgroundTransparency = 1
	wash.BorderSizePixel = 0
	wash.Visible = false
	wash.ZIndex = 1
	wash.Parent = screen

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
	rippleStroke.Color = RING_COLOR
	rippleStroke.Thickness = 3
	rippleStroke.Parent = ripple

	veilGui = Instance.new("ScreenGui")
	veilGui.Name = "SpiritSightVeil"
	veilGui.IgnoreGuiInset = true
	veilGui.ResetOnSpawn = false
	veilGui.DisplayOrder = -1
	veilGui.Parent = playerGui
	-- Gradient rotation points from transparent (0) to solid (1): toward each screen edge.
	veilEdges = {
		makeEdge("VeilTop", -90, Vector2.new(0, 0), veilGui),
		makeEdge("VeilBottom", 90, Vector2.new(0, 1), veilGui),
		makeEdge("VeilLeft", 180, Vector2.new(0, 0), veilGui),
		makeEdge("VeilRight", 0, Vector2.new(1, 0), veilGui),
	}

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

-- Draws the veil and wash from veilAmount, dimAmount and the breathing swell.
local function render()
	local depth = VEIL_DEPTH + (DIM_DEPTH - VEIL_DEPTH) * dimAmount
	local opacity = math.max(veilAmount * swell, dimAmount)
	for index, edge in veilEdges do
		local side = index > 2
		edge.Size = if side then UDim2.fromScale(depth * 0.7, 1) else UDim2.fromScale(1, depth)
		edge.BackgroundTransparency = 1 - opacity
		edge.Visible = opacity > 0.01
	end
	wash.BackgroundTransparency = 1 - WASH_OPACITY * dimAmount
	wash.Visible = dimAmount > 0.001
end

local function setDim(amount: number, blurOn: boolean)
	dimAmount = amount
	blur.Size = if blurOn then BLUR_SIZE * amount else 0
	render()
end

local function setFlash(amount: number, tint: Color3)
	flash.Enabled = amount > 0.001
	flash.Brightness = 0.25 * amount
	flash.Contrast = 0.15 * amount
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
		swell = 0.88 + math.sin((os.clock() - start) * 1.6) * 0.12
		render()
	end)
end

-- Plays the crossing into the spirit world. `onCovered` runs at the darkest moment, which is
-- where the caller swaps the world's look.
function SightTransition.Enter(onCovered: () -> ())
	token += 1
	local mine = token
	local screen = ensure()
	screen.Enabled = true
	local blurOn = not Settings.LowEffects()
	local covered = false
	local function cover()
		if not covered then
			covered = true
			onCovered()
		end
	end
	veilOn = true
	startBreathing()
	-- A press mid-exit starts from wherever the dim and veil already are.
	local fromVeil = veilAmount
	local fromDim = dimAmount
	blur.Enabled = blurOn

	local total = DIM_SECONDS + HOLD_SECONDS + OPEN_SECONDS
	animate(mine, function(t)
		if t < DIM_SECONDS then
			setDim(fromDim + (1 - fromDim) * easeInOut(t / DIM_SECONDS), blurOn)
			return false
		end
		cover()
		if t < DIM_SECONDS + HOLD_SECONDS then
			setDim(1, blurOn)
			setFlash(easeInOut((t - DIM_SECONDS) / HOLD_SECONDS) * 0.6, FLASH_TINT)
			return false
		end
		local k = math.min(1, (t - DIM_SECONDS - HOLD_SECONDS) / OPEN_SECONDS)
		local open = easeInOut(k)
		veilAmount = fromVeil + (1 - fromVeil) * open
		setDim(1 - open, blurOn)
		-- The flash peaks just as vision clears, then settles.
		setFlash(math.sin(math.min(1, k * 1.6 + 0.3) * math.pi) * 0.6 + (1 - k) * 0.2, FLASH_TINT)
		if blurOn then
			ripple.Visible = k < 1
			ripple.Size = UDim2.fromScale(0.2 + easeOut(k) * 1.3, 0.2 + easeOut(k) * 1.3)
			rippleStroke.Thickness = 3 * (1 - k) + 1
			rippleStroke.Transparency = 0.45 + 0.55 * k
		end
		if t >= total then
			veilAmount = 1
			setDim(0, false)
			ripple.Visible = false
			blur.Enabled = false
			flash.Enabled = false
			return true
		end
		return false
	end)
end

-- Plays the way back out. `onCovered` runs at the bottom of the dim.
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
	swell = 1
	ripple.Visible = false
	-- A press mid-enter starts from wherever the dim, veil and blur already are.
	local fromVeil = veilAmount
	local fromDim = dimAmount
	local peak = math.max(fromDim, EXIT_DIM_AMOUNT)
	local blurOn = blur.Enabled
	local total = EXIT_DIM_SECONDS + EXIT_OPEN_SECONDS
	animate(mine, function(t)
		if t < EXIT_DIM_SECONDS then
			setDim(fromDim + (peak - fromDim) * easeInOut(t / EXIT_DIM_SECONDS), blurOn)
			return false
		end
		cover()
		local k = math.min(1, (t - EXIT_DIM_SECONDS) / EXIT_OPEN_SECONDS)
		local open = easeInOut(k)
		veilAmount = fromVeil * (1 - open)
		setDim(peak * (1 - open), blurOn)
		-- Colour floods back: a brief saturated lift that settles to normal.
		flash.Enabled = k < 1
		flash.Saturation = 0.3 * (1 - open)
		flash.Brightness = 0.06 * (1 - open)
		flash.Contrast = 0
		flash.TintColor = Color3.new(1, 1, 1)
		if t >= total then
			veilAmount = 0
			setDim(0, false)
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

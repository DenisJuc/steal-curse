-- Shared pieces of the roll styles (Flicker, Flame, Omikuji). RollReel builds the style picked in
-- the "RollStyle" setting and calls Play for each roll; every style lands exactly at `seconds`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RarityConfig = require(ReplicatedStorage.Shared.RarityConfig)
local ReelStrip = require(ReplicatedStorage.Shared.ReelStrip)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local HuntFX = require(script.Parent.Parent.Parent.Effects.HuntFX)
local Settings = require(script.Parent.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Motion = require(script.Parent.Parent.Motion)
local Odds = require(script.Parent.Parent.Odds)
local RelicViewport = require(script.Parent.Parent.RelicViewport)
local Spring = require(script.Parent.Parent.Spring)
local UIKit = require(script.Parent.Parent.UIKit)

local RollKit = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
-- Tier index where the big effects start.
local LEGENDARY = 5
-- Seconds of hush added before landing, by tier index (Legendary and up).
local SUSPENSE = { 0, 0, 0, 0, 0.45, 0.7, 0.95, 1.2 }

export type Info = {
	Id: string,
	Name: string,
	TierName: string,
	TierIndex: number,
	Color: Color3,
	Odds: string,
}

export type Roll = {
	Result: Info,
	-- Relic ids to cycle through; the last one is the result.
	Teasers: { string },
	-- Whole roll, landing at the end.
	Seconds: number,
	-- The last part of Seconds is a hush before a big landing (0 below Legendary).
	Suspense: number,
}

export type Style = {
	Play: (roll: Roll) -> (),
	Hide: () -> (),
	Destroy: () -> (),
}

RollKit.TierCount = #RarityConfig.Tiers

-- Display info for a relic (with the mutation's name, color and odds when given).
function RollKit.info(relicId: string, mutation: string?): Info
	local relic = RelicConfig.ById[relicId]
	local tier = relic and RarityConfig.Get(relic.Tier)
	local color = if mutation
		then UIKit.mutationColor(mutation)
		elseif relic then UIKit.tierColor(relic.Tier)
		else UIKit.Colors.Text
	return {
		Id = relicId,
		Name = Odds.displayName(relicId, mutation),
		TierName = if tier then tier.Name else "",
		TierIndex = if relic then RarityConfig.IndexById[relic.Tier] or 1 else 1,
		Color = color,
		Odds = Odds.describe(relicId, mutation),
	}
end

function RollKit.tierColor(index: number): Color3
	local tier = RarityConfig.Tiers[math.clamp(index, 1, RollKit.TierCount)]
	return UIKit.tierColor(tier.Id)
end

function RollKit.tierName(index: number): string
	return RarityConfig.Tiers[math.clamp(index, 1, RollKit.TierCount)].Name
end

-- Relic renders are shared by every style; only the parented ones draw.
local renders = RelicViewport.cache(40)

-- Shows `relicId` filling `holder` (swaps the render, cheap after the first time).
function RollKit.showRelic(holder: GuiObject, relicId: string)
	local current = holder:FindFirstChild("Render")
	if current and current:GetAttribute("RelicId") == relicId then
		return
	end
	if current then
		current.Parent = nil
	end
	local render = renders.Get(relicId, relicId)
	render.Size = UDim2.fromScale(1, 1)
	render.Parent = holder
end

-- Gives the cached renders back before `root` is destroyed.
function RollKit.release(root: Instance)
	for _, child in root:GetDescendants() do
		if child.Name == "Render" and child:IsA("ViewportFrame") then
			child.Parent = nil
		end
	end
end

-- Calls `onStep(index)` for steps 1..count spread over `seconds` (fast, then slowing down; the last
-- lands at `seconds`). Late frames skip to the newest step. Returns a cancel function.
function RollKit.steps(count: number, seconds: number, onStep: (number) -> ()): () -> ()
	local start = os.clock()
	local done = 0
	local connection: RBXScriptConnection
	local function update()
		local elapsed = os.clock() - start
		local due = done
		while due < count and elapsed >= ReelStrip.stepTime(due + 1, count, seconds) do
			due += 1
		end
		if due > done then
			done = due
			onStep(due)
		end
		if done >= count then
			connection:Disconnect()
		end
	end
	connection = RunService.RenderStepped:Connect(update)
	update()
	return function()
		connection:Disconnect()
	end
end

-- A ring that grows out of the middle of `parent` and fades.
function RollKit.burst(parent: GuiObject, color: Color3, from: number, to: number, seconds: number?)
	if Settings.LowEffects() then
		return
	end
	local stroke = UIKit.stroke(color, 5, 0)
	local ring = UIKit.create("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(from, from),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = parent,
	}, { UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke })
	local time = seconds or 0.5
	local info = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = UDim2.fromOffset(to, to) }):Play()
	TweenService:Create(stroke, info, { Transparency = 1, Thickness = 1 }):Play()
	task.delay(time, ring.Destroy, ring)
end

-- Small glowing sparks flying out of the middle of `parent`.
function RollKit.sparks(parent: GuiObject, color: Color3, count: number, distance: number)
	if Settings.LowEffects() then
		return
	end
	for index = 1, count do
		local angle = (index / count + math.random() * 0.15) * math.pi * 2
		local spark = UIKit.create("Frame", {
			Name = "Spark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(7, 7),
			Rotation = 45,
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35),
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = parent,
		})
		local reach = distance * (0.7 + math.random() * 0.5)
		local time = 0.45 + math.random() * 0.2
		TweenService:Create(spark, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * reach, 0.5, math.sin(angle) * reach),
			Size = UDim2.fromOffset(2, 2),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(time, spark.Destroy, spark)
	end
end

-- The roll's tick: higher as the roll goes on (`progress` 0..1).
function RollKit.tick(progress: number, base: number?)
	Sounds.Play("ReelTick", nil, (base or 0.9) + progress * 0.45)
end

-- Landing sound, bigger for rarer tiers.
function RollKit.landSound(info: Info)
	Sounds.Play("ReelLand", nil, 1 + (info.TierIndex - 1) * 0.025)
	if info.TierIndex >= 4 then
		Sounds.Play("Shine", nil, 0.9 + info.TierIndex * 0.03)
	end
	if info.TierIndex >= LEGENDARY then
		-- A heavy stamp: deeper for rarer tiers.
		Sounds.Play("Seal", nil, 1.15 - (info.TierIndex - LEGENDARY) * 0.08)
	end
end

-- Escalation by tier --------------------------------------------------------------------------

local dimFrame: Frame? = nil
local flashFrame: Frame? = nil

-- Full-screen layers for the big landings: a dim behind every other UI and a flash above it.
function RollKit.Start(screen: ScreenGui)
	dimFrame = UIKit.create("Frame", {
		Name = "RollDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = -1,
		Parent = screen,
	})
	flashFrame = UIKit.create("Frame", {
		Name = "RollFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 60,
		Parent = screen,
	})
end

function RollKit.suspense(info: Info): number
	return SUSPENSE[math.clamp(info.TierIndex, 1, #SUSPENSE)] or 0
end

-- Darkens the world (not the UI) during a hush; `false` lifts it.
function RollKit.dim(on: boolean, seconds: number?)
	local frame = dimFrame
	if not frame then
		return
	end
	frame.Visible = true
	local tween = TweenService:Create(frame, TweenInfo.new(seconds or 0.3), { BackgroundTransparency = if on then 0.5 else 1 })
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not on then
			frame.Visible = false
		end
	end)
	tween:Play()
end

-- Whole-screen flash of `color` fading from `from` transparency.
function RollKit.screenFlash(color: Color3, from: number, seconds: number?)
	local frame = flashFrame
	if not frame or Settings.LowEffects() then
		return
	end
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = from
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(seconds or 0.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

function RollKit.cameraShake(amount: number, seconds: number)
	if Settings.Get("Camera") == "On" then
		HuntFX.shake(amount, seconds)
	end
end

-- Light rays turning slowly behind `parent`'s middle, fading out after `seconds`.
function RollKit.rays(parent: GuiObject, color: Color3, size: number, seconds: number, count: number)
	if Settings.LowEffects() then
		return
	end
	local rays = UIKit.create("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size * 0.6, size * 0.6),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = parent,
	})
	local bars: { Frame } = {}
	for index = 0, count - 1 do
		local bar = UIKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 14),
			Rotation = index * 180 / count,
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = rays,
		}, {
			UIKit.create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		table.insert(bars, bar)
	end
	TweenService:Create(rays, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(size, size) }):Play()
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 25
	end)
	task.delay(seconds, function()
		for _, bar in bars do
			TweenService:Create(bar, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		end
		task.wait(0.45)
		spin:Disconnect()
		rays:Destroy()
	end)
end

-- Slowly cycling rainbow over `gui` (Cosmic). Stops when `gui` is hidden or gone.
function RollKit.rainbow(gui: GuiObject)
	local gradient = UIKit.create("UIGradient", {
		Name = "Rainbow",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(130, 255, 170)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(130, 190, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 140, 255)),
		}),
		Parent = gui,
	})
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not gui.Parent or not gui.Visible or gradient.Parent ~= gui then
			connection:Disconnect()
			gradient:Destroy()
			return
		end
		gradient.Rotation = (gradient.Rotation + dt * 120) % 360
	end)
end

-- The tier-scaled landing around `center` (rays go behind `raysParent`): every landing bursts;
-- Rare adds sparks; Epic a shine on `card`; Legendary and up rays, a screen flash and a camera
-- kick, each step bigger; Celestial and Cosmic white out first.
function RollKit.impact(info: Info, center: GuiObject, raysParent: GuiObject, card: GuiObject?)
	local tier = info.TierIndex
	local color = info.Color
	RollKit.burst(center, color, 40, 120 + tier * 14)
	if tier >= 3 then
		RollKit.sparks(center, color, 2 + tier * 2, 55 + tier * 6)
	end
	if tier >= 4 and card then
		Motion.shine(card, 0.6)
	end
	if tier >= LEGENDARY then
		local step = tier - LEGENDARY
		RollKit.rays(raysParent, color, 260 + step * 70, 1.4 + step * 0.4, 6 + step * 2)
		RollKit.cameraShake(0.25 + step * 0.2, 0.45 + step * 0.15)
		if tier >= 7 then
			RollKit.screenFlash(WHITE, 0.15, 0.35)
			task.delay(0.2, RollKit.screenFlash, color, 0.35, 0.9)
		else
			RollKit.screenFlash(color, 0.6 - step * 0.15, 0.6)
		end
		task.delay(0.12, RollKit.burst, center, WHITE, 40, 200 + step * 60, 0.6)
		if tier >= 6 then
			task.delay(0.25, RollKit.burst, center, color, 60, 300 + step * 60, 0.8)
			task.delay(0.15, RollKit.sparks, center, WHITE, 8 + step * 4, 110)
		end
	end
	RollKit.landSound(info)
end

local hiding: { [GuiObject]: Tween } = {}

-- Shows a style's root (popping in unless it is already up). Cancels a running shrinkAway.
function RollKit.appear(root: GuiObject)
	local tween = hiding[root]
	hiding[root] = nil
	if tween then
		tween:Cancel()
	end
	if tween or not root.Visible then
		root.Visible = true
		Motion.pop(root, 0, 0.55)
	end
end

-- Shrinks a style's root away, then hides it.
function RollKit.shrinkAway(root: GuiObject)
	local scale = root:FindFirstChild("Juice")
	if not scale or not scale:IsA("UIScale") or not root.Visible then
		root.Visible = false
		return
	end
	Spring.stop(scale)
	local tween = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	hiding[root] = tween
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and hiding[root] == tween then
			hiding[root] = nil
			root.Visible = false
		end
	end)
	tween:Play()
end

return RollKit

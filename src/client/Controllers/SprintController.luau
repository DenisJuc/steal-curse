-- Sprint: hold Shift (keyboard), press L3 (gamepad, toggles) or the touch Run button (toggles) to
-- run at Config.Sprint.Multiplier x the walk speed the server sets (BaseWalkSpeed attribute, Swift
-- Step included). Stamina math lives in Shared/Stamina; a slim screen bar just above the bottom
-- ROLL bar shows it while it is not full (a bar under your feet got covered when zoomed in).
-- A WalkSpeed of 0 means a bind froze you (HuntController): sprint stays out of it.
-- Spirit Lane: on the paved Shrine Street you move Config.Plots.Street.Lane.Multiplier x faster
-- and sprinting there costs no stamina (purple wind trails your feet; a hint shows the first time).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local SkillConfig = require(ReplicatedStorage.Shared.SkillConfig)
local Stamina = require(ReplicatedStorage.Shared.Stamina)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local LANE_COLOR = Color3.fromRGB(190, 140, 255)

-- Wind streaks at the feet while the Spirit Lane speeds you up.
local function laneWind(root: BasePart): ParticleEmitter
	local existing = root:FindFirstChild("LaneWind")
	if existing and existing:IsA("ParticleEmitter") then
		return existing
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LaneWind"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(LANE_COLOR)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = root
	return emitter
end

local SprintController = {}

local ACTION = "Sprint"
local BAR_SIZE = Vector2.new(200, 10)
local BAR_COLOR = Color3.fromRGB(150, 220, 255)
local WINDED_COLOR = Color3.fromRGB(235, 80, 80)
-- Seconds a full bar stays before fading out.
local HIDE_DELAY = 0.6

local function makeBar(screen: ScreenGui): (Frame, Frame, Frame)
	local holder = UIKit.create("Frame", {
		Name = "StaminaBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(BAR_SIZE.X + 22, BAR_SIZE.Y + 8),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	UIKit.scaler(holder)
	UIKit.label({
		Name = "Icon",
		Text = "\u{00BB}",
		TextSize = 18,
		TextColor3 = BAR_COLOR,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		Parent = holder,
	})
	local back = UIKit.create("Frame", {
		Name = "Back",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y),
		BackgroundColor3 = Color3.fromRGB(18, 14, 28),
		BackgroundTransparency = 0.25,
		Parent = holder,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIKit.create("UIStroke", { Color = Color3.fromRGB(0, 0, 0), Thickness = 1.5, Transparency = 0.2 }),
	})
	local fill = UIKit.create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BAR_COLOR,
		Parent = back,
	}, {
		UIKit.create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	return holder, back, fill
end

-- `anchor` is the bottom ROLL bar: the stamina bar sits centred just above it.
function SprintController.Start(screen: ScreenGui, anchor: GuiObject?)
	local player = Players.LocalPlayer
	local cfg = Config.Sprint
	local state = Stamina.new()
	local held, toggled = false, false
	local fullFor = math.huge
	local holder, back, fill = makeBar(screen)
	local icon = holder:FindFirstChild("Icon") :: TextLabel

	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState, input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			held = inputState == Enum.UserInputState.Begin
		elseif inputState == Enum.UserInputState.Begin then
			toggled = not toggled
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle(ACTION, "Run")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -170, 1, -150))

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and humanoid and humanoid.Health > 0) then
			held, toggled = false, false
			holder.Visible = false
			return
		end
		local frozen = humanoid.WalkSpeed == 0
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local root = character:FindFirstChild("HumanoidRootPart")
		local onLane = root ~= nil
			and root:IsA("BasePart")
			and WorldLayout.onStreet(Config.Plots, Config.World, Config.Hub.PlazaSize, root.Position.X, root.Position.Z)
		local wantsRun = (held or toggled) and not frozen
		-- On the lane, running is free: stamina refills instead of draining.
		Stamina.step(state, dt, wantsRun and not onLane, moving, cfg)
		if state.Winded and not onLane then
			toggled = false
		end
		if not frozen then
			local base = character:GetAttribute("BaseWalkSpeed")
			local walk = if type(base) == "number" then base else SkillConfig.walkSpeed(0)
			local running = state.Running or (onLane and wantsRun)
			local speed = Stamina.speed(walk, running, cfg.Multiplier, cfg.MaxSpeed)
			if onLane then
				speed = math.min(speed * Config.Plots.Street.Lane.Multiplier, cfg.MaxSpeed)
			end
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end
		if root and root:IsA("BasePart") then
			local wind = laneWind(root)
			local boosted = onLane and moving and not frozen
			if wind.Enabled ~= boosted then
				wind.Enabled = boosted
				wind.Rate = if boosted then 40 else 0
			end
		end
		fullFor = if state.Value >= 1 then fullFor + dt else 0
		holder.Visible = fullFor < HIDE_DELAY and player:GetAttribute("HideInterface") ~= true
		if not holder.Visible then
			return
		end
		if anchor then
			local offset = anchor.AbsolutePosition - screen.AbsolutePosition
			holder.Position = UDim2.fromOffset(offset.X + anchor.AbsoluteSize.X / 2, offset.Y - 2)
		end
		fill.Size = UDim2.fromScale(state.Value, 1)
		local color = if state.Winded then WINDED_COLOR else BAR_COLOR
		fill.BackgroundColor3 = color
		icon.TextColor3 = color
		back.BackgroundTransparency = if state.Winded then 0.1 else 0.25
	end)
end

return SprintController

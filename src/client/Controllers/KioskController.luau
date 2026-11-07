-- Hub kiosks (GDD 4.1): triggering a kiosk's proximity prompt opens the menu named by its
-- OpensMenu attribute, the same as pressing that HUD button. The Bounty Board floats a "claim"
-- badge while finished bounties wait: always-on-top and visible from anywhere in the hub / home
-- ring, hidden once you enter the wild.
-- A kiosk whose menu is still locked by the roll-only start (HudUnlocks) shows "Locked" and,
-- when used, explains what unlocks it instead of opening.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local HudUnlocks = require(script.Parent.Parent.UI.HudUnlocks)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local KioskController = {}

local BADGE_STUDS = Vector2.new(10, 3.2)
local BADGE_LIFT = 11
local PULSE_SECONDS = 1.4
local PLACE_CHECK_SECONDS = 0.35

local function inWild(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	return WorldLayout.inWild(Config.World, root.Position.X, root.Position.Z)
end

local function makeBadge(prompt: ProximityPrompt)
	local part = prompt.Parent
	if not (part and part:IsA("BasePart")) or part:FindFirstChild("ReadyBadge") then
		return
	end
	local player = Players.LocalPlayer
	local colors = UIKit.Colors

	local gui = Instance.new("BillboardGui")
	gui.Name = "ReadyBadge"
	gui.Size = UDim2.fromScale(BADGE_STUDS.X, BADGE_STUDS.Y)
	gui.StudsOffset = Vector3.new(0, BADGE_LIFT, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	-- Hub / home ring only; culled in practice by hiding while in the wild.
	gui.MaxDistance = 2000
	gui.Enabled = false
	gui.Parent = part

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = colors.Panel
	pill.BackgroundTransparency = 0.05
	pill.BorderSizePixel = 0
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.Gold
	stroke.Thickness = 3
	stroke.Transparency = 0.1
	stroke.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = pill

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.AnchorPoint = Vector2.new(0, 0.5)
	accent.Position = UDim2.fromScale(0, 0.5)
	accent.Size = UDim2.fromScale(0.11, 0.64)
	accent.BackgroundColor3 = colors.Gold
	accent.BorderSizePixel = 0
	accent.Parent = pill
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0.4, 0)
	accentCorner.Parent = accent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.14, 0)
	label.Size = UDim2.fromScale(0.86, 1)
	label.FontFace = UIKit.TitleFont
	label.TextColor3 = colors.Text
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextStrokeTransparency = 0.35
	label.Text = "CLAIM BOUNTY"
	label.Parent = pill
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 36
	constraint.MinTextSize = 14
	constraint.Parent = label

	local juice = Instance.new("UIScale")
	juice.Name = "Juice"
	juice.Parent = pill

	local readyCount = 0
	local pulseConn: RBXScriptConnection? = nil

	local function stopPulse()
		if pulseConn then
			pulseConn:Disconnect()
			pulseConn = nil
		end
		juice.Scale = 1
	end

	local function startPulse()
		if pulseConn then
			return
		end
		local t0 = os.clock()
		pulseConn = RunService.Heartbeat:Connect(function()
			if not gui.Enabled then
				return
			end
			local wave = (math.sin((os.clock() - t0) * (math.pi * 2 / PULSE_SECONDS)) + 1) * 0.5
			juice.Scale = 1 + wave * 0.07
			stroke.Transparency = 0.05 + wave * 0.2
		end)
	end

	local function apply()
		local show = readyCount > 0 and not inWild()
		gui.Enabled = show
		if show then
			label.Text = if readyCount == 1 then "CLAIM BOUNTY" else `CLAIM x{readyCount}`
			startPulse()
		else
			stopPulse()
		end
	end

	local function refreshReady()
		local ready = player:GetAttribute("BountiesReady")
		readyCount = if type(ready) == "number" then ready else 0
		apply()
	end
	player:GetAttributeChangedSignal("BountiesReady"):Connect(refreshReady)
	refreshReady()

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < PLACE_CHECK_SECONDS then
			return
		end
		elapsed = 0
		if readyCount > 0 then
			apply()
		end
	end)
end

local function watchPrompt(item: Instance)
	if not item:IsA("ProximityPrompt") then
		return
	end
	local menu = item:GetAttribute("OpensMenu")
	if menu == "Bounties" then
		makeBadge(item)
	end
	-- A kiosk whose menu is still locked reads "Locked / Unlocks at 50 rolls" (the opener explains).
	local gateId = type(menu) == "string" and HudUnlocks.MenuGate[menu]
	if gateId then
		HudUnlocks.WatchPrompt(item, gateId)
	end
end

function KioskController.Start(openers: { [string]: () -> () })
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local menu = prompt:GetAttribute("OpensMenu")
		local open = type(menu) == "string" and openers[menu]
		if open then
			open()
		end
	end)
	for _, item in workspace:GetDescendants() do
		watchPrompt(item)
	end
	workspace.DescendantAdded:Connect(watchPrompt)
end

return KioskController

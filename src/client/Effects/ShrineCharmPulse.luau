-- SoftCap_P4 Shrine Charm: when the fused Shrine relic is on a pedestal, pulse every
-- CollectionConfig.Charms.Shrine.PulseSeconds and outline the nearest spirit signal.
-- Uses HuntController signal positions (works with Spirit Sight off — does not require orbs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CollectionConfig = require(ReplicatedStorage.Shared.CollectionConfig)
local HuntController = require(script.Parent.Parent.Hunt.HuntController)
local SpiritSight = require(script.Parent.SpiritSight)

local ShrineCharmPulse = {}

local DEFAULT_PULSE = (CollectionConfig.Charms.Shrine and CollectionConfig.Charms.Shrine.PulseSeconds) or 60
local OUTLINE_SECONDS = 4.5
local SHRINE_COLOR = Color3.fromRGB(120, 200, 255)

local function pulseSeconds(player: Player): number
	local attr = player:GetAttribute("ShrineCharmPulseSec")
	if type(attr) == "number" and attr >= 15 then
		return attr
	end
	return DEFAULT_PULSE
end

local lastPulse = 0
local activeHighlight: Highlight? = nil
local beacon: BasePart? = nil
local started = false
local folder: Folder? = nil

local function ensureFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "ShrineCharmFX"
	f.Parent = Workspace
	folder = f
	return f
end

local function clearHighlight()
	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function clearBeacon()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end

local function clearAll()
	clearHighlight()
	clearBeacon()
end

local function makeBeacon(position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = "ShrineCharmBeacon"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2.4, 2.4, 2.4)
	part.Material = Enum.Material.Neon
	part.Color = SHRINE_COLOR
	part.Transparency = 0.25
	part.CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0))
	part.Parent = ensureFolder()

	local light = Instance.new("PointLight")
	light.Color = SHRINE_COLOR
	light.Brightness = 2.2
	light.Range = 28
	light.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(120, 28)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "Signal"
	label.Parent = billboard

	return part
end

local function pulse()
	clearAll()
	local id, pos = HuntController.GetNearestSignalAny()
	if not id or not pos then
		return
	end
	-- Prefer live Spirit Sight orb when visible; otherwise a shrine beacon at the signal.
	local target: Instance? = SpiritSight.GetOrb(id)
	if not target then
		beacon = makeBeacon(pos)
		target = beacon
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ShrineCharmOutline"
	highlight.FillColor = SHRINE_COLOR
	highlight.OutlineColor = SHRINE_COLOR
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = target
	activeHighlight = highlight
	task.delay(OUTLINE_SECONDS, function()
		if activeHighlight == highlight then
			clearAll()
		end
	end)
end

function ShrineCharmPulse.Start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local wasOn = false
	RunService.Heartbeat:Connect(function()
		local on = player:GetAttribute("ShrineCharm") == true
		if not on then
			if wasOn then
				clearAll()
			end
			wasOn = false
			lastPulse = 0
			return
		end
		local now = os.clock()
		-- Pulse immediately when Shrine Charm becomes active on a pedestal.
		if not wasOn then
			wasOn = true
			lastPulse = now
			pulse()
			return
		end
		if lastPulse <= 0 then
			lastPulse = now
			return
		end
		if now - lastPulse >= pulseSeconds(player) then
			lastPulse = now
			pulse()
		end
	end)
end

return ShrineCharmPulse

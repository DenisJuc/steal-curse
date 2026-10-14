-- Yellow crackle around every player whose Lightning Luck is active (LightningLuck attribute, set by
-- LightningService), so others can see who is charged. Your own buff ending gets a toast.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local LightningAura = {}

local COLOR = Color3.fromRGB(255, 228, 120)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local NAME = "LightningAura"
local CHECK_EVERY = 0.3

local function build(root: BasePart)
	local holder = Instance.new("Attachment")
	holder.Name = NAME
	holder.Position = Vector3.new(0, 0.5, 0)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Color = ColorSequence.new(COLOR)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.25, 0.5)
	sparks.Speed = NumberRange.new(5, 10)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = if Settings.LowEffects() then 5 else 22
	sparks.Parent = holder
	local haze = Instance.new("ParticleEmitter")
	haze.Color = ColorSequence.new(COLOR)
	haze.LightEmission = 1
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 4) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 1) })
	haze.Lifetime = NumberRange.new(0.6, 1)
	haze.Speed = NumberRange.new(0, 0.5)
	haze.Rate = if Settings.LowEffects() then 0 else 6
	haze.LockedToPart = true
	haze.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = COLOR
	light.Range = 12
	light.Brightness = 1.6
	light.Parent = holder
	holder.Parent = root
end

local function update(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local want = type(player:GetAttribute("LightningLuck")) == "number"
	local existing = root:FindFirstChild(NAME)
	if want and not existing then
		build(root)
	elseif existing and not want then
		existing:Destroy()
	end
end

function LightningAura.Start()
	local localPlayer = Players.LocalPlayer
	local wasCharged = type(localPlayer:GetAttribute("LightningLuck")) == "number"
	localPlayer:GetAttributeChangedSignal("LightningLuck"):Connect(function()
		local charged = type(localPlayer:GetAttribute("LightningLuck")) == "number"
		if wasCharged and not charged then
			Toasts.Show("Lightning Luck faded.")
		end
		wasCharged = charged
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			update(player)
		end
	end)
end

return LightningAura

-- Spectral projection of a found relic above the player's head (GDD 3.2 "small spectral model
-- projection"). Client-only parts, never replicated; at most Config.Reveal.MaxProjections at once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicShapes = require(ReplicatedStorage.Shared.RelicShapes)
local Presentation = require(ReplicatedStorage.Shared.Presentation)
local MutationVFX = require(script.Parent.MutationVFX)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local RelicProjection = {}

local SCALE: { [string]: number } = { Small = 0.55, Medium = 0.9, Large = 1.3 }
local HEIGHT = 5

local active: { BasePart } = {}

function RelicProjection.Spawn(
	relicId: string,
	mutation: string?,
	category: Presentation.Category,
	seconds: number,
	lowEffects: boolean
)
	local relic = RelicConfig.ById[relicId]
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not relic or not root or not root:IsA("BasePart") then
		return
	end
	if lowEffects and category == "Small" then
		return
	end
	while #active >= Config.Reveal.MaxProjections do
		local oldest = table.remove(active, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	local start = CFrame.new(root.Position + Vector3.new(0, HEIGHT, 0))
	local props = RelicShapes.props(relic.ObjectType, start, SCALE[category])
	local part = Instance.new("Part")
	part.Name = "RelicProjection"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.35
	part.Color = UIKit.tierColor(relic.Tier)
	part.Shape = props.Shape or Enum.PartType.Block
	part.Size = props.Size
	part.CFrame = props.CFrame
	if mutation then
		MutationVFX.Apply(part, mutation, { Highlight = true, Particles = not lowEffects })
	end
	part.Parent = workspace
	table.insert(active, part)

	local life = math.max(seconds, 0.3)
	TweenService:Create(part, TweenInfo.new(life, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = props.CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.rad(160), 0),
	}):Play()
	TweenService:Create(part, TweenInfo.new(life * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, life * 0.6), {
		Transparency = 1,
	}):Play()
	task.delay(life + 0.05, function()
		local index = table.find(active, part)
		if index then
			table.remove(active, index)
		end
		part:Destroy()
	end)
end

return RelicProjection

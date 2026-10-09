-- Reusable mutation look (GDD 8): tint, Highlight outline and particles in the mutation color.
-- Works on any part, so every relic model gets it without new mutated models.
-- Highlights and particles don't render inside ViewportFrames; there only the tint shows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationConfig = require(ReplicatedStorage.Shared.MutationConfig)

local MutationVFX = {}

export type Options = {
	Highlight: boolean?,
	Particles: boolean?,
}

local TINT = 0.55

function MutationVFX.Color(mutationId: string): Color3?
	local mutation = MutationConfig.ById[mutationId]
	return if mutation then Color3.fromHex(mutation.Color) else nil
end

function MutationVFX.Apply(part: BasePart, mutationId: string, options: Options?)
	local color = MutationVFX.Color(mutationId)
	if not color then
		return
	end
	part.Color = part.Color:Lerp(color, TINT)
	if not options or options.Highlight ~= false then
		local highlight = Instance.new("Highlight")
		highlight.Name = "MutationHighlight"
		highlight.FillColor = color
		highlight.FillTransparency = 0.65
		highlight.OutlineColor = color
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Adornee = part
		highlight.Parent = part
	end
	if not options or options.Particles ~= false then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "MutationParticles"
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Rate = 18
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Parent = part
	end
end

return MutationVFX

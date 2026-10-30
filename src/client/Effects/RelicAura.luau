-- Premade aura effects on relic parts. Templates are the Models written by
-- tools/vfx/extract_auras.py: invisible parts (CFrames relative to the aura's root) carrying the
-- emitters, beams and lights, a RefHeight value (the pack dummy's height) and, on emitters that
-- the pack drove from a script, EmitCount / EmitEvery values that we replay here.
-- Everything is scaled from RefHeight to the relic's size and welded to the relic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RelicAura = {}

export type Options = {
	-- Overrides the size-derived scale (1 = as authored on a 5-stud dummy).
	Scale: number?,
	-- Multiplies the size-derived scale (Huge / Titanic).
	Boost: number?,
	-- Fewer particles (Settings.LowEffects).
	Low: boolean?,
}

export type Handle = { Destroy: (Handle) -> () }

local LOW_RATE = 0.4
local MIN_SCALE = 0.25

function RelicAura.template(name: string): Instance?
	local vfx = ReplicatedStorage:FindFirstChild("VFX")
	local auras = vfx and vfx:FindFirstChild("Auras")
	return auras and auras:FindFirstChild(name)
end

local function scaleSequence(sequence: NumberSequence, s: number): NumberSequence
	local points = {}
	for _, point in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(point.Time, point.Value * s, point.Envelope * s))
	end
	return NumberSequence.new(points)
end

local function scaleEffect(item: Instance, s: number, low: boolean)
	if item:IsA("ParticleEmitter") then
		item.Size = scaleSequence(item.Size, s)
		item.Speed = NumberRange.new(item.Speed.Min * s, item.Speed.Max * s)
		item.Acceleration *= s
		if low then
			item.Rate *= LOW_RATE
		end
	elseif item:IsA("Beam") then
		item.Width0 *= s
		item.Width1 *= s
		item.CurveSize0 *= s
		item.CurveSize1 *= s
	elseif item:IsA("Attachment") then
		item.Position *= s
	elseif item:IsA("Light") then
		(item :: any).Range *= s
	end
end

local function numberChild(parent: Instance, name: string): number?
	local value = parent:FindFirstChild(name)
	local result = if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then value.Value else nil
	if value then
		value:Destroy()
	end
	return result
end

-- Clones `template` onto `target` and returns a handle; Destroy() stops loops and removes it.
function RelicAura.attach(target: BasePart, template: Instance, options: Options?): Handle
	local opts = options or {}
	local low = opts.Low == true
	local aura = template:Clone()
	local refHeight = numberChild(aura, "RefHeight") or 5
	numberChild(aura, "SourceName")
	local size = target.Size
	local s = opts.Scale or math.max(size.X, size.Y, size.Z) / refHeight
	s = math.max(s * (opts.Boost or 1), MIN_SCALE)

	local loops = {}
	for _, item in aura:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			local count = numberChild(item, "EmitCount")
			local every = numberChild(item, "EmitEvery")
			if count and every then
				table.insert(loops, {
					Emitter = item,
					Count = if low then math.max(1, math.ceil(count * LOW_RATE)) else count,
					Every = math.max(every, 0.1),
				})
			end
		end
		scaleEffect(item, s, low)
	end

	local origin = target.CFrame
	for _, part in aura:GetChildren() do
		if part:IsA("BasePart") then
			local offset = part.CFrame
			part.Size *= s
			part.CFrame = origin * (offset - offset.Position + offset.Position * s)
			part.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = target
			weld.Part1 = part
			weld.Parent = part
		end
	end
	aura.Name = "RelicAura"
	aura.Parent = target

	local alive = true
	for _, loop in loops do
		task.spawn(function()
			while alive and loop.Emitter.Parent do
				loop.Emitter:Clear()
				loop.Emitter:Emit(loop.Count)
				task.wait(loop.Every)
			end
		end)
	end

	local handle = {}
	function handle.Destroy(_self: Handle)
		alive = false
		aura:Destroy()
	end
	return handle :: Handle
end

return RelicAura

-- Capture presentation by shared animation family (GDD 4.3 "Animation production"): after a
-- validated capture the sealed relic appears where the signal was, plays its family's motion,
-- then flies into the capturing player. Five families cover every relic (CaptureFamilies).
-- Client-only parts; used for the local player's captures and, cosmetically, for others nearby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CaptureFamilies = require(ReplicatedStorage.Shared.CaptureFamilies)
local RelicConfig = require(ReplicatedStorage.Shared.RelicConfig)
local RelicModels = require(ReplicatedStorage.Shared.RelicModels)
local ChainRig = require(script.Parent.ChainRig)
local MutationVFX = require(script.Parent.MutationVFX)
local Sounds = require(script.Parent.Parent.Sounds)

local CaptureAnimation = {}

export type Options = {
	-- Low effects: no extra parts, particles or lights; only the relic's motion.
	Low: boolean,
	-- Play sounds (only for the local player's own captures).
	Sound: boolean,
}

type Context = {
	Relic: BasePart,
	Size: Vector3,
	Rotation: CFrame,
	Origin: Vector3,
	Facing: Vector3,
	Color: Color3,
	Extras: { BasePart },
	Flashed: boolean,
	Low: boolean,
}

type Family = {
	Setup: (ctx: Context) -> (),
	-- t goes 0..1 over the family's Seconds; returns the relic's CFrame.
	Step: (ctx: Context, t: number) -> CFrame,
}

local SCALE = 1.1

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 3
end

local function decorPart(ctx: Context, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = ctx.Relic.Parent
	table.insert(ctx.Extras, part)
	return part
end

-- Faces `facing` with the relic's own resting tilt applied on top.
local function facingFrame(ctx: Context, position: Vector3, spin: number): CFrame
	return CFrame.lookAt(position, position + ctx.Facing) * CFrame.Angles(0, spin, 0) * ctx.Rotation
end

local FAMILIES: { [string]: Family } = {
	-- Weapons: rises spinning, then cuts a bright slash arc toward the player.
	Weapons = {
		Setup = function(ctx)
			if ctx.Low then
				return
			end
			decorPart(ctx, {
				Name = "Slash",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.1, 1, 1),
				Color = ctx.Color,
				Transparency = 1,
			})
		end,
		Step = function(ctx, t)
			local position = ctx.Origin + Vector3.new(0, easeOut(t) * 2.5, 0)
			local spin = easeOut(math.min(1, t / 0.7)) * math.pi * 6
			local slash = ctx.Extras[1]
			if slash and t >= 0.65 then
				local u = (t - 0.65) / 0.35
				local diameter = 1 + u * 9
				slash.Size = Vector3.new(0.1, diameter, diameter)
				slash.Transparency = 0.2 + u * 0.8
				-- A vertical disc facing the player: the cylinder axis (X) points at them.
				slash.CFrame = CFrame.lookAt(position, position + ctx.Facing) * CFrame.Angles(0, math.pi / 2, 0)
			end
			return facingFrame(ctx, position, spin)
		end,
	},
	-- Books / Scrolls: hovers while pages fan out in a circle and fold back in.
	Books = {
		Setup = function(ctx)
			if ctx.Low then
				return
			end
			for _ = 1, 6 do
				decorPart(ctx, {
					Name = "Page",
					Size = Vector3.new(0.9, 0.05, 1.2),
					Color = Color3.fromRGB(255, 248, 225),
					Transparency = 0.1,
				})
			end
		end,
		Step = function(ctx, t)
			local position = ctx.Origin + Vector3.new(0, 1 + math.sin(t * math.pi * 3) * 0.3, 0)
			local open = math.sin(t * math.pi)
			for index, page in ctx.Extras do
				local angle = index / #ctx.Extras * math.pi * 2 + t * math.pi * 4
				local offset = Vector3.new(math.cos(angle) * 2.4 * open, math.sin(t * 9 + index) * 0.4, math.sin(angle) * 2.4 * open)
				page.CFrame = CFrame.new(position + offset) * CFrame.Angles(0, -angle, math.sin(t * 12 + index) * 0.6)
				page.Transparency = 0.1 + math.max(0, t - 0.8) * 4.5
			end
			return facingFrame(ctx, position, t * math.pi * 2)
		end,
	},
	-- Masks / Vessels: rises, turns to stare at the player and breathes inside a ghostly aura.
	Masks = {
		Setup = function(ctx)
			if ctx.Low then
				return
			end
			decorPart(ctx, {
				Name = "Aura",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(3, 3, 3),
				Color = Color3.fromRGB(120, 70, 170),
				Transparency = 0.6,
			})
		end,
		Step = function(ctx, t)
			local position = ctx.Origin + Vector3.new(0, easeOut(t) * 1.6, 0)
			local breath = 1 + 0.18 * math.sin(t * math.pi * 4) ^ 2
			ctx.Relic.Size = ctx.Size * breath
			local aura = ctx.Extras[1]
			if aura then
				local diameter = 3 + t * 4
				aura.Size = Vector3.new(diameter, diameter, diameter)
				aura.CFrame = CFrame.new(position)
				aura.Transparency = 0.6 + t * 0.4
			end
			-- Face-on toward the player (the disc's axis is X); a slow sway keeps it alive.
			return CFrame.lookAt(position, position + ctx.Facing)
				* CFrame.Angles(0, math.pi / 2 + math.sin(t * 7) * 0.25, 0)
				* ctx.Rotation
		end,
	},
	-- Crystals / Fragments: shards orbit in and fuse into the relic with a flare.
	Crystals = {
		Setup = function(ctx)
			if ctx.Low then
				return
			end
			for _ = 1, 5 do
				decorPart(ctx, {
					Name = "Shard",
					Size = Vector3.new(0.4, 0.9, 0.4),
					Color = ctx.Color,
					Transparency = 0.15,
				})
			end
		end,
		Step = function(ctx, t)
			local position = ctx.Origin + Vector3.new(0, 1.2, 0)
			local gather = math.min(1, t / 0.7)
			for index, shard in ctx.Extras do
				local angle = index / #ctx.Extras * math.pi * 2 + t * math.pi * 5
				local radius = 3.2 * (1 - easeOut(gather))
				local height = math.sin(index * 1.3) * 1.5 * (1 - gather)
				shard.CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius))
					* CFrame.Angles(t * 9, angle, 0)
				shard.Transparency = if gather >= 1 then 1 else 0.15
			end
			local flare = if t >= 0.7 then math.sin((t - 0.7) / 0.3 * math.pi) * 0.3 else 0
			ctx.Relic.Size = ctx.Size * (1 + flare)
			return facingFrame(ctx, position, t * math.pi * 3)
		end,
	},
	-- Special / Legendary artifacts: rises high inside orbiting sparks and bursts with light.
	Special = {
		Setup = function(ctx)
			if ctx.Low then
				return
			end
			for _ = 1, 8 do
				decorPart(ctx, {
					Name = "Spark",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(0.45, 0.45, 0.45),
					Color = ctx.Color:Lerp(Color3.new(1, 1, 1), 0.4),
				})
			end
		end,
		Step = function(ctx, t)
			local position = ctx.Origin + Vector3.new(0, easeOut(t) * 3.2, 0)
			for index, spark in ctx.Extras do
				local tilt = if index % 2 == 0 then 0.6 else -0.6
				local angle = index / #ctx.Extras * math.pi * 2 + t * math.pi * 6
				local orbit = CFrame.Angles(tilt, 0, 0) * Vector3.new(math.cos(angle) * 2.6, 0, math.sin(angle) * 2.6)
				spark.CFrame = CFrame.new(position + orbit)
			end
			if t >= 0.85 and not ctx.Flashed then
				ctx.Flashed = true
				if not ctx.Low then
					ChainRig.SealFlash(position, 18)
				end
			end
			return facingFrame(ctx, position, t * math.pi * 4)
		end,
	},
}

type Made = { Part: BasePart, Size: Vector3, Rotation: CFrame, Color: Color3 }

local function makeRelic(parent: Instance, relicId: string, mutation: string?, low: boolean): Made?
	local part = RelicModels.build(relicId, CFrame.new(), SCALE, { Spectral = true })
	if not part then
		return nil
	end
	part.Name = "CapturedRelic"
	part.Transparency = 0.1
	part.Parent = parent
	if mutation then
		MutationVFX.Apply(part, mutation, { Highlight = true, Particles = not low })
	end
	if not low then
		local light = Instance.new("PointLight")
		light.Color = part.Color
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = part
	end
	return { Part = part, Size = part.Size, Rotation = part.CFrame.Rotation, Color = part.Color }
end

-- Plays the family animation of `relicId` at `from`, then flies the relic into `target`.
-- Returns the total length in seconds (0 if the relic is unknown).
function CaptureAnimation.Play(relicId: string, mutation: string?, from: Vector3, target: BasePart, options: Options): number
	local relic = RelicConfig.ById[relicId]
	if not relic then
		return 0
	end
	local family = CaptureFamilies.forObjectType(relic.ObjectType)
	local motion = FAMILIES[family.Id]
	local folder = Instance.new("Folder")
	folder.Name = "CaptureAnimation"
	folder.Parent = workspace
	local made = makeRelic(folder, relicId, mutation, options.Low)
	if not made then
		folder:Destroy()
		return 0
	end
	local part = made.Part
	local facing = target.Position - from
	facing = Vector3.new(facing.X, 0, facing.Z)
	local ctx: Context = {
		Relic = part,
		Size = made.Size,
		Rotation = made.Rotation,
		Origin = from,
		Facing = if facing.Magnitude > 0.1 then facing.Unit else Vector3.zAxis,
		Color = made.Color,
		Extras = {},
		Flashed = false,
		Low = options.Low,
	}
	motion.Setup(ctx)
	part.CFrame = motion.Step(ctx, 0)

	local total = CaptureFamilies.totalSeconds(family)
	local start = os.clock()
	local released: CFrame? = nil
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if elapsed < family.Seconds then
			part.CFrame = motion.Step(ctx, elapsed / family.Seconds)
			return
		end
		if not released then
			released = part.CFrame
			for _, extra in ctx.Extras do
				extra:Destroy()
			end
			table.clear(ctx.Extras)
		end
		local u = math.min(1, (elapsed - family.Seconds) / CaptureFamilies.CollectSeconds)
		local goal = if target.Parent then target.Position + Vector3.new(0, 1, 0) else (released :: CFrame).Position
		local eased = u * u
		local position = (released :: CFrame).Position:Lerp(goal, eased) + Vector3.new(0, math.sin(u * math.pi) * 2, 0)
		part.CFrame = CFrame.new(position) * (released :: CFrame).Rotation
		part.Size = ctx.Size * (1 - u * 0.75)
		if u >= 1 then
			connection:Disconnect()
			folder:Destroy()
			if options.Sound then
				Sounds.Play("Collect")
			end
			if not options.Low and target.Parent then
				ChainRig.SealFlash(target.Position, 4)
			end
		end
	end)
	return total
end

return CaptureAnimation

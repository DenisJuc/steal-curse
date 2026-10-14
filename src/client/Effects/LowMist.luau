-- Mist pooling in the low ground near you: pits, ravines and craters (found with the same
-- WildTerrain heights the server built the ground from) get a slow, flat smoke emitter. A small
-- pool of emitters follows you around; Low effects turns it off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local WildLayout = require(ReplicatedStorage.Shared.WildLayout)
local WildTerrain = require(ReplicatedStorage.Shared.WildTerrain)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Ambience = require(script.Parent.Ambience)
local Settings = require(script.Parent.Parent.Settings)

local LowMist = {}

local CHECK_SECONDS = 2
local MIST_COLOR = Color3.fromRGB(150, 160, 178)

type Pool = { Part: Part, Emitter: ParticleEmitter }

local function makePool(folder: Instance): Pool
	local part = Instance.new("Part")
	part.Name = "LowMist"
	part.Size = Vector3.new(12, 1.5, 12)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(MIST_COLOR)
	emitter.LightEmission = 0.05
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 11) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.78),
		NumberSequenceKeypoint.new(0.7, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-6, 6)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Rate = 0
	emitter.Parent = part
	return { Part = part, Emitter = emitter }
end

function LowMist.Start()
	local cfg = Config.Ambience.LowMist
	local shape = WildTerrain.new({
		Areas = Config.Areas,
		World = Config.World,
		AreaAt = WorldLayout.areaAt,
		PathDistance = WildLayout.pathDistance,
		PathHalfWidth = WildLayout.PathHalfWidth,
		Clearings = WildLayout.boxes(MapPropConfig.Props),
	})
	local folder = Instance.new("Folder")
	folder.Name = "LowMist"
	folder.Parent = workspace
	local pools: { Pool } = {}
	for _ = 1, cfg.Max do
		table.insert(pools, makePool(folder))
	end

	local elapsed = CHECK_SECONDS
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_SECONDS then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		local wild = Ambience.WildWeight()
		local on = camera ~= nil and wild > 0.3 and not Settings.LowEffects()
		local spots: { { Position: Vector3, Distance: number } } = {}
		if on and camera then
			local focus = camera.CFrame.Position
			local step = cfg.Step
			local cx, cz = math.floor(focus.X / step) * step, math.floor(focus.Z / step) * step
			for x = cx - cfg.Range, cx + cfg.Range, step do
				for z = cz - cfg.Range, cz + cfg.Range, step do
					local distance = math.sqrt((x - focus.X) ^ 2 + (z - focus.Z) ^ 2)
					if distance <= cfg.Range then
						local height = shape.heightAt(x, z)
						if height < cfg.Depth then
							table.insert(spots, { Position = Vector3.new(x, height + 0.8, z), Distance = distance })
						end
					end
				end
			end
			table.sort(spots, function(a, b)
				return a.Distance < b.Distance
			end)
		end
		for index, pool in pools do
			local spot = spots[index]
			if spot then
				pool.Part.Position = spot.Position
				pool.Emitter.Rate = 1.2 * wild
			else
				pool.Emitter.Rate = 0
			end
		end
	end)
end

return LowMist

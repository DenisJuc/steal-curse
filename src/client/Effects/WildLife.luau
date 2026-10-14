-- Things that live in the dark wild (client-only, cosmetic):
--   Hitodama: small blue spirit flames drifting around you; get close and they flee and go out.
--   Crows: perch on the dead trees near you (tagged "Perch") and burst off cawing when you come
--          close; a tree stays empty for a while after.
-- (The tall watcher figure is the Lost One, run by the server: WildFinds.)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Ambience = require(script.Parent.Ambience)
local HuntFX = require(script.Parent.HuntFX)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)

local WildLife = {}

local WISPS = 10
local WISPS_LOW = 4
local WISP_LIGHTS = 5
local WISP_COLOR = Color3.fromRGB(120, 190, 255)
local WISP_NEAR = { 40, 100 }
local WISP_FAR = 140
local WISP_FLEE = 14

local MAX_CROWS = 10
local CROW_RANGE = 70
local CROW_SCARE = 16
local CROW_COOLDOWN = 60
local CROW_COLOR = Color3.fromRGB(12, 12, 14)

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = false

local function groundAt(x: number, z: number, fallback: number): number
	groundParams.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, fallback + 60, z), Vector3.new(0, -140, 0), groundParams)
	return if hit then hit.Position.Y else fallback
end

local function part(parent: Instance, props: { [string]: any }): Part
	local item = HuntFX.part(props)
	item.Material = props.Material or Enum.Material.SmoothPlastic
	item.Parent = parent
	return item
end

-- A random point in the wild ring `min`..`max` studs from `from`, optionally within `cone`
-- radians of `facing`.
local function pointAround(from: Vector3, min: number, max: number, facing: Vector3?, cone: number?): Vector3?
	for _ = 1, 12 do
		local angle = math.random() * math.pi * 2
		if facing and cone then
			angle = math.atan2(facing.Z, facing.X) + (math.random() * 2 - 1) * cone
		end
		local distance = min + math.random() * (max - min)
		local x, z = from.X + math.cos(angle) * distance, from.Z + math.sin(angle) * distance
		if WorldLayout.inWild(Config.World, x, z, 8) and not WorldLayout.inStream(Config.World, x, z, 4) then
			return Vector3.new(x, groundAt(x, z, from.Y - 3), z)
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Hitodama

type Wisp = {
	Part: Part,
	Light: PointLight,
	Flame: ParticleEmitter,
	Home: Vector3,
	Seed: number,
	Fleeing: number?,
	Away: Vector3,
	Ground: number,
	GroundAt: number,
}

local function makeWisp(folder: Instance): Wisp
	local ball = part(folder, {
		Name = "Hitodama",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.7,
		Color = WISP_COLOR,
		Material = Enum.Material.Neon,
		Transparency = 1,
	})
	local light = Instance.new("PointLight")
	light.Color = WISP_COLOR
	light.Range = 9
	light.Brightness = 0
	light.Shadows = false
	light.Parent = ball
	local flame = Instance.new("ParticleEmitter")
	flame.Texture = HuntFX.FIRE
	flame.Color = ColorSequence.new(WISP_COLOR, Color3.fromRGB(60, 90, 255))
	flame.LightEmission = 1
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	flame.Lifetime = NumberRange.new(0.4, 0.7)
	flame.Speed = NumberRange.new(0.5, 1.5)
	flame.Acceleration = Vector3.new(0, 4, 0)
	flame.SpreadAngle = Vector2.new(15, 15)
	flame.Rate = 0
	flame.Parent = ball
	return {
		Part = ball,
		Light = light,
		Flame = flame,
		Home = Vector3.zero,
		Seed = math.random() * 100,
		Fleeing = nil,
		Away = Vector3.zero,
		Ground = 0,
		GroundAt = 0,
	}
end

local function placeWisp(wisp: Wisp, around: Vector3): boolean
	local home = pointAround(around, WISP_NEAR[1], WISP_NEAR[2])
	if not home then
		return false
	end
	wisp.Home = home
	wisp.Ground = home.Y
	wisp.GroundAt = os.clock()
	wisp.Fleeing = nil
	wisp.Part.Position = home + Vector3.new(0, 3, 0)
	return true
end

---------------------------------------------------------------------------------------------------
-- Crows

type Crow = { Model: Model, Body: Part, Wings: { Part }, Velocity: Vector3?, Born: number, Base: CFrame }

local function makeCrow(folder: Instance, at: CFrame): Crow
	local model = Instance.new("Model")
	model.Name = "Crow"
	local body = part(model, { Name = "Body", Size = Vector3.new(0.5, 0.5, 1.1), CFrame = at, Color = CROW_COLOR })
	part(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.45,
		CFrame = at * CFrame.new(0, 0.25, -0.6),
		Color = CROW_COLOR,
	})
	part(model, {
		Name = "Tail",
		Size = Vector3.new(0.4, 0.08, 0.6),
		CFrame = at * CFrame.new(0, 0.05, 0.75) * CFrame.Angles(0.3, 0, 0),
		Color = CROW_COLOR,
	})
	local wings = {}
	for _, side in { -1, 1 } do
		table.insert(
			wings,
			part(model, {
				Name = "Wing",
				Size = Vector3.new(1.1, 0.06, 0.6),
				CFrame = at * CFrame.new(side * 0.55, 0.1, 0) * CFrame.Angles(0, 0, side * -1.2),
				Color = CROW_COLOR,
			})
		)
	end
	model.PrimaryPart = body
	model.Parent = folder
	return { Model = model, Body = body, Wings = wings, Velocity = nil, Born = os.clock(), Base = at }
end

local function flap(crow: Crow, t: number)
	local beat = math.sin(t * 28) * 0.9
	local frame = crow.Body.CFrame
	for index, wing in crow.Wings do
		local side = if index == 1 then -1 else 1
		wing.CFrame = frame * CFrame.new(side * 0.25, 0.1, 0) * CFrame.Angles(0, 0, side * beat) * CFrame.new(side * 0.55, 0, 0)
	end
end

---------------------------------------------------------------------------------------------------

function WildLife.Start()
	local player = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "WildLife"
	folder.Parent = workspace

	local wisps: { Wisp } = {}
	for _ = 1, WISPS do
		table.insert(wisps, makeWisp(folder))
	end

	local crows: { [Model]: { Crow } } = {}
	local cooldown: { [Model]: number } = {}
	local flying: { Crow } = {}

	local crowCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local wild = Ambience.WildWeight()
		local active = root ~= nil and root:IsA("BasePart") and wild > 0.5
		local low = Settings.LowEffects()
		local position = if root and root:IsA("BasePart") then root.Position else Vector3.zero

		-- Hitodama
		local count = if low then WISPS_LOW else WISPS
		local lit = 0
		for index, wisp in wisps do
			local on = active and index <= count
			if not on then
				wisp.Part.Transparency = 1
				wisp.Light.Brightness = 0
				wisp.Flame.Rate = 0
				wisp.Home = Vector3.zero
				continue
			end
			if wisp.Home == Vector3.zero or (wisp.Home - position).Magnitude > WISP_FAR then
				if not placeWisp(wisp, position) then
					continue
				end
			end
			local t = now + wisp.Seed
			local visible = 1
			if wisp.Fleeing then
				local age = now - wisp.Fleeing
				wisp.Part.Position += wisp.Away * dt
				visible = math.max(0, 1 - age / 1.2)
				if age >= 1.2 then
					placeWisp(wisp, position)
				end
			else
				if now - wisp.GroundAt > 0.5 then
					wisp.GroundAt = now
					wisp.Ground = groundAt(wisp.Part.Position.X, wisp.Part.Position.Z, wisp.Ground)
				end
				local drift = Vector3.new(math.noise(t * 0.15, wisp.Seed) * 14, 0, math.noise(wisp.Seed, t * 0.15) * 14)
				local goal = wisp.Home + drift
				local current = wisp.Part.Position
				local target = Vector3.new(goal.X, wisp.Ground + 3 + math.sin(t * 1.7) * 0.6, goal.Z)
				wisp.Part.Position = current:Lerp(target, 1 - math.exp(-dt * 1.5))
				local gap = wisp.Part.Position - position
				if gap.Magnitude < WISP_FLEE then
					local flat = Vector3.new(gap.X, 0, gap.Z)
					wisp.Away = (if flat.Magnitude > 0.1 then flat.Unit else Vector3.xAxis) * 18 + Vector3.new(0, 4, 0)
					wisp.Fleeing = now
				end
			end
			local flicker = 0.85 + 0.15 * math.noise(t * 6, wisp.Seed)
			wisp.Part.Transparency = 1 - 0.85 * visible * wild
			wisp.Flame.Rate = if low then 0 else 25 * visible
			lit += 1
			wisp.Light.Brightness = if lit <= WISP_LIGHTS then 1.2 * visible * flicker * wild else 0
		end

		-- Crows: settle on nearby trees, burst off when you come close.
		crowCheck += dt
		if crowCheck >= 1 then
			crowCheck = 0
			local total = 0
			for tree, list in crows do
				if not tree.Parent or (tree:GetPivot().Position - position).Magnitude > CROW_RANGE + 20 or not active then
					for _, crow in list do
						crow.Model:Destroy()
					end
					crows[tree] = nil
				else
					total += #list
				end
			end
			if active then
				for _, tree in CollectionService:GetTagged("Perch") do
					if total >= MAX_CROWS then
						break
					end
					if not tree:IsA("Model") or crows[tree] or (cooldown[tree] or 0) > now then
						continue
					end
					local pivot = tree:GetPivot().Position
					local distance = (pivot - position).Magnitude
					if distance > CROW_RANGE or distance < CROW_SCARE + 6 or math.random() > 0.5 then
						continue
					end
					local _, size = tree:GetBoundingBox()
					local list = {}
					for _ = 1, math.random(1, 3) do
						local at = CFrame.new(
							pivot + Vector3.new((math.random() - 0.5) * size.X * 0.5, size.Y * 0.92, (math.random() - 0.5) * size.Z * 0.5)
						) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
						table.insert(list, makeCrow(folder, at))
					end
					crows[tree] = list
					total += #list
				end
			end
		end
		for tree, list in crows do
			if (tree:GetPivot().Position - position).Magnitude < CROW_SCARE then
				for _, crow in list do
					local away = crow.Body.Position - position
					away = Vector3.new(away.X, 0, away.Z)
					away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
					crow.Velocity = away * (8 + math.random() * 6) + Vector3.new((math.random() - 0.5) * 6, 12 + math.random() * 5, 0)
					crow.Born = now
					table.insert(flying, crow)
					Sounds.Play("CrowCaw", crow.Body, 0.85 + math.random() * 0.3)
					Sounds.Play("CrowFlap", crow.Body)
				end
				crows[tree] = nil
				cooldown[tree] = now + CROW_COOLDOWN
			end
		end
		for index = #flying, 1, -1 do
			local crow = flying[index]
			local velocity = crow.Velocity :: Vector3
			local at = crow.Body.Position + velocity * dt
			crow.Body.CFrame = CFrame.lookAt(at, at + velocity)
			flap(crow, now)
			for _, item in crow.Model:GetChildren() do
				if item:IsA("BasePart") and item ~= crow.Body and item.Name ~= "Wing" then
					item.CFrame = crow.Body.CFrame
						* (if item.Name == "Head" then CFrame.new(0, 0.25, -0.6) else CFrame.new(0, 0.05, 0.75) * CFrame.Angles(0.3, 0, 0))
				end
			end
			if now - crow.Born > 4 then
				crow.Model:Destroy()
				table.remove(flying, index)
			end
		end
	end)
end

return WildLife

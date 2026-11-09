-- Sound details of the world:
--   Distant sounds: now and then, while you are in the wild, one of your area's Distant sounds
--   (Config.Ambience.Areas.<id>.Distant) plays from somewhere out in the fog.
--   Footsteps: Roblox's own running loop (a plastic/brick step, whatever the floor) is muted,
--   whether the character sounds use Sounds or the new AudioPlayer API; one short step from the
--   floor's set (Config.FootstepSets) plays per stride, quicker the faster you move, at the
--   Footsteps volume from Settings.
-- Entries with an empty id stay silent / keep Roblox's default step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Ambience = require(script.Parent.Ambience)
local Settings = require(script.Parent.Parent.Settings)
local Sounds = require(script.Parent.Parent.Sounds)

local WildSounds = {}

local function playDistant(from: Vector3, inTown: boolean)
	local areaId = WorldLayout.areaAt(Config.Areas, Config.World, from.X, from.Z)
	local preset = if inTown then Config.Ambience.Town else (Config.Ambience.Areas :: any)[areaId]
	local list = preset and (preset :: any).Distant
	if not list or #list == 0 then
		return
	end
	local cfg = Config.Ambience.DistantSounds
	local angle = math.random() * math.pi * 2
	local distance = cfg.Distance[1] + math.random() * (cfg.Distance[2] - cfg.Distance[1])
	local holder = Instance.new("Part")
	holder.Name = "DistantSound"
	holder.Size = Vector3.one * 0.2
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.Position = from + Vector3.new(math.cos(angle) * distance, 4, math.sin(angle) * distance)
	holder.Parent = workspace
	Sounds.Play(list[math.random(1, #list)], holder, 0.9 + math.random() * 0.2)
	task.delay(16, function()
		holder:Destroy()
	end)
end

function WildSounds.Start()
	local player = Players.LocalPlayer
	local cfg = Config.Ambience.DistantSounds
	local nextSound = os.clock() + cfg.Every[1]
	local muted: { [Instance]: boolean } = {}
	-- The default script may create, restart or re-level the loop at any time, so it is muted on
	-- sight and held at zero.
	local function mute(sound: Instance)
		if muted[sound] then
			return
		end
		muted[sound] = true
		local function zero()
			if (sound :: any).Volume ~= 0 then
				(sound :: any).Volume = 0
			end
		end
		zero()
		sound:GetPropertyChangedSignal("Volume"):Connect(zero)
		sound.Destroying:Once(function()
			muted[sound] = nil
		end)
	end
	local cadence = Config.FootstepCadence
	local untilStep = 0
	local lastPick = 0

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and humanoid) then
			return
		end

		local now = os.clock()
		if now >= nextSound then
			nextSound = now + cfg.Every[1] + math.random() * (cfg.Every[2] - cfg.Every[1])
			local wild = Ambience.WildWeight()
			if wild > 0.6 then
				playDistant(root.Position, false)
			elseif wild < 0.2 then
				playDistant(root.Position, true)
			end
		end

		local running = root:FindFirstChild("Running")
		if running and (running:IsA("Sound") or running:IsA("AudioPlayer")) and not muted[running] then
			mute(running)
		end
		-- Steps follow real movement (keyboard, thumbstick, click-to-move alike), not input.
		local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		if humanoid.FloorMaterial == Enum.Material.Air or speed < 3 then
			untilStep = 0
			return
		end
		untilStep -= dt
		if untilStep > 0 then
			return
		end
		untilStep = math.max(cadence.MinGap, cadence.Walk * math.sqrt(16 / speed))
		local set = Config.FootstepSets[Config.Footsteps[humanoid.FloorMaterial.Name] or "Stone"]
		local pick = math.random(1, #set)
		if pick == lastPick and #set > 1 then
			pick = pick % #set + 1
		end
		lastPick = pick
		local volume = cadence.Volume * Settings.FootstepVolume()
		if volume <= 0.001 then
			return
		end
		local step = Instance.new("Sound")
		step.SoundId = set[pick]
		step.Volume = volume
		step.PlaybackSpeed = 0.92 + math.random() * 0.16
		step.RollOffMaxDistance = 60
		step.Parent = root
		step:Play()
		step.Ended:Once(function()
			step:Destroy()
		end)
	end)
end

return WildSounds

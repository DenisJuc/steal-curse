-- Sound details of the world:
--   Distant sounds: now and then, while you are in the wild, one of your area's Distant sounds
--   (Config.Ambience.Areas.<id>.Distant) plays from somewhere out in the fog.
--   Footsteps: the character's running sound follows the floor material (Config.Footsteps) and
--   speeds up while sprinting.
-- Entries with an empty id stay silent / keep Roblox's default step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local Ambience = require(script.Parent.Ambience)
local Sounds = require(script.Parent.Parent.Sounds)

local WildSounds = {}

local function playDistant(from: Vector3)
	local areaId = WorldLayout.areaAt(Config.Areas, Config.World, from.X, from.Z)
	local preset = (Config.Ambience.Areas :: any)[areaId]
	local list = preset and preset.Distant
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
	local defaults: { [Sound]: { Id: string, Speed: number } } = {}
	local lastMaterial: Enum.Material? = nil

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and humanoid) then
			return
		end

		local now = os.clock()
		if now >= nextSound then
			nextSound = now + cfg.Every[1] + math.random() * (cfg.Every[2] - cfg.Every[1])
			if Ambience.WildWeight() > 0.6 then
				playDistant(root.Position)
			end
		end

		local running = root:FindFirstChild("Running")
		if not (running and running:IsA("Sound")) then
			return
		end
		if not defaults[running] then
			defaults[running] = { Id = running.SoundId, Speed = running.PlaybackSpeed }
		end
		local base = character:GetAttribute("BaseWalkSpeed")
		local pace = if typeof(base) == "number" and base > 0 then humanoid.WalkSpeed / base else 1
		running.PlaybackSpeed = defaults[running].Speed * math.clamp(pace, 1, Config.Sprint.Multiplier)

		local material = humanoid.FloorMaterial
		if material == lastMaterial or material == Enum.Material.Air then
			return
		end
		lastMaterial = material
		local id = Config.Footsteps[material.Name]
		running.SoundId = if id and id ~= "" then id else defaults[running].Id
	end)
end

return WildSounds

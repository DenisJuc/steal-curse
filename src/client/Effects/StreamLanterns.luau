-- Drifts the paper lanterns the server floated on the stream (WildDressing, tagged
-- "StreamLantern"): they follow the current around the ring, bob and slowly turn. Client-only
-- motion of anchored parts; only lanterns near the camera are moved.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)

local StreamLanterns = {}

-- Degrees of the ring per second (about 1.8 studs/s at the stream).
local DRIFT_SPEED = 0.25
local MOVE_RANGE = 220
local WATER_Y = -0.85

function StreamLanterns.Start()
	local start = os.clock()
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local focus = camera.CFrame.Position
		local t = os.clock() - start
		local radius = Config.World.StreamRadius
		for _, model in CollectionService:GetTagged("StreamLantern") do
			if not model:IsA("Model") then
				continue
			end
			local angle = model:GetAttribute("Angle")
			local offset = model:GetAttribute("Offset")
			local phase = model:GetAttribute("Phase")
			if type(angle) ~= "number" or type(offset) ~= "number" or type(phase) ~= "number" then
				continue
			end
			local x, z = WorldLayout.polar(angle + t * DRIFT_SPEED, radius + offset)
			if (Vector3.new(x, focus.Y, z) - focus).Magnitude > MOVE_RANGE then
				continue
			end
			local bob = math.sin(t * 1.3 + phase) * 0.08
			local yaw = phase + t * 0.15
			local tilt = math.sin(t * 0.9 + phase) * 0.05
			model:PivotTo(CFrame.new(x, WATER_Y + bob, z) * CFrame.Angles(tilt, yaw, tilt * 0.6))
		end
	end)
end

return StreamLanterns

-- Switches map lights (PointLights tagged "MapLight" by the server's MapProps: lanterns, fungus,
-- runes) off on this client when they are farther than Config.Ambience.LightRange from the camera,
-- or always with Low effects. Keeps the open world cheap on phones.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.Parent.Settings)

local MapLightLOD = {}

local CHECK_SECONDS = 0.5

function MapLightLOD.Start()
	local elapsed = CHECK_SECONDS
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_SECONDS then
			return
		end
		elapsed = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local focus = camera.CFrame.Position
		local range = Config.Ambience.LightRange
		local low = Settings.LowEffects()
		for _, light in CollectionService:GetTagged("MapLight") do
			if not light:IsA("Light") then
				continue
			end
			local holder = light.Parent
			local on = false
			if not low and holder and holder:IsA("BasePart") then
				on = (holder.Position - focus).Magnitude <= range
			end
			if light.Enabled ~= on then
				light.Enabled = on
			end
		end
	end)
end

return MapLightLOD

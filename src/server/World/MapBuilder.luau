-- Builds the whole map from code at server start: lighting, ground, hub plaza and the plot ring.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BuildUtil = require(script.Parent.BuildUtil)
local PlotBuilder = require(script.Parent.PlotBuilder)

local MapBuilder = {}

export type Map = {
	Folder: Folder,
	Plots: { Model },
}

local SPIRIT = Color3.fromRGB(170, 110, 255)
local LANTERN = Color3.fromRGB(255, 176, 96)

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(70, 60, 95)
	Lighting.OutdoorAmbient = Color3.fromRGB(115, 105, 145)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 205, 170)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	Instance.new("Sky").Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(200, 175, 230)
	atmosphere.Decay = Color3.fromRGB(110, 80, 150)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Threshold = 1.3
	bloom.Size = 28
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.TintColor = Color3.fromRGB(255, 245, 255)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Parent = Lighting
end

local function buildHub(parent: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	local radius = Config.Hub.PlazaRadius

	BuildUtil.cylinder(hub, CFrame.new(0, 0.5, 0), 1, radius * 2, {
		Name = "Plaza",
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(92, 88, 104),
	})
	BuildUtil.decor(BuildUtil.cylinder(hub, CFrame.new(0, 1.05, 0), 0.1, 30, {
		Name = "SigilRing",
		Material = Enum.Material.Neon,
		Color = SPIRIT,
		Transparency = 0.35,
	}))

	BuildUtil.part(hub, {
		Name = "ObeliskBase",
		Size = Vector3.new(10, 3, 10),
		CFrame = CFrame.new(0, 2.5, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(60, 56, 72),
	})
	BuildUtil.part(hub, {
		Name = "Obelisk",
		Size = Vector3.new(5, 22, 5),
		CFrame = CFrame.new(0, 15, 0),
		Material = Enum.Material.Basalt,
		Color = Color3.fromRGB(36, 32, 48),
	})
	local crystal = BuildUtil.part(hub, {
		Name = "HubCrystal",
		Size = Vector3.new(4, 6, 4),
		CFrame = CFrame.new(0, 30, 0) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = SPIRIT,
	})
	BuildUtil.decor(crystal)
	BuildUtil.light(crystal, SPIRIT, 40, 3)
	BuildUtil.sparkles(crystal, SPIRIT, 10)
	BuildUtil.billboard(crystal, Config.GameName, 40, 5, 9, Color3.fromRGB(235, 215, 255))

	for index = 1, Config.Hub.LanternCount do
		local angle = (index - 0.5) / Config.Hub.LanternCount * math.pi * 2
		local position = Vector3.new(math.cos(angle) * (radius - 5), 0, math.sin(angle) * (radius - 5))
		BuildUtil.part(hub, {
			Name = "LanternPost",
			Size = Vector3.new(1, 8, 1),
			CFrame = CFrame.new(position + Vector3.new(0, 5, 0)),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(50, 38, 34),
		})
		local lamp = BuildUtil.part(hub, {
			Name = "Lantern",
			Size = Vector3.new(2, 2, 2),
			CFrame = CFrame.new(position + Vector3.new(0, 10, 0)),
			Material = Enum.Material.Neon,
			Color = LANTERN,
		})
		BuildUtil.decor(lamp)
		BuildUtil.light(lamp, LANTERN, 16, 1.5)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 1.05, 24)
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(80, 76, 94)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub

	hub.Parent = parent
end

local function buildPaths(parent: Instance)
	local inner = Config.Hub.PlazaRadius
	local outer = Config.Plots.RingRadius - Config.Plots.Size / 2
	local length = outer - inner
	for index = 1, Config.Plots.Count do
		local angle = (index - 1) / Config.Plots.Count * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local center = direction * (inner + length / 2) + Vector3.new(0, 0.2, 0)
		BuildUtil.part(parent, {
			Name = "Path",
			Size = Vector3.new(10, 0.4, length),
			CFrame = CFrame.lookAt(center, center + direction),
			Material = Enum.Material.Cobblestone,
			Color = Color3.fromRGB(112, 106, 100),
		})
	end
end

function MapBuilder.Build(): Map
	for _, name in { "Baseplate", "SpawnLocation" } do
		local template = workspace:FindFirstChild(name)
		if template then
			template:Destroy()
		end
	end

	setupLighting()

	local folder = Instance.new("Folder")
	folder.Name = "Map"

	BuildUtil.part(folder, {
		Name = "Ground",
		Size = Vector3.new(Config.Hub.GroundSize, 4, Config.Hub.GroundSize),
		CFrame = CFrame.new(0, -2, 0),
		Material = Enum.Material.Grass,
		Color = Color3.fromRGB(58, 72, 54),
	})
	buildHub(folder)
	buildPaths(folder)

	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plots"
	plotFolder.Parent = folder

	local plots = {}
	for index = 1, Config.Plots.Count do
		local angle = (index - 1) / Config.Plots.Count * math.pi * 2
		local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.Plots.RingRadius
		local cframe = CFrame.lookAt(position, Vector3.zero)
		plots[index] = PlotBuilder.Build(index, cframe, plotFolder)
	end

	folder.Parent = workspace
	return { Folder = folder, Plots = plots }
end

return MapBuilder

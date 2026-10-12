-- Builds the whole map from code at server start (GDD 4.1, Slice 11): lighting, the shrine town
-- (hub plaza and plot ring) and the wild ring around it (WildBuilder: terrain, paths, stream,
-- landmarks, props, signal spawn grid), then checks the part budget.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HubBuilder = require(script.Parent.HubBuilder)
local PlotBuilder = require(script.Parent.PlotBuilder)
local WildBuilder = require(script.Parent.WildBuilder)

local MapBuilder = {}

export type Map = {
	Folder: Folder,
	Plots: { Model },
	Wild: WildBuilder.Wild,
	PartCount: number,
}

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

local function countParts(folder: Instance): number
	local count = 0
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
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

	HubBuilder.Build(folder)

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

	local started = os.clock()
	local wild = WildBuilder.Build(folder)

	-- Plot relic displays are added later per player; this measures the static map.
	local partCount = countParts(folder)
	local summary = `{partCount} parts, {wild.PropCount} wild props, {#wild.SpawnPoints} signal spots,`
		.. ` wild built in {string.format("%.1f", os.clock() - started)} s`
	if partCount > Config.World.PartBudget then
		warn(`[Map] {summary}: over the budget of {Config.World.PartBudget}; consider StreamingEnabled.`)
	else
		print(`[Map] Built: {summary} (budget {Config.World.PartBudget}).`)
	end

	folder.Parent = workspace
	return { Folder = folder, Plots = plots, Wild = wild, PartCount = partCount }
end

return MapBuilder

-- Builds the whole map from code at server start (GDD 4.1, Slice 11): lighting, the shrine town
-- (hub plaza and Shrine Street) and the wild ring around it (WildBuilder: terrain, paths, stream,
-- landmarks, props, signal spawn grid), then checks the part budget.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local HubBuilder = require(script.Parent.HubBuilder)
local PlotBuilder = require(script.Parent.PlotBuilder)
local ShrineMaterialsBuilder = require(script.Parent.ShrineMaterialsBuilder)
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
	-- From Config.Ambience.Town (the client blends from there).
	local town = Config.Ambience.Town
	local function rgb(c: { number }): Color3
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	Lighting.ClockTime = town.Lighting.ClockTime
	Lighting.Brightness = town.Lighting.Brightness
	Lighting.Ambient = rgb(town.Lighting.Ambient)
	Lighting.OutdoorAmbient = rgb(town.Lighting.OutdoorAmbient)
	Lighting.ExposureCompensation = town.Lighting.Exposure
	Lighting.ColorShift_Top = Color3.fromRGB(255, 205, 170)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	Instance.new("Sky").Parent = Lighting

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = town.Atmosphere.Density
	atmosphere.Offset = town.Atmosphere.Offset
	atmosphere.Color = rgb(town.Atmosphere.Color)
	atmosphere.Decay = rgb(town.Atmosphere.Decay)
	atmosphere.Glare = 0.2
	atmosphere.Haze = town.Atmosphere.Haze
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
		local x, z = WorldLayout.plotPosition(Config.Plots, index)
		local fx, fz = WorldLayout.plotFacing(Config.Plots, index)
		local position = Vector3.new(x, 0, z)
		-- Local -Z (the entrance) faces the street.
		local cframe = CFrame.lookAt(position, position + Vector3.new(fx, 0, fz))
		plots[index] = PlotBuilder.Build(index, cframe, plotFolder)
	end

	-- Generated shrine materials on the courtyards, walls, paths, plaza, kiosks and Seal Shrines.
	local hub = folder:FindFirstChild("Hub")
	local dressed = ShrineMaterialsBuilder.Apply(plotFolder) + (if hub then ShrineMaterialsBuilder.Apply(hub) else 0)

	local started = os.clock()
	local wild = WildBuilder.Build(folder)

	-- Plot relic displays are added later per player; this measures the static map.
	local partCount = countParts(folder)
	local summary = `{partCount} parts ({dressed} with shrine materials), {wild.PropCount} wild props, {#wild.SpawnPoints} signal spots,`
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

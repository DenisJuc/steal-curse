-- Hub plaza (GDD 4.1): obelisk (or the imported HubTemple), stone lanterns, the spawn, a signpost
-- pointing at the three wild areas, and kiosks that open the Codex, Skills, Luck, Relics, Journal,
-- Bounties and Wardrobe menus via proximity prompts (the client opens the menu named by the prompt's OpensMenu
-- attribute).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local BuildUtil = require(script.Parent.BuildUtil)
local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local MapProps = require(script.Parent.MapProps)

local HubBuilder = {}

local SPIRIT = Color3.fromRGB(170, 110, 255)
local WOOD = Color3.fromRGB(64, 48, 42)
local KIOSK_COLORS = {
	Codex = Color3.fromRGB(255, 205, 90),
	Skills = Color3.fromRGB(150, 120, 255),
	Luck = Color3.fromRGB(120, 235, 140),
	Relics = Color3.fromRGB(190, 130, 255),
	Journal = Color3.fromRGB(120, 190, 255),
	Bounties = Color3.fromRGB(255, 150, 90),
	Wardrobe = Color3.fromRGB(255, 170, 210),
}
-- Beside the hub spawn, clear of the temple's front steps.
local SIGNPOST_AT = Vector3.new(11, 0, -24)

local function buildCenter(hub: Model)
	local size = Config.Hub.PlazaSize
	local halfW, halfD = size[1] / 2, size[2] / 2
	BuildUtil.part(hub, {
		Name = "Plaza",
		Size = Vector3.new(size[1], 1, size[2]),
		CFrame = CFrame.new(0, 0.5, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(92, 88, 104),
	})
	-- Dark kerb around the plaza edge.
	for _, edge in { { 0, -halfD, size[1], 1.2 }, { 0, halfD, size[1], 1.2 }, { -halfW, 0, 1.2, size[2] }, { halfW, 0, 1.2, size[2] } } do
		BuildUtil.part(hub, {
			Name = "PlazaKerb",
			Size = Vector3.new(edge[3], 0.3, edge[4]),
			CFrame = CFrame.new(edge[1], 1.15, edge[2]),
			Material = Enum.Material.Basalt,
			Color = Color3.fromRGB(44, 40, 54),
		})
	end
	BuildUtil.decor(BuildUtil.cylinder(hub, CFrame.new(0, 1.05, 0), 0.1, 30, {
		Name = "SigilRing",
		Material = Enum.Material.Neon,
		Color = SPIRIT,
		Transparency = 0.35,
	}))
	local crystalHeight = 30
	if MapProps.has("HubTemple") then
		MapProps.build(hub, "HubTemple", CFrame.new(0, 1, 0))
		local _, templeHeight = MapPropConfig.size("HubTemple")
		crystalHeight = templeHeight + 6
	else
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
	end
	local crystal = BuildUtil.part(hub, {
		Name = "HubCrystal",
		Size = Vector3.new(4, 6, 4),
		CFrame = CFrame.new(0, crystalHeight, 0) * CFrame.Angles(0, math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = SPIRIT,
	})
	BuildUtil.decor(crystal)
	BuildUtil.light(crystal, SPIRIT, 40, 3)
	BuildUtil.sparkles(crystal, SPIRIT, 10)
	BuildUtil.billboard(crystal, Config.GameName, 40, 5, 9, Color3.fromRGB(235, 215, 255))

	-- Lanterns around the edge: both sides, the back, and the front except the street mouth.
	local spacing = Config.Hub.LanternSpacing
	local inset = 4
	local spots = {}
	local countX = math.max(1, math.floor((size[1] - inset * 2) / spacing))
	for i = 0, countX do
		local x = -halfW + inset + i * (size[1] - inset * 2) / countX
		table.insert(spots, Vector3.new(x, 1, halfD - inset))
		if math.abs(x) > Config.Plots.Street.HalfWidth + 6 then
			table.insert(spots, Vector3.new(x, 1, -halfD + inset))
		end
	end
	local countZ = math.max(1, math.floor((size[2] - inset * 2) / spacing))
	for i = 1, countZ - 1 do
		local z = -halfD + inset + i * (size[2] - inset * 2) / countZ
		table.insert(spots, Vector3.new(-halfW + inset, 1, z))
		table.insert(spots, Vector3.new(halfW - inset, 1, z))
	end
	local glow = Config.Plots.Street.LanternLight
	for _, position in spots do
		local lantern = MapProps.build(hub, "StoneLantern", CFrame.lookAt(position, Vector3.new(0, 1, 0)))
		for _, descendant in if lantern then lantern:GetDescendants() else {} do
			if descendant:IsA("PointLight") then
				descendant.Range = glow.Range
				descendant.Brightness = glow.Brightness
			end
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 1.05, -22)
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(80, 76, 94)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub
end

local function buildKiosk(parent: Instance, kiosk: { Menu: string, Label: string, At: { number }, Prop: string? })
	local position = Vector3.new(kiosk.At[1], 0, kiosk.At[2])
	-- Front (-Z) faces the plaza's middle line, where players walk.
	local base = CFrame.lookAt(position + Vector3.new(0, 1, 0), Vector3.new(0, 1, kiosk.At[2]))
	local color = KIOSK_COLORS[kiosk.Menu] or SPIRIT

	local model = Instance.new("Model")
	model.Name = kiosk.Menu .. "Kiosk"
	BuildUtil.part(model, {
		Name = "KioskFloor",
		Size = Vector3.new(8, 0.4, 6),
		CFrame = base * CFrame.new(0, 0.2, 0),
		Material = Enum.Material.WoodPlanks,
		Color = Color3.fromRGB(86, 66, 56),
	})
	local counter = BuildUtil.part(model, {
		Name = "Counter",
		Size = Vector3.new(6.4, 3.4, 2.2),
		CFrame = base * CFrame.new(0, 2.1, -1.4),
		Material = Enum.Material.Wood,
		Color = WOOD,
	})
	for _, side in { -1, 1 } do
		BuildUtil.part(model, {
			Name = "KioskPost",
			Size = Vector3.new(0.6, 9, 0.6),
			CFrame = base * CFrame.new(side * 3.6, 4.9, 2.6),
			Material = Enum.Material.Wood,
			Color = WOOD,
		})
	end
	BuildUtil.part(model, {
		Name = "KioskRoof",
		Size = Vector3.new(8.6, 0.6, 6.6),
		CFrame = base * CFrame.new(0, 9.6, -0.2) * CFrame.Angles(math.rad(-10), 0, 0),
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(56, 48, 66),
	})
	local sign = BuildUtil.part(model, {
		Name = "KioskSign",
		Size = Vector3.new(7, 1.6, 0.3),
		CFrame = base * CFrame.new(0, 8.2, -2.9),
		Material = Enum.Material.Wood,
		Color = Color3.fromRGB(40, 32, 30),
	})
	BuildUtil.surfaceText(sign, Enum.NormalId.Front, kiosk.Label, color)
	local emblem = BuildUtil.decor(BuildUtil.part(model, {
		Name = "Emblem",
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = base * CFrame.new(0, 5.4, -1.4) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		Material = Enum.Material.Neon,
		Color = color,
	}))
	BuildUtil.light(emblem, color, 12, 1.2)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KioskPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = kiosk.Label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensMenu", kiosk.Menu)
	prompt.Parent = counter

	if kiosk.Prop then
		MapProps.build(model, kiosk.Prop, base * CFrame.new(5.8, 0, -0.5))
	end
	model.Parent = parent
end

local function buildSignpost(parent: Instance, frame: CFrame)
	local model = Instance.new("Model")
	model.Name = "AreaSignpost"
	BuildUtil.part(model, {
		Name = "SignPole",
		Size = Vector3.new(0.7, 11, 0.7),
		CFrame = CFrame.new(SIGNPOST_AT + Vector3.new(0, 6.5, 0)),
		Material = Enum.Material.Wood,
		Color = WOOD,
	})
	local paths = WorldLayout.townPaths(Config.Plots, Config.World, Config.Areas, Config.Hub.PlazaSize)
	for index, district in Config.Areas do
		-- Point each arm along that area's town path (its first leg out of the plaza).
		local path = paths[district.Id]
		local target = frame:PointToObjectSpace(Vector3.new(path[2][1], 0, path[2][2]))
		local direction = (Vector3.new(target.X, 0, target.Z) - SIGNPOST_AT).Unit
		local height = 10.4 - index * 1.6
		local center = SIGNPOST_AT + direction * 3.6 + Vector3.new(0, height, 0)
		local arm = BuildUtil.part(model, {
			Name = "SignArm",
			Size = Vector3.new(0.3, 1.3, 6.4),
			CFrame = CFrame.lookAt(center, center + direction),
			Material = Enum.Material.WoodPlanks,
			Color = Color3.fromRGB(96, 74, 58),
		})
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			BuildUtil.surfaceText(arm, face, district.Name, Color3.fromRGB(255, 236, 200))
		end
	end
	model.Parent = parent
end

-- Where the hub stands: the near end of Shrine Street, hub -Z pointing down the street.
function HubBuilder.CFrame(): CFrame
	local x, z, fx, fz = WorldLayout.hubFrame(Config.Plots)
	-- Raised so the plaza slab (top at 1) sits level with the smoothed town terrain (~2.2).
	local y = 1.2
	return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + fx, y, z + fz))
end

function HubBuilder.Build(parent: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	local frame = HubBuilder.CFrame()
	-- Built around the origin in hub space, then moved to the street's end.
	buildCenter(hub)
	buildSignpost(hub, frame)
	for _, kiosk in Config.Hub.Kiosks do
		buildKiosk(hub, kiosk)
	end
	hub.WorldPivot = CFrame.new()
	hub:PivotTo(frame)
	hub.Parent = parent
end

return HubBuilder

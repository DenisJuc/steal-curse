-- Hub plaza (GDD 4.1): obelisk, lanterns, the spawn, a signpost pointing at the three hunting
-- districts, and kiosks that open the Codex, Luck, Relics and Journal menus via proximity prompts
-- (the client opens the menu named by the prompt's OpensMenu attribute).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local BuildUtil = require(script.Parent.BuildUtil)

local HubBuilder = {}

local SPIRIT = Color3.fromRGB(170, 110, 255)
local LANTERN = Color3.fromRGB(255, 176, 96)
local WOOD = Color3.fromRGB(64, 48, 42)
local KIOSK_COLORS = {
	Codex = Color3.fromRGB(255, 205, 90),
	Luck = Color3.fromRGB(120, 235, 140),
	Relics = Color3.fromRGB(190, 130, 255),
	Journal = Color3.fromRGB(120, 190, 255),
}
local SIGNPOST_AT = Vector3.new(0, 0, 13)

local function buildCenter(hub: Model)
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
end

local function buildKiosk(parent: Instance, kiosk: { Menu: string, Label: string, AngleDegrees: number })
	local angle = math.rad(kiosk.AngleDegrees)
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.Hub.KioskRadius
	-- Front (-Z) faces the obelisk, where players walk.
	local base = CFrame.lookAt(position + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0))
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

	model.Parent = parent
end

local function buildSignpost(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "DistrictSignpost"
	BuildUtil.part(model, {
		Name = "SignPole",
		Size = Vector3.new(0.7, 11, 0.7),
		CFrame = CFrame.new(SIGNPOST_AT + Vector3.new(0, 6.5, 0)),
		Material = Enum.Material.Wood,
		Color = WOOD,
	})
	for index, district in Config.Districts do
		local cx, cz = WorldLayout.districtCenter(district, Config.World)
		local direction = (Vector3.new(cx, 0, cz) - SIGNPOST_AT).Unit
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

function HubBuilder.Build(parent: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	buildCenter(hub)
	buildSignpost(hub)
	for _, kiosk in Config.Hub.Kiosks do
		buildKiosk(hub, kiosk)
	end
	hub.Parent = parent
end

return HubBuilder

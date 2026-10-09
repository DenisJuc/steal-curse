-- Server-side look of the active Showcase on a plot's podium, so visitors see it too.
--   Level 1: the base structure (spirit circle / crimson throne / golden guardian).
--   Level 2: + neon aura ring and light.   Level 3: + sparkles and floating ornaments.
--   Level 4: + a light pillar and big ornaments.
-- Unlocked accessories are added on top (cosmetic only). Lights, particles, the pillar and the
-- ornament spin are thinned out per client by ShowcaseLOD. Podium local -Z faces the hub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ShowcaseConfig = require(ReplicatedStorage.Shared.ShowcaseConfig)
local BuildUtil = require(script.Parent.BuildUtil)

local ShowcaseVisuals = {}

export type View = {
	Id: string,
	Level: number,
	Accessories: { string },
}

-- Height of the dais top above the plot Base part's centre (see PlotBuilder: FLOOR_TOP 1.2,
-- dais 1.2 tall, Base centre at 0.5).
local DAIS_TOP = 1.2 + 1.2 - 0.5

local ACCENT = {
	Stance = Color3.fromRGB(150, 210, 255),
	Throne = Color3.fromRGB(220, 50, 60),
	Guardian = Color3.fromRGB(255, 200, 80),
}

local POSE_TEXT = {
	Stance = "Stand in the circle",
	Throne = "Sit on the throne",
	Guardian = "Stand guard",
}

type At = (x: number, y: number, z: number) -> CFrame

local function neon(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, transparency: number?)
	return BuildUtil.decor(BuildUtil.part(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = transparency or 0,
	}))
end

local function buildStance(model: Model, at: At, accent: Color3)
	BuildUtil.decor(BuildUtil.cylinder(model, at(0, 0.03, 0), 0.06, 9, {
		Name = "Circle",
		Material = Enum.Material.Neon,
		Color = accent,
		Transparency = 0.35,
	}))
	BuildUtil.decor(BuildUtil.cylinder(model, at(0, 0.05, 0), 0.06, 8.2, {
		Name = "CircleInner",
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(205, 200, 215),
	}))
	for index = 0, 3 do
		local angle = math.rad(45 + 90 * index)
		local x, z = math.cos(angle) * 6, math.sin(angle) * 6
		BuildUtil.part(model, {
			Name = "Post",
			Size = Vector3.new(0.9, 2.6, 0.9),
			CFrame = at(x, 1.3, z),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(80, 78, 92),
		})
		neon(model, "PostTip", Vector3.new(0.6, 0.6, 0.6), at(x, 2.9, z) * CFrame.Angles(0, math.rad(45), math.rad(45)), accent)
	end
end

local function buildThrone(model: Model, at: At, accent: Color3)
	local iron = Color3.fromRGB(60, 30, 34)
	BuildUtil.part(model, {
		Name = "ThroneBase",
		Size = Vector3.new(4.4, 1.4, 4.4),
		CFrame = at(0, 0.7, 1.5),
		Material = Enum.Material.Metal,
		Color = iron,
	})
	local seat = Instance.new("Seat")
	seat.Name = "ThroneSeat"
	seat.Anchored = true
	seat.Disabled = true
	seat.Size = Vector3.new(4, 0.6, 4)
	seat.CFrame = at(0, 1.7, 1.5)
	seat.Material = Enum.Material.Fabric
	seat.Color = accent
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	-- Only the pose prompt seats anyone (enabled just for that); visitors can't sit by touch.
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not seat.Occupant then
			seat.Disabled = true
		end
	end)
	seat.Parent = model
	BuildUtil.part(model, {
		Name = "Backrest",
		Size = Vector3.new(4.4, 6.5, 0.8),
		CFrame = at(0, 4.6, 3.6),
		Material = Enum.Material.Metal,
		Color = iron,
	})
	neon(model, "BackrestInlay", Vector3.new(2.6, 4.6, 0.2), at(0, 4.4, 3.15), accent, 0.15)
	for _, side in { -1, 1 } do
		BuildUtil.part(model, {
			Name = "Armrest",
			Size = Vector3.new(0.8, 1.2, 4),
			CFrame = at(side * 2.4, 2.6, 1.6),
			Material = Enum.Material.Metal,
			Color = iron,
		})
	end
	for index = -1, 1 do
		local height = if index == 0 then 2.2 else 1.5
		neon(model, "Spike", Vector3.new(0.6, height, 0.6), at(index * 1.5, 7.85 + height / 2, 3.6), accent)
	end
end

local function buildGuardian(model: Model, at: At, accent: Color3)
	BuildUtil.part(model, {
		Name = "GuardianPlinth",
		Size = Vector3.new(3.4, 1, 3),
		CFrame = at(0, 0.5, 5.4),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(230, 215, 170),
	})
	local spirit = { Size = Vector3.zero, Material = Enum.Material.Neon, Color = accent, Transparency = 0.3 }
	local function piece(name: string, size: Vector3, cframe: CFrame, shape: Enum.PartType?)
		local props = table.clone(spirit)
		props.Name = name
		props.Size = size
		props.CFrame = cframe
		local part = BuildUtil.decor(BuildUtil.part(model, props))
		if shape then
			part.Shape = shape
			part.Size = size
		end
		return part
	end
	piece("Body", Vector3.new(2.8, 4.6, 1.6), at(0, 3.3, 5.4))
	piece("Head", Vector3.new(1.9, 1.9, 1.9), at(0, 6.6, 5.4), Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		piece("Wing", Vector3.new(0.3, 5.2, 2.6), at(side * 2.3, 5, 6.1) * CFrame.Angles(0, 0, math.rad(-side * 25)))
	end
	piece("Spear", Vector3.new(0.3, 8.5, 0.3), at(2, 4.6, 4.8))
	piece("SpearTip", Vector3.new(0.7, 1.2, 0.7), at(2, 9.3, 4.8) * CFrame.Angles(0, math.rad(45), 0))
end

local ACCESSORY_BUILDERS: { [string]: (Model, At) -> () } = {
	BoneFluteCharm = function(model, at)
		local bone = Color3.fromRGB(232, 224, 205)
		for _, side in { -1, 1 } do
			local base = at(side * 4.2, 4.1, -4.2)
			BuildUtil.decor(BuildUtil.part(model, {
				Name = "BoneFlute",
				Size = Vector3.new(0.35, 2.4, 0.35),
				CFrame = base * CFrame.Angles(0, 0, math.rad(side * 30)),
				Material = Enum.Material.SmoothPlastic,
				Color = bone,
			}))
			neon(model, "FluteCord", Vector3.new(0.12, 0.9, 0.12), base * CFrame.new(0, -1.3, 0), Color3.fromRGB(150, 210, 255), 0.3)
		end
	end,
	AshenBanners = function(model, at)
		for _, side in { -1, 1 } do
			BuildUtil.part(model, {
				Name = "BannerPole",
				Size = Vector3.new(0.4, 9, 0.4),
				CFrame = at(side * 5.3, 4.5, 3),
				Material = Enum.Material.Wood,
				Color = Color3.fromRGB(40, 30, 32),
			})
			BuildUtil.decor(BuildUtil.part(model, {
				Name = "Banner",
				Size = Vector3.new(2.2, 5, 0.12),
				CFrame = at(side * 4.0, 6, 3),
				Material = Enum.Material.Fabric,
				Color = Color3.fromRGB(96, 92, 98),
			}))
			neon(model, "BannerSigil", Vector3.new(0.9, 0.9, 0.14), at(side * 4.0, 6.6, 2.97) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(220, 50, 60))
		end
	end,
	GuardianSigilTome = function(model, at)
		local book = at(0, 4.4, 3.7) * CFrame.Angles(math.rad(-30), 0, 0)
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "SigilTome",
			Size = Vector3.new(2.4, 0.3, 1.7),
			CFrame = book,
			Material = Enum.Material.Leather,
			Color = Color3.fromRGB(90, 50, 30),
		}))
		local page = neon(model, "SigilPage", Vector3.new(2.1, 0.08, 1.4), book * CFrame.new(0, 0.18, 0), Color3.fromRGB(190, 140, 255), 0.2)
		local light = BuildUtil.light(page, Color3.fromRGB(190, 140, 255), 8, 1.5)
		light.Name = "ShowcaseLight"
	end,
}

local function buildLevelEffects(model: Model, at: At, level: number, accent: Color3)
	if level < 2 then
		return
	end
	BuildUtil.decor(BuildUtil.cylinder(model, at(0, 0.08, 0), 0.12, 15.4, {
		Name = "AuraRing",
		Material = Enum.Material.Neon,
		Color = accent,
		Transparency = 0.55,
	}))
	local core = BuildUtil.decor(BuildUtil.part(model, {
		Name = "AuraCore",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = at(0, 4, 0),
		Transparency = 1,
	}))
	local light = BuildUtil.light(core, accent, 18, 1.2 + 0.4 * (level - 2))
	light.Name = "ShowcaseLight"
	if level < 3 then
		return
	end
	local sparkles = BuildUtil.sparkles(core, accent, 6 * (level - 2))
	sparkles.Name = "ShowcaseSparkles"
	sparkles.SpreadAngle = Vector2.new(60, 60)

	local ornaments = Instance.new("Model")
	ornaments.Name = "Ornaments"
	local center = BuildUtil.decor(BuildUtil.part(ornaments, {
		Name = "Center",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = at(0, 6, 0),
		Transparency = 1,
	}))
	ornaments.PrimaryPart = center
	for index = 0, 2 do
		local angle = math.rad(120 * index)
		neon(ornaments, "Ornament", Vector3.new(0.8, 1.4, 0.8), at(math.cos(angle) * 6.2, 6, math.sin(angle) * 6.2), accent, 0.1)
	end
	if level >= 4 then
		for index = 0, 2 do
			local angle = math.rad(60 + 120 * index)
			neon(ornaments, "BigOrnament", Vector3.new(1.4, 2.6, 1.4), at(math.cos(angle) * 7, 8.5, math.sin(angle) * 7) * CFrame.Angles(0, math.rad(45), 0), accent, 0.05)
		end
		BuildUtil.decor(BuildUtil.cylinder(model, at(0, 18, 0), 36, 11, {
			Name = "LightPillar",
			Material = Enum.Material.Neon,
			Color = accent,
			Transparency = 0.86,
		}))
	end
	ornaments.Parent = model
end

-- Builds (or clears, with view = nil) the Showcase on `plot`. `onPose` runs when the owner uses
-- the pose prompt. Rebuilds only when something visible changed.
function ShowcaseVisuals.Apply(plot: Model?, view: View?, ownerUserId: number?, onPose: ((Player) -> ())?)
	local podium = plot and plot:FindFirstChild("ShowcasePodium")
	local base = plot and plot.PrimaryPart
	if not podium or not base then
		return
	end
	local key = if view then `{view.Id}|{view.Level}|{table.concat(view.Accessories, ",")}` else ""
	if podium:GetAttribute("ShownKey") == key then
		return
	end
	podium:SetAttribute("ShownKey", key)
	local old = podium:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	local showcase = view and ShowcaseConfig.ById[view.Id]
	if not view or not showcase then
		return
	end

	local offset = Config.Plots.ShowcaseOffset
	local origin = base.CFrame * CFrame.new(offset[1], DAIS_TOP, offset[2])
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local accent = ACCENT[showcase.Style] or Color3.new(1, 1, 1)
	local model = Instance.new("Model")
	model.Name = "Display"
	model:SetAttribute("Style", showcase.Style)
	model:SetAttribute("Level", view.Level)

	if showcase.Style == "Throne" then
		buildThrone(model, at, accent)
	elseif showcase.Style == "Guardian" then
		buildGuardian(model, at, accent)
	else
		buildStance(model, at, accent)
	end
	buildLevelEffects(model, at, view.Level, accent)
	for _, accessoryId in view.Accessories do
		local build = ACCESSORY_BUILDERS[accessoryId]
		if build then
			build(model, at)
		end
	end

	local posePoint = BuildUtil.decor(BuildUtil.part(model, {
		Name = "PosePoint",
		Size = Vector3.new(1, 1, 1),
		CFrame = at(0, 0.5, 0),
		Transparency = 1,
	}))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PosePrompt"
	prompt.ActionText = POSE_TEXT[showcase.Style] or "Pose"
	prompt.ObjectText = `{showcase.Name} (Lv {view.Level})`
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonL1
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", ownerUserId or 0)
	prompt.Parent = posePoint
	if onPose then
		prompt.Triggered:Connect(onPose)
	end
	model.Parent = podium
end

-- Where a posing character stands (on the dais centre, facing the hub) and the throne seat.
function ShowcaseVisuals.PoseTarget(plot: Model?): (CFrame?, Seat?)
	local podium = plot and plot:FindFirstChild("ShowcasePodium")
	local display = podium and podium:FindFirstChild("Display")
	local point = display and display:FindFirstChild("PosePoint")
	if not display or not point or not point:IsA("BasePart") then
		return nil, nil
	end
	local seat = display:FindFirstChild("ThroneSeat")
	return point.CFrame * CFrame.new(0, -0.5, 0), if seat and seat:IsA("Seat") then seat else nil
end

return ShowcaseVisuals

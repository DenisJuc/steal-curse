-- Server-side look of the active Showcase on a plot's podium, so visitors see it too.
--   Level 1: the base structure (spirit circle / crimson throne / golden guardian).
--   Level 2: + neon aura ring and light.   Level 3: + sparkles and floating ornaments.
--   Level 4: + a light pillar and big ornaments.
-- Unlocked accessories are added on top (cosmetic only). Lights, particles, the pillar and the
-- ornament spin are thinned out per client by ShowcaseLOD. Podium local -Z faces the hub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ShowcaseConfig = require(ReplicatedStorage.Shared.ShowcaseConfig)
local MapPropConfig = require(ReplicatedStorage.Shared.MapPropConfig)
local BuildUtil = require(script.Parent.BuildUtil)
local MapProps = require(script.Parent.MapProps)

local ShowcaseVisuals = {}

export type View = {
	Id: string,
	Level: number,
	Accessories: { string },
}

-- Height of the dais top above the plot Base part's centre (see PlotBuilder: FLOOR_TOP 1.2,
-- dais 1.2 tall plus its 0.2 rim cap, Base centre at 0.5).
local DAIS_TOP = 1.2 + 1.4 - 0.5

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

-- Sealing chamber materials (match PlotBuilder).
local BASALT = Color3.fromRGB(66, 60, 76)
local PAPER = Color3.fromRGB(228, 216, 184)
local ROPE = Color3.fromRGB(176, 146, 98)

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

local function stone(parent: Instance, name: string, size: Vector3, cframe: CFrame)
	return BuildUtil.part(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Material = Enum.Material.Slate,
		Color = BASALT,
	})
end

-- A ring of short glowing segments lying flat at height `y` (a flat neon disc reads as plastic).
local function segmentRing(
	parent: Instance,
	at: At,
	name: string,
	radius: number,
	count: number,
	width: number,
	y: number,
	color: Color3,
	transparency: number
)
	local length = 2 * math.pi * radius / count - 0.08
	for i = 1, count do
		local angle = (i - 0.5) / count * math.pi * 2
		neon(
			parent,
			name,
			Vector3.new(length, 0.08, width),
			at(math.cos(angle) * radius, y, math.sin(angle) * radius) * CFrame.Angles(0, -angle + math.pi / 2, 0),
			color,
			transparency
		)
	end
end

-- A paper seal whose ink glows in `ink` (SurfaceGui ignores lighting), on both faces.
local function ofuda(parent: Instance, name: string, size: Vector3, cframe: CFrame, ink: Color3)
	local paper = BuildUtil.decor(BuildUtil.part(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Material = Enum.Material.Fabric,
		Color = PAPER,
	}))
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local label = BuildUtil.surfaceText(paper, face, "封", ink)
		label.Font = Enum.Font.Arial
	end
	return paper
end

-- Binding circle: a glowing sigil on the dais ringed by four sealed stone posts.
local function buildStance(model: Model, at: At, accent: Color3)
	segmentRing(model, at, "Circle", 4.2, 24, 0.35, 0.06, accent, 0.2)
	segmentRing(model, at, "CircleInner", 3.3, 18, 0.15, 0.06, accent, 0.5)
	local center = at(0, 2.1, 0).Position
	for index = 0, 3 do
		local angle = math.rad(45 + 90 * index)
		local x, z = math.cos(angle) * 5.8, math.sin(angle) * 5.8
		stone(model, "Post", Vector3.new(1.1, 3.4, 1.1), at(x, 1.7, z))
		stone(model, "PostCap", Vector3.new(1.5, 0.35, 1.5), at(x, 3.55, z))
		neon(model, "PostTip", Vector3.new(0.5, 0.5, 0.5), at(x, 4.05, z) * CFrame.Angles(0, math.rad(45), math.rad(45)), accent)
		-- Seal on the post's inner face, looking at the circle.
		local post = at(x, 2.1, z).Position
		local inward = (center - post).Unit
		ofuda(model, "PostSeal", Vector3.new(0.7, 1.5, 0.05), CFrame.lookAt(post + inward * 0.58, center), accent)
	end
end

-- Cursed throne: dark stone, a crimson seat, thin glowing inlays, horns and a sacred rope.
local function buildThrone(model: Model, at: At, accent: Color3)
	stone(model, "ThroneBase", Vector3.new(4.8, 1.4, 4.4), at(0, 0.7, 1.5))
	local seat = Instance.new("Seat")
	seat.Name = "ThroneSeat"
	seat.Anchored = true
	seat.Disabled = true
	seat.Size = Vector3.new(4, 0.6, 3.8)
	seat.CFrame = at(0, 1.7, 1.4)
	seat.Material = Enum.Material.Fabric
	seat.Color = Color3.fromRGB(110, 18, 26)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	-- Only the pose prompt seats anyone (enabled just for that); visitors can't sit by touch.
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not seat.Occupant then
			seat.Disabled = true
		end
	end)
	seat.Parent = model
	stone(model, "Backrest", Vector3.new(4.8, 6.5, 0.9), at(0, 4.6, 3.6))
	for _, side in { -1, 1 } do
		stone(model, "Armrest", Vector3.new(0.8, 1.2, 4), at(side * 2.4, 2.6, 1.6))
		neon(model, "Inlay", Vector3.new(0.14, 5, 0.1), at(side * 1.6, 4.6, 3.12), accent, 0.1)
		local horn = at(side * 2.1, 8.3, 3.6) * CFrame.Angles(0, 0, math.rad(-side * 28))
		stone(model, "Horn", Vector3.new(0.6, 2.4, 0.6), horn)
		neon(model, "HornTip", Vector3.new(0.45, 0.45, 0.45), horn * CFrame.new(0, 1.35, 0), accent)
	end
	neon(model, "Sigil", Vector3.new(1.1, 1.1, 0.1), at(0, 6.6, 3.12) * CFrame.Angles(0, 0, math.rad(45)), accent, 0.05)
	-- Horizontal rope across the backrest (BuildUtil.cylinder stands cylinders up; turn it back).
	BuildUtil.decor(BuildUtil.cylinder(model, at(0, 7.5, 3.0) * CFrame.Angles(0, 0, math.rad(-90)), 5.4, 0.5, {
		Name = "Shimenawa",
		Material = Enum.Material.Fabric,
		Color = ROPE,
	}))
	for index = -1, 1 do
		BuildUtil.decor(BuildUtil.part(model, {
			Name = "Shide",
			Size = Vector3.new(0.4, 1.2, 0.04),
			CFrame = at(index * 1.6, 6.75, 2.95),
			Material = Enum.Material.Fabric,
			Color = PAPER,
		}))
	end
end

-- Stone guardian (the Jizo statue, scaled up) on a plinth with a glowing halo behind its head.
local function buildGuardian(model: Model, at: At, accent: Color3)
	local plinthTop = 1.2
	stone(model, "GuardianPlinth", Vector3.new(3.8, plinthTop, 3.4), at(0, plinthTop / 2, 5.4))
	neon(model, "PlinthTrim", Vector3.new(3.9, 0.12, 3.5), at(0, plinthTop - 0.1, 5.4), accent, 0.2)
	local scale = 2
	MapProps.build(model, "JizoStatue", at(0, plinthTop, 5.4), scale)
	local _, height = MapPropConfig.size("JizoStatue")
	local haloY = plinthTop + height * scale * 0.8
	local count = 20
	local radius = 1.9
	for i = 1, count do
		local angle = (i - 0.5) / count * math.pi * 2
		neon(
			model,
			"Halo",
			Vector3.new(2 * math.pi * radius / count - 0.06, 0.18, 0.12),
			at(math.cos(angle) * radius, haloY + math.sin(angle) * radius, 6.7) * CFrame.Angles(0, 0, angle + math.pi / 2),
			accent,
			0.1
		)
	end
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
	segmentRing(model, at, "AuraRing", 7.4, 36, 0.4, 0.1, accent, 0.35)
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

	-- Floating seals circle the showcase (ShowcaseLOD spins the Ornaments model).
	local ornaments = Instance.new("Model")
	ornaments.Name = "Ornaments"
	local center = BuildUtil.decor(BuildUtil.part(ornaments, {
		Name = "Center",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = at(0, 6, 0),
		Transparency = 1,
	}))
	ornaments.PrimaryPart = center
	local function seals(count: number, radius: number, y: number, size: Vector3, offset: number)
		for index = 0, count - 1 do
			local angle = math.rad(offset + 360 / count * index)
			local position = at(math.cos(angle) * radius, y, math.sin(angle) * radius).Position
			ofuda(ornaments, "Ornament", size, CFrame.lookAt(position, at(0, y, 0).Position), accent)
		end
	end
	seals(3, 6.2, 6, Vector3.new(0.9, 1.8, 0.06), 0)
	if level >= 4 then
		seals(3, 7, 8.5, Vector3.new(1.3, 2.6, 0.06), 60)
		BuildUtil.decor(BuildUtil.cylinder(model, at(0, 18, 0), 36, 7, {
			Name = "LightPillar",
			Material = Enum.Material.Neon,
			Color = accent,
			Transparency = 0.9,
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
	-- The podium's "Showcase" label only marks an empty podium; a display speaks for itself.
	local dais = podium:FindFirstChild("Dais")
	local label = dais and dais:FindFirstChildOfClass("BillboardGui")
	if label then
		label.Enabled = view == nil
	end
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

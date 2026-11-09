-- First-minute intro hunt, client side (Config.Intro, IntroLayout, IntroService). For a brand new
-- player, right after the loading screen:
--   1. Wake up: black screen, eyelids blink open on the forest canopy, the camera rises behind you
--      and a glowing fox spirit streaks past and vanishes down the trail.
--   2. The chase: Pulse (Q / the big button) sends a ring out and shows where the spirit hides for a
--      few seconds (glow, light pillar, a beam from you to it). Getting close makes it bolt to its
--      next hiding spot. Twice.
--   3. The catch: cornered at the ruined shrine, Hold to Bind (E / hold the button). Chains shoot
--      up from a seal circle, the camera swings round, a white flash: SEALED. The server grants the
--      first relic and sends you home, where the normal tutorial starts.
-- The main HUD is hidden throughout; Skip intro is always on screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local IntroLayout = require(ReplicatedStorage.Shared.IntroLayout)
local Sounds = require(script.Parent.Parent.Sounds)

local IntroController = {}

local player = Players.LocalPlayer
local CFG = Config.Intro
local SPIRIT_COLOR = Color3.fromRGB(150, 225, 255)
local GOLD = Color3.fromRGB(255, 205, 120)
local SPIRIT_LIFT = 3.2

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function part(parent: Instance, props: { [string]: any }): Part
	local item = Instance.new("Part")
	item.Anchored = true
	item.CanCollide = false
	item.CanQuery = false
	item.CanTouch = false
	item.CastShadow = false
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(item :: any)[key] = value
	end
	item.Parent = parent
	return item
end

local function controls(): any?
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	return if ok and module then module:GetControls() else nil
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function IntroController.Start(screen: ScreenGui)
	task.spawn(function()
		-- Wait for the loading screen and the server's verdict.
		while player:GetAttribute("LoadingDone") ~= true do
			task.wait(0.2)
		end
		local waited = 0
		while player:GetAttribute("IntroPending") == nil and waited < 15 do
			waited += task.wait(0.2)
		end
		if player:GetAttribute("IntroPending") ~= true then
			return
		end
		IntroController.Run(screen)
	end)
end

function IntroController.Run(screen: ScreenGui)
	local IntroEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("IntroEvent") :: RemoteEvent
	local camera = workspace.CurrentCamera
	local control = controls()
	local connections: { RBXScriptConnection } = {}
	local ended = false

	screen.Enabled = false
	if control then
		control:Disable()
	end
	-- The deep-forest night is very dark: a light grade and a soft moonlit glow around the player
	-- for the intro only.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "IntroGrade"
	grade.Brightness = 0.08
	grade.Contrast = 0.12
	grade.Saturation = 0.1
	grade.TintColor = Color3.fromRGB(225, 235, 255)
	grade.Parent = game:GetService("Lighting")
	local glow: PointLight? = nil
	local function addGlow()
		local here = rootPart()
		if here and not glow then
			local newGlow = Instance.new("PointLight")
			newGlow.Name = "IntroGlow"
			newGlow.Color = Color3.fromRGB(170, 190, 255)
			newGlow.Range = 26
			newGlow.Brightness = 1.4
			newGlow.Shadows = false
			newGlow.Parent = here
			glow = newGlow
		end
	end

	-- UI ---------------------------------------------------------------------------------------
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = player:WaitForChild("PlayerGui")

	local function frame(props: { [string]: any }): Frame
		local item = Instance.new("Frame")
		item.BorderSizePixel = 0
		for key, value in props do
			(item :: any)[key] = value
		end
		item.Parent = gui
		return item
	end
	local function text(props: { [string]: any }): TextLabel
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Font = Enum.Font.FredokaOne
		item.TextColor3 = Color3.new(1, 1, 1)
		item.TextStrokeTransparency = 0.4
		for key, value in props do
			(item :: any)[key] = value
		end
		item.Parent = gui
		return item
	end

	local black = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 5 })
	local lidTop = frame({ Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 4 })
	local lidBottom = frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 4,
	})
	local flash = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 6 })
	local subtitle = text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.new(0.8, 0, 0, 40),
		TextSize = 28,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 7,
		Text = "",
	})
	local objective = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.new(0.8, 0, 0, 30),
		TextSize = 22,
		TextColor3 = GOLD,
		TextTransparency = 1,
		ZIndex = 3,
		Text = "",
	})
	local big = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(1, 0, 0, 90),
		TextSize = 84,
		TextColor3 = GOLD,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 7,
		Text = "SEALED!",
	})
	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -20, 0, 20)
	skip.Size = UDim2.fromOffset(150, 44)
	skip.BackgroundColor3 = Color3.fromRGB(40, 30, 58)
	skip.BackgroundTransparency = 0.2
	skip.Font = Enum.Font.FredokaOne
	skip.Text = "Skip intro"
	skip.TextSize = 20
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.ZIndex = 8
	skip.Parent = gui
	Instance.new("UICorner", skip).CornerRadius = UDim.new(0, 10)

	local action = Instance.new("TextButton")
	action.AnchorPoint = Vector2.new(1, 1)
	action.Position = UDim2.new(1, -40, 1, -150)
	action.Size = UDim2.fromOffset(150, 150)
	action.BackgroundColor3 = Color3.fromRGB(40, 70, 110)
	action.Font = Enum.Font.FredokaOne
	action.TextSize = 26
	action.TextColor3 = Color3.new(1, 1, 1)
	action.TextWrapped = true
	action.Visible = false
	action.ZIndex = 3
	action.AutoButtonColor = false
	action.Parent = gui
	Instance.new("UICorner", action).CornerRadius = UDim.new(1, 0)
	local actionStroke = Instance.new("UIStroke")
	actionStroke.Thickness = 4
	actionStroke.Color = SPIRIT_COLOR
	actionStroke.Parent = action
	local holdFill = Instance.new("Frame")
	holdFill.AnchorPoint = Vector2.new(0.5, 1)
	holdFill.Position = UDim2.fromScale(0.5, 1)
	holdFill.Size = UDim2.fromScale(1, 0)
	holdFill.BackgroundColor3 = GOLD
	holdFill.BackgroundTransparency = 0.35
	holdFill.BorderSizePixel = 0
	holdFill.ZIndex = 2
	holdFill.Parent = action
	Instance.new("UICorner", holdFill).CornerRadius = UDim.new(1, 0)
	local keyboard = UserInputService.KeyboardEnabled

	local function say(line: string, seconds: number?)
		subtitle.Text = line
		tween(subtitle, 0.35, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
		local token = line
		task.delay(seconds or 3, function()
			if subtitle.Text == token then
				tween(subtitle, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end)
	end
	local function goal(line: string)
		objective.Text = line
		tween(objective, 0.4, { TextTransparency = 0 })
	end

	-- World ------------------------------------------------------------------------------------
	local folder = Instance.new("Folder")
	folder.Name = "IntroFX"
	folder.Parent = workspace

	local spirit = part(folder, {
		Name = "IntroSpirit",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		Material = Enum.Material.Neon,
		Color = SPIRIT_COLOR,
	})
	local halo = part(folder, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Material = Enum.Material.Neon,
		Color = SPIRIT_COLOR,
		Transparency = 0.8,
	})
	local light = Instance.new("PointLight")
	light.Color = SPIRIT_COLOR
	light.Range = 20
	light.Brightness = 3
	light.Parent = spirit
	local spiritAttach = Instance.new("Attachment")
	spiritAttach.Parent = spirit
	local wisps = Instance.new("ParticleEmitter")
	wisps.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	wisps.Color = ColorSequence.new(SPIRIT_COLOR)
	wisps.LightEmission = 1
	wisps.Size = NumberSequence.new(0.6, 0)
	wisps.Lifetime = NumberRange.new(0.6, 1.2)
	wisps.Rate = 30
	wisps.Speed = NumberRange.new(1, 3)
	wisps.SpreadAngle = Vector2.new(180, 180)
	wisps.Parent = spiritAttach
	local trailA, trailB = Instance.new("Attachment"), Instance.new("Attachment")
	trailA.Position, trailB.Position = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0)
	trailA.Parent, trailB.Parent = spirit, spirit
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = trailA, trailB
	trail.Color = ColorSequence.new(SPIRIT_COLOR)
	trail.LightEmission = 1
	trail.Lifetime = 0.6
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = spirit

	local spiritPos = IntroLayout.world(Vector3.new(-14, SPIRIT_LIFT + 2, -10))
	local visible = 0
	local function setVisible(amount: number)
		visible = amount
		spirit.Transparency = 1 - amount
		halo.Transparency = 1 - amount * 0.2
		light.Enabled = amount > 0.05
		wisps.Enabled = amount > 0.05
		trail.Enabled = amount > 0.05
	end
	setVisible(0)
	local clock = 0
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt)
			clock += dt
			local bob = Vector3.new(0, math.sin(clock * 3) * 0.4, 0)
			spirit.CFrame = CFrame.new(spiritPos + bob)
			halo.CFrame = spirit.CFrame
			halo.Size = Vector3.one * (4 + math.sin(clock * 6) * 0.4)
		end)
	)

	local function flyTo(points: { Vector3 }, seconds: number)
		local done = false
		task.spawn(function()
			local each = seconds / #points
			for _, target in points do
				local from = spiritPos
				local t = 0
				while t < each do
					t += RunService.Heartbeat:Wait()
					local a = math.clamp(t / each, 0, 1)
					local eased = a * a * (3 - 2 * a)
					spiritPos = from:Lerp(target, eased) + Vector3.new(0, math.sin(a * math.pi) * 3, 0)
				end
				spiritPos = target
			end
			done = true
		end)
		return function()
			return done
		end
	end
	local function lifted(point: Vector3): Vector3
		return IntroLayout.world(point + Vector3.new(0, SPIRIT_LIFT, 0))
	end

	-- Cleanup ----------------------------------------------------------------------------------
	local function cleanup()
		for _, connection in connections do
			connection:Disconnect()
		end
		folder:Destroy()
		grade:Destroy()
		if glow then
			glow:Destroy()
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		screen.Enabled = true
		if control then
			control:Enable()
		end
		tween(black, 1, { BackgroundTransparency = 1 })
		for _, item in gui:GetDescendants() do
			if item:IsA("TextLabel") or item:IsA("TextButton") then
				item.Visible = false
			end
		end
		task.delay(1.1, function()
			gui:Destroy()
		end)
	end
	local function waitHome()
		local start = os.clock()
		while os.clock() - start < 4 do
			local root = rootPart()
			if root and (root.Position - IntroLayout.Origin.Position).Magnitude > 600 then
				break
			end
			task.wait(0.1)
		end
	end
	local function endIntro(how: string)
		if ended then
			return
		end
		ended = true
		tween(black, 0.5, { BackgroundTransparency = 0 })
		task.wait(0.55)
		IntroEvent:FireServer(how)
		waitHome()
		task.wait(0.3)
		cleanup()
	end
	skip.Activated:Connect(function()
		task.spawn(endIntro, "Skip")
	end)

	-- 1. Wake up --------------------------------------------------------------------------------
	IntroEvent:FireServer("Start")
	local start = os.clock()
	repeat
		task.wait(0.1)
		local root = rootPart()
	until (root and (root.Position - IntroLayout.Origin.Position).Magnitude < 60) or os.clock() - start > 6 or ended
	if ended then
		return
	end
	local root = rootPart() :: BasePart
	addGlow()
	local head = root.Position + Vector3.new(0, 0.6, 0)
	local forward = IntroLayout.Origin.LookVector
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(head, head + forward * 4 + Vector3.new(0, 10, 0))
	black.BackgroundTransparency = 1
	Sounds.Play("DistantWhisper")
	-- Two heavy blinks, then the eyes stay open.
	local function lids(open: number, seconds: number)
		tween(lidTop, seconds, { Size = UDim2.fromScale(1, 0.5 * (1 - open)) }, Enum.EasingStyle.Sine)
		tween(lidBottom, seconds, { Size = UDim2.fromScale(1, 0.5 * (1 - open)) }, Enum.EasingStyle.Sine)
		task.wait(seconds)
	end
	lids(0.25, 0.9)
	lids(0, 0.5)
	task.wait(0.3)
	lids(0.6, 0.8)
	lids(0.1, 0.4)
	say("...where am I?", 2.6)
	lids(1, 1.1)
	if ended then
		return
	end
	-- Rise behind the player.
	local behind = CFrame.lookAt(root.Position - forward * 11 + Vector3.new(0, 6, 0), root.Position + forward * 10 + Vector3.new(0, 2, 0))
	tween(camera, 2.4, { CFrame = behind }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	task.wait(2.5)
	if ended then
		return
	end
	-- The spirit streaks past.
	setVisible(1)
	spiritPos = lifted(Vector3.new(-16, 1, -12))
	Sounds.Play("SignalWhisper", spirit)
	Sounds.Play("BranchSnap")
	local arrived = flyTo({ lifted(Vector3.new(4, 1, -18)), lifted(Vector3.new(-2, 0, -30)), lifted(IntroLayout.Spots[1].At) }, 2.2)
	local followUntil = os.clock() + 2.4
	while os.clock() < followUntil and not ended do
		local eye = root.Position - forward * 11 + Vector3.new(0, 6, 0)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, spiritPos), 0.12)
		RunService.RenderStepped:Wait()
	end
	repeat
		task.wait()
	until arrived() or ended
	tween(halo, 0.6, { Transparency = 1 })
	tween(spirit, 0.6, { Transparency = 1 })
	task.wait(0.6)
	setVisible(0)
	if ended then
		return
	end
	say("A cursed spirit! It's getting away...", 3)
	camera.CameraType = Enum.CameraType.Custom
	if control then
		control:Enable()
	end
	goal(if keyboard then "Track the spirit: press Q to Pulse" else "Track the spirit: tap Pulse")
	action.Visible = true

	-- 2. The chase -------------------------------------------------------------------------------
	local stage = 1
	local fleeing = false
	local lastPulse = -math.huge
	local revealUntil = 0
	local binding = false
	local holdStart: number? = nil
	local beam: Beam? = nil
	local pillar: Part? = nil

	local function pulse()
		if ended or fleeing or binding or os.clock() - lastPulse < CFG.PulseCooldown then
			return
		end
		lastPulse = os.clock()
		local here = rootPart()
		if not here then
			return
		end
		Sounds.Play("Pulse")
		local ring = part(folder, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 4, 4),
			CFrame = CFrame.new(here.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = SPIRIT_COLOR,
			Transparency = 0.2,
		})
		tween(ring, 0.9, { Size = Vector3.new(0.3, 90, 90), Transparency = 1 })
		task.delay(1, function()
			ring:Destroy()
		end)
		revealUntil = os.clock() + CFG.RevealSeconds
		Sounds.Play("SignalPing", spirit)
		if not pillar then
			pillar = part(folder, {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(80, 2.2, 2.2),
				Material = Enum.Material.Neon,
				Color = SPIRIT_COLOR,
				Transparency = 1,
			})
		end
		if not beam then
			local fromAttach = Instance.new("Attachment")
			fromAttach.Name = "IntroBeamFrom"
			fromAttach.Parent = here
			local newBeam = Instance.new("Beam")
			newBeam.Attachment0, newBeam.Attachment1 = fromAttach, spiritAttach
			newBeam.Color = ColorSequence.new(SPIRIT_COLOR)
			newBeam.LightEmission = 1
			newBeam.Width0, newBeam.Width1 = 0.4, 1.2
			newBeam.FaceCamera = true
			newBeam.Segments = 20
			newBeam.CurveSize0 = 6
			newBeam.Parent = folder
			beam = newBeam
		end
		if stage == 1 then
			goal("Follow the light to the spirit")
		end
	end

	local function flee()
		fleeing = true
		local nextSpot = IntroLayout.Spots[stage + 1]
		setVisible(1)
		Sounds.Play("SignalWhisper", spirit)
		Sounds.Play("BranchSnap")
		say(if stage == 1 then "It saw you! Pulse again to find it." else "It's tiring... after it!", 3)
		local points = {}
		for _, point in nextSpot.Path do
			table.insert(points, lifted(point))
		end
		table.insert(points, lifted(nextSpot.At))
		local done = flyTo(points, 2.6)
		task.spawn(function()
			repeat
				task.wait()
			until done() or ended
			stage += 1
			fleeing = false
			revealUntil = 0
			if stage == #IntroLayout.Spots then
				goal("It's cornered at the shrine!")
				Sounds.Play("DistantHowl")
			else
				goal(if keyboard then "Press Q to Pulse and find it" else "Tap Pulse to find it")
			end
		end)
	end

	-- 3. The catch -------------------------------------------------------------------------------
	local function catch()
		binding = true
		action.Visible = false
		objective.Visible = false
		if control then
			control:Disable()
		end
		local here = rootPart()
		camera.CameraType = Enum.CameraType.Scriptable
		local center = spiritPos
		local ground = IntroLayout.world(IntroLayout.Spots[#IntroLayout.Spots].At + Vector3.new(0, 0.4, 0))
		Sounds.Play("ChainRattle", spirit)
		-- Seal circle: a faint gold disc under a ring of glowing segments and eight runes, spinning.
		local circle = part(folder, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.08, 1, 1),
			CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = GOLD,
			Transparency = 0.85,
		})
		tween(circle, 0.8, { Size = Vector3.new(0.08, 20, 20) }, Enum.EasingStyle.Back)
		local ringParts: { { Part: Part, Angle: number, Radius: number } } = {}
		for k = 1, 28 do
			local angle = k / 28 * math.pi * 2
			table.insert(ringParts, {
				Angle = angle,
				Radius = 9.6,
				Part = part(folder, {
					Size = Vector3.new(2, 0.12, 0.35),
					Material = Enum.Material.Neon,
					Color = GOLD,
					Transparency = 0.15,
				}),
			})
		end
		for k = 1, 8 do
			table.insert(ringParts, {
				Angle = k / 8 * math.pi * 2,
				Radius = 7.4,
				Part = part(folder, {
					Size = Vector3.new(0.9, 0.12, 0.9),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(255, 240, 200),
				}),
			})
		end
		local spin = 0
		local function placeRing(dt: number)
			spin += dt * 0.8
			for _, entry in ringParts do
				local a = entry.Angle + spin * (if entry.Radius < 8 then -1 else 1)
				local at = ground + Vector3.new(math.cos(a) * entry.Radius, 0.02, math.sin(a) * entry.Radius)
				-- Dashes follow the circle (tangent), runes just turn with it.
				entry.Part.CFrame = CFrame.new(at) * CFrame.Angles(0, -a + math.pi / 2, 0)
			end
		end
		placeRing(0)
		-- Six chains shoot up from the circle to the spirit, link by link.
		for k = 0, 5 do
			local angle = k / 6 * math.pi * 2
			local anchor = ground + Vector3.new(math.cos(angle) * 9, 0, math.sin(angle) * 9)
			task.spawn(function()
				local links = 9
				for i = 1, links do
					local a = (i - 0.5) / links
					local at = anchor:Lerp(center, a)
					part(folder, {
						Size = Vector3.new(0.5, 0.5, 1.4),
						CFrame = CFrame.lookAt(at, center) * CFrame.Angles(0, 0, if i % 2 == 0 then math.rad(90) else 0),
						Material = Enum.Material.Neon,
						Color = GOLD,
					})
					task.wait(0.035)
				end
			end)
		end
		-- The camera swings round the spirit while the chains tighten.
		local angle0 = math.atan2((here and here.Position.Z or center.Z + 10) - center.Z, (here and here.Position.X or center.X) - center.X)
		local t = 0
		task.delay(0.5, function()
			Sounds.Play("ChainTighten", spirit)
			Sounds.Play("BindRiser")
		end)
		while t < 2.8 do
			local dt = RunService.RenderStepped:Wait()
			t += dt
			placeRing(dt)
			local a = angle0 + t * 0.7
			local radius = 20 - t * 2
			local eye = center + Vector3.new(math.cos(a) * radius, 9 - t * 1.2, math.sin(a) * radius)
			local shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * (t * 0.15)
			camera.CFrame = CFrame.lookAt(eye, center + shake)
			camera.FieldOfView = 70 - t * 6
			halo.Size = Vector3.one * (4 + math.sin(t * 30) * 1.2)
		end
		-- Flash, shockwave, sealed.
		Sounds.Play("SealSuck")
		Sounds.Play("Thunder")
		tween(flash, 0.12, { BackgroundTransparency = 0 })
		task.wait(0.15)
		setVisible(0)
		halo.Transparency = 1
		local wave = part(folder, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 6, 6),
			CFrame = CFrame.new(ground + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = Color3.new(1, 1, 1),
			Transparency = 0.1,
		})
		tween(wave, 1.2, { Size = Vector3.new(0.4, 120, 120), Transparency = 1 })
		for _, item in folder:GetChildren() do
			if item:IsA("BasePart") and item ~= wave and item ~= circle and item ~= spirit and item ~= halo then
				tween(item, 0.8, { Transparency = 1 })
			end
		end
		tween(flash, 1.4, { BackgroundTransparency = 1 })
		Sounds.Play("Shine")
		big.Text = "SEALED!"
		tween(big, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0.3 }, Enum.EasingStyle.Back)
		say("The spirit is bound into a relic. Your shrine awaits.", 3.5)
		task.wait(3)
		tween(big, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		endIntro("Finish")
	end

	-- Input and the per-frame chase logic.
	local function holding(): boolean
		return holdStart ~= nil
	end
	local function startHold()
		if binding or ended then
			return
		end
		holdStart = os.clock()
	end
	local function stopHold()
		holdStart = nil
		holdFill.Size = UDim2.fromScale(1, 0)
	end
	local canBind = false
	action.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if canBind then
				startHold()
			else
				pulse()
			end
		end
	end)
	action.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stopHold()
		end
	end)
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.Q then
				pulse()
			elseif input.KeyCode == Enum.KeyCode.E and canBind then
				startHold()
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.E then
				stopHold()
			end
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			if ended or binding then
				return
			end
			-- The chase is played with the normal camera, whatever left it scripted.
			if camera.CameraType ~= Enum.CameraType.Custom then
				camera.CameraType = Enum.CameraType.Custom
			end
			local here = rootPart()
			if not here then
				return
			end
			local distance = (here.Position - spiritPos).Magnitude
			local final = stage == #IntroLayout.Spots
			-- Glow: always while fleeing or cornered, otherwise only after a pulse.
			local revealed = fleeing or final or os.clock() < revealUntil
			local target = if fleeing then 1 elseif final then 0.85 elseif revealed then 0.9 else 0
			setVisible(visible + (target - visible) * 0.15)
			if pillar then
				pillar.CFrame = CFrame.new(spiritPos + Vector3.new(0, 38, 0)) * CFrame.Angles(0, 0, math.rad(90))
				pillar.Transparency = if revealed and not fleeing and not final then 0.55 else 1
			end
			if beam then
				beam.Enabled = revealed and not fleeing and not final and distance > 10
			end
			if not final and not fleeing and distance < CFG.FleeDistance then
				flee()
			end
			canBind = final and not fleeing and distance < CFG.BindDistance
			action.Text = if canBind then (if keyboard then "HOLD\nE" else "HOLD\nTO BIND") else (if keyboard then "PULSE\nQ" else "PULSE")
			actionStroke.Color = if canBind then GOLD else SPIRIT_COLOR
			if final and not fleeing then
				goal(if canBind then (if keyboard then "Hold E to bind the spirit!" else "Hold the button to bind it!") else "It's cornered at the shrine! Get close.")
			end
			if holding() then
				if not canBind then
					stopHold()
				else
					local progress = (os.clock() - (holdStart :: number)) / CFG.BindSeconds
					holdFill.Size = UDim2.fromScale(1, math.clamp(progress, 0, 1))
					if progress >= 1 then
						stopHold()
						task.spawn(catch)
					end
				end
			end
		end)
	)
end

return IntroController

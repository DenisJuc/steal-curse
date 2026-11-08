-- Zone luck gates, this player's view (ZoneGateService is the authority). Every border between an
-- open and a locked cell (ZoneGates.borders for the replicated "GateLuck") gets a glowing seal line
-- on the ground and big "NEEDS xN LUCK" signs, built only on this client, so other players see
-- their own gates. When gate luck opens a cell its line flashes and sinks away and one banner says
-- "Abandoned Village Deep unlocked!" (none on join). The server's push-back message shows here.
-- Each line also raises a seal wall: a shimmering, solid barrier (local to this player, so it only
-- stops the players it applies to) that you walk into instead of being teleported back. Bumping it
-- says what it needs. The server's push-back stays as the authority (spawns, teleports, exploits);
-- with the wall in place a player walking normally never reaches it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local WorldLayout = require(ReplicatedStorage.Shared.WorldLayout)
local ZoneGates = require(ReplicatedStorage.Shared.ZoneGates)
local Banner = require(script.Parent.Parent.UI.Banner)
local Toasts = require(script.Parent.Parent.UI.Toasts)

local ZoneGateView = {}

local GATES = Config.ZoneGates
local CONTEXT: ZoneGates.Context = {
	Areas = Config.Areas,
	World = Config.World,
	Bands = Config.HuntStreak,
	Gates = GATES,
}
local SEGMENT = 10
local SIGN_EVERY = 110
local LINE_COLOR = Color3.fromRGB(GATES.LineColor[1], GATES.LineColor[2], GATES.LineColor[3])
local BAND_NAMES = { Edge = "Edge", Deep = "Deep", Heart = "Heart" }
-- Seal wall: height above the line, depth below it (so dips in the ground leave no gap under it),
-- and thickness. Taller than a jump.
local WALL_HEIGHT = 14
local WALL_DEPTH = 6
local WALL_THICKNESS = 1
-- The neon sheet that makes the wall visible: faint enough to see the zone through it.
local WALL_GLOW_TRANSPARENCY = 0.9
-- Seconds between "needs xN LUCK" messages from bumping a wall.
local BUMP_GAP = Config.ZoneGates.MessageGap

local areaNames: { [string]: string } = {}
for _, area in Config.Areas do
	areaNames[area.Id] = area.Name
end

local function keyOf(border: ZoneGates.Border): string
	return `{border.Kind}:{border.Area}:{border.Band}:{math.floor((border.Radius or border.Angle or 0) * 10)}`
end

local function groundY(x: number, z: number, folder: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else 0
end

local lastBump = 0

-- Bumping a wall says what the zone needs (the server's message only comes on a push-back).
local function bumped(border: ZoneGates.Border)
	local now = os.clock()
	if now - lastBump < BUMP_GAP then
		return
	end
	lastBump = now
	local luck = Players.LocalPlayer:GetAttribute("GateLuck")
	local have = if type(luck) == "number" then ` (you: x{Format.number(luck)})` else ""
	Toasts.Show(
		`{areaNames[border.Area] or border.Area} {BAND_NAMES[border.Band]} needs x{Format.number(border.Required)} LUCK{have}`,
		"Error"
	)
end

local function wallPart(a: Vector3, b: Vector3, border: ZoneGates.Border, parent: Instance)
	local length = (b - a).Magnitude
	local wall = Instance.new("Part")
	wall.Name = "SealWall"
	wall.Anchored = true
	wall.CanCollide = true
	-- Not queryable: the camera, ground raycasts and VFX placement look straight through it.
	wall.CanQuery = false
	wall.CanTouch = true
	wall.CastShadow = false
	wall.Material = Enum.Material.ForceField
	wall.Color = LINE_COLOR
	wall.Transparency = 0
	-- Long enough to overlap its neighbours so corners leave no gap.
	wall.Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT + WALL_DEPTH, length + 1.5)
	wall.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, (WALL_HEIGHT - WALL_DEPTH) / 2, 0)
	wall.Touched:Connect(function(hit)
		local character = Players.LocalPlayer.Character
		if character and hit:IsDescendantOf(character) then
			bumped(border)
		end
	end)
	wall.Parent = parent
	-- ForceField alone is almost invisible in the dark wild (players hit an unseen barrier), so a
	-- thin translucent neon sheet makes the wall read as a red seal barrier.
	local glow = Instance.new("Part")
	glow.Name = "SealWallGlow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.CastShadow = false
	glow.Material = Enum.Material.Neon
	glow.Color = LINE_COLOR
	glow.Transparency = WALL_GLOW_TRANSPARENCY
	glow.Size = Vector3.new(0.2, wall.Size.Y, wall.Size.Z)
	glow.CFrame = wall.CFrame
	glow.Parent = parent
end

local function segmentPart(a: Vector3, b: Vector3, parent: Instance)
	local part = Instance.new("Part")
	part.Name = "SealLine"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = LINE_COLOR
	part.Transparency = 0.15
	local length = (b - a).Magnitude
	part.Size = Vector3.new(0.6, 0.35, length + 0.4)
	part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 0.15, 0)
	part.Parent = parent
end

local function sign(at: Vector3, border: ZoneGates.Border, parent: Instance)
	local anchor = Instance.new("Part")
	anchor.Name = "GateSign"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	-- Well above head height so it reads over characters and the HUD bubble.
	anchor.CFrame = CFrame.new(at + Vector3.new(0, 12, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(280, 90)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = anchor
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.62)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 120, 135)
	title.TextStrokeTransparency = 0
	title.Text = `NEEDS x{Format.number(border.Required)} LUCK`
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.62)
	sub.Size = UDim2.fromScale(1, 0.32)
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(235, 230, 240)
	sub.TextStrokeTransparency = 0.2
	sub.Text = `{areaNames[border.Area] or border.Area} · {BAND_NAMES[border.Band]}`
	sub.Parent = gui
	-- A small glowing post under the sign so it reads as a marker, not floating text.
	local post = Instance.new("Part")
	post.Name = "GatePost"
	post.Anchored = true
	post.CanCollide = false
	post.CanQuery = false
	post.CanTouch = false
	post.Material = Enum.Material.Neon
	post.Color = LINE_COLOR
	post.Size = Vector3.new(0.5, 9, 0.5)
	post.CFrame = CFrame.new(at + Vector3.new(0, 4.5, 0))
	post.Parent = parent
	anchor.Parent = parent
end

local function build(border: ZoneGates.Border, root: Instance): Model
	local model = Instance.new("Model")
	model.Name = keyOf(border)
	local points: { Vector3 } = {}
	if border.Kind == "Arc" then
		local radius = border.Radius :: number
		local span = border.To - border.From
		local steps = math.max(2, math.ceil(math.rad(span) * radius / SEGMENT))
		for i = 0, steps do
			local x, z = WorldLayout.polar(border.From + span * i / steps, radius)
			table.insert(points, Vector3.new(x, 0, z))
		end
	else
		local angle = border.Angle :: number
		local length = border.To - border.From
		local steps = math.max(2, math.ceil(length / SEGMENT))
		for i = 0, steps do
			local x, z = WorldLayout.polar(angle, border.From + length * i / steps)
			table.insert(points, Vector3.new(x, 0, z))
		end
	end
	for index, point in points do
		points[index] = Vector3.new(point.X, groundY(point.X, point.Z, root), point.Z)
	end
	local walked = 0
	local nextSign = SIGN_EVERY / 2
	for i = 1, #points - 1 do
		segmentPart(points[i], points[i + 1], model)
		wallPart(points[i], points[i + 1], border, model)
		walked += (points[i + 1] - points[i]).Magnitude
		if walked >= nextSign then
			sign(points[i + 1], border, model)
			nextSign += SIGN_EVERY
		end
	end
	model.Parent = root
	return model
end

local function dissolve(model: Model)
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			-- Open at once: the wall stops blocking before it finishes fading.
			item.CanCollide = false
		end
		if item:IsA("BasePart") and item.Transparency < 1 then
			item.Color = Color3.fromRGB(255, 240, 170)
			TweenService:Create(item, info, {
				Transparency = 1,
				CFrame = item.CFrame * CFrame.new(0, 3, 0),
			}):Play()
		elseif item:IsA("BillboardGui") then
			item.Enabled = false
		end
	end
	task.delay(0.9, function()
		model:Destroy()
	end)
end

function ZoneGateView.Start()
	local player = Players.LocalPlayer
	local root = Instance.new("Folder")
	root.Name = "ZoneGateLines"
	root.Parent = workspace
	local shown: { [string]: { Model: Model, Border: ZoneGates.Border } } = {}
	local first = true

	local function refresh()
		local luck = player:GetAttribute("GateLuck")
		if type(luck) ~= "number" then
			return
		end
		local wanted = {}
		for _, border in ZoneGates.borders(CONTEXT, luck) do
			wanted[keyOf(border)] = border
		end
		local opened: { [string]: boolean } = {}
		for key, entry in shown do
			if not wanted[key] then
				shown[key] = nil
				if first then
					entry.Model:Destroy()
				else
					dissolve(entry.Model)
					-- The cell behind this line is open now (one banner per cell).
					if ZoneGates.allowedCell(CONTEXT, luck, entry.Border.Area, entry.Border.Band) then
						opened[`{entry.Border.Area}|{entry.Border.Band}`] = true
					end
				end
			end
		end
		for key, border in wanted do
			if not shown[key] then
				shown[key] = { Model = build(border, root), Border = border }
			end
		end
		if not first then
			local cells = {}
			for cell in opened do
				table.insert(cells, cell)
			end
			local gold = Color3.fromRGB(255, 215, 120)
			if #cells == 1 then
				local area, band = string.match(cells[1], "^(.-)|(.*)$")
				Banner.Show(
					"ZONE UNLOCKED",
					`{areaNames[area :: string] or area} {BAND_NAMES[band :: string] or band} unlocked!`,
					gold
				)
			elseif #cells > 1 then
				-- A big jump in luck opens several at once: one banner, not a queue of them.
				Banner.Show("ZONES UNLOCKED", `{#cells} new zones of the wild are open!`, gold)
			end
		end
		first = false
	end

	player:GetAttributeChangedSignal("GateLuck"):Connect(refresh)
	task.defer(refresh)

	local Blocked = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ZoneGateBlocked") :: RemoteEvent
	Blocked.OnClientEvent:Connect(function(info: any)
		if type(info) == "table" and type(info.Text) == "string" then
			local where = if type(info.Area) == "string" then `{info.Area} {BAND_NAMES[info.Band] or ""} ` else ""
			Toasts.Show(`{where}{info.Text}`, "Error")
		end
	end)
end

return ZoneGateView

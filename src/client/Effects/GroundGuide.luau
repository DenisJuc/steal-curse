-- Glowing chevrons on the ground that lead the local player somewhere (tutorial guidance): "go to
-- the wild", "walk over the collect pad", "this way to the nearest spirit". The chevrons follow a
-- PathfindingService route (straight line if no route is found), are re-routed as the player moves,
-- and scroll toward the target so the direction reads at a glance. Client-only, local parts.
--
-- GroundGuide.SetTarget(getter) starts guiding to whatever `getter` returns each update (nil hides
-- the arrows, e.g. no spirit around yet); GroundGuide.SetTarget(nil) stops.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GroundGuide = {}

local COUNT = 9
local SPACING = 5
-- First chevron this far ahead of the player, so it never sits under their feet.
local START = 4
-- Studs per second the chevrons scroll toward the target.
local SCROLL = 6
-- Hide when the target is this close: the player is there.
local ARRIVED = 3
local REPATH_SECONDS = 1.2
local COLOR = Color3.fromRGB(255, 215, 120)

local folder: Folder? = nil
local chevrons: { Model } = {}
local getTarget: (() -> Vector3?)? = nil
local route: { Vector3 } = {}
local routedTo: Vector3? = nil
local lastRoute = 0
local routing = false
local connection: RBXScriptConnection? = nil

local function makeChevron(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "GuideArrow"
	for side = -1, 1, 2 do
		local arm = Instance.new("Part")
		arm.Name = "Arm"
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CanTouch = false
		arm.CastShadow = false
		arm.Material = Enum.Material.Neon
		arm.Color = COLOR
		-- Big enough to read from the default camera distance.
		arm.Size = Vector3.new(0.8, 0.15, 3.4)
		arm:SetAttribute("Side", side)
		arm.Parent = model
	end
	model.Parent = parent
	return model
end

local function ensureParts()
	if folder and folder.Parent then
		return
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "TutorialGuide"
	newFolder.Parent = workspace
	folder = newFolder
	table.clear(chevrons)
	for _ = 1, COUNT do
		table.insert(chevrons, makeChevron(newFolder))
	end
end

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function ground(position: Vector3): Vector3?
	local exclude: { Instance } = {}
	if folder then
		table.insert(exclude, folder)
	end
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(exclude, character)
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rayParams)
	return if hit then hit.Position else nil
end

local function reroute(from: Vector3, to: Vector3)
	if routing then
		return
	end
	routing = true
	lastRoute = os.clock()
	task.spawn(function()
		-- Walk-only route first: the plot front fence is low enough to jump, and arrows that hop
		-- fences confuse new players (they should leave through the gate). Jumps only when no
		-- walking route exists (some wild ledges), then a straight line.
		local points = {}
		for _, canJump in { false, true } do
			local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = canJump })
			local ok = pcall(function()
				path:ComputeAsync(from, to)
			end)
			if ok and path.Status == Enum.PathStatus.Success then
				for _, waypoint in path:GetWaypoints() do
					table.insert(points, waypoint.Position)
				end
				break
			end
		end
		if #points == 0 then
			points = { from, to }
		end
		route = points
		routedTo = to
		routing = false
	end)
end

local function hideAll()
	for _, chevron in chevrons do
		for _, arm in chevron:GetChildren() do
			(arm :: BasePart).Transparency = 1
		end
	end
end

-- The route from the player's current spot: drop the waypoints already passed.
local function liveRoute(from: Vector3): { Vector3 }
	local best, bestDistance = 1, math.huge
	for i, point in route do
		local distance = (Vector3.new(point.X, from.Y, point.Z) - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = i, distance
		end
	end
	local points = { from }
	for i = best + 1, #route do
		table.insert(points, route[i])
	end
	if #points == 1 and routedTo then
		table.insert(points, routedTo)
	end
	return points
end

local function pointAt(points: { Vector3 }, distance: number): (Vector3?, Vector3?)
	local walked = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length = flat.Magnitude
		if length > 1e-3 then
			if walked + length >= distance then
				local t = (distance - walked) / length
				return a:Lerp(b, t), flat.Unit
			end
			walked += length
		end
	end
	return nil, nil
end

local function update()
	local root = rootPart()
	local target = getTarget and getTarget()
	if not root or not target then
		hideAll()
		return
	end
	local from = root.Position
	if (Vector3.new(target.X, from.Y, target.Z) - from).Magnitude <= ARRIVED then
		hideAll()
		return
	end
	if not routedTo or (routedTo - target).Magnitude > 4 or os.clock() - lastRoute > REPATH_SECONDS then
		reroute(from, target)
	end
	if #route == 0 then
		return
	end
	local points = liveRoute(from)
	local phase = (os.clock() * SCROLL) % SPACING
	for i, chevron in chevrons do
		local along = START + (i - 1) * SPACING + phase
		local spot, direction = pointAt(points, along)
		local floor = spot and ground(spot)
		if not spot or not direction or not floor then
			for _, arm in chevron:GetChildren() do
				(arm :: BasePart).Transparency = 1
			end
			continue
		end
		-- Fade in at the near end and out at the far end so the scroll loops without popping.
		local fade = math.min(1, (along - START) / SPACING, (START + COUNT * SPACING - along) / SPACING)
		local base = CFrame.lookAt(floor + Vector3.new(0, 0.15, 0), floor + Vector3.new(0, 0.15, 0) + direction)
		for _, arm in chevron:GetChildren() do
			local part = arm :: BasePart
			local side = part:GetAttribute("Side") :: number
			-- Two arms meeting at the front: a ">" pointing along the route.
			part.CFrame = base * CFrame.new(side * 1.05, 0, 0.6) * CFrame.Angles(0, math.rad(side * 40), 0)
			part.Transparency = 0.15 + 0.85 * (1 - math.clamp(fade, 0, 1))
		end
	end
end

function GroundGuide.SetTarget(getter: (() -> Vector3?)?)
	getTarget = getter
	route = {}
	routedTo = nil
	if getter then
		ensureParts()
		if not connection then
			connection = RunService.Heartbeat:Connect(update)
		end
	else
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if folder then
			folder:Destroy()
			folder = nil
		end
		table.clear(chevrons)
	end
end

function GroundGuide.IsActive(): boolean
	return getTarget ~= nil
end

return GroundGuide

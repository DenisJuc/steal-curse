-- Client-side level of detail for the Showcases on every plot (built by the server's
-- ShowcaseVisuals). Far away (or with Low effects) their lights, sparkles and light pillar are
-- switched off on this client; nearby, the ornaments slowly orbit. Also hides the pose prompt on
-- plots that aren't ours (only the owner can pose).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)

local ShowcaseLOD = {}

-- Beyond this distance only the solid structure is drawn.
local DETAIL_RANGE = 150
local CHECK_SECONDS = 0.5
local ORBIT_SPEED = math.rad(20)

type Entry = { Display: Model, Near: boolean?, Low: boolean?, Angle: number, Origin: CFrame? }

local function plotsFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Plots")
end

local function setDetail(display: Model, on: boolean)
	for _, descendant in display:GetDescendants() do
		if descendant:IsA("PointLight") or descendant:IsA("ParticleEmitter") then
			descendant.Enabled = on
		elseif descendant:IsA("BasePart") and descendant.Name == "LightPillar" then
			descendant.LocalTransparencyModifier = if on then 0 else 1
		end
	end
end

function ShowcaseLOD.Start()
	local entries: { [Model]: Entry } = {}
	local elapsed = 0

	local function check()
		local folder = plotsFolder()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not folder or not root or not root:IsA("BasePart") then
			return
		end
		local low = Settings.LowEffects()
		local seen = {}
		for _, plot in folder:GetChildren() do
			local podium = plot:FindFirstChild("ShowcasePodium")
			local display = podium and podium:FindFirstChild("Display")
			if not display or not display:IsA("Model") then
				continue
			end
			seen[display] = true
			local entry = entries[display]
			if not entry then
				entry = { Display = display, Angle = 0 }
				entries[display] = entry
				local prompt = display:FindFirstChild("PosePrompt", true)
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Enabled = prompt:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
				end
				local ornaments = display:FindFirstChild("Ornaments")
				if ornaments and ornaments:IsA("Model") then
					entry.Origin = ornaments:GetPivot()
				end
			end
			local near = (display:GetPivot().Position - root.Position).Magnitude <= DETAIL_RANGE
			if entry.Near ~= near or entry.Low ~= low then
				entry.Near, entry.Low = near, low
				setDetail(display, near and not low)
			end
		end
		for display in entries do
			if not seen[display] then
				entries[display] = nil
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= CHECK_SECONDS then
			elapsed = 0
			check()
		end
		for _, entry in entries do
			local ornaments = entry.Display:FindFirstChild("Ornaments")
			if entry.Near and not entry.Low and entry.Origin and ornaments and ornaments:IsA("Model") then
				entry.Angle = (entry.Angle + ORBIT_SPEED * dt) % (2 * math.pi)
				ornaments:PivotTo(entry.Origin * CFrame.Angles(0, entry.Angle, 0))
			end
		end
	end)
end

return ShowcaseLOD

-- Client-side level of detail for the Showcases on every plot (built by the server's
-- ShowcaseVisuals). Nearby, each "ShowcaseVfx" anchor gets its premade effect (RelicAura), the
-- floating seals orbit and the star orrery turns; far away (or with Low effects) effects and
-- lights are dropped on this client. Also hides the pose prompt on plots that aren't ours (only
-- the owner can pose) and while we are posing, so it doesn't cover the pose.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)
local RelicAura = require(script.Parent.RelicAura)

local ShowcaseLOD = {}

-- Beyond this distance only the solid structure is drawn.
local DETAIL_RANGE = 150
local CHECK_SECONDS = 0.5
local ORBIT_SPEED = math.rad(20)
local ORRERY_SPEED = math.rad(14)

type Entry = {
	Display: Model,
	Near: boolean?,
	Low: boolean?,
	Angle: number,
	Origin: CFrame?,
	OrreryOrigin: CFrame?,
	Effects: { RelicAura.Handle },
	Prompt: ProximityPrompt?,
}

local function plotsFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Plots")
end

local function setDetail(entry: Entry, on: boolean)
	for _, descendant in entry.Display:GetDescendants() do
		if descendant:IsA("PointLight") then
			descendant.Enabled = on
		end
	end
	for _, handle in entry.Effects do
		handle:Destroy()
	end
	entry.Effects = {}
	if not on then
		return
	end
	for _, anchor in entry.Display:GetDescendants() do
		local name = anchor:GetAttribute("ShowcaseVfx")
		local template = type(name) == "string" and RelicAura.template(name)
		if template and anchor:IsA("BasePart") then
			local scale = anchor:GetAttribute("VfxScale")
			table.insert(entry.Effects, RelicAura.attach(anchor, template, {
				Scale = if type(scale) == "number" then scale else 1,
			}))
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
				entry = { Display = display, Angle = 0, Effects = {} }
				entries[display] = entry
				local prompt = display:FindFirstChild("PosePrompt", true)
				if prompt and prompt:IsA("ProximityPrompt") then
					entry.Prompt = prompt
				end
				local ornaments = display:FindFirstChild("Ornaments")
				if ornaments and ornaments:IsA("Model") then
					entry.Origin = ornaments:GetPivot()
				end
				local orrery = display:FindFirstChild("Orrery")
				if orrery and orrery:IsA("Model") then
					entry.OrreryOrigin = orrery:GetPivot()
				end
			end
			if entry.Prompt then
				local posing = character:GetAttribute("ShowcasePose") ~= nil
				entry.Prompt.Enabled = entry.Prompt:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
					and not posing
			end
			local near = (display:GetPivot().Position - root.Position).Magnitude <= DETAIL_RANGE
			if entry.Near ~= near or entry.Low ~= low then
				entry.Near, entry.Low = near, low
				setDetail(entry, near and not low)
			end
		end
		for display, entry in entries do
			if not seen[display] then
				for _, handle in entry.Effects do
					handle:Destroy()
				end
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
			local orrery = entry.Display:FindFirstChild("Orrery")
			if entry.Near and not entry.Low and entry.OrreryOrigin and orrery and orrery:IsA("Model") then
				orrery:PivotTo(entry.OrreryOrigin * CFrame.Angles(0, os.clock() * ORRERY_SPEED, 0))
			end
		end
	end)
end

return ShowcaseLOD

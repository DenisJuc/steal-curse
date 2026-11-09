-- Draw distance for small wild props (2026-11-09, phones): flowers, ferns, mushrooms, rocks, logs
-- and other map props smaller than MAX_SIZE studs are parked out of the workspace on this client
-- while they are farther from the camera than the range (deep in the fog or behind the town veil,
-- so nothing visible pops), and come back as you approach. Low effects (phones by default) use a
-- shorter range. Landmarks, shrines and perches always stay. Only this client changes; the server
-- copy is untouched.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)

local DecorLOD = {}

local MAX_SIZE = 30
local RANGE = { Full = 320, Low = 180 }
-- Studs of slack before a parked prop returns, so props on the edge don't flicker in and out.
local HYSTERESIS = 20
-- Props checked per frame (about 1,000 props: a full sweep every few frames, never one long frame).
local PER_STEP = 120
local KEEP_TAGS = { "Landmark", "CursedShrine", "Perch" }

type Entry = { Model: Model, Position: Vector3, Home: Instance, Parked: boolean }

local function keep(model: Model): boolean
	for _, tag in KEEP_TAGS do
		if CollectionService:HasTag(model, tag) then
			return true
		end
	end
	return false
end

function DecorLOD.Start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local wild = map:WaitForChild("Wild")
		local parking = Instance.new("Folder")
		parking.Name = "ParkedDecor"
		parking.Parent = ReplicatedStorage

		local entries: { Entry } = {}
		for _, model in wild:GetDescendants() do
			if not model:IsA("Model") or model:GetAttribute("Prop") == nil or keep(model) then
				continue
			end
			-- Only top-level props (a prop nested in another prop moves with its parent).
			if model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model") and model.Parent:GetAttribute("Prop") ~= nil then
				continue
			end
			local ok, extents = pcall(function()
				return model:GetExtentsSize()
			end)
			if not ok or math.max(extents.X, extents.Y, extents.Z) > MAX_SIZE then
				continue
			end
			table.insert(entries, { Model = model, Position = model:GetPivot().Position, Home = model.Parent :: Instance, Parked = false })
		end

		local cursor = 1
		RunService.Heartbeat:Connect(function()
			local camera = workspace.CurrentCamera
			if not camera or #entries == 0 then
				return
			end
			local focus = camera.Focus.Position
			local range = if Settings.LowEffects() then RANGE.Low else RANGE.Full
			for _ = 1, math.min(PER_STEP, #entries) do
				local entry = entries[cursor]
				cursor = cursor % #entries + 1
				if entry.Model.Parent == nil and not entry.Parked then
					continue -- destroyed by the server
				end
				local offset = entry.Position - focus
				local distance = Vector2.new(offset.X, offset.Z).Magnitude
				if entry.Parked and distance < range - HYSTERESIS then
					entry.Model.Parent = entry.Home
					entry.Parked = false
				elseif not entry.Parked and distance > range then
					entry.Model.Parent = parking
					entry.Parked = true
				end
			end
		end)
	end)
end

return DecorLOD

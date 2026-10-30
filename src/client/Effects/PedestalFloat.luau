-- Relics on pedestals (the server's RelicDisplay parts) turn slowly and bob up and down, on this
-- client only. Their welded auras ride along; the pedestal lights sit on the stand, not the relic.
-- Only displays within RANGE of the camera move; Low effects keeps the bob but drops the turn.

local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)

local PedestalFloat = {}

local RANGE = 140
local BOB_STUDS = 0.35
local BOB_SPEED = 1.6
-- Radians per second.
local TURN_SPEED = 0.6

type Entry = { Base: CFrame, Phase: number }

function PedestalFloat.Start()
	local entries: { [BasePart]: Entry } = {}

	local function track(item: Instance)
		if not item:IsA("BasePart") or item.Name ~= "RelicDisplay" or entries[item] then
			return
		end
		local part = item :: BasePart
		entries[part] = { Base = part.CFrame, Phase = math.random() * math.pi * 2 }
		part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(workspace) then
				entries[part] = nil
			end
		end)
	end

	workspace.DescendantAdded:Connect(track)
	for _, item in workspace:GetDescendants() do
		track(item)
	end

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local focus = camera.CFrame.Position
		local now = os.clock()
		local turn = not Settings.LowEffects()
		for part, entry in entries do
			local base = entry.Base
			if (base.Position - focus).Magnitude > RANGE then
				continue
			end
			local bob = math.sin(now * BOB_SPEED + entry.Phase) * BOB_STUDS
			local angle = if turn then now * TURN_SPEED + entry.Phase else 0
			part.CFrame = CFrame.new(base.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, angle, 0) * base.Rotation
		end
	end)
end

return PedestalFloat

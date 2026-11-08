-- After a teleport (spawning at your shrine, Home / Hub / Wild / Shrine travel) the camera kept its
-- old angle, so you arrived looking the wrong way: at the street instead of into your shrine. When
-- the character jumps farther than JUMP studs in one frame, swing the camera behind its new facing.
-- Only the normal (Custom) camera is touched; reveals and binds that script the camera are left alone.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraSnap = {}

local JUMP = 40
-- High enough to look over the sacred rope across a plot gate and under the torii beam when you
-- arrive home (the spawn sits just inside the gate).
local BACK = 12
local UP = 10

local function snap(root: BasePart)
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	flat = flat.Unit
	local focus = root.Position + Vector3.new(0, 1.5, 0)
	camera.CFrame = CFrame.lookAt(focus - flat * BACK + Vector3.new(0, UP, 0), focus + flat * 4)
end

function CameraSnap.Start()
	local last: Vector3? = nil
	local lastRoot: BasePart? = nil
	RunService.RenderStepped:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			last, lastRoot = nil, nil
			return
		end
		local position = root.Position
		if root == lastRoot and last and (position - last).Magnitude > JUMP then
			snap(root)
		end
		last, lastRoot = position, root
	end)
end

return CameraSnap

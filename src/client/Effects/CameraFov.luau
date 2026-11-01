-- The camera's resting field of view, shared by every effect that zooms (reveal zoom, bind
-- close-in). Effects zoom relative to this baseline and return to it, never to whatever the
-- camera shows at that moment: reading the live value while another zoom is still easing back
-- made back-to-back reveals stack until the view sat inside the character.

local CameraFov = {}

local DEFAULT = 70
local rest: number? = nil

function CameraFov.Rest(): number
	if not rest then
		local camera = workspace.CurrentCamera
		local current = if camera then camera.FieldOfView else DEFAULT
		-- First read happens at startup, before any effect; a narrowed view would mean one already ran.
		rest = if current >= 50 and current <= 120 then current else DEFAULT
	end
	return rest :: number
end

return CameraFov

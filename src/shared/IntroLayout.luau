-- Where the intro hunt's glade sits and its key spots (IntroBuilder builds it, IntroService moves
-- players there, IntroController runs the hunt). Pure. Glade space: X right, -Z forward along the
-- trail, Y up from the ground top. The glade is far out along the Haunted Forest's angle, past the
-- wild's terrain, so the client ambience reads it as deep forest (fog, rain, wild music).

local IntroLayout = {}

local ANGLE = math.rad(22.5)
local RADIUS = 2200

IntroLayout.Origin = CFrame.new(math.cos(ANGLE) * RADIUS, 0, math.sin(ANGLE) * RADIUS)

-- Ground footprint (studs): the trail runs from +Back to -Front.
IntroLayout.HalfWidth = 46
IntroLayout.Back = 30
IntroLayout.Front = 245

-- Where the player wakes, facing down the trail.
IntroLayout.Wake = Vector3.new(0, 0, 0)

-- The spirit's hiding spots in order; the last is the shrine clearing where it is sealed. Each
-- comes with the curve it flees along to get there.
IntroLayout.Spots = {
	{ At = Vector3.new(8, 0, -62), Path = { Vector3.new(-2, 0, -22), Vector3.new(10, 0, -44) } },
	{ At = Vector3.new(-22, 0, -128), Path = { Vector3.new(14, 0, -84), Vector3.new(-6, 0, -108) } },
	{ At = Vector3.new(0, 0, -206), Path = { Vector3.new(-30, 0, -152), Vector3.new(-14, 0, -184) } },
}

-- The trail the flagstones follow (wake point, spots and the curves between).
function IntroLayout.trail(): { Vector3 }
	local points = { IntroLayout.Wake }
	for _, spot in IntroLayout.Spots do
		for _, point in spot.Path do
			table.insert(points, point)
		end
		table.insert(points, spot.At)
	end
	return points
end

-- Glade space -> world.
function IntroLayout.world(point: Vector3): Vector3
	return IntroLayout.Origin:PointToWorldSpace(point)
end

function IntroLayout.frame(point: Vector3, facing: Vector3?): CFrame
	local at = IntroLayout.world(point)
	local look = IntroLayout.Origin:VectorToWorldSpace(facing or Vector3.new(0, 0, -1))
	return CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z))
end

return IntroLayout

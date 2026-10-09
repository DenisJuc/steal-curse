-- Placeholder relic shapes by object type, until Slice 8 imports real models. Shared by the
-- server pedestals and the client reveals (projections and the reveal viewport).

local RelicShapes = {}

-- Part properties for a relic shape centred at `at`, scaled by `scale` (default 1).
function RelicShapes.props(objectType: string, at: CFrame, scale: number?): { [string]: any }
	local s = scale or 1
	if objectType == "Weapon" then
		return {
			Size = Vector3.new(0.5, 4.2, 0.5) * s,
			CFrame = at * CFrame.new(0, 0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(20)),
		}
	elseif objectType == "Book" then
		return { Size = Vector3.new(2.2, 0.6, 1.7) * s, CFrame = at * CFrame.Angles(math.rad(-15), 0, 0) }
	elseif objectType == "Mask" then
		return {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 2.4, 2.4) * s,
			CFrame = at * CFrame.new(0, 0.4 * s, 0),
		}
	elseif objectType == "Crystal" then
		return {
			Size = Vector3.new(1.3, 2.6, 1.3) * s,
			CFrame = at * CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(0, math.rad(45), 0),
		}
	end
	return { Shape = Enum.PartType.Ball, Size = Vector3.new(1.9, 1.9, 1.9) * s, CFrame = at }
end

return RelicShapes

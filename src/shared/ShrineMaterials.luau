-- Shrine materials (2026-11-08): MaterialVariants made with Studio's material generator. Game
-- scripts may not set a MaterialVariant's texture properties (that needs Plugin capability), so the
-- variants themselves live in assets/Materials/ShrineMaterials.model.json, which Rojo builds into
-- MaterialService. This module only names them and says which town parts wear which one. Pure
-- (Lune-tested; the spec also checks the model file).

local ShrineMaterials = {}

-- Names of the variants in MaterialService.ShrineMaterials, with the base Material each needs.
ShrineMaterials.Base = {
	-- Dark diamond slate tiles: plot courtyards and the hub plaza.
	ShrineSlateTile = "Slate",
	-- Old stone blocks with moss in the seams: plot walls.
	ShrineMossWall = "Brick",
	-- Dark worn lacquered wood: kiosks and the Seal Shrine.
	ShrineLacquerWood = "Wood",
	-- Irregular flagstones: the processional path through each plot.
	ShrineFlagstone = "Cobblestone",
} :: { [string]: string }

-- Part name -> material, inside a plot or the hub. `Wood` parts of kiosks and the Seal Shrine get
-- the lacquer by their material instead (see ShrineMaterials.forPart).
ShrineMaterials.ByPartName = {
	Floor = "ShrineSlateTile",
	Plaza = "ShrineSlateTile",
	Wall = "ShrineMossWall",
	Path = "ShrineFlagstone",
} :: { [string]: string }

-- Models whose wooden parts take the lacquer.
ShrineMaterials.LacquerModels = { SealShrine = true, Kiosk = true } :: { [string]: boolean }

-- The material variant for a part, or nil to leave it alone. `material` is the part's current
-- Material name and `modelName` the name of the model it sits in (kiosks end in "Kiosk").
function ShrineMaterials.forPart(name: string, material: string, modelName: string?): string?
	local byName = ShrineMaterials.ByPartName[name]
	if byName then
		return byName
	end
	if (material == "Wood" or material == "WoodPlanks") and modelName then
		local key = if string.sub(modelName, -5) == "Kiosk" then "Kiosk" else modelName
		if ShrineMaterials.LacquerModels[key] then
			return "ShrineLacquerWood"
		end
	end
	return nil
end

return ShrineMaterials

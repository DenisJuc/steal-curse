-- Shrine materials (ShrineMaterials): complete asset data and the part rules.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local ShrineMaterials = require("../../src/shared/ShrineMaterials")
local expect = require("../lib/expect")

return {
	{
		Name = "variants: the Rojo model file has every named variant, its base and four asset maps",
		Run = function()
			local model = serde.decode("json", fs.readFile("assets/Materials/ShrineMaterials.model.json"))
			local found = {}
			for _, child in model.children do
				expect.equal(child.className, "MaterialVariant", `{child.name} is a MaterialVariant`)
				local props = child.properties
				found[child.name] = true
				expect.equal(props.BaseMaterial, ShrineMaterials.Base[child.name], `{child.name} base matches the module`)
				for _, key in { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" } do
					local id = props[key]
					expect.truthy(type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil, `{child.name} {key} is an asset id`)
				end
				expect.truthy(props.StudsPerTile > 0, `{child.name} tile size`)
			end
			for name in ShrineMaterials.Base do
				expect.truthy(found[name], `{name} is in the model file`)
			end
			for part, name in ShrineMaterials.ByPartName do
				expect.truthy(ShrineMaterials.Base[name] ~= nil, `{part} uses a known material`)
			end
		end,
	},
	{
		Name = "rules: floors, walls and paths by name; lacquer only on kiosk and Seal Shrine wood",
		Run = function()
			expect.equal(ShrineMaterials.forPart("Floor", "Limestone", "Plot1"), "ShrineSlateTile", "courtyard floor")
			expect.equal(ShrineMaterials.forPart("Plaza", "Slate", "Hub"), "ShrineSlateTile", "hub plaza")
			expect.equal(ShrineMaterials.forPart("Wall", "Slate", "Plot3"), "ShrineMossWall", "plot wall")
			expect.equal(ShrineMaterials.forPart("Path", "Cobblestone", "Plot2"), "ShrineFlagstone", "processional path")
			expect.equal(ShrineMaterials.forPart("Counter", "Wood", "CodexKiosk"), "ShrineLacquerWood", "kiosk wood")
			expect.equal(ShrineMaterials.forPart("Hokora", "Wood", "SealShrine"), "ShrineLacquerWood", "seal shrine wood")
			expect.equal(ShrineMaterials.forPart("Counter", "Slate", "CodexKiosk"), nil, "only wood gets lacquer")
			expect.equal(ShrineMaterials.forPart("Trunk", "Wood", "HomeBlossomTree"), nil, "props keep their own look")
			expect.equal(ShrineMaterials.forPart("Capstone", "Basalt", "Plot1"), nil, "unlisted parts untouched")
		end,
	},
}
